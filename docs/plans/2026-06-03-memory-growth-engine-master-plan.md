# Master-Plan: Memory Growth Engine (user.md + soul.md)

*Erstellt: 2026-06-03 · Sprint #1+#2 aus der Audit-Prioliste · Agent: Claude Code (Opus 4.8)*
*Status: READY — noch nicht begonnen*

## Ziel

`user.md` und `soul.md` wachsen mit dem User mit, statt auf dem Init-Default stehenzubleiben —
**ohne** die Sicherheits-Boundary zu brechen, dass nichts Untrusted autonom in die Agent-Identität
schreibt. Lösung: **"propose, don't commit"** mit Kandidaten-Queue und einem leichten Gate.

- **user.md** (Präferenzen): Queue + observed/inferred/confirmed-Klassifikation. Promotion in user.md
  bei `confirmed` ODER (`inferred` + occ≥2 + conf≥0.6). `signal:mood` nie promoten.
- **soul.md** (Identität, Stufe B): Queue `soul-candidates.md` (sichtbarer Anhang). Beim **nächsten
  Session-Start** zeigt `session-bootstrap` "N soul-Kandidaten warten — übernehmen? [j/n]". Nur bei
  explizitem "j" schreibt der Agent in EINEM bestätigten Vorgang. Kein Auto-Write.

## Harte Boundaries (gelten durchgehend)

1. **Trust-Boundary:** Kandidaten entstehen NUR aus direkten User-Korrekturen/-Aussagen in der
   Konversation. NIEMALS aus Web/Docs/NotebookLM/Wiki-Inhalt (Memory-Poisoning, Unit-42).
2. **session-bootstrap bleibt read-only** — die EINZIGE Ausnahme ist der eine bestätigte soul-Write
   nach explizitem "j". Dieser Write ist ein separater, klar markierter Schritt NACH dem Briefing,
   kein Teil des Read-Pfads. (Alternativ als eigener Mini-Command, falls Read-Only-Reinheit wichtiger.)
3. **mem-schema.sh ist SSoT** — jeder neue Store wird DORT angelegt, sonst schlägt der init↔schema
   Drift-Test in `validate-plugin.sh` an.
4. **TDD durchgehend:** jeder neue Mechanismus zuerst als Test (RED), der bei fehlender Spec rot wird;
   bidirektional verifizieren (strip→FAIL, restore→PASS), wie bei den self-improve-Hebeln.
5. **No-Self-Mod gilt analog:** soul.md ist für den Agenten, was die self-improve-SKILL.md für den
   Loop ist — kein autonomer Self-Edit ohne User-Gate.
6. **Windows:** `set +e`, kein hartes `jq`, GitBash+Linux. Chirurgisches Staging (Regel 7).
7. **Test-Baseline grün halten:** aktuell 175/175 (validate-plugin) + 147/147 (validate-skills).

---

## Phase 0: Schema-Stores anlegen (SSoT)

**Datei:** `scripts/mem-schema.sh`

Neue Stores in `create_memory_structure()`:
- `working/user-candidates.json` → `[]` (Präferenz-Beobachtungen, Queue)
- `identity/user-changelog.json` → `[]` (Append-Log jeder user.md-Änderung, Rollback-Quelle)
- `identity/soul-candidates.md` → Stub `# Soul Candidates\n\n*Keine offenen Kandidaten.*\n`

**RED:** Test in `validate-plugin.sh`: nach `bash scripts/mem-schema.sh <tmp>` existieren die 3 neuen
Pfade. (Schlägt jetzt fehl — Stores fehlen.)

**GREEN:** Stores in `MEM_JSON_ARRAY` (die zwei JSON) + Markdown-Stub-Block (soul-candidates) ergänzen.

**REFACTOR:** prüfen, dass `init.md`-Drift-Test grün bleibt (init muss dieselbe Dateimenge erzeugen —
er sourct mem-schema.sh, also automatisch konsistent).

**Schema `user-candidates.json` (ein Eintrag):**
```json
{
  "id": "UC1",
  "observation": "User bevorzugt pytest -x über volle Suite bei Debugging",
  "key": "test-invocation-style",
  "status": "observed",          // observed | inferred | confirmed
  "signal_type": "preference",   // preference | mood (mood wird NIE promoted)
  "confidence": 0.5,
  "occurrences": 1,
  "evidence": ["session 2026-06-03"],
  "first_seen": "2026-06-03",
  "last_seen": "2026-06-03",
  "trust_source": "conversation" // IMMER conversation; andere Werte werden verworfen
}
```

**Schema `user-changelog.json` (ein Eintrag):**
```json
{
  "ts": "2026-06-03T14:00:00Z",
  "field": "Preferences",
  "old_value": "...",
  "new_value": "...",
  "candidate_id": "UC1",
  "evidence": ["..."]
}
```

---

## Phase 1: Signal-Detection in wrap-up (user.md)

**Warum wrap-up, nicht iteration-logger:** wrap-up läuft am Session-Ende über die GANZE Session
(iteration-logger feuert nur bei explizitem Trigger). Signal-Erkennung gehört dorthin, wo der volle
Session-Kontext vorliegt. iteration-logger bekommt optional ein leichtes Tagging (Phase 1b), ist aber
nicht der primäre Pfad.

**Datei:** `skills/wrap-up/SKILL.md` — Step 6 ("Update user.md") ersetzen.

**Neue Mechanik (Step 6 neu):**
1. **Beobachten:** Über die Session hinweg nach stabilen Präferenz-Signalen scannen (User korrigierte
   denselben Stil, bestätigte einen nicht-offensichtlichen Ansatz, äußerte klare Vorliebe).
   `signal:mood`/Frustration → markieren, aber NIE promoten.
2. **In Queue schreiben:** Beobachtung als Kandidat in `working/user-candidates.json`. Wenn `key`
   schon existiert → `occurrences++`, `last_seen` aktualisieren, ggf. `status` hochstufen.
3. **Klassifikation:**
   - `observed` — 1× gesehen → nur Queue, nie user.md.
   - `inferred` — Agent leitet ab → unsicher markiert.
   - `confirmed` — User hat explizit bestätigt ODER 2× wiederholt (Schwelle von 3→2 gesenkt).
4. **Promotion in user.md:** nur `confirmed` ODER (`inferred` + occ≥2 + conf≥0.6). Jede Promotion:
   - Append in `user-changelog.json` (old/new/evidence/ts) VOR dem user.md-Write (Atomarität, vgl.
     self-improve Hebel 4).
   - Kandidat-Status auf `promoted` setzen.
5. **Trust-Check:** Kandidaten mit `trust_source != "conversation"` werden verworfen (Guard).

**RED:** Test in `validate-skills.sh`:
- wrap-up Step 6 nennt `user-candidates.json` + Drei-Stufen (`observed`/`inferred`/`confirmed`).
- wrap-up Step 6 nennt `signal:mood` als Nie-Promote-Ausnahme.
- wrap-up Step 6 nennt `user-changelog.json` (Audit/Rollback).
- Marker `(user-growth)` im Body.

**GREEN:** Step 6 umschreiben.
**REFACTOR:** sicherstellen, dass der bestehende Test "wrap-up: Do NOT update user.md for one-off
corrections" (falls vorhanden) noch passt oder präzisiert wird.

### Phase 1b (optional, leicht): iteration-logger Signal-Tag
**Datei:** `skills/iteration-logger/SKILL.md` Step 4b. Wenn eine Iteration eine User-Präferenz/-Korrektur
enthält, optional `signal:preference` an `working/current-session.json.learnings_draft` hängen, damit
wrap-up es leichter findet. Kein Pflicht-Pfad, nur Komfort.

---

## Phase 2: soul.md Growth Stufe B

**Teil A — Kandidaten sammeln (wrap-up):**
**Datei:** `skills/wrap-up/SKILL.md` — neuer Step 6.5 ("Soul Candidates").

- Stabile IDENTITÄTS-Signale (vs. flüchtige Präferenzen) erkennen: harte "won't"-Linien, geänderte
  Kommunikations-Defaults, neue Guard-Rails, die der User WIEDERHOLT einfordert.
- Als Eintrag an `identity/soul-candidates.md` anhängen (sichtbarer Markdown-Block mit Vorschlag +
  Evidenz + Datum). KEIN Write in soul.md hier.
- Trust-Check identisch (nur conversation).
- Anti-Bloat-Hinweis: wenn soul.md sich 80-Zeilen-Cap nähert, im Kandidat vermerken.

**Teil B — Gate beim Session-Start (session-bootstrap):**
**Datei:** `skills/session-bootstrap/SKILL.md` — neuer Schritt NACH dem Briefing.

- Wenn `identity/soul-candidates.md` offene Kandidaten enthält (nicht der leere Stub):
  Briefing-Zeile "SOUL CANDIDATES: N warten — übernehmen? [j/n]".
- Bei "j": Agent übernimmt die Kandidaten in EINEM Write in soul.md, leert die Queue, loggt nach
  `user-changelog.json` (field: soul). Bei "n"/keine Antwort: nichts tun, Kandidaten bleiben.
- **Read-Only-Reinheit:** Dieser Write ist explizit als die EINE Ausnahme markiert und passiert NUR
  auf User-"j". Das Briefing selbst bleibt read-only. (Falls dir das zu unrein ist: stattdessen
  `commands/soul-review.md` als separater Mini-Command — Entscheidung beim Bau treffen.)

**Teil C — 80-Zeilen-Linter (memory-maintenance):**
**Datei:** `skills/memory-maintenance/SKILL.md` — Konsistenz-Check Step 8.
- `soul.md > 80 Zeilen` → warnen "soul.md zu lang ({n} Zeilen) — verdichten, Identität verwässert".

**RED:** Tests in `validate-skills.sh`:
- wrap-up nennt `soul-candidates.md` + Trust-Check + `(soul-growth)`-Marker.
- session-bootstrap nennt `soul-candidates.md` + "[j/n]"-Gate + dass der Write NUR bei Bestätigung
  passiert (Read-Only-Ausnahme explizit).
- memory-maintenance nennt 80-Zeilen-Cap für soul.md.

**GREEN:** drei Stellen umschreiben.
**REFACTOR:** prüfen, dass der bestehende session-bootstrap "read-only"-Test nicht bricht — ggf.
präzisieren auf "read-only EXCEPT confirmed soul-write".

---

## Phase 3: Integration, Tests, Doku

1. **Volle Suite grün** (`bash tests/run-all.sh`) — Baseline + neue Cases.
2. **Bidirektionale Gegenprobe** für jeden neuen Test (strip→FAIL, restore→PASS).
3. **DEPENDENCIES.md** aktualisieren: neue Stores + Schreiber (wrap-up→user-candidates/soul-candidates/
   user-changelog; session-bootstrap→soul.md bedingt).
4. **Version-Bump** 3.2.6 → 3.3.0 (neues Feature, Minor). plugin.json + PROJECT.md + CHANGELOG.
5. **Codex-Verifier** über den Sprint-Commit (Regel 9).
6. **Wiki:** Audit-TODO/Sprint-Ergebnis als Session-Note; ggf. Audit-Prioliste als Wiki-TODO für #3-6.

---

## Reihenfolge & Commits (chirurgisch)

| Commit | Inhalt | Tests |
|---|---|---|
| 1 | Phase 0: Schema-Stores in mem-schema.sh + Drift-Test | validate-plugin |
| 2 | Phase 1: wrap-up Step 6 user.md-Growth + Tests | validate-skills |
| 3 | Phase 2: soul.md Stufe B (wrap-up 6.5 + bootstrap-Gate + linter) + Tests | validate-skills |
| 4 | Phase 3: DEPENDENCIES.md + Version-Bump + CHANGELOG | beide |

Jeder Commit hält die Baseline grün und fügt eigene Cases hinzu. Kein `.agent-memory/` im Commit.

---

## Offene Entscheidungen (vor/während Bau klären)

1. **soul-Gate-Ort:** in session-bootstrap (1 j/n, minimal Reibung, kleine Read-Only-Ausnahme) ODER
   separater `/soul-review`-Command (Read-Only bleibt rein, mehr Reibung). *Plan-Default: bootstrap.*
2. **user.md-Format:** strukturierte Sektionen (Preferences/Work Style/Known Corrections — wie heute)
   beibehalten, Kandidaten dort einsortieren. *Plan-Default: ja, bestehende Sektionen.*
3. **Mood-Erkennung:** rein heuristisch im wrap-up-Prompt (Frust-Marker, Einmaligkeit) — kein
   Sentiment-Modell. *Plan-Default: heuristisch.*
