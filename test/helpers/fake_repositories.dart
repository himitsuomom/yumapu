// test/helpers/fake_repositories.dart
//
// In-memory fake implementations of repository interfaces for use in tests.
// All methods succeed by default. Set `shouldFail = true` to simulate errors.

import 'package:yu_map/core/result/result.dart';
import 'package:yu_map/domain/repositories/i_favorite_repository.dart';
import 'package:yu_map/domain/repositories/i_follow_repository.dart';

// ── FakeFavoriteRepository ────────────────────────────────────────────────────

class FakeFavoriteRepository implements IFavoriteRepository {
  final Set<String> _favorites;
  bool shouldFail;

  FakeFavoriteRepository({Set<String>? initial, this.shouldFail = false})
      : _favorites = initial ?? {};

  @override
  Future<Result<Set<String>>> getFavoriteIds() async {
    if (shouldFail) {
      return Failure(const NetworkException('simulated network error'));
    }
    return Success(Set.from(_favorites));
  }

  @override
  Future<Result<void>> addFavorite(String facilityId) async {
    if (shouldFail) {
      return Failure(const NetworkException('simulated network error'));
    }
    _favorites.add(facilityId);
    return const Success(null);
  }

  @override
  Future<Result<void>> removeFavorite(String facilityId) async {
    if (shouldFail) {
      return Failure(const NetworkException('simulated network error'));
    }
    _favorites.remove(facilityId);
    return const Success(null);
  }
}

// ── FakeFollowRepository ─────────────────────────────────────────────────────

class FakeFollowRepository implements IFollowRepository {
  final Set<String> _following;
  bool shouldFail;

  FakeFollowRepository({Set<String>? initial, this.shouldFail = false})
      : _following = initial ?? {};

  @override
  Future<Result<Set<String>>> getFollowingIds() async {
    if (shouldFail) {
      return Failure(const NetworkException('simulated network error'));
    }
    return Success(Set.from(_following));
  }

  @override
  Future<Result<({int followers, int following})>> getFollowCounts(
      String userId) async {
    if (shouldFail) {
      return Failure(const NetworkException('simulated network error'));
    }
    return const Success((followers: 10, following: 5));
  }

  @override
  Future<Result<void>> follow(String targetUserId) async {
    if (shouldFail) {
      return Failure(const NetworkException('simulated network error'));
    }
    _following.add(targetUserId);
    return const Success(null);
  }

  @override
  Future<Result<void>> unfollow(String targetUserId) async {
    if (shouldFail) {
      return Failure(const NetworkException('simulated network error'));
    }
    _following.remove(targetUserId);
    return const Success(null);
  }

  @override
  Future<Result<bool>> isFollowing(String targetUserId) async {
    if (shouldFail) {
      return Failure(const NetworkException('simulated network error'));
    }
    return Success(_following.contains(targetUserId));
  }
}
