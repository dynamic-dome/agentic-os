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
            if echo "$desc_line" | grep -qE '\|[[:space:]]*$|>[[:space:]]*$'; then
                # Multiline: measure content after description: line until next frontmatter key or ---
                desc_len=$(awk '
                    /^description:/ { in_desc=1; next }
                    in_desc && (/^[a-z_][a-z_]*:/ || /^---/) { exit }
                    in_desc { print }
                ' "$skill_file" | wc -c)
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

# test-validator, code-reviewer merged into quality-gate in v3 consolidation

echo ""
echo "-- quality-gate language consistency --"
QG_FILE="$SKILLS_DIR/quality-gate/SKILL.md"
if [ -f "$QG_FILE" ]; then
    if grep -q "^### Schritt" "$QG_FILE"; then
        fail "quality-gate: body uses German section headers (e.g. 'Schritt') — skill bodies must use English"
    else
        pass "quality-gate: body section headers use English (no 'Schritt' headers)"
    fi
fi

echo ""
echo "-- wrap-up session-summary template language consistency --"
WU_FILE="$SKILLS_DIR/wrap-up/SKILL.md"
if [ -f "$WU_FILE" ]; then
    # The LOCAL .agent-memory/session-summary.md template (Step 5) must use English
    # for consistency with the rest of the plugin. The CENTRAL cross-project handoff
    # (Step 7.6a) is EXEMPT: it follows the external SESSION-WORKFLOW.md spec, which
    # mandates German headers ("# Letzte Session" etc.) and forbids inventing other
    # formats. So we scan only the body BEFORE Step 7.6.
    WU_LOCAL_PART=$(awk '/^## Step 7.6/{exit} {print}' "$WU_FILE")
    if echo "$WU_LOCAL_PART" | grep -q "## Was wurde gemacht\|## Offene Punkte\|## Naechste Schritte\|## Aktive Warnungen"; then
        fail "wrap-up: LOCAL session-summary.md template (Step 5) uses German section headers — must use English (Step 7.6a central handoff is exempt by SESSION-WORKFLOW.md)"
    else
        pass "wrap-up: LOCAL session-summary.md template uses English section headers (central handoff in Step 7.6a correctly exempt)"
    fi
fi

# tdd, code-reviewer JSON template tests removed — merged into quality-gate in v3

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

# code-reviewer trigger test removed — merged into quality-gate in v3

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
echo "-- research-pipeline: no non-standard triggers: field --"
RPL_FILE="$SKILLS_DIR/research-pipeline/SKILL.md"
if [ -f "$RPL_FILE" ]; then
    FRONTMATTER=$(awk '/^---/{c++} c==1{print} c==2{exit}' "$RPL_FILE")
    if echo "$FRONTMATTER" | grep -q "^triggers:"; then
        fail "research-pipeline: has non-standard triggers: field — no other skill uses this field; trigger phrases belong in the description: field"
    else
        pass "research-pipeline: no non-standard triggers: field (consistent with all other skills)"
    fi
fi

echo ""
echo "-- research-pipeline: description in English --"
RPL_FILE="$SKILLS_DIR/research-pipeline/SKILL.md"
if [ -f "$RPL_FILE" ]; then
    DESC=$(awk '/^---/{c++; next} c==1 && /^description:/{sub(/^description:[[:space:]]*/,""); p=1; print} c==1 && p && /^[a-z_-]+:/{p=0} c==1 && p{print} c==2{exit}' "$RPL_FILE")
    if echo "$DESC" | grep -qi "optimierte\|ersparnis\|spart[[:space:]]\|web-recherche"; then
        fail "research-pipeline: description field contains German text — description must be English for consistent skill matching"
    else
        pass "research-pipeline: description field uses English"
    fi
fi

# research-phase test removed — merged into self-improve in v3
echo ""
echo "-- self-improve: research findings persistence --"
SI_FILE="$SKILLS_DIR/self-improve/SKILL.md"
if [ -f "$SI_FILE" ]; then
    if grep -q "agent-memory/research\|research-cache" "$SI_FILE"; then
        pass "self-improve: persists research findings to .agent-memory/research/ for cross-session reuse"
    else
        fail "self-improve: missing research findings persistence"
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
echo "-- self-improve: metadata block present --"
SI2_FILE="$SKILLS_DIR/self-improve/SKILL.md"
if [ -f "$SI2_FILE" ]; then
    FRONTMATTER=$(awk '/^---/{c++} c==1{print} c==2{exit}' "$SI2_FILE")
    if echo "$FRONTMATTER" | grep -q "metadata:"; then
        pass "self-improve: has metadata block (consistent with all other skills)"
    else
        fail "self-improve: missing metadata block — all other skills have metadata with author, version, part-of, layer fields for plugin membership and discoverability"
    fi
fi

echo ""
echo "-- research-pipeline: metadata block present --"
RP2_FILE="$SKILLS_DIR/research-pipeline/SKILL.md"
if [ -f "$RP2_FILE" ]; then
    FRONTMATTER=$(awk '/^---/{c++} c==1{print} c==2{exit}' "$RP2_FILE")
    if echo "$FRONTMATTER" | grep -q "metadata:"; then
        pass "research-pipeline: has metadata block (consistent with all other skills)"
    else
        fail "research-pipeline: missing metadata block — all skills must have metadata with author, version, part-of, layer fields for plugin membership and discoverability"
    fi
fi

# analysis-phase tests removed — merged into self-improve in v3

echo ""
echo "-- self-improve: consistent rollback strategy (no git stash) --"
SI_FILE="$SKILLS_DIR/self-improve/SKILL.md"
if [ -f "$SI_FILE" ]; then
    if grep -qE "git stash (push|pop)" "$SI_FILE"; then
        fail "self-improve: uses 'git stash push/pop' for rollback — contradicts improvement-phase which forbids stash-based rollback (fragile: stash may be empty or contain unrelated entries). Use commit-hash checkpoint instead."
    else
        pass "self-improve: rollback strategy consistent — no git stash push/pop (uses commit-hash checkpoint)"
    fi
fi

echo ""
echo "-- research-pipeline: timeout value consistent (no 60s/600s conflict) --"
RP3_FILE="$SKILLS_DIR/research-pipeline/SKILL.md"
if [ -f "$RP3_FILE" ]; then
    if grep -q "\-\-timeout 600" "$RP3_FILE" && grep -q "within 60s" "$RP3_FILE"; then
        fail "research-pipeline: timeout inconsistency — --timeout 600 (10min) in step 4 conflicts with 'within 60s' in error handling section"
    else
        pass "research-pipeline: timeout values consistent (no --timeout 600 vs 60s conflict)"
    fi
fi

echo ""
echo "-- wrap-up: state.json path specified for self-improve loop check --"
WU3_FILE="$SKILLS_DIR/wrap-up/SKILL.md"
if [ -f "$WU3_FILE" ]; then
    if grep -q "state.json" "$WU3_FILE" && ! grep -qE "improvements/state\.json|improvements/state" "$WU3_FILE"; then
        fail "wrap-up: references 'state.json' without path — agents won't know it's 'improvements/state.json' in the plugin root"
    else
        pass "wrap-up: state.json reference includes full path (improvements/state.json)"
    fi
fi

echo ""
echo "-- session-bootstrap: errors.json load count consistent with usage --"
SB2_FILE="$SKILLS_DIR/session-bootstrap/SKILL.md"
if [ -f "$SB2_FILE" ]; then
    if grep -q "last 5 entries" "$SB2_FILE" && grep -q "Last 3 errors\|last 3 errors" "$SB2_FILE"; then
        fail "session-bootstrap: Step 2 loads 'last 5 entries' from errors.json but Step 4/5 only use 'last 3 errors' — inconsistent, causes confusion about buffer size"
    else
        pass "session-bootstrap: errors.json load count consistent with usage in Step 4/5"
    fi
fi

echo ""
echo "-- quality-gate: WARN verdict checks regressions --"
QG_FILE="$SKILLS_DIR/quality-gate/SKILL.md"
if [ -f "$QG_FILE" ]; then
    WARN_LINE=$(grep "^\*\*WARN\*\*:" "$QG_FILE" | head -1)
    if echo "$WARN_LINE" | grep -qiE "regression"; then
        pass "quality-gate: WARN verdict criteria includes regression check"
    else
        fail "quality-gate: WARN verdict ignores regressions — a build with regressions should never be WARN (only FAIL)"
    fi
fi

echo ""
echo "-- quality-gate: pytest collection gate --"
QG_FILE="$SKILLS_DIR/quality-gate/SKILL.md"
if [ -f "$QG_FILE" ]; then
    if grep -q -- "--co -q" "$QG_FILE" && grep -qiE "0 tests collected|collected 0 items|no tests ran|exit code 5" "$QG_FILE" && grep -q "health_score = 0" "$QG_FILE"; then
        pass "quality-gate: pytest collection gate fails closed on zero collected tests"
    else
        fail "quality-gate: missing pytest collection gate — must run pytest --co -q and fail when zero tests are collected"
    fi
fi

echo ""
echo "-- skill-generator: template includes metadata block --"
SG_FILE="$SKILLS_DIR/skill-generator/SKILL.md"
if [ -f "$SG_FILE" ]; then
    TEMPLATE=$(awk '/^```markdown/{found=1; next} found && /^```/{exit} found{print}' "$SG_FILE")
    if echo "$TEMPLATE" | grep -q "metadata:"; then
        pass "skill-generator: template includes metadata block (consistent with all existing skills)"
    else
        fail "skill-generator: template missing metadata block — all 10 existing skills have metadata with author/version/part-of/layer; generated skills should too"
    fi
fi

# --- self-improve hardening levers (Wiki-TODO 2026-06-02-self-improve-mechanismus-haerten) ---
# Each test pins one of the 5 levers into the SKILL.md body so they cannot silently
# drift back out. SI_HARDEN_FILE is the self-improve skill.
SI_HARDEN_FILE="$SKILLS_DIR/self-improve/SKILL.md"

# Each lever carries a unique "(lever N)" marker in the SKILL.md body. The tests bind to
# that marker AND a concept phrase, so stripping the hardening removes the marker and the
# test goes red — verified via a strip-and-restore counter-probe (2026-06-03).

echo ""
echo "-- self-improve: lever 1 (global pattern-fixing before commit) --"
if [ -f "$SI_HARDEN_FILE" ]; then
    # Phase 3 must grep the just-fixed signature tree-wide before commit, not stop at the first hit.
    if grep -qiE "\(lever 1\)" "$SI_HARDEN_FILE" \
       && grep -qiE "all occurrences of the pattern before commit|fix all occurrences" "$SI_HARDEN_FILE"; then
        pass "self-improve: lever 1 present — global pattern-fixing across the tree before commit"
    else
        fail "self-improve: lever 1 missing — Phase 3 must grep the fixed pattern across the whole skill/plugin tree and fix every occurrence before commit (else the loop re-fixes the same pattern in a later iteration)"
    fi
fi

echo ""
echo "-- self-improve: lever 2 (substance-based diminishing-returns stop) --"
if [ -f "$SI_HARDEN_FILE" ]; then
    # Circuit breaker must consider substance (only language/count fixes), not just fix-count.
    if grep -qiE "\(lever 2\)" "$SI_HARDEN_FILE" \
       && grep -qiE "only cosmetic fixes|SUBSTANCE-CONVERGENCE" "$SI_HARDEN_FILE"; then
        pass "self-improve: lever 2 present — substance-based diminishing-returns stop"
    else
        fail "self-improve: lever 2 missing — circuit breaker must also stop when N consecutive iterations produce only language/count fixes (no functional bug), not just on fix-count"
    fi
fi

echo ""
echo "-- self-improve: lever 3 (functional analysis lens in Phase 2) --"
if [ -f "$SI_HARDEN_FILE" ]; then
    # Phase 2 must include a functional/runtime lens, not only frontmatter/language/counts.
    if grep -qiE "\(lever 3\)" "$SI_HARDEN_FILE" \
       && grep -qiE "Functional Lens|functional lens" "$SI_HARDEN_FILE"; then
        pass "self-improve: lever 3 present — functional analysis lens in Phase 2"
    else
        fail "self-improve: lever 3 missing — Phase 2 must add a functional lens (e.g. does a skill declare outputs no step writes? does a gate ignore regressions?), not only frontmatter/language/count checks"
    fi
fi

echo ""
echo "-- self-improve: lever 4 (state<->.md atomicity check) --"
if [ -f "$SI_HARDEN_FILE" ]; then
    # Every state.json history entry must have a matching .md block; the two writes are coupled.
    if grep -qiE "\(lever 4\)" "$SI_HARDEN_FILE" \
       && grep -qiE "STATE-MD-DRIFT" "$SI_HARDEN_FILE"; then
        pass "self-improve: lever 4 present — state.json<->.md atomicity / consistency check"
    else
        fail "self-improve: lever 4 missing — every state.json history entry must have a matching iterations-*.md block; the .md write must be coupled atomically to the state.json update"
    fi
fi

echo ""
echo "-- self-improve: lever 5 (absolute baseline sanity check) --"
if [ -f "$SI_HARDEN_FILE" ]; then
    # Absolute test-count sanity (halved / zero -> STOP), not only per-iteration delta.
    if grep -qiE "\(lever 5\)" "$SI_HARDEN_FILE" \
       && grep -qiE "BASELINE-SANITY" "$SI_HARDEN_FILE"; then
        pass "self-improve: lever 5 present — absolute baseline sanity check"
    else
        fail "self-improve: lever 5 missing — Phase 0/4 must add an absolute baseline sanity check (test count halved or zero -> STOP + report), not only the per-iteration delta"
    fi
fi

# --- Memory Growth Engine (Master-Plan 2026-06-03, Sprint user.md + soul.md) ---
# Pins the growth mechanics into the owning skill bodies. Marker-based + concept phrase,
# bidirectionally verified (strip -> FAIL, restore -> PASS).
WU_GROW_FILE="$SKILLS_DIR/wrap-up/SKILL.md"
SB_GROW_FILE="$SKILLS_DIR/session-bootstrap/SKILL.md"
MM_GROW_FILE="$SKILLS_DIR/memory-maintenance/SKILL.md"

echo ""
echo "-- wrap-up: user.md growth engine (candidate queue + 3-stage classification) --"
if [ -f "$WU_GROW_FILE" ]; then
    # Also pin the promotion rule (inferred + occ>=2 + conf>=0.6) and the changelog-before-write
    # atomicity — otherwise the test stays green if those guarantees are stripped (Codex MAJOR #1).
    if grep -qiE "\(user-growth\)" "$WU_GROW_FILE" \
       && grep -qiE "user-candidates\.json" "$WU_GROW_FILE" \
       && grep -qiE "observed.*inferred.*confirmed|observed / inferred / confirmed" "$WU_GROW_FILE" \
       && grep -qiE "inferred.*AND.*occurrences|occurrences.*AND.*confidence" "$WU_GROW_FILE" \
       && grep -qE "0\.6" "$WU_GROW_FILE" \
       && grep -qiE "changelog BEFORE|before the user\.md|changelog.*before the|first.*append.*changelog" "$WU_GROW_FILE"; then
        pass "wrap-up: user.md growth engine present — queue + 3-stage + promotion rule + changelog-before-write"
    else
        fail "wrap-up: user.md growth engine missing — Step 6 must use working/user-candidates.json with observed/inferred/confirmed, the promotion rule (inferred + occ>=2 + conf>=0.6) AND changelog-before-write atomicity, replacing the dead '3+ corrections' direct-write"
    fi
fi

echo ""
echo "-- wrap-up: user.md growth — mood never promoted + changelog/rollback --"
if [ -f "$WU_GROW_FILE" ]; then
    if grep -qiE "signal:mood|mood.*never promot|never promot.*mood" "$WU_GROW_FILE" \
       && grep -qiE "user-changelog\.json" "$WU_GROW_FILE"; then
        pass "wrap-up: user.md growth — mood-marker excluded from promotion + user-changelog.json audit/rollback"
    else
        fail "wrap-up: user.md growth missing safeguards — must exclude signal:mood from promotion AND log every change to identity/user-changelog.json (audit + rollback)"
    fi
fi

echo ""
echo "-- wrap-up: user.md growth — trust boundary (conversation-only) --"
if [ -f "$WU_GROW_FILE" ]; then
    # Candidates must originate from user conversation, NEVER from web/docs/notebooklm/wiki (poisoning).
    # Bind the forbidden-source list to the (trust-boundary) marker's own block (grep -A2), so an
    # unrelated 'NotebookLM' elsewhere (Step 7 sync) can't keep this green if the boundary is stripped
    # (Codex MAJOR #2 — verified strip->FAIL on the marker block).
    TB_BLOCK=$(grep -A2 -iE "\(trust-boundary\)" "$WU_GROW_FILE")
    if [ -n "$TB_BLOCK" ] \
       && echo "$TB_BLOCK" | grep -qiE "trust_source|conversation" \
       && echo "$TB_BLOCK" | grep -qiE "web/docs|NotebookLM|wiki content|untrusted"; then
        pass "wrap-up: user.md growth — trust boundary enforced (conversation-only, forbidden sources named in marker block)"
    else
        fail "wrap-up: user.md growth missing trust boundary — the (trust-boundary) block must name the forbidden sources (web/docs/NotebookLM/wiki) candidates may NEVER come from (memory poisoning)"
    fi
fi

echo ""
echo "-- wrap-up: soul.md growth — candidate queue (Stufe B, no auto-write) --"
if [ -f "$WU_GROW_FILE" ]; then
    # Also pin the no-autonomous-write invariant, not just the queue file (Codex MAJOR #3).
    if grep -qiE "\(soul-growth\)" "$WU_GROW_FILE" \
       && grep -qiE "soul-candidates\.md" "$WU_GROW_FILE" \
       && grep -qiE "[Nn]ever write .?soul\.md|[Nn]ever auto-write|NEVER auto-written|not write .?soul\.md here" "$WU_GROW_FILE"; then
        pass "wrap-up: soul.md growth present — appends to soul-candidates.md, never auto-writes soul.md"
    else
        fail "wrap-up: soul.md growth missing — must append to identity/soul-candidates.md AND state the never-write-soul.md-directly invariant"
    fi
fi

echo ""
echo "-- session-bootstrap: soul.md candidate gate ([j/n], confirmed-write only) --"
if [ -f "$SB_GROW_FILE" ]; then
    if grep -qiE "soul-candidates\.md" "$SB_GROW_FILE" \
       && grep -qiE "\[j/n\]|j/n" "$SB_GROW_FILE" \
       && grep -qiE "only (on|after) (confirm|user|explicit)|confirmed.*write|nur bei" "$SB_GROW_FILE"; then
        pass "session-bootstrap: soul candidate gate present — [j/n], soul.md write only on explicit confirmation"
    else
        fail "session-bootstrap: soul candidate gate missing — must surface soul-candidates.md with a [j/n] gate and write soul.md ONLY on explicit user confirmation (the single read-only exception)"
    fi
fi

echo ""
echo "-- memory-maintenance: soul.md 80-line anti-bloat cap --"
if [ -f "$MM_GROW_FILE" ]; then
    if grep -qiE "soul\.md" "$MM_GROW_FILE" && grep -qiE "80[ -]?(line|Zeile)" "$MM_GROW_FILE"; then
        pass "memory-maintenance: soul.md 80-line cap present (anti-bloat linter)"
    else
        fail "memory-maintenance: soul.md 80-line cap missing — consistency check must warn when soul.md exceeds 80 lines (identity dilution)"
    fi
fi

# --- patterns.json schema canon (Audit-Hebel #3, 2026-06-03) ---
# pattern-extractor is the sole writer of patterns.json, so its documented schema is the
# Single Source of Truth. The canonical fields are description / recommendation / evidence
# (NOT the legacy name/solution/source_errors or title/prevention/error_ids shapes). The skill
# must also instruct normalization of legacy entries on read, so the store converges to one shape.
PE_SCHEMA_FILE="$SKILLS_DIR/pattern-extractor/SKILL.md"

echo ""
echo "-- pattern-extractor: canonical patterns.json schema (description/recommendation/evidence) --"
if [ -f "$PE_SCHEMA_FILE" ]; then
    if grep -qiE "\(pattern-schema-canon\)" "$PE_SCHEMA_FILE" \
       && grep -qE '"recommendation"' "$PE_SCHEMA_FILE" \
       && grep -qE '"evidence"' "$PE_SCHEMA_FILE" \
       && grep -qE '"severity"' "$PE_SCHEMA_FILE" \
       && grep -qiE "normaliz|legacy.*(solution|source_errors|prevention|error_ids)|solution.*->.*recommendation" "$PE_SCHEMA_FILE"; then
        pass "pattern-extractor: canonical schema pinned + legacy-normalization instruction present"
    else
        fail "pattern-extractor: patterns.json schema canon missing — must declare description/recommendation/evidence as canonical AND instruct normalizing legacy name/solution/source_errors + title/prevention/error_ids entries on read (single-shape convergence)"
    fi
fi

# --- sync-context recency supersession (Audit-Hebel #4, 2026-06-03) ---
# Conflicting facts in the same scope must be resolved by recency (write-time supersession),
# NOT by confidence alone — a stale high-confidence fact must not beat a newer one (Mem0
# interference). Max one `active` per (fact_type, scope); the older one becomes `superseded`
# (never deleted). Confidence-merge for NON-conflicting same-fact entries stays.
SC_SUP_FILE="$SKILLS_DIR/sync-context/SKILL.md"

echo ""
echo "-- sync-context: recency supersession on conflict (not confidence-only) --"
if [ -f "$SC_SUP_FILE" ]; then
    if grep -qiE "\(recency-supersession\)" "$SC_SUP_FILE" \
       && grep -qiE "supersed" "$SC_SUP_FILE" \
       && grep -qiE "max(imum)? (one|1) active|one active per|never delete" "$SC_SUP_FILE" \
       && grep -qiE "recency|newer.*wins|timestamp|last_seen.*wins" "$SC_SUP_FILE" \
       && grep -qiE "confidence (only|does not|only ranks)|ranks .*non-conflicting|non-conflicting.*merge" "$SC_SUP_FILE"; then
        pass "sync-context: recency supersession present — conflicts by recency (superseded not deleted), confidence-merge kept for non-conflicts"
    else
        fail "sync-context: recency supersession missing — same-scope CONFLICTS must be resolved by recency (write-time supersession: max 1 active per scope, older -> superseded, never deleted), not by confidence alone (stale-high-confidence interference)"
    fi
fi

# --- sync-context 4.A privacy pre-filter (must run BEFORE the gate) ---
# A denied tag (credentials/pii/secret) or signal_type "mood" must be dropped from the
# push set BEFORE the confidence threshold / promotion gate — privacy cannot be bought
# back by a high confidence or occurrence count.
echo ""
echo "-- sync-context: privacy pre-filter precedes the gate --"
if [ -f "$SC_SUP_FILE" ]; then
    if grep -qiE "\(privacy-filter\)" "$SC_SUP_FILE" \
       && grep -qiE "MEM_GLOBAL_DENY_TAGS|is_denied" "$SC_SUP_FILE" \
       && grep -qiE "Denied \(privacy\)" "$SC_SUP_FILE" \
       && grep -qiE "BEFORE the (threshold|gate)|runs BEFORE|checked first" "$SC_SUP_FILE"; then
        pass "sync-context: privacy pre-filter present and ordered before the gate"
    else
        fail "sync-context: privacy pre-filter missing or not ordered — denied tags / signal_type mood must be dropped BEFORE the confidence/promotion gate (Denied (privacy)), reading MEM_GLOBAL_DENY_TAGS via is_denied"
    fi
fi

# --- sync-context 4.A global provenance schema on push ---
# Every entry written to the global store carries the G-<type>-<n> provenance contract:
# scope (conflict key), valid_from, source_evidence, lifecycle.
echo ""
echo "-- sync-context: global provenance schema stamped on push --"
if [ -f "$SC_SUP_FILE" ]; then
    if grep -qiE "\(provenance-schema\)" "$SC_SUP_FILE" \
       && grep -qiE "G-<?fact_type>?-|G-pattern-" "$SC_SUP_FILE" \
       && grep -qiE "valid_from" "$SC_SUP_FILE" \
       && grep -qiE "source_evidence" "$SC_SUP_FILE" \
       && grep -qiE "scope.*compute_scope|compute_scope\(fact_type" "$SC_SUP_FILE"; then
        pass "sync-context: global provenance schema present (G-<type>-<n>, scope, valid_from, source_evidence)"
    else
        fail "sync-context: global provenance schema missing — push must stamp G-<fact_type>-<n> id, scope=compute_scope(fact_type,tags), valid_from, source_evidence, lifecycle on every global entry"
    fi
fi

# --- sync-context 4.A promotion gate (local -> global) ---
# Three hard conditions to promote to active: confidence>=0.6 AND occurrences>=3 AND
# |source_projects|>=2. Failing the gate keeps the entry as candidate (never active).
echo ""
echo "-- sync-context: promotion gate (conf>=0.6 ∧ occ>=3 ∧ projects>=2) --"
if [ -f "$SC_SUP_FILE" ]; then
    if grep -qiE "\(promotion-gate\)" "$SC_SUP_FILE" \
       && grep -qiE "passes_promotion_gate" "$SC_SUP_FILE" \
       && grep -qiE "occurrences >= 3" "$SC_SUP_FILE" \
       && grep -qiE "source_projects\` ?>= 2|source_projects\| ?>= 2|\|source_projects\| >= 2" "$SC_SUP_FILE" \
       && grep -qiE "lifecycle: ?candidate|stays .candidate" "$SC_SUP_FILE"; then
        pass "sync-context: promotion gate present — 3 conditions, fail keeps candidate"
    else
        fail "sync-context: promotion gate missing — promotion to active needs confidence>=0.6 AND occurrences>=3 AND |source_projects|>=2 (passes_promotion_gate); failing keeps lifecycle:candidate"
    fi
fi

# --- sync-context 4.A pull lifecycle filter ---
# Pull serves ONLY lifecycle:active; candidate/superseded/archived are never pulled.
echo ""
echo "-- sync-context: pull serves only lifecycle:active --"
if [ -f "$SC_SUP_FILE" ]; then
    if grep -qiE "\(pull-lifecycle-filter\)" "$SC_SUP_FILE" \
       && grep -qiE "lifecycle: ?active" "$SC_SUP_FILE" \
       && grep -qiE "[Ss]kip .*(candidate|superseded|archived)" "$SC_SUP_FILE"; then
        pass "sync-context: pull lifecycle filter present — only active served"
    else
        fail "sync-context: pull lifecycle filter missing — Pull must serve ONLY lifecycle:active and skip candidate/superseded/archived"
    fi
fi

echo ""
echo "=== Results: $PASSED/$TESTS passed, $ERRORS failures ==="
[ "$ERRORS" -eq 0 ]
