#!/usr/bin/env python3
"""Gemini nutrition accuracy evaluator.

This script evaluates Gemini nutrition estimation accuracy on 100 random
samples from Hugging Face dataset `mmathys/food-nutrients`.

The evaluator uses the app-aligned meal analysis contract (Supabase Edge
Function `analyze-meal`) while computing accuracy against dataset totals:
`total_calories`, `total_mass`, `total_fat`, `total_carb`, `total_protein`.

Key features:
- Deterministic sampling (seed=42)
- Structured JSON prompting for Gemini
- Per-sample error tracking and detailed CSV output
- Summary report with MAPE per nutrient
- Resume support via progress log (failed samples are retried on next start)
- Retry with exponential backoff for transient/rate-limit errors
- CLI model switching with clear model-specific reporting
- Full comparison reset whenever model is changed

Usage:
    cp .env.example .env
    # Fill GEMINI_API_KEY in .env
    python tools/accuracyComparsion/gemini_food_accuracy_eval.py
    python tools/accuracyComparsion/gemini_food_accuracy_eval.py --model gemini-3.1-flash-lite
    python tools/accuracyComparsion/gemini_food_accuracy_eval.py --model gemini-3.1-flash-lite --rpm-limit 15
    python tools/accuracyComparsion/gemini_food_accuracy_eval.py --model gemini-2.5-flash --rpm-limit 4 --rpd-limit 19 --auto-wait-daily-quota
    # Host timezone is auto-detected for daily reset estimation.
    python tools/accuracyComparsion/gemini_food_accuracy_eval.py --model gemini-2.5-flash --rpm-limit 4 --rpd-limit 19 --auto-wait-daily-quota --daily-reset-timezone Asia/Hong_Kong

Dependencies:
    pip install datasets pillow google-genai python-dotenv

Python:
    Use Python 3.10-3.13. Python 3.14 currently has a known incompatibility
    with Hugging Face datasets/dill pickling internals.
"""

from __future__ import annotations

import argparse
import csv
from collections import deque
from datetime import datetime, timedelta
import io
import json
import logging
import os
import random
import re
import statistics
import sys
import time
from dataclasses import dataclass, replace
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Tuple
from zoneinfo import ZoneInfo

from google import genai
from google.genai import types as genai_types
from datasets import load_dataset
from dotenv import load_dotenv
from huggingface_hub import hf_hub_download
from PIL import Image


# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
@dataclass(frozen=True)
class EvalConfig:
    """Runtime configuration for the evaluator."""

    # Dataset settings
    dataset_name: str = "mmathys/food-nutrients"
    dataset_split: str = "test"
    sample_size: int = 100
    random_seed: int = 42

    # Gemini settings
    model_name: str = "gemini-3.1-flash-lite-preview"
    api_key_env_var: str = "GEMINI_API_KEY"
    request_timeout_seconds: int = 90

    # Gemini quota policy (configure based on dashboard limits)
    gemini_rpm_limit: int = 15
    gemini_tpm_limit: int = 250_000
    gemini_rpd_limit: int = 500
    tpm_utilization_target: float = 1.0
    estimated_tokens_per_request: int = 3_500
    rate_limit_buffer_seconds: float = 0.0

    # Retry settings
    max_retries: int = 6
    initial_backoff_seconds: float = 2.0
    backoff_multiplier: float = 2.0
    max_backoff_seconds: float = 60.0
    # Optional extra delay after each sample, in addition to quota throttling.
    inter_request_sleep_seconds: float = 0.0
    daily_quota_reset_timezone: str = "America/Los_Angeles"

    # Output settings
    output_dir: Path = Path(__file__).resolve().parent / "outputs"
    detailed_csv_file: str = "detailed_results.csv"
    progress_jsonl_file: str = "progress.jsonl"
    summary_txt_file: str = "summary_report.txt"
    log_file: str = "run.log"
    run_context_file: str = "last_run_context.json"


CFG = EvalConfig()


# Friendly aliases for model names that users commonly type.
MODEL_NAME_ALIASES: Dict[str, str] = {
    "gemini-3.1-flash-lite": "gemini-3.1-flash-lite-preview",
}


MIN_PYTHON: Tuple[int, int] = (3, 10)
MAX_PYTHON_EXCLUSIVE: Tuple[int, int] = (3, 14)


# Public schema required keys from metadata records.
SCHEMA_REQUIRED_KEYS: Tuple[str, ...] = (
    "id",
    "split",
    "ingredients",
    "total_calories",
    "total_mass",
    "total_fat",
    "total_carb",
    "total_protein",
)


# Image source may come from decoded dataset image or metadata file path.
SCHEMA_IMAGE_SOURCE_KEYS: Tuple[str, ...] = (
    "image",
    "file_name",
)


# Public schema ingredient keys.
SCHEMA_INGREDIENT_KEYS: Tuple[str, ...] = (
    "id",
    "name",
    "grams",
    "calories",
    "fat",
    "carb",
    "protein",
)


# Evaluation targets strictly following dataset total fields.
EVAL_FIELDS: Tuple[str, ...] = (
    "total_calories",
    "total_protein",
    "total_carb",
    "total_fat",
    "total_mass",
)


FIELD_DISPLAY_NAMES: Dict[str, str] = {
    "total_calories": "total_calories (kcal)",
    "total_protein": "total_protein (g)",
    "total_carb": "total_carb (g)",
    "total_fat": "total_fat (g)",
    "total_mass": "total_mass (g)",
}


# Fallback mapping from total fields to ingredient-level fields.
INGREDIENT_FALLBACK_KEYS: Dict[str, Tuple[str, ...]] = {
    "total_calories": ("calories",),
    "total_protein": ("protein",),
    "total_carb": ("carb",),
    "total_fat": ("fat",),
    # App contract supports solids via grams and drinks via ml.
    "total_mass": ("grams", "ml"),
}


RESPONSE_SCHEMA: Dict[str, Any] = {
    "type": "object",
    "properties": {
        "ingredients": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "id": {"type": "string"},
                    "name": {"type": "string"},
                    "grams": {"anyOf": [{"type": "number"}, {"type": "null"}]},
                    "ml": {"anyOf": [{"type": "number"}, {"type": "null"}]},
                    "calories": {"type": "number"},
                    "fat": {"type": "number"},
                    "carb": {"type": "number"},
                    "protein": {"type": "number"},
                    "sugar": {"type": "number"},
                    "confidence": {"type": "number"},
                },
                "required": [
                    "id",
                    "name",
                    "calories",
                    "fat",
                    "carb",
                    "protein",
                    "sugar",
                    "confidence",
                ],
                "additionalProperties": False,
            },
        },
        "total_calories": {"type": "number"},
        "total_mass": {"type": "number"},
        "total_fat": {"type": "number"},
        "total_carb": {"type": "number"},
        "total_protein": {"type": "number"},
        "total_sugar": {"anyOf": [{"type": "number"}, {"type": "null"}]},
        "error": {"anyOf": [{"type": "string"}, {"type": "null"}]},
    },
    "required": [
        "ingredients",
        "total_calories",
        "total_mass",
        "total_fat",
        "total_carb",
        "total_protein",
    ],
    "additionalProperties": False,
}


def csv_columns() -> List[str]:
    """Return deterministic CSV columns for per-sample details."""
    cols = [
        "image_id",
        "run_model",
        "status",
        "error_message",
        "model_id",
        "model_split",
        "id_match",
        "split_match",
    ]
    for field in EVAL_FIELDS:
        cols.extend(
            [
                f"ground_truth_{field}",
                f"gemini_{field}",
                f"abs_error_{field}",
                f"pct_error_{field}",
            ],
        )
    cols.append("raw_model_json")
    return cols


def validate_public_schema(dataset: Any) -> None:
    """Fail fast when the loaded dataset does not match expected public schema."""
    if len(dataset) == 0:
        raise ValueError("Dataset split is empty.")

    probe = dataset[0]

    missing_required = [
        key for key in SCHEMA_REQUIRED_KEYS if key not in probe]
    if missing_required:
        raise ValueError(
            "Dataset schema mismatch. Missing required keys: "
            + ", ".join(missing_required),
        )

    has_image_source = any(key in probe for key in SCHEMA_IMAGE_SOURCE_KEYS)
    if not has_image_source:
        raise ValueError(
            "Dataset schema mismatch. Missing image source key: "
            "expected one of image or file_name.",
        )

    ingredients = probe.get("ingredients")
    if isinstance(ingredients, list) and ingredients:
        ingredient_probe = ingredients[0]
        if isinstance(ingredient_probe, dict):
            missing_ingredient = [
                key for key in SCHEMA_INGREDIENT_KEYS if key not in ingredient_probe
            ]
            if missing_ingredient:
                raise ValueError(
                    "Dataset schema mismatch. Missing ingredient keys: "
                    + ", ".join(missing_ingredient),
                )
        else:
            raise ValueError(
                "Dataset schema mismatch. Ingredient entries are not objects.",
            )
    else:
        logging.warning(
            "Schema check warning: first sample has no ingredient entries. "
            "Continuing with top-level schema validation only.",
        )


def setup_logging(config: EvalConfig) -> None:
    """Configure console and file logging."""
    config.output_dir.mkdir(parents=True, exist_ok=True)
    log_path = config.output_dir / config.log_file

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s | %(levelname)s | %(message)s",
        handlers=[
            logging.StreamHandler(),
            logging.FileHandler(log_path, encoding="utf-8"),
        ],
    )


def load_env_vars(config: EvalConfig) -> None:
    """Load environment variables from .env if available."""
    script_dir = Path(__file__).resolve().parent
    env_path = script_dir / ".env"

    # Load local .env first (next to script), then current working directory.
    if env_path.exists():
        load_dotenv(dotenv_path=env_path, override=False)
    load_dotenv(override=False)


def assert_supported_python_version() -> None:
    """Validate Python version compatibility for this evaluator."""
    version = sys.version_info[:2]
    if version < MIN_PYTHON or version >= MAX_PYTHON_EXCLUSIVE:
        current = f"{sys.version_info.major}.{sys.version_info.minor}"
        raise RuntimeError(
            "Unsupported Python version for this evaluator. "
            f"Current: {current}. "
            "Please use Python 3.10-3.13 (recommended: 3.11) and recreate the venv.",
        )


def model_slug(model_name: str) -> str:
    """Create a filesystem-safe folder name from model name."""
    slug = re.sub(r"[^a-z0-9]+", "_", model_name.lower()).strip("_")
    return slug or "unknown_model"


def resolve_model_name(model_name: str) -> str:
    """Resolve user-provided model names to canonical API model ids."""
    normalized = model_name.strip()
    if not normalized:
        return normalized
    return MODEL_NAME_ALIASES.get(normalized.lower(), normalized)


def parse_cli_args(config: EvalConfig, argv: Optional[List[str]] = None) -> argparse.Namespace:
    """Parse optional runtime overrides from CLI arguments."""
    detected_reset_tz = detect_host_timezone_name(
        config.daily_quota_reset_timezone)

    parser = argparse.ArgumentParser(
        description=(
            "Evaluate Gemini nutrition accuracy on mmathys/food-nutrients "
            "with deterministic sampling."
        ),
    )
    parser.add_argument(
        "--model",
        default=config.model_name,
        help=(
            "Gemini model to evaluate (default: %(default)s). "
            "Alias: gemini-3.1-flash-lite -> gemini-3.1-flash-lite-preview"
        ),
    )
    parser.add_argument(
        "--rpm-limit",
        type=int,
        default=config.gemini_rpm_limit,
        help="Requests-per-minute limit (default: %(default)s).",
    )
    parser.add_argument(
        "--tpm-limit",
        type=int,
        default=config.gemini_tpm_limit,
        help="Tokens-per-minute limit (default: %(default)s).",
    )
    parser.add_argument(
        "--rpd-limit",
        type=int,
        default=config.gemini_rpd_limit,
        help="Requests-per-day limit (default: %(default)s).",
    )
    parser.add_argument(
        "--sample-size",
        type=int,
        default=config.sample_size,
        help="Number of deterministic samples to evaluate (default: %(default)s).",
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=config.random_seed,
        help="Random seed for deterministic sampling (default: %(default)s).",
    )
    parser.add_argument(
        "--force-fresh",
        action="store_true",
        help="Reset current model outputs and rerun from scratch.",
    )
    parser.add_argument(
        "--auto-wait-daily-quota",
        action="store_true",
        help=(
            "When daily quota is exhausted, sleep until quota is likely available "
            "and continue automatically."
        ),
    )
    parser.add_argument(
        "--daily-reset-timezone",
        default=detected_reset_tz,
        help=(
            "IANA timezone used to estimate daily quota reset time "
            "(default: auto-detected host timezone, current=%(default)s)."
        ),
    )
    return parser.parse_args(argv)


def is_valid_iana_timezone(timezone_name: str) -> bool:
    """Return whether timezone_name is a valid IANA timezone."""
    if not timezone_name.strip():
        return False

    try:
        ZoneInfo(timezone_name)
        return True
    except Exception:
        return False


def detect_host_timezone_name(fallback_timezone: str) -> str:
    """Detect host IANA timezone, falling back when detection is inconclusive."""
    env_tz = os.environ.get("TZ", "").strip()
    if env_tz and is_valid_iana_timezone(env_tz):
        return env_tz

    local_tz = datetime.now().astimezone().tzinfo
    zone_key = getattr(local_tz, "key", None)
    if isinstance(zone_key, str) and is_valid_iana_timezone(zone_key):
        return zone_key

    # Best-effort fallback for systems where /etc/localtime points into zoneinfo.
    try:
        resolved = Path("/etc/localtime").resolve()
        marker = "/zoneinfo/"
        resolved_text = resolved.as_posix()
        if marker in resolved_text:
            candidate = resolved_text.split(marker, 1)[1]
            if is_valid_iana_timezone(candidate):
                return candidate
    except OSError:
        pass

    return fallback_timezone


def parse_quota_wait_seconds(message: str) -> Optional[int]:
    """Parse a suggested wait duration in seconds from quota error message."""
    match = re.search(
        r"approximately\s+([0-9]+)\s+seconds", message, re.IGNORECASE)
    if match:
        return int(match.group(1))

    match = re.search(
        r"retry in\s+([0-9]+(?:\.[0-9]+)?)s", message, re.IGNORECASE)
    if match:
        return max(1, int(float(match.group(1))))

    return None


def seconds_until_next_daily_reset(timezone_name: str) -> int:
    """Estimate seconds until next daily reset at local midnight in timezone."""
    try:
        tz = ZoneInfo(timezone_name)
    except Exception:
        logging.warning(
            "Invalid timezone '%s'. Falling back to UTC for reset estimate.", timezone_name)
        tz = ZoneInfo("UTC")

    now = datetime.now(tz)
    next_reset = (now + timedelta(days=1)).replace(
        hour=0,
        minute=0,
        second=5,
        microsecond=0,
    )
    return max(1, int((next_reset - now).total_seconds()))


def choose_daily_quota_wait_seconds(
    message: str,
    reset_timezone: str,
) -> Tuple[int, str]:
    """Choose a wait strategy for daily quota exhaustion.

    Prefer timezone reset estimate when provider retry hint is very short
    (for example 59s) but daily quota exhaustion was detected.
    """
    provider_wait = parse_quota_wait_seconds(message)
    reset_wait = seconds_until_next_daily_reset(reset_timezone)

    if provider_wait is None:
        return reset_wait, f"estimated next daily reset in {reset_timezone}"

    # Daily quota errors may still include short retry hints. Use reset estimate
    # when hint looks minute-level but reset estimate is much longer.
    if provider_wait < 900 and reset_wait > 1800:
        return reset_wait, (
            f"provider hint={provider_wait}s looked short; "
            f"using estimated reset in {reset_timezone}"
        )

    return max(30, provider_wait), "provider retry hint"


def warn_if_quota_seems_too_high(config: EvalConfig) -> None:
    """Warn when configured limits exceed common Gemini 2.5 Flash free-tier limits."""
    model = config.model_name.strip().lower()
    if model != "gemini-2.5-flash":
        return

    if config.gemini_rpm_limit > 5:
        logging.warning(
            "Configured RPM=%d exceeds common free-tier RPM=5 for gemini-2.5-flash.",
            config.gemini_rpm_limit,
        )

    if config.gemini_rpd_limit > 20:
        logging.warning(
            "Configured RPD=%d exceeds common free-tier RPD=20 for gemini-2.5-flash.",
            config.gemini_rpd_limit,
        )


def load_run_context(context_path: Path) -> Dict[str, Any]:
    """Load last run context metadata if available."""
    if not context_path.exists():
        return {}

    try:
        with context_path.open("r", encoding="utf-8") as f:
            payload = json.load(f)
        if isinstance(payload, dict):
            return payload
    except (json.JSONDecodeError, OSError):
        pass

    return {}


def save_run_context(context_path: Path, payload: Dict[str, Any]) -> None:
    """Persist run context metadata for future model-switch detection."""
    context_path.parent.mkdir(parents=True, exist_ok=True)
    with context_path.open("w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=True, indent=2)


def clear_run_artifacts(paths: Iterable[Path]) -> None:
    """Delete run artifacts if they exist."""
    for path in paths:
        try:
            if path.exists() and path.is_file():
                path.unlink()
        except OSError:
            logging.warning("Unable to delete stale artifact: %s", path)


class QuotaRateLimiter:
    """Minute-bucket limiter for RPM/TPM with hard guard for RPD.

    Behavior is intentionally strict for user-configured RPM policies:
    send up to `rpm_limit` requests inside the current minute bucket,
    then sleep until the next minute window.
    """

    def __init__(
        self,
        rpm_limit: int,
        tpm_limit: int,
        rpd_limit: int,
        tpm_utilization_target: float,
        estimated_tokens_per_request: int,
        buffer_seconds: float,
    ) -> None:
        self.rpm_limit = max(1, rpm_limit)
        self.tpm_limit = max(1, tpm_limit)
        self.rpd_limit = max(1, rpd_limit)
        self.tpm_budget = max(1, int(self.tpm_limit * tpm_utilization_target))
        self.estimated_tokens_per_request = max(
            1, estimated_tokens_per_request)
        self.buffer_seconds = max(0.0, buffer_seconds)

        self._day_request_times: deque[float] = deque()
        self._minute_window_start: Optional[float] = None
        self._minute_request_count = 0
        self._minute_token_count = 0

    def _prune_day(self, now: float) -> None:
        while self._day_request_times and (now - self._day_request_times[0]) >= 86400.0:
            self._day_request_times.popleft()

    def _reset_minute_window(self, now: float) -> None:
        self._minute_window_start = now
        self._minute_request_count = 0
        self._minute_token_count = 0

    def _seconds_until_next_window(self, now: float) -> float:
        if self._minute_window_start is None:
            return 0.0
        elapsed = now - self._minute_window_start
        return max(0.0, 60.0 - elapsed + self.buffer_seconds)

    def acquire(self) -> None:
        """Block until a new request can be sent under configured quotas."""
        while True:
            now = time.time()
            self._prune_day(now)

            if len(self._day_request_times) >= self.rpd_limit:
                oldest = self._day_request_times[0]
                wait_seconds = max(1, int(86400 - (now - oldest)))
                raise QuotaExhaustedError(
                    "Daily Gemini quota reached (RPD limit). "
                    f"Please retry after approximately {wait_seconds} seconds.",
                )

            if self._minute_window_start is None or (now - self._minute_window_start) >= 60.0:
                self._reset_minute_window(now)

            if self._minute_request_count >= self.rpm_limit:
                wait_seconds = self._seconds_until_next_window(now)
                logging.info(
                    "Minute request quota reached (%d/%d). Sleeping %.2fs before next batch.",
                    self._minute_request_count,
                    self.rpm_limit,
                    wait_seconds,
                )
                time.sleep(wait_seconds)
                continue

            if self._minute_token_count + self.estimated_tokens_per_request > self.tpm_budget:
                wait_seconds = self._seconds_until_next_window(now)
                logging.info(
                    "Minute token quota reached (%d/%d). Sleeping %.2fs before next batch.",
                    self._minute_token_count,
                    self.tpm_budget,
                    wait_seconds,
                )
                time.sleep(wait_seconds)
                continue

            break

        now = time.time()
        if self._minute_window_start is None or (now - self._minute_window_start) >= 60.0:
            self._reset_minute_window(now)

        self._minute_request_count += 1
        self._minute_token_count += self.estimated_tokens_per_request
        self._day_request_times.append(now)


class QuotaExhaustedError(RuntimeError):
    """Raised when the daily request quota is exhausted."""


class FatalModelConfigError(RuntimeError):
    """Raised when model configuration is invalid and run should stop immediately."""


def optional_float(value: Any) -> Optional[float]:
    """Convert value to float when possible, otherwise return None."""
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str):
        stripped = value.strip()
        if not stripped:
            return None
        try:
            return float(stripped)
        except ValueError:
            return None
    return None


def first_numeric(source: Dict[str, Any], keys: Iterable[str]) -> Optional[float]:
    """Find the first numeric value in source for any key in keys."""
    for key in keys:
        if key in source:
            parsed = optional_float(source.get(key))
            if parsed is not None:
                return parsed
    return None


def sum_ingredient_nutrient(
    ingredients: Any,
    ingredient_keys: Tuple[str, ...],
) -> Optional[float]:
    """Sum a nutrient from ingredient entries if the field exists."""
    if not isinstance(ingredients, list):
        return None

    values: List[float] = []
    for ingredient in ingredients:
        if not isinstance(ingredient, dict):
            continue
        value = first_numeric(ingredient, ingredient_keys)
        if value is not None:
            values.append(value)

    if not values:
        return None
    return float(sum(values))


def extract_ground_truth(sample: Dict[str, Any]) -> Dict[str, Optional[float]]:
    """Extract ground-truth totals from schema-defined fields."""
    gt: Dict[str, Optional[float]] = {}
    ingredients = sample.get("ingredients")

    for field in EVAL_FIELDS:
        value = first_numeric(sample, (field,))
        if value is None:
            value = sum_ingredient_nutrient(
                ingredients=ingredients,
                ingredient_keys=INGREDIENT_FALLBACK_KEYS[field],
            )
        gt[field] = value

    return gt


def get_image_id(sample: Dict[str, Any], fallback_index: int) -> str:
    """Read sample id safely, with deterministic fallback."""
    sample_id = sample.get("id")
    if isinstance(sample_id, str) and sample_id.strip():
        return sample_id.strip()
    return f"sample_{fallback_index:04d}"


def load_pil_image(
    sample: Dict[str, Any],
    dataset_name: str,
    snapshot_root: Path,
) -> Image.Image:
    """Load image as RGB PIL from decoded object or metadata file_name path."""
    image_obj = sample.get("image")

    if isinstance(image_obj, Image.Image):
        pil_image: Image.Image = image_obj
        return pil_image.convert("RGB")

    if isinstance(image_obj, dict):
        image_bytes = image_obj.get("bytes")
        image_path = image_obj.get("path")

        if image_bytes:
            return Image.open(io.BytesIO(image_bytes)).convert("RGB")
        if image_path:
            return Image.open(image_path).convert("RGB")

    file_name = sample.get("file_name")
    if isinstance(file_name, str) and file_name.strip():
        local_image_path = snapshot_root / file_name
        if local_image_path.exists():
            return Image.open(local_image_path).convert("RGB")

        cached_path = hf_hub_download(
            repo_id=dataset_name,
            filename=file_name,
            repo_type="dataset",
        )
        return Image.open(cached_path).convert("RGB")

    raise ValueError("Unable to load image from dataset sample.")


def build_prompt(image_id: str) -> str:
    """Build strict prompt aligned with app analyze-meal contract."""
    return f"""
You are a professional nutritionist specialising in analysing food and drink photos from any cuisine.

Core capabilities:
- All cuisines: Western, Japanese/Korean, Southeast Asian, Chinese, Hong Kong-style.
- Familiar with Hong Kong local food (cha chaan teng, dai pai dong, dim sum, street snacks).

Sample reference id for evaluator bookkeeping only: {image_id}

Return one JSON object only (no markdown, no code fence, no extra text).

The JSON must strictly follow this app contract:
{{
    "ingredients": [
        {{
            "id": string,
            "name": string,
            "grams": number|null,
            "ml": number|null,
            "calories": number,
            "fat": number,
            "carb": number,
            "protein": number,
            "sugar": number,
            "confidence": number
        }}
    ],
    "total_calories": number,
    "total_mass": number,
    "total_fat": number,
    "total_carb": number,
    "total_protein": number,
    "total_sugar": number|null,
    "error": string|null
}}

Rules:
1) Ingredient id should follow ingr_########## format (example: ingr_0000000192).
2) Solid food: grams > 0 and ml = null.
3) Liquid/drink: ml > 0 and grams = null.
4) Never set both grams and ml to non-null values.
5) confidence must be between 0.0 and 1.0.
6) All numeric values must be non-negative.
7) Totals should match ingredient sums as closely as possible.
8) If no food/drink or image is unclear: return ingredients as [], set all totals to 0, set error to a short reason.
""".strip()


def extract_response_text(response: Any) -> str:
    """Extract plain response text from Gemini SDK response object."""
    text = getattr(response, "text", None)
    if isinstance(text, str) and text.strip():
        return text.strip()

    # Fallback path for older/alternative SDK response shapes.
    candidates = getattr(response, "candidates", None)
    if isinstance(candidates, list) and candidates:
        content = getattr(candidates[0], "content", None)
        parts = getattr(content, "parts", None) if content else None
        if isinstance(parts, list) and parts:
            part_text = getattr(parts[0], "text", None)
            if isinstance(part_text, str) and part_text.strip():
                return part_text.strip()

    raise ValueError("Gemini response does not contain text output.")


def parse_json_strict(raw_text: str) -> Dict[str, Any]:
    """Parse strict JSON; fallback to first JSON object if needed."""
    try:
        parsed = json.loads(raw_text)
        if isinstance(parsed, dict):
            return parsed
    except json.JSONDecodeError:
        pass

    # Defensive fallback in case of accidental wrapper text.
    match = re.search(r"\{.*\}", raw_text, flags=re.DOTALL)
    if match:
        parsed = json.loads(match.group(0))
        if isinstance(parsed, dict):
            return parsed

    raise ValueError("Model output is not a valid JSON object.")


def extract_response_payload(response: Any) -> Dict[str, Any]:
    """Extract JSON payload from structured response or fallback text parsing."""
    parsed = getattr(response, "parsed", None)
    if isinstance(parsed, dict):
        return parsed

    if parsed is not None and hasattr(parsed, "model_dump"):
        dumped = parsed.model_dump()
        if isinstance(dumped, dict):
            return dumped

    raw_text = extract_response_text(response)
    try:
        return parse_json_strict(raw_text)
    except ValueError as exc:
        preview = " ".join(raw_text.strip().split())[:500]
        raise ValueError(
            "Model output is not a valid JSON object. "
            f"Raw preview: {preview}",
        ) from exc


def normalize_prediction(payload: Dict[str, Any]) -> Dict[str, Optional[float]]:
    """Normalize Gemini payload into schema-aligned total fields."""
    normalized: Dict[str, Optional[float]] = {}
    ingredients = payload.get("ingredients")

    for field in EVAL_FIELDS:
        value = first_numeric(payload, (field,))
        if value is None:
            value = sum_ingredient_nutrient(
                ingredients=ingredients,
                ingredient_keys=INGREDIENT_FALLBACK_KEYS[field],
            )
        normalized[field] = value

    return normalized


def is_retryable_exception(exc: Exception) -> bool:
    """Identify transient failures (rate limit, timeout, temporary server errors)."""
    message = str(exc).lower()
    retry_signals = (
        "429",
        "rate limit",
        "quota",
        "resource exhausted",
        "timeout",
        "timed out",
        "deadline",
        "503",
        "502",
        "500",
        "temporarily unavailable",
        "unavailable",
        "internal",
        "connection reset",
    )
    return any(signal in message for signal in retry_signals)


def is_model_not_found_exception(exc: Exception) -> bool:
    """Return True when API error indicates invalid/unsupported model id."""
    message = str(exc).lower()
    return (
        "404" in message
        and "not_found" in message
        and "models/" in message
        and "generatecontent" in message
    )


def is_daily_quota_exhausted_exception(exc: Exception) -> bool:
    """Return True when API error indicates per-day request quota exhaustion."""
    message = str(exc).lower()
    daily_markers = (
        "generaterequestsperday",
        "perday",
        "requests, limit: 20",
        "generate_content_free_tier_requests",
    )
    return "resource_exhausted" in message and any(m in message for m in daily_markers)


def extract_retry_delay_seconds(exc: Exception) -> Optional[float]:
    """Extract server-suggested retry delay in seconds if present."""
    message = str(exc)

    match = re.search(
        r"retry in\s+([0-9]+(?:\.[0-9]+)?)s", message, flags=re.IGNORECASE)
    if match:
        return float(match.group(1))

    match = re.search(r"['\"]retryDelay['\"]:\s*['\"]([0-9]+)s['\"]", message)
    if match:
        return float(match.group(1))

    return None


def call_gemini_with_retry(
    client: genai.Client,
    image: Image.Image,
    image_id: str,
    config: EvalConfig,
    rate_limiter: QuotaRateLimiter,
) -> Tuple[Dict[str, Optional[float]], Dict[str, Any]]:
    """Call Gemini with retry/backoff and parse prediction payload."""
    prompt = build_prompt(image_id=image_id)
    backoff_seconds = config.initial_backoff_seconds

    for attempt in range(1, config.max_retries + 1):
        try:
            rate_limiter.acquire()
            response = client.models.generate_content(
                model=config.model_name,
                contents=[prompt, image],
                config=genai_types.GenerateContentConfig(
                    temperature=0.0,
                    responseMimeType="application/json",
                    responseJsonSchema=RESPONSE_SCHEMA,
                    # Disable thinking tokens so JSON output is not truncated by MAX_TOKENS.
                    thinkingConfig=genai_types.ThinkingConfig(
                        thinkingBudget=0),
                    maxOutputTokens=2048,
                ),
            )

            payload = extract_response_payload(response)
            prediction = normalize_prediction(payload)
            return prediction, payload

        except QuotaExhaustedError:
            raise

        except Exception as exc:
            if is_model_not_found_exception(exc):
                raise FatalModelConfigError(
                    "Gemini model is not available for generateContent. "
                    f"Configured model: {config.model_name}. "
                    "Use a valid model id (for Flash Lite use: "
                    "gemini-3.1-flash-lite-preview)."
                ) from exc

            if is_daily_quota_exhausted_exception(exc):
                retry_delay = extract_retry_delay_seconds(exc)
                delay_text = (
                    f"{retry_delay:.0f} seconds"
                    if retry_delay is not None
                    else "the next daily quota window"
                )
                raise QuotaExhaustedError(
                    "Daily Gemini API request quota is exhausted according to API response. "
                    f"Suggested retry after approximately {delay_text}.",
                ) from exc

            retryable = is_retryable_exception(exc)
            is_last_attempt = attempt >= config.max_retries

            if (not retryable) or is_last_attempt:
                raise

            retry_delay = extract_retry_delay_seconds(exc)
            if retry_delay is not None:
                sleep_seconds = min(retry_delay, config.max_backoff_seconds)
            else:
                sleep_seconds = min(
                    backoff_seconds, config.max_backoff_seconds)

            jitter = random.uniform(0.0, 0.5)
            total_sleep = sleep_seconds + jitter

            logging.warning(
                "Retryable Gemini error for %s on attempt %d/%d: %s. "
                "Sleeping %.2fs before retry.",
                image_id,
                attempt,
                config.max_retries,
                exc,
                total_sleep,
            )
            time.sleep(total_sleep)
            backoff_seconds *= config.backoff_multiplier

    raise RuntimeError("Unexpected retry loop termination.")


def compute_errors(
    ground_truth: Dict[str, Optional[float]],
    prediction: Dict[str, Optional[float]],
) -> Dict[str, Dict[str, Optional[float]]]:
    """Compute absolute and percentage error per schema total field."""
    errors: Dict[str, Dict[str, Optional[float]]] = {}

    for field in EVAL_FIELDS:
        gt = ground_truth.get(field)
        pred = prediction.get(field)

        abs_error: Optional[float] = None
        pct_error: Optional[float] = None

        if gt is not None and pred is not None:
            abs_error = abs(gt - pred)
            if gt != 0:
                pct_error = (abs_error / abs(gt)) * 100.0

        errors[field] = {
            "abs_error": abs_error,
            "pct_error": pct_error,
        }

    return errors


def empty_prediction() -> Dict[str, Optional[float]]:
    """Return an empty prediction payload keyed by schema eval fields."""
    return {field: None for field in EVAL_FIELDS}


def serialize_float(value: Optional[float]) -> str:
    """Serialize float for CSV with stable precision; empty for missing values."""
    if value is None:
        return ""
    return f"{value:.6f}"


def make_csv_row(
    image_id: str,
    run_model: str,
    expected_split: str,
    status: str,
    error_message: str,
    ground_truth: Dict[str, Optional[float]],
    prediction: Dict[str, Optional[float]],
    errors: Dict[str, Dict[str, Optional[float]]],
    raw_payload: Dict[str, Any],
) -> Dict[str, str]:
    """Build one detailed CSV row."""
    row: Dict[str, str] = {
        "image_id": image_id,
        "run_model": run_model,
        "status": status,
        "error_message": error_message,
        "model_id": str(raw_payload.get("id", "")),
        "model_split": str(raw_payload.get("split", "")),
        "id_match": str(raw_payload.get("id") == image_id) if "id" in raw_payload else "",
        "split_match": (
            str(raw_payload.get("split") == expected_split)
            if "split" in raw_payload
            else ""
        ),
    }

    for field in EVAL_FIELDS:
        row[f"ground_truth_{field}"] = serialize_float(ground_truth.get(field))
        row[f"gemini_{field}"] = serialize_float(prediction.get(field))
        row[f"abs_error_{field}"] = serialize_float(errors[field]["abs_error"])
        row[f"pct_error_{field}"] = serialize_float(errors[field]["pct_error"])

    row["raw_model_json"] = json.dumps(raw_payload, ensure_ascii=True)

    return row


def ensure_csv_exists(csv_path: Path, columns: List[str]) -> None:
    """Create CSV with header if missing."""
    if csv_path.exists():
        return

    with csv_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=columns)
        writer.writeheader()


def append_csv_row(csv_path: Path, columns: List[str], row: Dict[str, str]) -> None:
    """Append one row to detailed CSV."""
    with csv_path.open("a", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=columns)
        writer.writerow(row)


def append_progress(progress_path: Path, payload: Dict[str, Any]) -> None:
    """Append one JSON line to progress log for resume support."""
    with progress_path.open("a", encoding="utf-8") as f:
        f.write(json.dumps(payload, ensure_ascii=True) + "\n")


def load_latest_status_by_id(progress_path: Path) -> Dict[str, str]:
    """Load latest status per image id from progress log."""
    if not progress_path.exists():
        return {}

    latest_status: Dict[str, str] = {}
    with progress_path.open("r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                payload = json.loads(line)
            except json.JSONDecodeError:
                continue

            image_id = payload.get("image_id")
            status = str(payload.get("status", "")).strip().lower()
            if isinstance(image_id, str) and image_id and status:
                latest_status[image_id] = status

    return latest_status


def parse_float_cell(cell: Optional[str]) -> Optional[float]:
    """Parse a float from CSV cell, returning None if empty/invalid."""
    if cell is None:
        return None
    stripped = cell.strip()
    if not stripped:
        return None
    try:
        return float(stripped)
    except ValueError:
        return None


def summarize_results(csv_path: Path) -> Dict[str, Any]:
    """Build summary metrics from detailed CSV."""
    if not csv_path.exists():
        return {
            "attempt_rows": 0,
            "processed_count": 0,
            "success_count": 0,
            "failed_count": 0,
            "field_mapes": {field: None for field in EVAL_FIELDS},
            "field_counts": {field: 0 for field in EVAL_FIELDS},
            "overall_mape": None,
            "overall_accuracy": None,
        }

    pct_errors_by_field: Dict[str, List[float]] = {
        field: [] for field in EVAL_FIELDS}
    abs_errors_by_field: Dict[str, List[float]] = {
        field: [] for field in EVAL_FIELDS}
    attempt_rows = 0
    success_count = 0
    failed_count = 0
    latest_rows_by_image: Dict[str, Dict[str, str]] = {}

    with csv_path.open("r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            attempt_rows += 1
            image_id = (row.get("image_id") or "").strip()
            if not image_id:
                continue
            latest_rows_by_image[image_id] = row

    processed_count = len(latest_rows_by_image)

    for row in latest_rows_by_image.values():
        status = (row.get("status") or "").strip().lower()
        if status == "ok":
            success_count += 1
        else:
            failed_count += 1

        for field in EVAL_FIELDS:
            pct = parse_float_cell(row.get(f"pct_error_{field}", ""))
            if pct is not None:
                pct_errors_by_field[field].append(pct)

            abs_v = parse_float_cell(row.get(f"abs_error_{field}", ""))
            if abs_v is not None:
                abs_errors_by_field[field].append(abs_v)

    field_mapes: Dict[str, Optional[float]] = {}
    field_maes: Dict[str, Optional[float]] = {}
    field_median_apes: Dict[str, Optional[float]] = {}
    field_p90_apes: Dict[str, Optional[float]] = {}
    field_counts: Dict[str, int] = {}

    def _percentile(sorted_vals: List[float], pct: float) -> float:
        # Linear interpolation percentile (0-100)
        if not sorted_vals:
            raise ValueError("empty list")
        n = len(sorted_vals)
        if n == 1:
            return sorted_vals[0]
        k = (pct / 100.0) * (n - 1)
        f = int(k)
        c = min(n - 1, f + 1)
        if f == c:
            return sorted_vals[int(k)]
        d = k - f
        return sorted_vals[f] + (sorted_vals[c] - sorted_vals[f]) * d

    for field in EVAL_FIELDS:
        pct_vals = pct_errors_by_field[field]
        abs_vals = abs_errors_by_field[field]
        field_counts[field] = len(pct_vals)
        field_mapes[field] = statistics.mean(pct_vals) if pct_vals else None
        field_maes[field] = statistics.mean(abs_vals) if abs_vals else None
        if pct_vals:
            sorted_pct = sorted(pct_vals)
            field_median_apes[field] = statistics.median(sorted_pct)
            field_p90_apes[field] = _percentile(sorted_pct, 90.0)
        else:
            field_median_apes[field] = None
            field_p90_apes[field] = None

    all_pct_values: List[float] = []
    all_abs_values: List[float] = []
    for field in EVAL_FIELDS:
        all_pct_values.extend(pct_errors_by_field[field])
        all_abs_values.extend(abs_errors_by_field[field])

    overall_mape: Optional[float] = (
        statistics.mean(all_pct_values) if all_pct_values else None
    )
    overall_mae: Optional[float] = (
        statistics.mean(all_abs_values) if all_abs_values else None
    )
    overall_median_ape: Optional[float] = (
        statistics.median(all_pct_values) if all_pct_values else None
    )
    overall_p90_ape: Optional[float] = (
        (_percentile(sorted(all_pct_values), 90.0)) if all_pct_values else None
    )

    overall_accuracy: Optional[float] = None
    if overall_mape is not None:
        overall_accuracy = max(0.0, 100.0 - overall_mape)

    return {
        "attempt_rows": attempt_rows,
        "processed_count": processed_count,
        "success_count": success_count,
        "failed_count": failed_count,
        "field_mapes": field_mapes,
        "field_maes": field_maes,
        "field_median_apes": field_median_apes,
        "field_p90_apes": field_p90_apes,
        "field_counts": field_counts,
        "overall_mape": overall_mape,
        "overall_mae": overall_mae,
        "overall_median_ape": overall_median_ape,
        "overall_p90_ape": overall_p90_ape,
        "overall_accuracy": overall_accuracy,
    }


def format_summary_text(summary: Dict[str, Any], config: EvalConfig) -> str:
    """Format human-readable summary for console and txt file."""
    lines: List[str] = []
    lines.append("Gemini Nutrition Accuracy Evaluation")
    lines.append("=" * 54)
    lines.append(f"Dataset: {config.dataset_name} ({config.dataset_split})")
    lines.append(f"Sample size target: {config.sample_size}")
    lines.append(f"Random seed: {config.random_seed}")
    lines.append(f"Model: {config.model_name}")
    lines.append("")
    lines.append("Run summary")
    lines.append("-" * 54)
    lines.append(f"Attempt rows (all runs): {summary['attempt_rows']}")
    lines.append(f"Latest unique images: {summary['processed_count']}")
    lines.append(f"Successful predictions: {summary['success_count']}")
    lines.append(f"Failed predictions: {summary['failed_count']}")
    lines.append("")
    lines.append("MAPE by schema total field (%)")
    lines.append("-" * 54)

    for field in EVAL_FIELDS:
        mape = summary["field_mapes"][field]
        count = summary["field_counts"][field]
        display_name = FIELD_DISPLAY_NAMES[field]
        if mape is None:
            lines.append(
                f"{display_name:>24}: N/A "
                f"(valid comparisons={count}; ground truth may be missing or zero)",
            )
        else:
            lines.append(
                f"{display_name:>24}: {mape:8.3f} (valid comparisons={count})",
            )

    lines.append("")
    lines.append("MAE / Median APE / P90 APE by schema total field")
    lines.append("-" * 54)

    for field in EVAL_FIELDS:
        mae = summary.get("field_maes", {}).get(field)
        median_ape = summary.get("field_median_apes", {}).get(field)
        p90 = summary.get("field_p90_apes", {}).get(field)
        count = summary["field_counts"][field]
        display_name = FIELD_DISPLAY_NAMES[field]
        if mae is None and median_ape is None and p90 is None:
            lines.append(
                f"{display_name:>24}: N/A (valid comparisons={count})",
            )
        else:
            mae_s = f"{mae:8.3f}" if mae is not None else "   N/A  "
            med_s = f"{median_ape:6.3f}" if median_ape is not None else " N/A "
            p90_s = f"{p90:6.3f}" if p90 is not None else " N/A "
            lines.append(
                f"{display_name:>24}: MAE={mae_s} | medianAPE={med_s}% | P90APE={p90_s}% (n={count})",
            )
    lines.append("")
    lines.append("Overall")
    lines.append("-" * 54)
    overall_mape = summary["overall_mape"]
    overall_accuracy = summary["overall_accuracy"]

    if overall_mape is None:
        lines.append("Overall MAPE: N/A")
        lines.append("Estimated accuracy: N/A")
    else:
        lines.append(f"Overall MAPE: {overall_mape:.3f}%")
        lines.append(
            f"Estimated accuracy (100 - MAPE): {overall_accuracy:.3f}%")

    # Overall additional metrics: MAE, median APE, P90 APE
    overall_mae = summary.get("overall_mae")
    overall_median_ape = summary.get("overall_median_ape")
    overall_p90_ape = summary.get("overall_p90_ape")

    if overall_mae is None and overall_median_ape is None and overall_p90_ape is None:
        lines.append("Overall MAE / medianAPE / P90APE: N/A")
    else:
        mae_s = f"{overall_mae:.3f}" if overall_mae is not None else "N/A"
        med_s = f"{overall_median_ape:.3f}" if overall_median_ape is not None else "N/A"
        p90_s = f"{overall_p90_ape:.3f}" if overall_p90_ape is not None else "N/A"
        lines.append(
            f"Overall MAE: {mae_s} | medianAPE: {med_s}% | P90APE: {p90_s}%",
        )

    lines.append("")
    lines.append(
        "Note: This report strictly follows public schema totals "
        "(total_calories, total_mass, total_fat, total_carb, total_protein).",
    )
    lines.append(
        "Model switching policy: changing --model starts a fresh full comparison run.",
    )

    return "\n".join(lines)


def write_summary(summary_path: Path, text: str) -> None:
    """Write summary text file."""
    with summary_path.open("w", encoding="utf-8") as f:
        f.write(text)


def main(argv: Optional[List[str]] = None) -> None:
    """Main entry point."""
    assert_supported_python_version()
    load_env_vars(CFG)

    args = parse_cli_args(CFG, argv)

    requested_model = str(args.model or "").strip()
    if not requested_model:
        raise ValueError("--model cannot be empty.")

    selected_model = resolve_model_name(requested_model)
    alias_applied = selected_model != requested_model

    if args.sample_size <= 0:
        raise ValueError("--sample-size must be greater than 0.")
    if args.rpm_limit <= 0 or args.tpm_limit <= 0 or args.rpd_limit <= 0:
        raise ValueError(
            "--rpm-limit, --tpm-limit, and --rpd-limit must be greater than 0.")

    runtime_cfg = replace(
        CFG,
        model_name=selected_model,
        sample_size=args.sample_size,
        random_seed=args.seed,
        gemini_rpm_limit=args.rpm_limit,
        gemini_tpm_limit=args.tpm_limit,
        gemini_rpd_limit=args.rpd_limit,
        daily_quota_reset_timezone=str(
            args.daily_reset_timezone).strip() or CFG.daily_quota_reset_timezone,
        output_dir=CFG.output_dir / model_slug(selected_model),
    )

    setup_logging(runtime_cfg)

    if alias_applied:
        logging.info(
            "Model alias resolved: %s -> %s",
            requested_model,
            selected_model,
        )

    context_path = CFG.output_dir / CFG.run_context_file
    detailed_csv_path = runtime_cfg.output_dir / runtime_cfg.detailed_csv_file
    progress_path = runtime_cfg.output_dir / runtime_cfg.progress_jsonl_file
    summary_path = runtime_cfg.output_dir / runtime_cfg.summary_txt_file

    previous_context = load_run_context(context_path)
    previous_model = str(previous_context.get("model_name", "")).strip()
    model_switched = bool(
        previous_model and previous_model != runtime_cfg.model_name)

    if args.force_fresh or model_switched:
        clear_run_artifacts((detailed_csv_path, progress_path, summary_path))
        if model_switched:
            logging.info(
                "Model switched from %s to %s. Starting a fresh full comparison run.",
                previous_model,
                runtime_cfg.model_name,
            )
        else:
            logging.info(
                "Force-fresh enabled. Starting a fresh full comparison run.")

    save_run_context(
        context_path,
        {
            "model_name": runtime_cfg.model_name,
            "model_slug": model_slug(runtime_cfg.model_name),
            "dataset_name": runtime_cfg.dataset_name,
            "dataset_split": runtime_cfg.dataset_split,
            "sample_size": runtime_cfg.sample_size,
            "random_seed": runtime_cfg.random_seed,
            "updated_at": int(time.time()),
        },
    )

    columns = csv_columns()
    ensure_csv_exists(detailed_csv_path, columns)

    # Resume support: skip successful ids only; failed ids are retried each start.
    latest_status_by_id = load_latest_status_by_id(progress_path)
    successful_ids = {
        image_id
        for image_id, status in latest_status_by_id.items()
        if status == "ok"
    }
    failed_ids = {
        image_id
        for image_id, status in latest_status_by_id.items()
        if status != "ok"
    }
    if latest_status_by_id:
        logging.info(
            "Resume mode active. Successful=%d | Failed queued for retry=%d",
            len(successful_ids),
            len(failed_ids),
        )

    api_key = os.environ.get(runtime_cfg.api_key_env_var)
    if not api_key:
        raise EnvironmentError(
            f"Missing API key. Set environment variable {runtime_cfg.api_key_env_var}.",
        )

    client = genai.Client(
        api_key=api_key,
        http_options=genai_types.HttpOptions(
            timeout=runtime_cfg.request_timeout_seconds * 1000,
        ),
    )

    rate_limiter = QuotaRateLimiter(
        rpm_limit=runtime_cfg.gemini_rpm_limit,
        tpm_limit=runtime_cfg.gemini_tpm_limit,
        rpd_limit=runtime_cfg.gemini_rpd_limit,
        tpm_utilization_target=runtime_cfg.tpm_utilization_target,
        estimated_tokens_per_request=runtime_cfg.estimated_tokens_per_request,
        buffer_seconds=runtime_cfg.rate_limit_buffer_seconds,
    )

    logging.info("Running model: %s", runtime_cfg.model_name)
    logging.info("Output folder: %s", runtime_cfg.output_dir)
    logging.info("Daily quota reset timezone: %s",
                 runtime_cfg.daily_quota_reset_timezone)
    warn_if_quota_seems_too_high(runtime_cfg)
    logging.info(
        "Quota policy: RPM=%d (burst then wait next minute) | TPM=%d (target=%.0f%%) | "
        "RPD=%d | est_tokens/request=%d",
        runtime_cfg.gemini_rpm_limit,
        runtime_cfg.gemini_tpm_limit,
        runtime_cfg.tpm_utilization_target * 100,
        runtime_cfg.gemini_rpd_limit,
        runtime_cfg.estimated_tokens_per_request,
    )

    logging.info(
        "Loading dataset metadata: %s and filtering split [%s]",
        runtime_cfg.dataset_name,
        runtime_cfg.dataset_split,
    )

    metadata_path = hf_hub_download(
        repo_id=runtime_cfg.dataset_name,
        filename="metadata.jsonl",
        repo_type="dataset",
    )
    metadata_snapshot_root = Path(metadata_path).resolve().parent

    try:
        dataset = load_dataset("json", data_files=metadata_path, split="train")
    except TypeError as exc:
        # Python 3.14 changed pickle internals and can break datasets/dill cache hashing.
        if "_batch_setitems" in str(exc):
            raise RuntimeError(
                "Detected Python pickle compatibility issue while loading dataset. "
                "Please use Python 3.10-3.13 (recommended: 3.11), recreate the venv, "
                "and reinstall requirements.",
            ) from exc
        raise

    validate_public_schema(dataset)

    dataset = dataset.filter(
        lambda row: row["split"] == runtime_cfg.dataset_split)

    if len(dataset) == 0:
        raise ValueError(
            f"No rows found for split={runtime_cfg.dataset_split} in metadata.jsonl.",
        )

    if len(dataset) < runtime_cfg.sample_size:
        raise ValueError(
            f"Dataset split has {len(dataset)} rows, but sample_size={runtime_cfg.sample_size}.",
        )

    selected = dataset.shuffle(seed=runtime_cfg.random_seed).select(
        range(runtime_cfg.sample_size),
    )
    logging.info(
        "Selected %d deterministic samples for evaluation.", len(selected))

    processed_this_run = 0
    interrupted = False
    stopped_due_to_quota = False
    stopped_due_to_model_config = False

    for index, sample in enumerate(selected):
        image_id = get_image_id(sample, fallback_index=index)

        if image_id in successful_ids:
            continue

        ground_truth = extract_ground_truth(sample)
        prediction = empty_prediction()
        raw_payload: Dict[str, Any] = {}
        status = "failed"
        error_message = "Unexpected control flow before request execution."

        while True:
            try:
                image = load_pil_image(
                    sample=sample,
                    dataset_name=runtime_cfg.dataset_name,
                    snapshot_root=metadata_snapshot_root,
                )
                prediction, raw_payload = call_gemini_with_retry(
                    client=client,
                    image=image,
                    image_id=image_id,
                    config=runtime_cfg,
                    rate_limiter=rate_limiter,
                )
                status = "ok"
                error_message = ""
                break

            except KeyboardInterrupt:
                interrupted = True
                logging.warning(
                    "Execution interrupted by user. Saving progress and exiting.")
                break

            except QuotaExhaustedError as exc:
                if args.auto_wait_daily_quota:
                    wait_seconds, wait_reason = choose_daily_quota_wait_seconds(
                        message=str(exc),
                        reset_timezone=runtime_cfg.daily_quota_reset_timezone,
                    )
                    logging.warning(
                        "Daily quota limit hit for %s. Auto-wait enabled; sleeping %ds and retrying (%s).",
                        image_id,
                        wait_seconds,
                        wait_reason,
                    )
                    time.sleep(wait_seconds)
                    continue

                stopped_due_to_quota = True
                logging.warning(
                    "Stopping run due to quota limit (API/local guard): %s", exc)
                break

            except FatalModelConfigError as exc:
                stopped_due_to_model_config = True
                logging.error(
                    "Stopping run due to model configuration error: %s", exc)
                break

            except Exception as exc:
                logging.exception("Failed sample %s", image_id)
                status = "failed"
                error_message = str(exc)
                break

        if interrupted or stopped_due_to_quota or stopped_due_to_model_config:
            break

        errors = compute_errors(ground_truth, prediction)

        row = make_csv_row(
            image_id=image_id,
            run_model=runtime_cfg.model_name,
            expected_split=runtime_cfg.dataset_split,
            status=status,
            error_message=error_message,
            ground_truth=ground_truth,
            prediction=prediction,
            errors=errors,
            raw_payload=raw_payload,
        )

        append_csv_row(detailed_csv_path, columns, row)
        append_progress(
            progress_path,
            {
                "image_id": image_id,
                "status": status,
                "error_message": error_message,
                "timestamp": int(time.time()),
            },
        )

        if status == "ok":
            successful_ids.add(image_id)
            failed_ids.discard(image_id)
        else:
            failed_ids.add(image_id)

        processed_this_run += 1

        if processed_this_run % 5 == 0:
            logging.info(
                "Progress: processed %d new samples in this run.", processed_this_run)

        time.sleep(runtime_cfg.inter_request_sleep_seconds)

    summary = summarize_results(detailed_csv_path)
    summary_text = format_summary_text(summary, runtime_cfg)
    write_summary(summary_path, summary_text)

    print("\n" + summary_text)

    if interrupted:
        logging.info(
            "Run stopped early. New samples processed this run: %d. "
            "Resume by running the script again.",
            processed_this_run,
        )
    elif stopped_due_to_model_config:
        logging.info(
            "Run stopped due to invalid model configuration. "
            "New samples processed this run: %d. "
            "Fix --model and run again.",
            processed_this_run,
        )
    elif stopped_due_to_quota:
        logging.info(
            "Run stopped due to quota limit. New samples processed this run: %d. "
            "Retry later by running the script again.",
            processed_this_run,
        )
    else:
        logging.info(
            "Run completed. New samples processed this run: %d", processed_this_run)


if __name__ == "__main__":
    main()
