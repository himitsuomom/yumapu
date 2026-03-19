import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class PlatformService {
  static bool get isWeb => kIsWeb;

  static bool get isIOS {
    if (kIsWeb) return false;
    return Platform.isIOS;
  }

  static bool get isAndroid {
    if (kIsWeb) return false;
    return Platform.isAndroid;
  }

  static bool get isMacOS {
    if (kIsWeb) return false;
    return Platform.isMacOS;
  }

  static bool get isMobile => isIOS || isAndroid;
  
  static bool get isDesktop =>
      isMacOS || (!kIsWeb && (Platform.isWindows || Platform.isLinux));

  /// レスポンシブ判定: 幅が600px以上ならデスクトップ/タブレットレイアウトとみなす
  static bool isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width > 600;
  }

  // レスポンシブ判定: スモール
  static bool isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  // レスポンシブ判定: Medium
  static bool isMediumScreen(BuildContext context) {
    return MediaQuery.of(context).size.width >= 600 &&
        MediaQuery.of(context).size.width < 900;
  }

  /// Get platform name
  static String getPlatformName() {
    if (isWeb) {
      return 'web';
    } else if (Platform.isAndroid) {
      return 'Android';
    } else if (Platform.isIOS) {
      return 'iOS';
    } else if (Platform.isMacOS) {
      return 'macOS';
    } else if (Platform.isWindows) {
      return 'Windows';
    } else if (Platform.isLinux) {
      return 'Linux';
    }
    return 'Unknown';
  }
}
