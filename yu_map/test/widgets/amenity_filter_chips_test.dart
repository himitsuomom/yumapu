// test/widgets/amenity_filter_chips_test.dart
//
// Widget tests for AmenityFilterChips.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yu_map/presentation/widgets/amenity_filter_chips.dart';

void main() {
  group('AmenityFilterChips', () {
    testWidgets('renders all 9 amenity chips', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AmenityFilterChips(
              selected: const {},
              onChanged: (_) {},
            ),
          ),
        ),
      );

      // There should be 9 filter chips
      expect(find.byType(FilterChip), findsNWidgets(9));
    });

    testWidgets('displays Japanese labels', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AmenityFilterChips(
              selected: const {},
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('サウナ'), findsOneWidget);
      expect(find.text('タトゥーOK'), findsOneWidget);
      expect(find.text('露天風呂'), findsOneWidget);
      expect(find.text('水風呂'), findsOneWidget);
      expect(find.text('天然温泉'), findsOneWidget);
      expect(find.text('駐車場'), findsOneWidget);
      expect(find.text('宿泊可'), findsOneWidget);
      expect(find.text('混浴'), findsOneWidget);
      expect(find.text('岩盤浴'), findsOneWidget);
    });

    testWidgets('chip reflects selected state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AmenityFilterChips(
              selected: const {'sauna': true, 'parking': true},
              onChanged: (_) {},
            ),
          ),
        ),
      );

      // Find FilterChip widgets and check selection
      final chips = tester.widgetList<FilterChip>(find.byType(FilterChip));
      final chipList = chips.toList();

      // sauna is the first chip and should be selected
      expect(chipList[0].selected, true);
      // tattoo_friendly is not selected
      expect(chipList[1].selected, false);
    });

    testWidgets('tapping unselected chip calls onChanged with key added', (tester) async {
      Map<String, bool>? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AmenityFilterChips(
              selected: const {},
              onChanged: (val) => result = val,
            ),
          ),
        ),
      );

      // Tap the first chip (サウナ = sauna)
      await tester.tap(find.text('サウナ'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!['sauna'], true);
    });

    testWidgets('tapping selected chip calls onChanged with key removed', (tester) async {
      Map<String, bool>? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AmenityFilterChips(
              selected: const {'sauna': true},
              onChanged: (val) => result = val,
            ),
          ),
        ),
      );

      // Tap the selected sauna chip to deselect
      await tester.tap(find.text('サウナ'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.containsKey('sauna'), false);
    });

    testWidgets('widget is constrained to 40px height', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AmenityFilterChips(
              selected: const {},
              onChanged: (_) {},
            ),
          ),
        ),
      );

      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(sizedBox.height, 40);
    });

    testWidgets('multiple chips can be selected simultaneously', (tester) async {
      Map<String, bool>? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AmenityFilterChips(
              selected: const {'sauna': true, 'outdoor_bath': true},
              onChanged: (val) => result = val,
            ),
          ),
        ),
      );

      // The third chip (露天風呂) is tapped to deselect
      await tester.tap(find.text('露天風呂'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      // sauna should still be present, outdoor_bath removed
      expect(result!['sauna'], true);
      expect(result!.containsKey('outdoor_bath'), false);
    });
  });
}
