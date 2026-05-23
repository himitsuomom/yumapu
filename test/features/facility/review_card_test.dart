// test/features/facility/review_card_test.dart
//
// Widget tests for ReviewCard.
// ReviewCard is a pure StatelessWidget with no provider dependencies,
// making it straightforward to test without any mocking.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:yu_map/domain/entities/review.dart';
import 'package:yu_map/features/facility/widgets/review_card.dart';

// ── Helper ────────────────────────────────────────────────────────────────

Review _makeReview({
  String id = 'r1',
  String content = 'とても良い温泉でした',
  int rating = 5,
  int likesCount = 0,
  String? authorDisplayName = 'テストユーザー',
  bool authorIsPremium = false,
}) {
  return Review(
    id: id,
    userId: 'u1',
    facilityId: 'f1',
    content: content,
    rating: rating,
    likesCount: likesCount,
    createdAt: DateTime(2024, 1, 15),
    authorDisplayName: authorDisplayName,
    authorIsPremium: authorIsPremium,
  );
}

Widget buildCard(Review review, {
  VoidCallback? onLike,
  VoidCallback? onUnlike,
  bool isLiked = false,
  VoidCallback? onDelete,
  VoidCallback? onEdit,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ReviewCard(
        review: review,
        onLike: onLike,
        onUnlike: onUnlike,
        isLiked: isLiked,
        onDelete: onDelete,
        onEdit: onEdit,
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    // ReviewCard uses DateFormat with 'ja' locale — initialize it first.
    await initializeDateFormatting('ja');
  });

  testWidgets('renders review content text', (tester) async {
    final review = _makeReview(content: 'とても良い温泉でした');
    await tester.pumpWidget(buildCard(review));
    await tester.pump();

    expect(find.text('とても良い温泉でした'), findsOneWidget);
  });

  testWidgets('renders author display name', (tester) async {
    final review = _makeReview(authorDisplayName: 'テストユーザー');
    await tester.pumpWidget(buildCard(review));
    await tester.pump();

    expect(find.text('テストユーザー'), findsOneWidget);
  });

  testWidgets('renders 匿名ユーザー when authorDisplayName is null', (tester) async {
    final review = _makeReview(authorDisplayName: null);
    await tester.pumpWidget(buildCard(review));
    await tester.pump();

    expect(find.text('匿名ユーザー'), findsOneWidget);
  });

  testWidgets('renders formatted date', (tester) async {
    final review = _makeReview();
    await tester.pumpWidget(buildCard(review));
    await tester.pump();

    expect(find.text('2024/01/15'), findsOneWidget);
  });

  testWidgets('does not render likes count when likesCount is 0', (tester) async {
    final review = _makeReview(likesCount: 0);
    await tester.pumpWidget(buildCard(review));
    await tester.pump();

    // When likesCount == 0 the icon row is suppressed
    expect(find.text('0'), findsNothing);
  });

  testWidgets('renders likes count when likesCount > 0', (tester) async {
    final review = _makeReview(likesCount: 7);
    await tester.pumpWidget(buildCard(review));
    await tester.pump();

    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('calls onLike callback when like button tapped', (tester) async {
    bool liked = false;
    final review = _makeReview(likesCount: 0);
    await tester.pumpWidget(
      buildCard(review, onLike: () => liked = true, isLiked: false),
    );
    await tester.pump();

    // The InkWell toggle shows text 'いいね' when not liked
    await tester.tap(find.text('いいね'));
    expect(liked, isTrue);
  });

  testWidgets('calls onUnlike callback when liked and button tapped',
      (tester) async {
    bool unliked = false;
    final review = _makeReview(likesCount: 3);
    await tester.pumpWidget(
      buildCard(review, onUnlike: () => unliked = true, isLiked: true),
    );
    await tester.pump();

    // The InkWell toggle shows text 'いいね済み' when liked
    await tester.tap(find.text('いいね済み'));
    expect(unliked, isTrue);
  });

  testWidgets('shows PopupMenuButton when onDelete is provided', (tester) async {
    final review = _makeReview();
    await tester.pumpWidget(
      buildCard(review, onDelete: () {}),
    );
    await tester.pump();

    // PopupMenuButton renders by default with Icons.more_vert
    expect(find.byType(PopupMenuButton<String>), findsOneWidget);
  });

  testWidgets('does not show PopupMenuButton when onDelete is null',
      (tester) async {
    final review = _makeReview();
    await tester.pumpWidget(buildCard(review));
    await tester.pump();

    expect(find.byType(PopupMenuButton<String>), findsNothing);
  });

  testWidgets('renders Card widget', (tester) async {
    final review = _makeReview();
    await tester.pumpWidget(buildCard(review));
    await tester.pump();

    expect(find.byType(Card), findsOneWidget);
  });
}
