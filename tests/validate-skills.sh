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

echo ""
echo "=== Results: $PASSED/$TESTS passed, $ERRORS failures ==="
[ "$ERRORS" -eq 0 ]
