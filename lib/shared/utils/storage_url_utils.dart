/// Normalizes Supabase Storage URLs so the app always uses a reachable base URL.
String normalizeStorageUrl(String url, {required String baseUrl}) {
  final trimmedUrl = url.trim();
  if (trimmedUrl.isEmpty) {
    return trimmedUrl;
  }

  final normalizedBaseUrl = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
  if (normalizedBaseUrl.isEmpty) {
    return trimmedUrl;
  }

  final baseUri = Uri.tryParse(normalizedBaseUrl);
  if (baseUri == null || baseUri.host.isEmpty) {
    return trimmedUrl;
  }

  final parsedUrl = Uri.tryParse(trimmedUrl);

  if (parsedUrl == null || !parsedUrl.hasScheme) {
    final normalizedPath = trimmedUrl.startsWith('/')
        ? trimmedUrl
        : '/$trimmedUrl';
    return '$normalizedBaseUrl$normalizedPath';
  }

  final isStoragePath =
      parsedUrl.path.startsWith('/storage/v1/object/sign/') ||
      parsedUrl.path.startsWith('/storage/v1/object/public/') ||
      parsedUrl.path.startsWith('/storage/v1/render/image/');

  if (!isStoragePath) {
    return trimmedUrl;
  }

  final sameOrigin =
      parsedUrl.scheme == baseUri.scheme &&
      parsedUrl.host == baseUri.host &&
      _resolvedPort(parsedUrl) == _resolvedPort(baseUri);

  if (sameOrigin) {
    return trimmedUrl;
  }

  return Uri(
    scheme: baseUri.scheme,
    host: baseUri.host,
    port: baseUri.hasPort ? baseUri.port : null,
    path: parsedUrl.path,
    query: parsedUrl.hasQuery ? parsedUrl.query : null,
    fragment: parsedUrl.hasFragment ? parsedUrl.fragment : null,
  ).toString();
}

int _resolvedPort(Uri uri) {
  if (uri.hasPort) {
    return uri.port;
  }

  return uri.scheme == 'https' ? 443 : 80;
}
