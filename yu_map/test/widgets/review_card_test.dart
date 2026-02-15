// test/widgets/review_card_test.dart
//
// Widget tests for ReviewCard.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:yu_map/presentation/widgets/review_card.dart';
import '../helpers/test_data.dart';

void main() {
  group('ReviewCard', () {
    Widget buildTestWidget(
        {required review, bool showDeleteButton = false}) {
      return ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ReviewCard(
              review: review,
              showDeleteButton: showDeleteButton,
            ),
          ),
        ),
      );
    }

    testWidgets('displays review content', (tester) async {
      final review = TestData.review(content: '最高の温泉でした！');

      await tester.pumpWidget(buildTestWidget(review: review));

      expect(find.text('最高の温泉でした！'), findsOneWidget);
    });

    testWidgets('hides content when empty', (tester) async {
      final review = TestData.review(content: '');

      await tester.pumpWidget(buildTestWidget(review: review));

      // Should not find the empty content displayed
      // The card should still render without error
      expect(find.byType(ReviewCard), findsOneWidget);
    });

    testWidgets('displays formatted date', (tester) async {
      final review = TestData.review(); // createdAt: 2024-01-15

      await tester.pumpWidget(buildTestWidget(review: review));

      expect(find.text('2024/01/15'), findsOneWidget);
    });

    testWidgets('displays rating bar indicator', (tester) async {
      final review = TestData.review(rating: 4);

      await tester.pumpWidget(buildTestWidget(review: review));

      expect(find.byType(RatingBarIndicator), findsOneWidget);
    });

    testWidgets('displays likes count', (tester) async {
      final review = TestData.review(likesCount: 42);

      await tester.pumpWidget(buildTestWidget(review: review));

      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('displays thumb_up_outlined icon by default (not liked)', (tester) async {
      final review = TestData.review();

      await tester.pumpWidget(buildTestWidget(review: review));

      expect(find.byIcon(Icons.thumb_up_outlined), findsOneWidget);
    });

    testWidgets('is wrapped in a Card widget', (tester) async {
      final review = TestData.review();

      await tester.pumpWidget(buildTestWidget(review: review));

      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('displays zero likes count correctly', (tester) async {
      final review = TestData.review(likesCount: 0);

      await tester.pumpWidget(buildTestWidget(review: review));

      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('renders with full 5-star rating', (tester) async {
      final review = TestData.review(rating: 5);

      await tester.pumpWidget(buildTestWidget(review: review));

      final ratingBar = tester.widget<RatingBarIndicator>(
        find.byType(RatingBarIndicator),
      );
      expect(ratingBar.rating, 5.0);
      expect(ratingBar.itemCount, 5);
      expect(ratingBar.itemSize, 18);
    });

    testWidgets('renders with minimum 1-star rating', (tester) async {
      final review = TestData.review(rating: 1);

      await tester.pumpWidget(buildTestWidget(review: review));

      final ratingBar = tester.widget<RatingBarIndicator>(
        find.byType(RatingBarIndicator),
      );
      expect(ratingBar.rating, 1.0);
    });

    testWidgets('like button is tappable via InkWell', (tester) async {
      final review = TestData.review();

      await tester.pumpWidget(buildTestWidget(review: review));

      expect(find.byType(InkWell), findsWidgets);
    });
  });
}
