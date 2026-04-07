// lib/services/ad_service.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:yu_map/core/config/app_config.dart';
import 'package:yu_map/core/logger/app_logger.dart';

class AdService {
  RewardedAd? _rewardedAd;

  Future<void> loadRewardedAd() async {
    await RewardedAd.load(
      adUnitId: AppConfig.admobRewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewardedAd = ad,
        onAdFailedToLoad: (error) {
          AppLogger.error('RewardedAd failed to load', tag: 'AdService', error: error);
          _rewardedAd = null;
        },
      ),
    );
  }

  Future<bool> showVideoAdForFacility(String facilityId) async {
    if (_rewardedAd == null) {
      AppLogger.warning('Warning: Ad attempted to show before loading', tag: 'AdService');
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
        // Log reward if needed
      },
    );

    return completer.future;
  }

  Widget buildBannerAd() {
    // Placeholder - banner ads usually require instantiation within widget tree state
    return const SizedBox(height: 50, child: Center(child: Text("Banner Ad")));
  }
}
