// lib/services/ad_service.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  RewardedAd? _rewardedAd;
  bool _isLoading = false;

  /// Whether a rewarded ad is currently loaded and ready to show.
  bool get isAdReady => _rewardedAd != null;

  /// Test Ad Unit IDs (replace with production IDs before release).
  static String get _rewardedAdUnitId => Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/5224354917'
      : 'ca-app-pub-3940256099942544/1712485313';

  static String get _bannerAdUnitId => Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/6300978111'
      : 'ca-app-pub-3940256099942544/2934735716';

  Future<void> loadRewardedAd() async {
    if (_isLoading) return;
    _isLoading = true;

    try {
      await RewardedAd.load(
        adUnitId: _rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedAd = ad;
            _isLoading = false;
          },
          onAdFailedToLoad: (error) {
            debugPrint('RewardedAd failed to load: ${error.message}');
            _rewardedAd = null;
            _isLoading = false;
          },
        ),
      );
    } catch (e) {
      debugPrint('RewardedAd.load exception: $e');
      _isLoading = false;
    }
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
        _rewardedAd = null;
        loadRewardedAd(); // Pre-load the next ad
        if (!completer.isCompleted) completer.complete(true);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Ad failed to show: ${error.message}');
        ad.dispose();
        _rewardedAd = null;
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    await _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        debugPrint('User earned reward: ${reward.amount} ${reward.type}');
      },
    );

    return completer.future;
  }

  /// Creates a banner ad widget.
  /// Should be used within a StatefulWidget that calls dispose on the BannerAd.
  Widget buildBannerAd({
    AdSize adSize = AdSize.banner,
    void Function()? onAdLoaded,
    void Function(String)? onAdFailedToLoad,
  }) {
    final bannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('BannerAd loaded.');
          onAdLoaded?.call();
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('BannerAd failed to load: ${error.message}');
          ad.dispose();
          onAdFailedToLoad?.call(error.message);
        },
      ),
    )..load();

    return SizedBox(
      width: adSize.width.toDouble(),
      height: adSize.height.toDouble(),
      child: AdWidget(ad: bannerAd),
    );
  }

  /// Disposes of currently loaded ads.
  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }
}
