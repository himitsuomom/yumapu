// lib/services/review_service.dart
//
// レビュー取得ロジックの共通サービス。
//
// 背景: FacilityDetailScreen._fetchReviewPage() が Supabase クライアントに
// 直接クエリを打っていた（責務の分離不足・テスト困難・キャッシュ非対応）。
// このファイルに抽出することで:
//   - ウィジェットがデータ層に直接依存しない構造になる
//   - ReviewService をモックしてウィジェットテストが書きやすくなる
//   - 将来的にキャッシュ層を追加する際の変更箇所が1か所に集約される
//
// 使い方 (facility_detail_screen.dart):
//   final reviews = await ReviewService.fetchPage(
//     client: client,
//     facilityId: facilityId,
//     page: page,
//   );

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/core/constants/app_constants.dart';
import 'package:yu_map/domain/entities/review.dart';

/// レビューデータの取得を担当する静的ユーティリティクラス。
///
/// Widget のライフサイクル外で状態を保持しないため、
/// テストしやすいシンプルな設計にしている（CheckinService と同じパターン）。
abstract final class ReviewService {
  /// 指定施設のレビューをページ単位で取得する。
  ///
  /// - [client]: Supabase クライアント（null の場合は空リストを返す）
  /// - [facilityId]: 取得対象の施設 ID
  /// - [page]: 0 始まりのページ番号（1ページ = [AppConstants.pageSize] 件）
  ///
  /// 戻り値: 取得できたレビューのリスト（エラー時は例外を throw する）
  /// 呼び出し元でエラーハンドリングを行うこと。
  static Future<List<Review>> fetchPage({
    required SupabaseClient? client,
    required String facilityId,
    required int page,
  }) async {
    if (client == null) return [];

    final from = page * AppConstants.pageSize;
    final to = from + AppConstants.pageSize - 1;

    final rows = await client
        .from('reviews')
        .select('*, users!user_id(display_name, avatar_url, is_premium)')
        .eq('facility_id', facilityId)
        .order('created_at', ascending: false)
        .range(from, to) as List;

    return rows
        .map((r) => Review.fromJson(r as Map<String, dynamic>))
        .toList();
  }
}
