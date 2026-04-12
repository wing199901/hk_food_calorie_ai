import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hk_food_calorie_ai/env/env.dart';
import 'package:hk_food_calorie_ai/features/add_food/add_food_page.dart';
import 'package:hk_food_calorie_ai/shared/providers/providers.dart';
import 'package:hk_food_calorie_ai/shared/services/storage_service.dart';
import 'package:hk_food_calorie_ai/shared/services/supabase_service.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../test/helpers/test_app.dart';

const _testEmail = String.fromEnvironment('TEST_EMAIL');
const _testPassword = String.fromEnvironment('TEST_PASSWORD');
const _testImagePath = String.fromEnvironment(
  'TEST_IMAGE_PATH',
  defaultValue: 'integration_test/images/3_egg_tarts.jpg',
);

class _GeneratedImage {
  final Directory tempDir;
  final String path;

  const _GeneratedImage({required this.tempDir, required this.path});
}

class _FakeIosImagePickerPlatform extends ImagePickerPlatform {
  _FakeIosImagePickerPlatform({required this.imagePath});

  final String imagePath;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    if (source != ImageSource.gallery) return null;
    return XFile(imagePath);
  }

  @override
  Future<PickedFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
  }) async {
    final file = await getImageFromSource(source: source);
    return file == null ? null : PickedFile(file.path);
  }
}

Future<void> _ensureSupabaseInitialized() async {
  try {
    Supabase.instance.client;
    return;
  } catch (_) {
    await SupabaseService.initialize();
  }
}

Future<void> _precheckSupabaseReachability() async {
  final uri = Uri.parse(Env.supabaseUrl);
  final host = uri.host;
  final port = uri.hasPort
      ? uri.port
      : (uri.scheme.toLowerCase() == 'https' ? 443 : 80);

  Socket? socket;
  try {
    socket = await Socket.connect(
      host,
      port,
      timeout: const Duration(seconds: 3),
    );
  } catch (error) {
    throw TestFailure(
      'Cannot reach Supabase at ${uri.scheme}://$host:$port. '
      'Please ensure the target Supabase is running/reachable, then retry. '
      'Raw error: $error',
    );
  } finally {
    await socket?.close();
  }
}

Future<_GeneratedImage> _createSyntheticMealImage() async {
  final image = img.Image(width: 800, height: 600);

  // Build a simple plate-style scene to improve food detection consistency.
  img.fill(image, color: img.ColorRgb8(165, 129, 94));
  img.fillCircle(
    image,
    x: 400,
    y: 320,
    radius: 235,
    color: img.ColorRgb8(248, 248, 248),
  );
  img.fillCircle(
    image,
    x: 400,
    y: 320,
    radius: 220,
    color: img.ColorRgb8(236, 236, 236),
  );

  img.fillCircle(
    image,
    x: 360,
    y: 300,
    radius: 95,
    color: img.ColorRgb8(244, 220, 128),
  );
  img.fillCircle(
    image,
    x: 470,
    y: 340,
    radius: 78,
    color: img.ColorRgb8(208, 128, 72),
  );
  img.fillCircle(
    image,
    x: 445,
    y: 260,
    radius: 58,
    color: img.ColorRgb8(246, 243, 194),
  );
  img.fillCircle(
    image,
    x: 448,
    y: 262,
    radius: 24,
    color: img.ColorRgb8(245, 185, 70),
  );

  final directory = await Directory.systemTemp.createTemp(
    'fitcalorie-real-analysis-',
  );
  final output = File('${directory.path}/synthetic_meal.jpg');
  await output.writeAsBytes(img.encodeJpg(image, quality: 95));

  return _GeneratedImage(tempDir: directory, path: output.path);
}

Future<_GeneratedImage> _prepareMealImage() async {
  if (_testImagePath.trim().isNotEmpty) {
    final requestedPath = _testImagePath.trim();
    final source = File(requestedPath);

    Uint8List bytes;
    String extension;

    if (await source.exists()) {
      bytes = await source.readAsBytes();
      extension = source.path.contains('.')
          ? source.path.substring(source.path.lastIndexOf('.'))
          : '.jpg';
    } else {
      try {
        final assetData = await rootBundle.load(requestedPath);
        bytes = assetData.buffer.asUint8List();
      } catch (_) {
        throw TestFailure(
          'TEST_IMAGE_PATH does not exist as file or bundled asset: $requestedPath',
        );
      }

      extension = requestedPath.contains('.')
          ? requestedPath.substring(requestedPath.lastIndexOf('.'))
          : '.jpg';
    }

    final directory = await Directory.systemTemp.createTemp(
      'fitcalorie-real-analysis-source-',
    );
    final copied = File('${directory.path}/meal$extension');
    await copied.writeAsBytes(bytes, flush: true);
    return _GeneratedImage(tempDir: directory, path: copied.path);
  }

  return _createSyntheticMealImage();
}

Future<void> _waitForAnalyzeResult(WidgetTester tester) async {
  final deadline = DateTime.now().add(const Duration(seconds: 90));

  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));

    final hasAddMealButton = find.text('Add Meal').evaluate().isNotEmpty;
    final hasSnackBar = find.byType(SnackBar).evaluate().isNotEmpty;
    if (hasAddMealButton || hasSnackBar) return;
  }

  throw TestFailure('Timed out waiting for real analysis response.');
}

String? _readSnackBarText(WidgetTester tester) {
  final snackBarFinder = find.byType(SnackBar);
  if (snackBarFinder.evaluate().isEmpty) return null;

  final textFinder = find.descendant(
    of: snackBarFinder.first,
    matching: find.byType(Text),
  );
  if (textFinder.evaluate().isEmpty) return null;

  final widget = tester.widget<Text>(textFinder.first);
  return widget.data;
}

Future<void> _waitForLocalMealSave({
  required StorageService storage,
  required int countBefore,
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 20));

  while (DateTime.now().isBefore(deadline)) {
    if (storage.getMeals().length > countBefore) return;
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  throw TestFailure('Meal was not saved locally in time.');
}

Future<Map<String, dynamic>> _waitForRemoteMealRecord(String mealId) async {
  final client = Supabase.instance.client;
  final deadline = DateTime.now().add(const Duration(seconds: 30));

  while (DateTime.now().isBefore(deadline)) {
    final row = await client
        .from('meal_records')
        .select('id,total_calories,items,deleted_at')
        .eq('id', mealId)
        .maybeSingle();

    if (row != null) {
      return Map<String, dynamic>.from(row);
    }

    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  throw TestFailure('Timed out waiting for meal_records row: $mealId');
}

Future<String> _probeAnalyzeMealRaw(String imagePath) async {
  final client = Supabase.instance.client;
  final uid = client.auth.currentUser?.id;
  if (uid == null) return 'probe_skipped: no authenticated user';

  try {
    final bytes = await File(imagePath).readAsBytes();
    final response = await client.functions.invoke(
      'analyze-meal',
      body: {
        'image_path': '$uid/probe-diagnostic.jpg',
        'date': DateTime.now().toIso8601String().split('T').first,
        'image_base64': base64Encode(bytes),
      },
    );

    final data = response.data;
    if (data is Map) {
      final payload = Map<String, dynamic>.from(data);
      return jsonEncode({
        'success': payload['success'],
        'code': payload['code'],
        'error': payload['error'],
        'analysis_id': payload['analysis_id'],
      });
    }

    return 'probe_response_non_map';
  } catch (error) {
    return 'probe_exception: $error';
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'real backend flow: upload image, analyze meal, and persist record',
    (tester) async {
      if (_testEmail.isEmpty || _testPassword.isEmpty) {
        fail(
          'TEST_EMAIL and TEST_PASSWORD are required for test-analysis-flow.',
        );
      }

      await _ensureSupabaseInitialized();
      await _precheckSupabaseReachability();

      final supabase = SupabaseService();
      await supabase.signOut();
      await supabase.signIn(email: _testEmail, password: _testPassword);
      addTearDown(() async {
        await supabase.signOut();
      });

      final storage = StorageService(supabaseService: supabase);
      await storage.init();
      storage.clearAllLocalData();

      final generatedImage = await _prepareMealImage();
      addTearDown(() async {
        if (await generatedImage.tempDir.exists()) {
          await generatedImage.tempDir.delete(recursive: true);
        }
      });

      final originalImagePicker = ImagePickerPlatform.instance;
      ImagePickerPlatform.instance = _FakeIosImagePickerPlatform(
        imagePath: generatedImage.path,
      );
      addTearDown(() {
        ImagePickerPlatform.instance = originalImagePicker;
      });

      String? destination;
      final localMealsBefore = storage.getMeals().length;

      await tester.pumpWidget(
        buildTestApp(
          overrides: [
            storageProvider.overrideWith((ref) => storage),
            supabaseProvider.overrideWith((ref) => supabase),
          ],
          child: AddFoodPage(
            onNavigate: (page) => destination = page,
            showTestControls: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Upload Photo'));
      await tester.pump();

      await _waitForAnalyzeResult(tester);

      if (find.text('Add Meal').evaluate().isEmpty) {
        final snackBarText = _readSnackBarText(tester) ?? 'unknown';
        final probeResult = await _probeAnalyzeMealRaw(generatedImage.path);
        fail(
          'Real analysis did not produce a savable meal result. '
          'Check Gemini key / edge function status. '
          'Latest message: $snackBarText. '
          'Backend probe: $probeResult. '
          'If backend probe shows NO_FOOD_DETECTED, rerun with '
          'TEST_IMAGE_PATH pointing to a real food photo.',
        );
      }

      await tester.tap(find.text('Add Meal'));
      await tester.pumpAndSettle();

      expect(destination, 'home');

      await _waitForLocalMealSave(
        storage: storage,
        countBefore: localMealsBefore,
      );
      final savedMeal = storage.getMeals().last;

      expect(savedMeal.name.trim(), isNotEmpty);
      expect(savedMeal.calories, greaterThanOrEqualTo(0));

      final remoteRecord = await _waitForRemoteMealRecord(savedMeal.id);
      expect(remoteRecord['id'], savedMeal.id);
      expect(remoteRecord['deleted_at'], isNull);
      expect(remoteRecord['total_calories'], isA<num>());

      final items =
          (remoteRecord['items'] as List<dynamic>?) ?? const <dynamic>[];
      expect(items, isNotEmpty);

      debugPrint('Preserved meal_records row id: ${savedMeal.id}');
    },
  );
}
