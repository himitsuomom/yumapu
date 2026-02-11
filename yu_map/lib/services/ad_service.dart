// lib/services/ad_service.dart
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';

class AdService {
  RewardedAd? _rewardedAd;
  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  
  static const int _minInterval = 120; // Minimum seconds between rewarded ads
  static const int _maxInterval = 300; // Maximum seconds between rewarded ads
  
  // Store timestamps for user interactions with ads
  final Map<String, DateTime> _adInteractionTimestamps = {};
  
  bool _isInitialized = false;
  bool _isTestMode = true;
  String? _userId;

  void initialize({String? userId, bool enableTesting = true}) {
    _isTestMode = enableTesting;
    _userId = userId;
    _isInitialized = true;
    
    if (kDebugMode) {
      debugPrint('Ad service initialized with test mode: $enableTesting');
    }
  }

  Future<void> loadRewardedAd() async {
    if (!_isInitialized) {
      debugPrint('Ad service not initialized');
      return;
    }
    
    String adUnitId = _isTestMode || kDebugMode
        ? 'ca-app-pub-3940256099942544/5224354917' // Test ID
        : Platform.isAndroid
            ? String.fromEnvironment('ANDROID_REWARDED_AD_UNIT_ID',
                defaultValue: 'ca-app-pub-3940256099942544/5224354917')
            : String.fromEnvironment('IOS_REWARDED_AD_UNIT_ID',
                defaultValue: 'ca-app-pub-3940256099942544/1712485313'); // Test ID

    final adRequest = AdRequest(
      nonPersonalizedAds: false,
      keywords: ['japan', 'hotsprings', 'onsen', 'baths'],
      contentUrl: 'https://yomap.example.com',
      requestAgent: 'flutter',
    );

    await RewardedAd.load(
      adUnitId: adUnitId,
      request: adRequest,
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          if (kDebugMode) {
            debugPrint('RewardedAd loaded successfully');
          }
        },
        onAdFailedToLoad: (error) {
          debugPrint('RewardedAd failed to load: $error');
          _rewardedAd = null;
        },
      ),
    );
  }

  Future<bool> showVideoAdForFacility(String facilityId) async {
    if (!_isInitialized) {
      debugPrint('Ad service not initialized');
      return false;
    }
    
    // Check if enough time has passed since last rewarded ad interaction
    if (!canShowRewardedAd(facilityId)) {
      final timeDiff = DateTime.now().difference(_adInteractionTimestamps[facilityId]!).inSeconds;
      final remaining = _minInterval - timeDiff;
      debugPrint('Cannot show rewarded ad yet. Wait $remaining more seconds.');
      return false;
    }

    if (_rewardedAd == null) {
      debugPrint('Warning: Ad attempted to show before loading');
      return false;
    }

    final completer = Completer<bool>();

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        loadRewardedAd(); // Reload after dismissal
        
        // Record the ad interaction
        recordAdInteraction(facilityId);
        
        completer.complete(true);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        debugPrint('RewardedAd failed to show: $error');
        loadRewardedAd(); // Try to reload
        completer.complete(false);
      },
    );

    await _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        debugPrint('User earned reward: ${reward.amount} ${reward.type}');
        // Log reward event for analytics
        debugPrint('Ad reward earned for facility $facilityId');
      },
    );

    return completer.future;
  }

  Widget buildBannerAd() {
    if (!_isInitialized) {
      return const SizedBox.shrink();
    }
    
    // Return a placeholder during development or if ads are disabled for premium users
    return Container(
      height: 50,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Text("Advertisement"),
      ),
    );
  }

  // Check if enough time has passed since last rewarded ad interaction
  bool canShowRewardedAd(String facilityId) {
    final now = DateTime.now();
    final lastInteraction = _adInteractionTimestamps[facilityId];
    
    if (lastInteraction == null) {
      return true; // First ad interaction for this facility
    }
    
    final timeDiff = now.difference(lastInteraction).inSeconds;
    return timeDiff >= _minInterval;
  }
  
  // Update timestamp when a rewarded ad interaction occurs
  void recordAdInteraction(String facilityId) {
    _adInteractionTimestamps[facilityId] = DateTime.now();
  }
  
  // Get a random wait time before showing next rewarded ad (in seconds)
  int getNextAdInterval() {
    return Random().nextInt(_maxInterval - _minInterval) + _minInterval;
  }

  // Clean up old interaction records periodically
  void cleanupOldRecords(Duration maxAge) {
    final cutoffTime = DateTime.now().subtract(maxAge);
    final toRemove = <String>[];

    for (final entry in _adInteractionTimestamps.entries) {
      if (entry.value.isBefore(cutoffTime)) {
        toRemove.add(entry.key);
      }
    }

    for (final key in toRemove) {
      _adInteractionTimestamps.remove(key);
    }
  }

  // Get ad metrics for a specific facility
  Map<String, dynamic> getAdMetrics(String facilityId) {
    return {
      'can_show_rewarded': canShowRewardedAd(facilityId),
      'last_interaction': _adInteractionTimestamps[facilityId]?.toIso8601String(),
      'next_available_in': _getNextAvailableIn(facilityId),
      'test_mode': _isTestMode,
    };
  }
  
  int _getNextAvailableIn(String facilityId) {
    final lastInteraction = _adInteractionTimestamps[facilityId];
    if (lastInteraction == null) return 0;
    
    final timeDiff = DateTime.now().difference(lastInteraction).inSeconds;
    return timeDiff < _minInterval ? _minInterval - timeDiff : 0;
  }

  // Get ad targeting options
  Map<String, String> getTargetingOptions() {
    final options = <String, String>{};
    
    if (_userId != null) {
      options['user_id'] = _userId!;
    }
    
    return options;
  }

  // Get current ad service status
  Map<String, dynamic> getStatus() {
    return {
      'initialized': _isInitialized,
      'test_mode': _isTestMode,
      'rewarded_ad_loaded': _rewardedAd != null,
      'user_id': _userId,
      'total_interactions_recorded': _adInteractionTimestamps.length,
    };
  }

  // Dispose of all ads and clean up resources
  void dispose() {
    _rewardedAd?.dispose();
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _adInteractionTimestamps.clear();
    _isInitialized = false;
  }
}
