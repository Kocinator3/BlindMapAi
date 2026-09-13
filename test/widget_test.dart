import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slepa_mapa/main.dart';
import 'package:slepa_mapa/data/store.dart';
import 'package:slepa_mapa/map/map_canvas.dart';

void main() {
  testWidgets('launch, answer demo, feedback and persisted record', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = AppStore();
    await tester.runAsync(store.load);
    store.language = 'en';
    await tester.pumpWidget(SlepaMapa(store: store, land: const []));
    await tester.pumpAndSettle();
    expect(find.text('SlepáMapa'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Play').first);
    await tester.pumpAndSettle();
    expect(find.text('Kde leží Praha?'), findsOneWidget);
    expect(find.text('Confirm answer'), findsOneWidget);
    final map = find.byType(MapCanvas);
    await tester.tapAt(tester.getCenter(map));
    await tester.pump();
    await tester.tap(find.text('Confirm answer'));
    await tester.pumpAndSettle();
    expect(store.history.length, 1);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.textContaining('Blue: your attempt'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('mobile home and language/settings controls', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = AppStore();
    await tester.runAsync(store.load);
    await tester.pumpWidget(SlepaMapa(store: store, land: const []));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nastavení'));
    await tester.pumpAndSettle();
    expect(find.text('Tmavý režim'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
