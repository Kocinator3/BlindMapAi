import 'package:flutter/material.dart';

import '../data/store.dart';
import '../domain/geo.dart';
import '../domain/level.dart';
import 'gameplay.dart';
import 'editor.dart';
import 'ai_page.dart';

class HomePage extends StatefulWidget {
  final AppStore store;
  final List<List<GeoPoint>> land;
  const HomePage({super.key, required this.store, required this.land});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;
  GameMode mode = GameMode.learning;
  String tr(String cs, String en) => widget.store.language == 'cs' ? cs : en;
  Future<void> edit([Level? level]) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            LevelEditor(store: widget.store, land: widget.land, level: level),
      ),
    );
    if (mounted) setState(() {});
  }

  void play(Level level) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => GameplayPage(
        level: level,
        store: widget.store,
        land: widget.land,
        mode: mode,
      ),
    ),
  );
  Future<void> import() async {
    final level = await showJsonEditor(
      context,
      null,
      czech: widget.store.language == 'cs',
    );
    if (level != null && mounted) await edit(level);
  }

  Future<void> action(Future<void> Function() operation) async {
    try {
      await operation();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Widget cards(List<Level> levels) => Column(
    children: [
      for (final level in levels)
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.public, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        level.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Text(
                      '${level.questions.length} ${tr('otázek', 'questions')}',
                    ),
                  ],
                ),
                if (level.unverified)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      tr(
                        'Orientační data · zkontroluj geografii',
                        'Approximate data · verify geography',
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '${tr('Nejlepší', 'Best')}: ${widget.store.best(level.id)} / ${level.questions.length * 1000}',
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => play(level),
                      icon: const Icon(Icons.play_arrow),
                      label: Text(tr('Hrát', 'Play')),
                    ),
                    OutlinedButton(
                      onPressed: () => edit(level),
                      child: Text(tr('Upravit / kopie', 'Edit / copy')),
                    ),
                    TextButton(
                      onPressed: () async {
                        final updated = await showJsonEditor(
                          context,
                          level,
                          czech: widget.store.language == 'cs',
                        );
                        if (updated != null && mounted) await edit(updated);
                      },
                      child: Text('JSON'),
                    ),
                    if (widget.store.custom.contains(level))
                      TextButton(
                        onPressed: () => action(() async {
                          final yes = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: Text(
                                tr('Smazat úroveň?', 'Delete level?'),
                              ),
                              content: Text(level.title),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: Text(tr('Zrušit', 'Cancel')),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(c, true),
                                  child: Text(tr('Smazat', 'Delete')),
                                ),
                              ],
                            ),
                          );
                          if (yes == true) await widget.store.delete(level);
                        }),
                        child: Text(tr('Smazat', 'Delete')),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
    ],
  );
  @override
  Widget build(BuildContext context) {
    final labels = [
      tr('Hrát', 'Play'),
      tr('Moje úrovně', 'My levels'),
      tr('Statistiky', 'Statistics'),
      tr('Nastavení', 'Settings'),
    ];
    final icons = [
      Icons.explore_outlined,
      Icons.edit_location_alt_outlined,
      Icons.insights,
      Icons.settings_outlined,
    ];
    final content = <Widget>[
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('Poznej svět po svém.', 'Find your way around the world.'),
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 8),
          Text(
            tr(
              'Bez účtu. Bez internetu. Jen ty a mapa.',
              'No account. No internet. Just you and a map.',
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            children: [
              for (final m in GameMode.values)
                ChoiceChip(
                  label: Text(switch (m) {
                    GameMode.practice => tr('Procvičování', 'Practice'),
                    GameMode.learning => tr('Učení', 'Learning'),
                    GameMode.challenge => tr('Výzva', 'Challenge'),
                  }),
                  selected: mode == m,
                  onSelected: (_) => setState(() => mode = m),
                ),
            ],
          ),
          const SizedBox(height: 20),
          cards(widget.store.levels),
        ],
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('Tvoje mapové výzvy', 'Your map challenges'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => edit(),
                icon: const Icon(Icons.add),
                label: Text(tr('Vytvořit úroveň', 'Create level')),
              ),
              OutlinedButton(
                onPressed: import,
                child: Text(tr('Importovat JSON', 'Import JSON')),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        AiPage(store: widget.store, land: widget.land),
                  ),
                ),
                icon: const Icon(Icons.auto_awesome),
                label: Text(tr('AI autor', 'AI author')),
              ),
            ],
          ),
          const SizedBox(height: 20),
          cards(widget.store.custom),
          if (widget.store.custom.isEmpty)
            Text(
              tr(
                'Vytvoř otázku a nakresli odpověď přímo do mapy.',
                'Create a question and draw the answer directly on the map.',
              ),
            ),
        ],
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('Každý pokus tě posouvá', 'Every attempt moves you forward'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 24,
            runSpacing: 16,
            children: [
              Text(
                'XP ${widget.store.xp}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text('${tr('Úroveň', 'Level')} ${widget.store.playerLevel}'),
              Text('${tr('Série', 'Streak')}: ${widget.store.streak}'),
              Text(
                '${tr('Odpovědí', 'Answers')}: ${widget.store.history.length}',
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            tr('Procvičit chyby a zopakovat', 'Practice mistakes and review'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (widget.store.mistakes.isEmpty)
            Text(
              tr(
                'Zatím není co opakovat. Zahraj si úroveň!',
                'Nothing to review yet. Play a level!',
              ),
            ),
          for (final item in widget.store.mistakes)
            ListTile(
              leading: const Icon(Icons.refresh),
              title: Text(item.$2.prompt),
              subtitle: Text(item.$1.title),
              trailing: const Icon(Icons.play_arrow),
              onTap: () => play(
                Level(
                  id: item.$1.id,
                  title: item.$1.title,
                  map: item.$1.map,
                  questions: [item.$2],
                ),
              ),
            ),
        ],
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('Nastavení', 'Settings'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          SwitchListTile(
            title: Text(tr('Tmavý režim', 'Dark theme')),
            value: widget.store.dark,
            onChanged: (v) =>
                action(() => widget.store.updateSettings(dark: v)),
          ),
          ListTile(
            title: Text(tr('Jazyk aplikace', 'App language')),
            trailing: DropdownButton<String>(
              value: widget.store.language,
              items: const [
                DropdownMenuItem(value: 'cs', child: Text('Čeština')),
                DropdownMenuItem(value: 'en', child: Text('English')),
              ],
              onChanged: (v) =>
                  action(() => widget.store.updateSettings(language: v)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome),
            title: Text(
              tr('AI poskytovatel a generování', 'AI provider and generation'),
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => AiPage(store: widget.store, land: widget.land),
              ),
            ),
          ),
          const Divider(),
          Text(
            tr('O aplikaci', 'About'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Text(
            'SlepáMapa 0.1.0\nOffline geography learning. MIT license.\nMap data: Natural Earth, public domain.\nGeographic outlines are simplified teaching aids.',
          ),
          TextButton(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'SlepáMapa',
              applicationVersion: '0.1.0',
              applicationLegalese: 'MIT · Natural Earth public domain',
            ),
            child: Text(tr('Licence', 'Licenses')),
          ),
        ],
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('SlepáMapa'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('✦ ${widget.store.xp} XP'),
          ),
        ],
      ),
      body: Row(
        children: [
          if (MediaQuery.sizeOf(context).width >= 850)
            NavigationRail(
              selectedIndex: tab,
              onDestinationSelected: (i) => setState(() => tab = i),
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (var i = 0; i < labels.length; i++)
                  NavigationRailDestination(
                    icon: Icon(icons[i]),
                    label: Text(labels[i]),
                  ),
              ],
            ),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1050),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.store.warning != null)
                        MaterialBanner(
                          content: Text(widget.store.warning!),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  setState(() => widget.store.warning = null),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      content[tab],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: MediaQuery.sizeOf(context).width < 850
          ? NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (i) => setState(() => tab = i),
              destinations: [
                for (var i = 0; i < labels.length; i++)
                  NavigationDestination(icon: Icon(icons[i]), label: labels[i]),
              ],
            )
          : null,
    );
  }
}
