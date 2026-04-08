import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const MethodChannel _packageInfoChannel = MethodChannel(
  'dev.fluttercommunity.plus/package_info',
);

Future<void> mockPackageInfo({
  String appName = 'FitCalorie',
  String packageName = 'com.fitcalorie.app',
  String version = '1.0.0',
  String buildNumber = '1',
}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_packageInfoChannel, (methodCall) async {
        return {
          'appName': appName,
          'packageName': packageName,
          'version': version,
          'buildNumber': buildNumber,
          'buildSignature': 'test-signature',
          'installerStore': 'test-store',
        };
      });
}

Future<void> clearPluginMocks() async {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_packageInfoChannel, null);
}
