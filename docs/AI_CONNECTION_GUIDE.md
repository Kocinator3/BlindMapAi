# Připojení AI při generování úrovní

V aplikaci otevři **Tvorba úrovně s AI → Pomocí API → Jak připojit AI přes API**.
Návod je součástí aplikace, funguje offline a obsahuje českou i anglickou verzi.
Rozbal poskytovatele a stiskni **Použít nastavení**. Vyplní se jméno a Base URL;
starý model a klíč se vymažou. Samotné použití nastavení neodesílá požadavek.

| Poskytovatel | Base URL | Klíč a model |
| --- | --- | --- |
| OpenAI | `https://api.openai.com/v1` | API klíč z OpenAI dashboardu, přesné dostupné ID modelu podporujícího Chat Completions |
| Google Gemini | `https://generativelanguage.googleapis.com/v1beta/openai` | Gemini API klíč z Google AI Studio, dostupné ID textového modelu |
| Anthropic Claude | `https://api.anthropic.com/v1` | API klíč z Claude Console, dostupné ID modelu; kompatibilní rozhraní pro vyzkoušení |
| DeepSeek | `https://api.deepseek.com` | API klíč z platformy DeepSeek, aktuální ID chatového modelu |
| Ollama | `http://localhost:11434/v1` | Model nainstalovaný na stejném zařízení, celý název z `ollama list`; klíč prázdný |

Modely se mění: zkopíruj přesné ID z dokumentace nebo seznamu modelů dostupných
pro svůj účet, nikoli zobrazovaný název webového chatu. Ověř API kredit a kvótu.
Do Base URL nepřidávej `/chat/completions`, aplikace jej připojí sama.

1. Vlož model a API klíč. Klíč zůstává jen v paměti stránky, neukládá se na disk.
2. Stiskni **Test spojení**. Odešle krátký požadavek, který podléhá cenám a kvótě
   poskytovatele. Úspěch nepotvrzuje správnost geografie ani schopnost vrátit úroveň.
3. Zadej celý seznam míst, téma a jazyk. Pokračuj k návrhu katalogu a stiskni
   **Vygenerovat celý návrh přes API**. Všechny dotazy přijdou v jednom JSONu
   podle [protokolu návrhu](CATALOG_TEXT_INSTRUCTIONS.md).
4. Aplikace ověří celý seznam a nabídne opravy chybějících či nejednoznačných míst.
   Zkontroluj katalog na mapě a stiskni **Potvrdit katalog a pokračovat**.
5. Stiskni **Vygenerovat finální úroveň přes API**, zkontroluj editor a ulož úroveň.
   Geometrie katalogových položek pochází z lokální mapy.

Při volbě **Ručně přes chat** projdeš stejnými pěti kroky. Do chatu kopíruješ
nejprve zadání s návodem pro celý návrh, potom potvrzený katalog s finálním promptem.
Obě odpovědi vložíš přímo do odpovídajícího kroku průvodce. Jednotlivé dotazy
ani stránky výsledků se ručně nepřenášejí. Tečky dole ukazují aktuální a zbývající kroky.

Claude klíče vyžadující `anthropic-workspace-id` nejsou přímo podporované, protože
aplikace neposílá vlastní hlavičky. Použij vhodný klíč, vlastní kompatibilní bránu,
nebo kopírování promptu. Kompatibilita konkrétního modelu závisí na poskytovateli;
placená produkční API nebyla v rámci testů volána.

Pro Ollama nejprve nainstaluj a stáhni model, spusť server (`ollama serve`, pokud
již neběží). Na telefonu `localhost` znamená telefon, nikoli počítač. Pro jiný
počítač je potřeba HTTPS brána; aplikace povoluje HTTP jen na loopbacku.

Chyby: 401/403 znamenají ověřit klíč a oprávnění, 404 adresu a ID modelu,
429 kredit/kvótu; při 400 zkontroluj podporu Chat Completions. Při timeoutu zvol
až 180 sekund nebo menší model. Bez API lze kopírovat prompt do webového chatu
a výsledný JSON vložit do editoru. Hraní a ruční tvorba zůstávají offline.

Oficiální zdroje ověřené 2026-09-20:
[OpenAI](https://developers.openai.com/api/docs/quickstart),
[Gemini](https://ai.google.dev/gemini-api/docs/openai),
[Claude](https://platform.claude.com/docs/en/cli-sdks-libraries/libraries/openai-sdk),
[DeepSeek](https://api-docs.deepseek.com/),
[Ollama](https://docs.ollama.com/api/openai-compatibility).
