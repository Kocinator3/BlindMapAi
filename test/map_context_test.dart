import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slepa_mapa/domain/geo.dart';
import 'package:slepa_mapa/domain/level.dart';
import 'package:slepa_mapa/map/map_canvas.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'offline city data cover inhabited continents and distinguish capitals',
    () async {
      final land = await MapCanvas.loadLand();
      final context = MapContext.forLand(land);
      expect(context.rivers.length, greaterThan(300));
      expect(context.cities.length, greaterThan(3000));
      for (final reference in [
        (const GeoPoint(14.42, 50.08), true), // Prague
        (const GeoPoint(-77.04, 38.9), true), // Washington
        (const GeoPoint(-47.88, -15.79), true), // Brasilia
        (const GeoPoint(31.24, 30.04), true), // Cairo
        (const GeoPoint(139.69, 35.69), true), // Tokyo
        (const GeoPoint(149.13, -35.28), true), // Canberra
        (const GeoPoint(-74.0, 40.71), false), // New York
        (const GeoPoint(151.21, -33.87), false), // Sydney
      ]) {
        final nearest = context.cities.reduce(
          (a, b) =>
              distanceKm(a.point, reference.$1) <
                  distanceKm(b.point, reference.$1)
              ? a
              : b,
        );
        expect(distanceKm(nearest.point, reference.$1), lessThan(15));
        expect(nearest.capital, reference.$2);
      }
    },
  );
  testWidgets('map receives offline context and honors both layer toggles', (
    tester,
  ) async {
    final land = await tester.runAsync(MapCanvas.loadLand);
    for (final visible in [true, false]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapCanvas(
              land: land!,
              config: MapConfig(rivers: visible, cities: visible),
              type: AnswerType.point,
              points: const [],
              onChanged: (_) {},
              czech: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final dynamic painter = tester
          .widget<CustomPaint>(
            find
                .descendant(
                  of: find.byType(MapCanvas),
                  matching: find.byType(CustomPaint),
                )
                .last,
          )
          .painter;
      expect(painter.showCities, visible);
      expect(painter.showRivers, visible);
      expect((painter.context as MapContext).cities, isNotEmpty);
      expect(
        find.text('○ city · ⬠ capital · Natural Earth'),
        visible ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
    }
  });
}
