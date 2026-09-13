import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/store.dart';
import 'features/home.dart';
import 'map/map_canvas.dart';
import 'domain/geo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'SlepáMapa',
    ], await rootBundle.loadString('LICENSE'));
    yield LicenseEntryWithLineBreaks([
      'Natural Earth geographic data',
    ], await rootBundle.loadString('docs/DATA_SOURCES.md'));
  });
  try {
    final store = await AppStore.open();
    final land = await MapCanvas.loadLand();
    runApp(SlepaMapa(store: store, land: land));
  } catch (error) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: SelectableText(
                'SlepáMapa could not open its local data.\n$error\nRestart after checking disk access.',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SlepaMapa extends StatelessWidget {
  final AppStore store;
  final List<List<GeoPoint>> land;
  const SlepaMapa({super.key, required this.store, required this.land});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) => MaterialApp(
      title: 'SlepáMapa',
      debugShowCheckedModeBanner: false,
      locale: Locale(store.language),
      supportedLocales: const [Locale('cs'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff19756b)),
        scaffoldBackgroundColor: const Color(0xfff7f6f0),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff64cfba),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: store.dark ? ThemeMode.dark : ThemeMode.light,
      home: HomePage(store: store, land: land),
    ),
  );
}
