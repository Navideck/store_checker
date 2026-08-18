import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:store_checker/store_checker.dart';

void main() {
  const MethodChannel channel = MethodChannel('store_checker');

  TestWidgetsFlutterBinding.ensureInitialized();

  String sourceName = 'TestFlight';
  String currentVersion = '1.0.0';
  String appStoreVersion = '1.0.0';

  HttpOverrides? previousHttpOverrides;

  setUp(() {
    previousHttpOverrides = HttpOverrides.current;
    HttpOverrides.global = _FakeHttpOverrides(appStoreVersion);
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

  test('getSource returns IS_IN_REVIEW when installed version is newer', () async {
    sourceName = 'TestFlight';
    currentVersion = '2.0.0';
    appStoreVersion = '1.9.9';
    expect(await StoreChecker.getSource, Source.IS_IN_REVIEW);
  }, skip: !Platform.isIOS && !Platform.isMacOS ? 'iOS/macOS only' : false);

  test('getSource compares versions segment by segment', () async {
    sourceName = 'TestFlight';
    currentVersion = '1.10.0';
    appStoreVersion = '1.2.0';
    expect(await StoreChecker.getSource, Source.IS_IN_REVIEW);
  }, skip: !Platform.isIOS && !Platform.isMacOS ? 'iOS/macOS only' : false);

  test('getSource returns TEST_FLIGHT when version is not newer', () async {
    sourceName = 'TestFlight';
    currentVersion = '1.0.0';
    appStoreVersion = '1.0.0';
    expect(await StoreChecker.getSource, Source.IS_INSTALLED_FROM_TEST_FLIGHT);
  }, skip: !Platform.isIOS && !Platform.isMacOS ? 'iOS/macOS only' : false);
}

class _FakeHttpOverrides extends HttpOverrides {
  final String appStoreVersion;

  _FakeHttpOverrides(this.appStoreVersion);

  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      _FakeHttpClient(appStoreVersion);
}

class _FakeHttpClient implements HttpClient {
  final String appStoreVersion;

  _FakeHttpClient(this.appStoreVersion);

  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      _FakeHttpRequest(appStoreVersion);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeHttpRequest implements HttpClientRequest {
  final String appStoreVersion;

  _FakeHttpRequest(this.appStoreVersion);

  @override
  Future<HttpClientResponse> close() async =>
      _FakeHttpResponse(appStoreVersion);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeHttpResponse implements HttpClientResponse {
  final String appStoreVersion;

  _FakeHttpResponse(this.appStoreVersion);

  @override
  int get statusCode => 200;

  @override
  Stream<S> transform<S>(StreamTransformer<List<int>, S> streamTransformer) {
    final body = jsonEncode({
      'resultCount': 1,
      'results': [
        {'version': appStoreVersion}
      ]
    });
    return streamTransformer.bind(Stream.value(utf8.encode(body)));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}