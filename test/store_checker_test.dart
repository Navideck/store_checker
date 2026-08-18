import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:store_checker/store_checker.dart';

Uri? lastRequestUri;

void main() {
  const MethodChannel channel = MethodChannel('store_checker');

  TestWidgetsFlutterBinding.ensureInitialized();

  String sourceName = 'TestFlight';
  String currentVersion = '1.0.0';
  String? appStoreVersion = '1.0.0';

  HttpOverrides? previousHttpOverrides;

  setUp(() {
    lastRequestUri = null;
    previousHttpOverrides = HttpOverrides.current;
    HttpOverrides.global = _FakeHttpOverrides(() => appStoreVersion);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'getPackageInfo') {
        return {
          'bundleId': 'store.checker.store_checker_example',
          'version': currentVersion,
        };
      }
      return (Platform.isIOS || Platform.isMacOS)
          ? sourceName
          : 'com.android.vending';
    });
  });

  tearDown(() {
    HttpOverrides.global = previousHttpOverrides;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getSource', () async {
    sourceName = 'AppStore';
    final expected = (Platform.isIOS || Platform.isMacOS)
        ? Source.IS_INSTALLED_FROM_APP_STORE
        : Source.IS_INSTALLED_FROM_PLAY_STORE;
    expect(await StoreChecker.getSource, expected);
  });

  test('getSource returns IS_PENDING_RELEASE when installed version is newer', () async {
    sourceName = 'TestFlight';
    currentVersion = '2.0.0';
    appStoreVersion = '1.9.9';
    expect(await StoreChecker.getSource, Source.IS_PENDING_RELEASE);
  }, skip: !Platform.isIOS && !Platform.isMacOS ? 'iOS/macOS only' : false);

  test('getSource compares versions segment by segment', () async {
    sourceName = 'TestFlight';
    currentVersion = '1.10.0';
    appStoreVersion = '1.2.0';
    expect(await StoreChecker.getSource, Source.IS_PENDING_RELEASE);
  }, skip: !Platform.isIOS && !Platform.isMacOS ? 'iOS/macOS only' : false);

  test('getSource returns TEST_FLIGHT when version is not newer', () async {
    sourceName = 'TestFlight';
    currentVersion = '1.0.0';
    appStoreVersion = '1.0.0';
    expect(await StoreChecker.getSource, Source.IS_INSTALLED_FROM_TEST_FLIGHT);
  }, skip: !Platform.isIOS && !Platform.isMacOS ? 'iOS/macOS only' : false);

  test(
      'getSource returns IS_PENDING_RELEASE on first submission with no published version',
      () async {
    sourceName = 'TestFlight';
    currentVersion = '1.0.0';
    appStoreVersion = null;
    expect(await StoreChecker.getSource, Source.IS_PENDING_RELEASE);
  }, skip: !Platform.isIOS && !Platform.isMacOS ? 'iOS/macOS only' : false);

  test('getSource returns TEST_FLIGHT when the store lookup fails', () async {
    sourceName = 'TestFlight';
    currentVersion = '2.0.0';
    appStoreVersion = 'failure';
    expect(await StoreChecker.getSource, Source.IS_INSTALLED_FROM_TEST_FLIGHT);
  }, skip: !Platform.isIOS && !Platform.isMacOS ? 'iOS/macOS only' : false);

  test('store lookup includes the device region as country parameter', () async {
    sourceName = 'TestFlight';
    currentVersion = '1.0.0';
    appStoreVersion = '1.0.0';
    await StoreChecker.getSource;

    expect(lastRequestUri, isNotNull);
    final locale = Platform.localeName;
    final separator = locale.lastIndexOf('_') > locale.lastIndexOf('-')
        ? locale.lastIndexOf('_')
        : locale.lastIndexOf('-');
    if (separator == -1 || separator == locale.length - 1) {
      // Locale has no region; the parameter must be omitted
      expect(lastRequestUri!.queryParameters.containsKey('country'), isFalse);
    } else {
      final code = locale.substring(separator + 1).toUpperCase();
      expect(code.length, 2);
      expect(lastRequestUri!.queryParameters['country'], code);
    }
  }, skip: !Platform.isIOS && !Platform.isMacOS ? 'iOS/macOS only' : false);
}

class _FakeHttpOverrides extends HttpOverrides {
  final String? Function() appStoreVersion;

  _FakeHttpOverrides(this.appStoreVersion);

  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      _FakeHttpClient(appStoreVersion);
}

class _FakeHttpClient implements HttpClient {
  final String? Function() appStoreVersion;

  _FakeHttpClient(this.appStoreVersion);

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    lastRequestUri = url;
    return _FakeHttpRequest(appStoreVersion);
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeHttpRequest implements HttpClientRequest {
  final String? Function() appStoreVersion;

  _FakeHttpRequest(this.appStoreVersion);

  @override
  Future<HttpClientResponse> close() async =>
      _FakeHttpResponse(appStoreVersion);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeHttpResponse implements HttpClientResponse {
  final String? Function() appStoreVersion;

  _FakeHttpResponse(this.appStoreVersion);

  @override
  int get statusCode => appStoreVersion() == 'failure' ? 500 : 200;

  @override
  Stream<S> transform<S>(StreamTransformer<List<int>, S> streamTransformer) {
    final version = appStoreVersion();
    final body = version == null
        ? jsonEncode({
            'resultCount': 0,
            'results': <Object?>[],
          })
        : jsonEncode({
            'resultCount': 1,
            'results': [
              {'version': version}
            ]
          });
    return streamTransformer.bind(Stream.value(utf8.encode(body)));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}