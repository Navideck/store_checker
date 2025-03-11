import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

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
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String bundleId = packageInfo.packageName;
      String currentVersion = packageInfo.version;
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
      } else if (appStoreVersion != null &&
          currentVersion.compareTo(appStoreVersion) > 0) {
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

  static Future<String?> _fetchAppStoreVersion(String bundleId) async {
    try {
      String url = 'http://itunes.apple.com/lookup?bundleId=$bundleId';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['resultCount'] > 0) {
          return data['results'][0]['version'];
        }
      }
    } catch (e) {
      print("Error fetching App Store version: $e");
    }
    return null;
  }

  static Future<String?> _fetchPlayStoreVersion(String bundleId) async {
    // TODO: Implement Android
    return null;
  }
}
