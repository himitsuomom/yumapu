// lib/services/ad_service.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  RewardedAd? _rewardedAd;
  BannerAd? _bannerAd;

  Future<void> loadRewardedAd() async {
    await RewardedAd.load(
      adUnitId: Platform.isAndroid 
          ? 'ca-app-pub-3940256099942544/5224354917' // Test ID
          : 'ca-app-pub-3940256099942544/1712485313', // Test ID
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

  Future<bool> showVideoAdForFacility(String facilityId) async {
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
