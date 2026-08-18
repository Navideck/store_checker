import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

/* Source is where apk/ipa is available to Download */
enum Source {
  IS_INSTALLED_FROM_PLAY_STORE,
  IS_INSTALLED_FROM_PLAY_PACKAGE_INSTALLER,
  IS_INSTALLED_FROM_RU_STORE,
  IS_INSTALLED_FROM_LOCAL_SOURCE,
  IS_INSTALLED_FROM_AMAZON_APP_STORE,
  IS_INSTALLED_FROM_HUAWEI_APP_GALLERY,
  IS_INSTALLED_FROM_SAMSUNG_GALAXY_STORE,
  IS_INSTALLED_FROM_SAMSUNG_SMART_SWITCH_MOBILE,
  IS_INSTALLED_FROM_OPPO_APP_MARKET,
  IS_INSTALLED_FROM_XIAOMI_GET_APPS,
  IS_INSTALLED_FROM_VIVO_APP_STORE,
  IS_INSTALLED_FROM_OTHER_SOURCE,
  IS_INSTALLED_FROM_APP_STORE,
  IS_INSTALLED_FROM_TEST_FLIGHT,
  IS_IN_REVIEW,
  UNKNOWN,
}

/* Store Checker is useful to find the origin of installed apk/ipa */
class StoreChecker {
  static const MethodChannel _channel = const MethodChannel('store_checker');

  /* Get origin of installed apk/ipa */
  static Future<Source> get getSource async {
    final String? sourceName = await _channel.invokeMethod('getSource');
    if (Platform.isAndroid) {
      if (sourceName == null) {
        // Installed apk using adb commands or side loading or downloaded from any cloud service
        return Source.IS_INSTALLED_FROM_LOCAL_SOURCE;
      } else if (sourceName.compareTo('com.android.vending') == 0) {
        // Installed apk from Google Play Store
        return Source.IS_INSTALLED_FROM_PLAY_STORE;
      } else if (sourceName.compareTo('com.google.android.packageinstaller') ==
          0) {
        // Installed apk from Google Package installer/ firebase app tester
        return Source.IS_INSTALLED_FROM_PLAY_PACKAGE_INSTALLER;
      } else if (sourceName.compareTo('com.amazon.venezia') == 0) {
        // Installed apk from Amazon App Store
        return Source.IS_INSTALLED_FROM_AMAZON_APP_STORE;
      } else if (sourceName.compareTo('com.huawei.appmarket') == 0) {
        // Installed apk from Huawei App Store
        return Source.IS_INSTALLED_FROM_HUAWEI_APP_GALLERY;
      } else if (sourceName.compareTo('com.sec.android.app.samsungapps') == 0) {
        // Installed apk from Samsung App Store
        return Source.IS_INSTALLED_FROM_SAMSUNG_GALAXY_STORE;
      } else if (sourceName.compareTo('com.sec.android.easyMover') == 0) {
        // Installed apk from Samsung Smart Switch Mobile
        return Source.IS_INSTALLED_FROM_SAMSUNG_SMART_SWITCH_MOBILE;
      } else if (sourceName.compareTo('com.oppo.market') == 0) {
        // Installed apk from Oppo App Store
        return Source.IS_INSTALLED_FROM_OPPO_APP_MARKET;
      } else if (sourceName.compareTo('com.xiaomi.mipicks') == 0) {
        // Installed apk from Xiaomi App Store
        return Source.IS_INSTALLED_FROM_XIAOMI_GET_APPS;
      } else if (sourceName.compareTo('com.vivo.appstore') == 0) {
        // Installed apk from Vivo App Store
        return Source.IS_INSTALLED_FROM_VIVO_APP_STORE;
      } else if (sourceName.compareTo('ru.vk.store') == 0) {
        // Installed apk from RuStore
        return Source.IS_INSTALLED_FROM_RU_STORE;
      } else {
        // Installed apk from Amazon app store or other markets
        return Source.IS_INSTALLED_FROM_OTHER_SOURCE;
      }
    } else if (Platform.isIOS || Platform.isMacOS) {
      final packageInfo = await _getPackageInfo();
      String bundleId = packageInfo['bundleId'] ?? '';
      String currentVersion = packageInfo['version'] ?? '';
      String? appStoreVersion = await _fetchStoreVersion(bundleId);

      if (sourceName == null) {
        // Unknown source when null on iOS
        return Source.UNKNOWN;
      } else if (sourceName.isEmpty) {
        // Downloaded ipa using cloud service and installed
        return Source.IS_INSTALLED_FROM_LOCAL_SOURCE;
      } else if (sourceName.compareTo('AppStore') == 0) {
        // Installed ipa from App Store
        return Source.IS_INSTALLED_FROM_APP_STORE;
      } else if (appStoreVersion == null) {
        // Could not determine the live store version (e.g. network failure)
        return Source.IS_INSTALLED_FROM_TEST_FLIGHT;
      } else if (appStoreVersion.isEmpty ||
          _isNewerVersion(currentVersion, appStoreVersion)) {
        // First submission with no published version yet, or installed
        // version is newer than the published one
        return Source.IS_IN_REVIEW;
      } else {
        // Installed ipa from Test Flight
        return Source.IS_INSTALLED_FROM_TEST_FLIGHT;
      }
    }
    // Installed from Unknown source
    return Source.UNKNOWN;
  }

  static Future<String?> _fetchStoreVersion(String bundleId) async {
    if (Platform.isIOS || Platform.isMacOS)
      return _fetchAppStoreVersion(bundleId);
    else if (Platform.isAndroid)
      return _fetchPlayStoreVersion(bundleId);
    else
      return null;
  }

  // Compares dot-separated numeric version strings segment by segment,
  // so e.g. "1.10.0" is correctly treated as newer than "1.2.0".
  static bool _isNewerVersion(String current, String appStore) {
    final currentParts = current.split('.').map(int.tryParse).toList();
    final appStoreParts = appStore.split('.').map(int.tryParse).toList();
    final length =
        currentParts.length > appStoreParts.length ? currentParts.length : appStoreParts.length;
    for (var i = 0; i < length; i++) {
      final currentPart = i < currentParts.length ? currentParts[i] ?? 0 : 0;
      final appStorePart = i < appStoreParts.length ? appStoreParts[i] ?? 0 : 0;
      if (currentPart != appStorePart) return currentPart > appStorePart;
    }
    return false;
  }

  static Future<Map<String, String>> _getPackageInfo() async {
    final Map<Object?, Object?>? info =
        await _channel.invokeMapMethod('getPackageInfo');
    return {
      'bundleId': info?['bundleId'] as String? ?? '',
      'version': info?['version'] as String? ?? '',
    };
  }

  static Future<String?> _fetchAppStoreVersion(String bundleId) async {
    try {
      final country = _countryCode();
      String url = 'https://itunes.apple.com/lookup?bundleId=$bundleId';
      if (country.isNotEmpty) {
        url = '$url&country=$country';
      }
      final client = HttpClient();
      try {
        final request = await client.getUrl(Uri.parse(url));
        final response = await request.close();
        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          final data = jsonDecode(body);
          if (data['resultCount'] > 0) {
            return data['results'][0]['version'];
          } else {
            // The bundle id is not published on the App Store yet,
            // which happens on the first submission of the app
            return '';
          }
        }
      } finally {
        client.close(force: true);
      }
    } catch (e) {
      print("Error fetching App Store version: $e");
    }
    return null;
  }

  // Returns the region of the device locale (e.g. "US" from "en_US" or
// "en-US") or an empty string when the locale has no region.
  static String _countryCode() {
    final locale = Platform.localeName;
    final separator = locale.lastIndexOf('_') > locale.lastIndexOf('-')
        ? locale.lastIndexOf('_')
        : locale.lastIndexOf('-');
    if (separator == -1 || separator == locale.length - 1) return '';
    final code = locale.substring(separator + 1).toUpperCase();
    return code.length == 2 ? code : '';
  }

  static Future<String?> _fetchPlayStoreVersion(String bundleId) async {
    // TODO: Implement Android
    return null;
  }
}
