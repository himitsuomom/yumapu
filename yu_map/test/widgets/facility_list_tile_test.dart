// test/widgets/facility_list_tile_test.dart
//
// Widget tests for FacilityListTile.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yu_map/presentation/widgets/facility_list_tile.dart';
import '../helpers/test_data.dart';

void main() {
  group('FacilityListTile', () {
    testWidgets('displays facility name', (tester) async {
      final facility = TestData.facility(name: '極楽温泉');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FacilityListTile(facility: facility),
          ),
        ),
      );

      expect(find.text('極楽温泉'), findsOneWidget);
    });

    testWidgets('displays address when present', (tester) async {
      final facility = TestData.facility(address: '東京都港区1-2-3');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FacilityListTile(facility: facility),
          ),
        ),
      );

      expect(find.text('東京都港区1-2-3'), findsOneWidget);
    });

    testWidgets('hides address when null', (tester) async {
      final facility = TestData.facility(address: null);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FacilityListTile(facility: facility),
          ),
        ),
      );

      // Should only show the name, not any address text
      expect(find.text(facility.name), findsOneWidget);
    });

    testWidgets('displays 5 star icons', (tester) async {
      final facility = TestData.facility();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FacilityListTile(facility: facility),
          ),
        ),
      );

      expect(find.byIcon(Icons.star), findsNWidgets(5));
    });

    testWidgets('displays data source text', (tester) async {
      final facility = TestData.facility();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FacilityListTile(facility: facility),
          ),
        ),
      );

      expect(find.text(facility.dataSource), findsOneWidget);
    });

    testWidgets('shows hot_tub leading icon', (tester) async {
      final facility = TestData.facility();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FacilityListTile(facility: facility),
          ),
        ),
      );

      expect(find.byIcon(Icons.hot_tub), findsOneWidget);
    });

    testWidgets('shows chevron_right trailing icon', (tester) async {
      final facility = TestData.facility();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FacilityListTile(facility: facility),
          ),
        ),
      );

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('responds to tap callback', (tester) async {
      bool tapped = false;
      final facility = TestData.facility();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FacilityListTile(
              facility: facility,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ListTile));
      expect(tapped, true);
    });

    testWidgets('does not crash when onTap is null', (tester) async {
      final facility = TestData.facility();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FacilityListTile(facility: facility),
          ),
        ),
      );

      // Tap should not throw
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();
    });

    testWidgets('is wrapped in a Card widget', (tester) async {
      final facility = TestData.facility();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FacilityListTile(facility: facility),
          ),
        ),
      );

      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('has CircleAvatar as leading widget', (tester) async {
      final facility = TestData.facility();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FacilityListTile(facility: facility),
          ),
        ),
      );

      expect(find.byType(CircleAvatar), findsOneWidget);
    });
  });
}
