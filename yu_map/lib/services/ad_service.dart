// lib/services/ad_service.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:yu_map/core/config/app_config.dart';

class AdService {
  RewardedAd? _rewardedAd;

  /// Banner ad unit ID for the current platform.
  static String get bannerAdUnitId => Platform.isAndroid
      ? AppConfig.adMobBannerIdAndroid
      : AppConfig.adMobBannerIdIos;

  /// Rewarded ad unit ID for the current platform.
  static String get rewardedAdUnitId => Platform.isAndroid
      ? AppConfig.adMobRewardedIdAndroid
      : AppConfig.adMobRewardedIdIos;

  Future<void> loadRewardedAd() async {
    await RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewardedAd = ad,
        onAdFailedToLoad: (error) {
          debugPrint('RewardedAd failed to load: $error');
          _rewardedAd = null;
        },
      ),
    );
  }

  Future<bool> showRewardedAd() async {
    if (_rewardedAd == null) {
      debugPrint('Warning: Ad attempted to show before loading');
      return false;
    }

    final completer = Completer<bool>();

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        loadRewardedAd();
        completer.complete(true);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        completer.complete(false);
      },
    );

    await _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        // Reward earned — caller handles the reward logic.
      },
    );

    return completer.future;
  }
}
