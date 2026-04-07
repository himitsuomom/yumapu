import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:yu_map/core/config/app_config.dart';

/// Manages AdMob rewarded ads.
///
/// Banner ads are handled directly by [BannerAdWidget] in the UI layer.
/// This service owns loading and showing rewarded ads.
class AdService {
  RewardedAd? _rewardedAd;

  /// Banner ad unit ID for the current platform.
  static String get bannerAdUnitId {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppConfig.adMobBannerIdIos;
    }
    return AppConfig.adMobBannerIdAndroid;
  }

  /// Rewarded ad unit ID for the current platform.
  static String get rewardedAdUnitId {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppConfig.adMobRewardedIdIos;
    }
    return AppConfig.adMobRewardedIdAndroid;
  }

  /// Pre-loads a rewarded ad so it is ready to show without delay.
  Future<void> loadRewardedAd() async {
    if (!AppConfig.isAdMobConfigured) return;
    await RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewardedAd = ad,
        onAdFailedToLoad: (error) {
          debugPrint('AdService: RewardedAd failed to load: $error');
          _rewardedAd = null;
        },
      ),
    );
  }

  /// Shows the pre-loaded rewarded ad. Returns true if the ad was shown.
  /// Automatically reloads the next ad after dismissal.
  Future<bool> showRewardedAd() async {
    if (_rewardedAd == null) return false;

    final completer = Completer<bool>();

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
        completer.complete(true);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        completer.complete(false);
      },
    );

    await _rewardedAd!.show(onUserEarnedReward: (_, __) {});
    return completer.future;
  }
}
