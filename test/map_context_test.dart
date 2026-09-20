import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slepa_mapa/domain/geo.dart';
import 'package:slepa_mapa/domain/level.dart';
import 'package:slepa_mapa/domain/map_detail.dart';
import 'package:slepa_mapa/map/map_canvas.dart';

class RecordingCanvas implements Canvas {
  final paths = <(Path, int, PaintingStyle)>[];
  @override
  void drawPath(Path path, Paint paint) =>
      paths.add((path, paint.color.toARGB32(), paint.style));
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'city detail grows with zoom while capitals and major cities stay visible',
    () async {
      final land = await MapCanvas.loadLand();
      final context = MapContext.forLand(land);
      final world = context.citiesAt(100);
      expect(world.length, lessThan(context.cities.length ~/ 4));
      expect(
        world,
        containsAll(
          context.cities.where((c) => c.capital || c.population >= 2000000),
        ),
      );
      expect(identical(world, context.citiesAt(80)), isTrue);
      var previous = world.length;
      for (final span in [30.0, 10.0, 3.0, .5]) {
        final current = context.citiesAt(span);
        expect(current.length, greaterThanOrEqualTo(previous));
        expect(
          current.every(
            (c) => c.capital || c.population >= cityPopulationThreshold(span),
          ),
          isTrue,
        );
        previous = current.length;
      }
      expect(context.citiesAt(.5).length, context.cities.length);
    },
  );
  test(
    'offline rivers cover all inhabited continents with valid open parts',
    () async {
      final land = await MapCanvas.loadLand();
      final rivers = MapContext.forLand(land).rivers;
      expect(rivers.length, greaterThan(2000));
      for (final line in rivers) {
        expect(line.length, greaterThanOrEqualTo(2));
        for (final point in line) {
          expect(point.lon.isFinite && point.lat.isFinite, isTrue);
          expect(point.lon, inInclusiveRange(-180, 180));
          expect(point.lat, inInclusiveRange(-90, 90));
        }
      }
      for (final reference in [
        ('Danube', const GeoPoint(18.99, 45.38)),
        ('Nile', const GeoPoint(31.16, 27.22)),
        ('Yangtze', const GeoPoint(112.94, 29.48)),
        ('Mississippi', const GeoPoint(-89.48, 36.45)),
        ('Amazon', const GeoPoint(-60.0, -3.1)),
        ('Murray', const GeoPoint(139.93, -34.15)),
      ]) {
        expect(
          rivers
              .expand((line) => line)
              .any((point) => distanceKm(point, reference.$2) < 30),
          isTrue,
          reason: '${reference.$1} must be present in the offline river layer',
        );
      }
    },
  );
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
  test(
    'lake context preserves islands and worldwide source coverage',
    () async {
      final land = await MapCanvas.loadLand();
      final lakes = MapContext.forLand(land).lakes;
      expect(lakes.length, 1366);
      expect(lakes.where((p) => p.length > 1), isNotEmpty);
      for (final reference in [
        const GeoPoint(-87, 47),
        const GeoPoint(33, -1),
        const GeoPoint(108, 53),
      ]) {
        expect(
          lakes
              .expand((p) => p.first)
              .any((p) => distanceKm(p, reference) < 250),
          isTrue,
        );
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
              config: MapConfig(
                rivers: visible,
                cities: visible,
                lakes: visible,
              ),
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
      expect(painter.showLakes, visible);
      expect((painter.context as MapContext).lakes.length, greaterThan(1300));
      expect((painter.context as MapContext).cities, isNotEmpty);
      expect(
        find.text('○ city · ⬠ capital · Natural Earth'),
        visible ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('water shares one color and country boundaries paint above it', (
    tester,
  ) async {
    final land = await tester.runAsync(MapCanvas.loadLand);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapCanvas(
            land: land!,
            config: const MapConfig(center: GeoPoint(33, -1), span: 12),
            type: AnswerType.point,
            points: const [],
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final painter = tester
        .widget<CustomPaint>(
          find
              .descendant(
                of: find.byType(MapCanvas),
                matching: find.byType(CustomPaint),
              )
              .last,
        )
        .painter!;
    final canvas = RecordingCanvas();
    painter.paint(canvas, const Size(400, 400));
    const water = 0xff729fb4, border = 0xff829b94;
    expect(
      canvas.paths.where((p) => p.$2 == water && p.$3 == PaintingStyle.fill),
      isNotEmpty,
    );
    expect(
      canvas.paths.where((p) => p.$2 == water && p.$3 == PaintingStyle.stroke),
      isNotEmpty,
    );
    final lastWater = canvas.paths.lastIndexWhere((p) => p.$2 == water);
    final firstBorder = canvas.paths.indexWhere((p) => p.$2 == border);
    expect(firstBorder, greaterThan(lastWater));
    expect(tester.takeException(), isNull);
  });
}
