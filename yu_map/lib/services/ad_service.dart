// lib/services/ad_service.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:collection';

class AdService {
  RewardedAd? _rewardedAd;
  BannerAd? _bannerAd;
  
  // Timestamp map to track when ads are shown for facilities
  final Map<String, DateTime> _facilityAdTimestamps = {};
  static const int _maxTimestampEntries = 100; // Prevent unbounded growth

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
        // Add timestamp for the facility after ad is dismissed
        if (facilityId.isNotEmpty) {
          _facilityAdTimestamps[facilityId] = DateTime.now();
          
          // Implement basic cleanup to prevent unbounded growth
          if (_facilityAdTimestamps.length > _maxTimestampEntries) {
            // Remove oldest entries to maintain size
            final sortedKeys = _facilityAdTimestamps.keys.toList()
              ..sort((a, b) => _facilityAdTimestamps[a]!.compareTo(_facilityAdTimestamps[b]!));
            
            while (_facilityAdTimestamps.length > _maxTimestampEntries ~/ 2) {
              _facilityAdTimestamps.remove(sortedKeys.removeAt(0));
            }
          }
        }
        
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

  // Safe timestamp lookup with null check
  DateTime? getAdTimestampForFacility(String facilityId) {
    if (_facilityAdTimestamps.containsKey(facilityId)) {
      return _facilityAdTimestamps[facilityId];
    }
    return null;
  }
  
  bool hasAdBeenShownForFacility(String facilityId) {
    final timestamp = getAdTimestampForFacility(facilityId);
    return timestamp != null;
  }

  Widget buildBannerAd() {
    // Placeholder - banner ads usually require instantiation within widget tree state
    return const SizedBox(height: 50, child: Center(child: Text("Banner Ad")));
  }
}
