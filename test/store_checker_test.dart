import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:store_checker/store_checker.dart';

void main() {
  const MethodChannel channel = MethodChannel('store_checker');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'getPackageInfo') {
        return {
          'bundleId': 'store.checker.store_checker_example',
          'version': '1.0.0',
        };
      }
      return (Platform.isIOS || Platform.isMacOS) ? 'AppStore' : 'com.android.vending';
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getSource', () async {
    final expected = (Platform.isIOS || Platform.isMacOS)
        ? Source.IS_INSTALLED_FROM_APP_STORE
        : Source.IS_INSTALLED_FROM_PLAY_STORE;
    expect(await StoreChecker.getSource, expected);
  });
}
