// lib/domain/repositories/i_favorite_repository.dart
import 'package:yu_map/core/result/result.dart';

abstract interface class IFavoriteRepository {
  Future<Result<Set<String>>> getFavoriteIds();
  Future<Result<void>> addFavorite(String facilityId);
  Future<Result<void>> removeFavorite(String facilityId);
}
