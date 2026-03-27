#!/usr/bin/env bash
# Validates all SKILL.md files for required sections and quality.
# Exit codes: 0 = all pass, 1 = failures found

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ERRORS=0
TESTS=0
PASSED=0

pass() { TESTS=$((TESTS + 1)); PASSED=$((PASSED + 1)); echo "  PASS: $1"; }
fail() { TESTS=$((TESTS + 1)); ERRORS=$((ERRORS + 1)); echo "  FAIL: $1"; }

echo "=== Skill Validation ==="

SKILLS_DIR="$PLUGIN_ROOT/skills"

for skill_dir in "$SKILLS_DIR"/*/; do
    [ -d "$skill_dir" ] || continue
    skill_name=$(basename "$skill_dir")
    skill_file="$skill_dir/SKILL.md"

    echo ""
    echo "-- $skill_name --"

    if [ ! -f "$skill_file" ]; then
        fail "$skill_name: SKILL.md not found"
        continue
    fi
    pass "$skill_name: SKILL.md exists"

    # Check frontmatter
    if head -1 "$skill_file" | grep -q "^---"; then
        pass "$skill_name: has frontmatter"

        if grep -q "^name:" "$skill_file"; then
            pass "$skill_name: has name"
        else
            fail "$skill_name: missing name field in frontmatter — skill cannot be identified by registry"
        fi

        if grep -q "^description:" "$skill_file"; then
            pass "$skill_name: has description"
            # Handle both inline and multiline (| or >) YAML descriptions
            desc_line=$(grep "^description:" "$skill_file" | head -1)
            if echo "$desc_line" | grep -qE '\|$|>$'; then
                # Multiline: measure content after description: line until next frontmatter key or ---
                desc_len=$(sed -n '/^description:/,/^[a-z_]*:\|^---/{/^description:/d;/^[a-z_]*:/d;/^---/d;p;}' "$skill_file" | wc -c)
            else
                desc_len=$(echo "$desc_line" | sed 's/^description: *//' | wc -c)
            fi
            if [ "$desc_len" -gt 20 ]; then
                pass "$skill_name: description meaningful (${desc_len}c)"
            else
                fail "$skill_name: description too short (${desc_len}c)"
            fi
        else
            fail "$skill_name: missing description"
        fi
    else
        fail "$skill_name: missing frontmatter"
    fi

    content=$(cat "$skill_file")

    # Trigger/intent information
    if echo "$content" | grep -qi "trigger\|when to use\|intent\|invoke\|use this"; then
        pass "$skill_name: has trigger info"
    else
        fail "$skill_name: missing trigger info"
    fi

    # Steps/procedure
    if echo "$content" | grep -qi "step\|procedure\|workflow\|process\|phase\|ablauf\|cycle\|schritt"; then
        pass "$skill_name: has steps"
    else
        fail "$skill_name: missing steps"
    fi

    # Content length
    content_len=$(wc -c < "$skill_file")
    if [ "$content_len" -gt 500 ]; then
        pass "$skill_name: sufficient content (${content_len}b)"
    else
        fail "$skill_name: too short (${content_len}b)"
    fi

    # Examples or output format
    if echo "$content" | grep -qi "example\|output\|format\|template"; then
        pass "$skill_name: has examples/format"
    else
        fail "$skill_name: missing examples/format"
    fi
done

# skill-generator specific: must have English intent-style trigger phrases
echo ""
echo "-- skill-generator specific --"
SG_FILE="$SKILLS_DIR/skill-generator/SKILL.md"
if [ -f "$SG_FILE" ]; then
    if grep -qi "keep doing\|keep repeating\|repetitive\|I keep\|automate this\|same thing" "$SG_FILE"; then
        pass "skill-generator: has English intent triggers (e.g. 'I keep doing this')"
    else
        fail "skill-generator: missing English intent triggers — users won't say 'generate skill', they'll say 'I keep doing this'"
    fi
fi

echo ""
echo "-- skill-generator trigger language consistency --"
if [ -f "$SG_FILE" ]; then
    if grep -qiE "skill aus pattern|workflow als skill|Skill erstellen|neuen Skill generieren|diesen workflow automatisieren|das mache ich staendig|kann man das als skill" "$SG_FILE"; then
        fail "skill-generator: description trigger phrases contain German — triggers must use English so non-German users can invoke the skill"
    else
        pass "skill-generator: description trigger phrases use English (no German triggers)"
    fi
fi

echo ""
echo "-- test-validator language consistency --"
TV_FILE="$SKILLS_DIR/test-validator/SKILL.md"
if [ -f "$TV_FILE" ]; then
    if grep -q "^### Schritt" "$TV_FILE"; then
        fail "test-validator: body uses German section headers (e.g. 'Schritt') — skill bodies must use English for consistency with the rest of the plugin"
    else
        pass "test-validator: body section headers use English (no 'Schritt' headers)"
    fi
fi

echo ""
echo "-- test-validator trigger language consistency --"
if [ -f "$TV_FILE" ]; then
    if grep -qE "laufen lassen|ausfuehren|kaputt gemacht|funktioniert noch|ist was kaputt" "$TV_FILE"; then
        fail "test-validator: description trigger phrases contain German — all triggers must use English for correct auto-triggering"
    else
        pass "test-validator: description trigger phrases use English (no German triggers)"
    fi
fi

echo ""
echo "-- code-reviewer language consistency --"
CR_FILE="$SKILLS_DIR/code-reviewer/SKILL.md"
if [ -f "$CR_FILE" ]; then
    if grep -q "^### Schritt" "$CR_FILE"; then
        fail "code-reviewer: body uses German section headers (e.g. 'Schritt') — skill bodies must use English for consistency with the rest of the plugin"
    else
        pass "code-reviewer: body section headers use English (no 'Schritt' headers)"
    fi
fi

echo ""
echo "-- wrap-up session-summary template language consistency --"
WU_FILE="$SKILLS_DIR/wrap-up/SKILL.md"
if [ -f "$WU_FILE" ]; then
    if grep -q "## Was wurde gemacht\|## Offene Punkte\|## Naechste Schritte\|## Aktive Warnungen" "$WU_FILE"; then
        fail "wrap-up: session-summary.md template uses German section headers — template must use English for consistency with the rest of the plugin"
    else
        pass "wrap-up: session-summary.md template uses English section headers"
    fi
fi

echo ""
echo "-- tdd trigger language consistency --"
TDD_FILE="$SKILLS_DIR/tdd/SKILL.md"
if [ -f "$TDD_FILE" ]; then
    if grep -q "erst testen dann coden\|schreib erstmal einen test\|das muss getestet sein" "$TDD_FILE"; then
        fail "tdd: description contains German trigger phrases — triggers must use English for consistent auto-matching"
    else
        pass "tdd: description trigger phrases use English (no German triggers)"
    fi
fi

echo ""
echo "-- code-reviewer JSON template language consistency --"
CR_FILE="$SKILLS_DIR/code-reviewer/SKILL.md"
if [ -f "$CR_FILE" ]; then
    if grep -q "Beschreibung des Problems\|Vorgeschlagene Verbesserung\|Kurze Zusammenfassung" "$CR_FILE"; then
        fail "code-reviewer: JSON output template uses German field values — template must use English placeholders"
    else
        pass "code-reviewer: JSON output template uses English field values"
    fi
fi

echo ""
echo "-- pattern-extractor trigger language consistency --"
PE_FILE="$SKILLS_DIR/pattern-extractor/SKILL.md"
if [ -f "$PE_FILE" ]; then
    if grep -q "Muster extrahieren\|Patterns analysieren\|welche Muster erkennst du\|was lief heute schief\|warum passiert das immer wieder\|welche fehler mache ich oft" "$PE_FILE"; then
        fail "pattern-extractor: description contains German trigger phrases — triggers must use English for consistent auto-matching"
    else
        pass "pattern-extractor: description trigger phrases use English (no German triggers)"
    fi
fi

echo ""
echo "-- iteration-logger trigger language consistency --"
IL_FILE="$SKILLS_DIR/iteration-logger/SKILL.md"
if [ -f "$IL_FILE" ]; then
    if grep -q "Iteration loggen\|Fortschritt festhalten\|was habe ich gemacht\|ich hab gerade einen bug gefixt\|feature ist fertig\|das sollten wir festhalten" "$IL_FILE"; then
        fail "iteration-logger: description contains German trigger phrases — triggers must use English for consistent auto-matching"
    else
        pass "iteration-logger: description trigger phrases use English (no German triggers)"
    fi
fi

echo ""
echo "-- context-keeper trigger language consistency --"
CK_FILE="$SKILLS_DIR/context-keeper/SKILL.md"
if [ -f "$CK_FILE" ]; then
    if grep -q "kontext aktualisieren\|entscheidung festhalten\|warum haben wir\|projektstand aktualisieren\|ADR erstellen\|wir haben uns fuer\|ich nutze jetzt\|projekt hat sich geaendert" "$CK_FILE"; then
        fail "context-keeper: description contains German trigger phrases — triggers must use English for consistent auto-matching"
    else
        pass "context-keeper: description trigger phrases use English (no German triggers)"
    fi
fi

echo ""
echo "-- session-bootstrap trigger language consistency --"
SB_FILE="$SKILLS_DIR/session-bootstrap/SKILL.md"
if [ -f "$SB_FILE" ]; then
    if grep -q "Session starten\|Briefing laden\|woran habe ich gearbeitet\|wo waren wir\|was wissen wir\|neue session\|Projektstand\|lass uns weitermachen\|wo stehen wir\|was ist der aktuelle stand" "$SB_FILE"; then
        fail "session-bootstrap: description contains German trigger phrases — triggers must use English for consistent auto-matching"
    else
        pass "session-bootstrap: description trigger phrases use English (no German triggers)"
    fi
fi

echo ""
echo "-- sync-context trigger language consistency --"
SC_FILE="$SKILLS_DIR/sync-context/SKILL.md"
if [ -f "$SC_FILE" ]; then
    if grep -q "Kontext synchronisieren\|globale Patterns holen\|Wissen teilen\|was gibt es in anderen projekten\|welche patterns kann ich importieren\|wissen uebertragen" "$SC_FILE"; then
        fail "sync-context: description contains German trigger phrases — triggers must use English for consistent auto-matching"
    else
        pass "sync-context: description trigger phrases use English (no German triggers)"
    fi
fi

echo ""
echo "-- wrap-up trigger language consistency --"
WU_FILE="$SKILLS_DIR/wrap-up/SKILL.md"
if [ -f "$WU_FILE" ]; then
    if grep -q "Session beenden\|Zusammenfassung\|fertig fuer heute\|kontext sichern\|ich hoer jetzt auf\|schluss fuer heute\|mach mal ne zusammenfassung\|session beenden\|Keine Iterationen\|Fehler behoben\|aktualisiert\." "$WU_FILE"; then
        fail "wrap-up: description or body contains German phrases — must use English for consistent auto-matching"
    else
        pass "wrap-up: trigger phrases and body use English (no German phrases)"
    fi
fi

echo ""
echo "-- code-reviewer trigger language consistency --"
CR_FILE="$SKILLS_DIR/code-reviewer/SKILL.md"
if [ -f "$CR_FILE" ]; then
    if grep -q "code reviewen\|qualitaet pruefen\|ist der code gut so\|schauen wir uns den code an" "$CR_FILE"; then
        fail "code-reviewer: description contains German trigger phrases — triggers must use English for consistent auto-matching"
    else
        pass "code-reviewer: trigger phrases use English (no German triggers)"
    fi
fi

echo ""
echo "-- session-bootstrap body language consistency --"
SB_FILE="$SKILLS_DIR/session-bootstrap/SKILL.md"
if [ -f "$SB_FILE" ]; then
    if grep -q "Keine vorherige Session gefunden\|Stichwörter" "$SB_FILE"; then
        fail "session-bootstrap: body contains German strings — all user-facing text must use English for consistency"
    else
        pass "session-bootstrap: body uses English (no German strings)"
    fi
fi

echo ""
echo "-- sync-context body language consistency --"
SC_BODY_FILE="$SKILLS_DIR/sync-context/SKILL.md"
if [ -f "$SC_BODY_FILE" ]; then
    if grep -q "holen\|importieren\|teilen\|exportieren\|beides\|was gibt es" "$SC_BODY_FILE"; then
        fail "sync-context: body contains German intent phrases — all direction-matching phrases must use English for consistency"
    else
        pass "sync-context: body uses English (no German direction phrases)"
    fi
fi

echo ""
echo "-- research-phase: findings persistence --"
RP_FILE="$SKILLS_DIR/research-phase/SKILL.md"
if [ -f "$RP_FILE" ]; then
    if grep -q "agent-memory/research\|research-cache" "$RP_FILE"; then
        pass "research-phase: persists findings to .agent-memory/research/ for cross-session reuse"
    else
        fail "research-phase: missing findings persistence — findings are ephemeral and lost after each session (P7: cache intermediate outputs)"
    fi
fi

echo ""
echo "-- wrap-up: optional NotebookLM sync --"
WU2_FILE="$SKILLS_DIR/wrap-up/SKILL.md"
if [ -f "$WU2_FILE" ]; then
    if grep -qi "notebooklm\|notebook.*sync\|sync.*notebook" "$WU2_FILE"; then
        pass "wrap-up: has optional NotebookLM sync step to close learnings feedback loop"
    else
        fail "wrap-up: missing optional NotebookLM sync — session learnings never reach NotebookLM knowledge base (P1: close bidirectional flows)"
    fi
fi

echo ""
echo "=== Results: $PASSED/$TESTS passed, $ERRORS failures ==="
[ "$ERRORS" -eq 0 ]
