import 'package:flutter/material.dart';

class AiConnectionPreset {
  final String name, baseUrl, cs, en, docs;
  const AiConnectionPreset(
    this.name,
    this.baseUrl,
    this.cs,
    this.en,
    this.docs,
  );
}

const aiConnectionPresets = [
  AiConnectionPreset(
    'OpenAI',
    'https://api.openai.com/v1',
    '1. V OpenAI API dashboardu vytvoř API klíč a ověř dostupný kredit/limity.\n2. Zkopíruj ID textového modelu dostupného pro tvůj projekt, který podporuje Chat Completions.\n3. Použij nastavení níže, vlož model a klíč do formuláře.',
    '1. Create a key in the OpenAI API dashboard and check available credit/limits.\n2. Copy the ID of a text model available to your project that supports Chat Completions.\n3. Apply these settings, then enter the model and key.',
    'https://developers.openai.com/api/docs/quickstart',
  ),
  AiConnectionPreset(
    'Google Gemini',
    'https://generativelanguage.googleapis.com/v1beta/openai',
    '1. V Google AI Studio vytvoř Gemini API klíč.\n2. Z dokumentace nebo seznamu dostupných modelů zkopíruj přesné ID textového modelu.\n3. Použij tuto adresu kompatibility s OpenAI a vlož model a klíč.',
    '1. Create a Gemini API key in Google AI Studio.\n2. Copy an exact text model ID from the documentation or available models list.\n3. Apply this OpenAI compatibility address and enter the model and key.',
    'https://ai.google.dev/gemini-api/docs/openai',
  ),
  AiConnectionPreset(
    'Anthropic Claude',
    'https://api.anthropic.com/v1',
    '1. V Claude Console vytvoř API klíč a zjisti dostupné ID modelu.\n2. Použij nastavení a vlož model a klíč. Jde o kompatibilní rozhraní určené zejména k vyzkoušení.\n3. Klíče vyžadující hlavičku anthropic-workspace-id tato aplikace přímo nepodporuje. Použij vhodný klíč, vlastní kompatibilní bránu nebo kopírování promptu.',
    '1. Create an API key in Claude Console and find an available model ID.\n2. Apply settings and enter the model and key. This compatibility layer is primarily intended for evaluation.\n3. Keys requiring the anthropic-workspace-id header are not directly supported here. Use a suitable key, your own compatible gateway, or copy the prompt.',
    'https://platform.claude.com/docs/en/cli-sdks-libraries/libraries/openai-sdk',
  ),
  AiConnectionPreset(
    'DeepSeek',
    'https://api.deepseek.com',
    '1. Na platformě DeepSeek vytvoř API klíč a ověř kredit/limity.\n2. V aktuální dokumentaci zjisti přesné ID dostupného chatového modelu.\n3. Použij nastavení a vlož model a klíč; nepřidávej do adresy /chat/completions.',
    '1. Create a key on the DeepSeek platform and check credit/limits.\n2. Find an exact available chat model ID in the current documentation.\n3. Apply settings and enter the model and key; do not append /chat/completions to the address.',
    'https://api-docs.deepseek.com/',
  ),
  AiConnectionPreset(
    'Ollama (local)',
    'http://localhost:11434/v1',
    '1. Na stejném počítači nainstaluj Ollama, stáhni model a spusť server (ollama serve, pokud již neběží).\n2. Příkaz ollama list vypíše instalované modely; zkopíruj celý název včetně tagu do pole Model. Klíč může zůstat prázdný.\n3. Na telefonu localhost znamená telefon, nikoli počítač. Pro jiný počítač použij zabezpečenou HTTPS bránu. HTTP přes LAN tato aplikace nepovoluje.',
    '1. Install Ollama on the same computer, download a model and start its server (ollama serve if not already running).\n2. Run ollama list and copy the full installed model name including its tag into Model. Leave the key empty.\n3. On a phone, localhost means the phone, not your computer. Use a secure HTTPS gateway for another computer. LAN HTTP is not allowed by this app.',
    'https://docs.ollama.com/api/openai-compatibility',
  ),
];

class AiConnectionGuide extends StatelessWidget {
  final bool czech;
  const AiConnectionGuide({super.key, required this.czech});
  String tr(String cs, String en) => czech ? cs : en;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(tr('Jak připojit AI přes API', 'Connect AI via API')),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          tr(
            'Vyber poskytovatele. Návody jsou dostupné offline; otevření návodu ani použití nastavení nic neodesílá. API účet a jeho limity ověř u poskytovatele. Webový chat není API adresa.',
            'Choose a provider. These guides work offline; opening a guide or applying settings sends nothing. Check your API account and limits with the provider. A chat website is not an API address.',
          ),
        ),
        for (final preset in aiConnectionPresets)
          ExpansionTile(
            title: Text(preset.name),
            childrenPadding: const EdgeInsets.all(12),
            children: [
              SelectableText(czech ? preset.cs : preset.en),
              const SizedBox(height: 12),
              SelectableText('Base URL: ${preset.baseUrl}'),
              const SizedBox(height: 8),
              Text(
                tr(
                  'Oficiální dokumentace (adresu lze zkopírovat):',
                  'Official documentation (copyable address):',
                ),
              ),
              SelectableText(preset.docs),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.pop(context, preset),
                child: Text(tr('Použít nastavení', 'Apply settings')),
              ),
            ],
          ),
        const Divider(),
        Text(
          tr('Potom ve formuláři', 'Next, in the form'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          tr(
            '1. Doplň model a API klíč. Použití nastavení vymaže starý model i klíč; nový klíč zůstává jen v paměti stránky.\n2. Test spojení odešle krátký požadavek podle cen a kvóty poskytovatele.\n3. Zadej celý seznam míst a jazyk. Pokračuj a vygeneruj celý návrh katalogu přes API.\n4. Oprav nejasné položky, zkontroluj mapu a potvrď katalog.\n5. Vygeneruj finální úroveň přes API, zkontroluj editor a ulož úroveň. Tečky dole ukazují zbývající kroky.',
            '1. Enter a model and API key. Applying settings clears the old model and key; the new key stays only in page memory.\n2. Test connection sends a short request subject to provider prices and quota.\n3. Enter the complete list of places and language. Continue and generate the entire catalog proposal via API.\n4. Repair ambiguous items, check the map and approve the catalog.\n5. Generate the final level via API, review the editor and save. Dots at the bottom show remaining steps.',
          ),
        ),
        const SizedBox(height: 16),
        Text(
          tr('Když spojení nefunguje', 'Troubleshooting'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          tr(
            '401/403: ověř klíč a přístup k modelu. 404: zkontroluj Base URL i ID modelu. 429: ověř kvótu/kredit a zkus to později. 400: ověř podporu Chat Completions. Při časovém limitu zvol až 180 s nebo menší model. Aplikace sama přidává /chat/completions.\nBez API zvol na začátku Ručně přes chat. Průvodce připraví nejprve zadání pro celý katalog a po jeho kontrole finální prompt. Hraní i ruční tvorba fungují bez internetu.',
            '401/403: check the key and model access. 404: check Base URL and model ID. 429: check quota/credit and retry later. 400: check Chat Completions support. For timeouts, choose up to 180 s or a smaller model. The app appends /chat/completions itself.\nWithout API access, choose Manual chat at the start. The wizard prepares the complete catalog request and, after review, the final prompt. Gameplay and manual authoring work offline.',
          ),
        ),
      ],
    ),
  );
}
