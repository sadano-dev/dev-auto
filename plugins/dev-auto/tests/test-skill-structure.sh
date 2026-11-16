#!/usr/bin/env bash
# test-skill-structure.sh — Validate dev-auto plugin structure
# Checks plugin.json / marketplace entry / SKILL.md conventions / references /
# cross-skill references / detect-env.sh behavior

set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_DIR/../.." && pwd)"

PASS=0
FAIL=0

pass() { echo "  ✅ PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  ❌ FAIL: $1"; FAIL=$((FAIL + 1)); }

summary() {
  echo ""
  echo "======================================"
  echo "Results: $PASS passed, $FAIL failed"
  [[ $FAIL -eq 0 ]]
}

SKILLS=(run spec review-loop pr-finalize design-explore ideate refine)

echo ""
echo "Test: dev-auto Plugin Structure"
echo "======================================"

# ============================================================
# Test 1: plugin.json
# ============================================================
echo ""
echo "Test 1: plugin.json"
if python3 -m json.tool "$PLUGIN_DIR/.claude-plugin/plugin.json" >/dev/null 2>&1; then
  pass "plugin.json is valid JSON"
else
  fail "plugin.json is not valid JSON"
fi
if grep -q '"name": "dev-auto"' "$PLUGIN_DIR/.claude-plugin/plugin.json"; then
  pass "plugin.json name is dev-auto"
else
  fail "plugin.json name is not dev-auto"
fi

# ============================================================
# Test 2: marketplace.json entry (and version in sync)
# ============================================================
echo ""
echo "Test 2: marketplace.json entry"
MARKETPLACE_JSON="$REPO_ROOT/.claude-plugin/marketplace.json"
if python3 -m json.tool "$MARKETPLACE_JSON" >/dev/null 2>&1; then
  pass "marketplace.json is valid JSON"
else
  fail "marketplace.json is not valid JSON"
fi
if python3 - "$MARKETPLACE_JSON" "$PLUGIN_DIR/.claude-plugin/plugin.json" <<'PY'
import json, sys
m = json.load(open(sys.argv[1]))
p = json.load(open(sys.argv[2]))
e = [x for x in m["plugins"] if x["name"] == "dev-auto"]
sys.exit(0 if e and e[0]["source"] == "./plugins/dev-auto" and e[0]["version"] == p["version"] else 1)
PY
then
  pass "marketplace.json has dev-auto entry with matching version"
else
  fail "marketplace.json dev-auto entry missing or version mismatch"
fi

# ============================================================
# Test 3: SKILL.md presence
# ============================================================
echo ""
echo "Test 3: SKILL.md presence"
for s in "${SKILLS[@]}"; do
  if [[ -f "$PLUGIN_DIR/skills/$s/SKILL.md" ]]; then
    pass "skills/$s/SKILL.md exists"
  else
    fail "skills/$s/SKILL.md missing"
  fi
done

# ============================================================
# Test 4: frontmatter (name matches dir, description present)
# ============================================================
echo ""
echo "Test 4: SKILL.md frontmatter"
for s in "${SKILLS[@]}"; do
  f="$PLUGIN_DIR/skills/$s/SKILL.md"
  [[ -f "$f" ]] || continue
  if head -1 "$f" | grep -q '^---$'; then
    pass "$s: frontmatter opens with ---"
  else
    fail "$s: frontmatter missing"
  fi
  if awk '/^---$/{n++} n==1' "$f" | grep -q "^name: $s$"; then
    pass "$s: frontmatter name matches directory"
  else
    fail "$s: frontmatter name does not match directory"
  fi
  if awk '/^---$/{n++} n==1' "$f" | grep -q '^description: '; then
    pass "$s: frontmatter has description"
  else
    fail "$s: frontmatter missing description"
  fi
done

# ============================================================
# Test 5: required sections
# ============================================================
echo ""
echo "Test 5: required sections"
REQUIRED_SECTIONS=("## いつ使うか" "## 進め方" "## 成果物" "## 完了チェックリスト" "## 次のステップ" "## やらないこと")
for s in "${SKILLS[@]}"; do
  f="$PLUGIN_DIR/skills/$s/SKILL.md"
  [[ -f "$f" ]] || continue
  missing=""
  for sec in "${REQUIRED_SECTIONS[@]}"; do
    grep -q "^$sec" "$f" || missing="$missing '$sec'"
  done
  if [[ -z "$missing" ]]; then
    pass "$s: all required sections present"
  else
    fail "$s: missing sections:$missing"
  fi
done

# ============================================================
# Test 6: references files exist
# ============================================================
echo ""
echo "Test 6: references files"
EXPECTED_REFS=(
  "run/references/state-format.md"
  "run/references/autonomous-policy.md"
  "run/references/slicing.md"
  "spec/references/spec-templates.md"
  "spec/references/mockup-viewer.html"
  "design-explore/references/board-template.html"
  "design-explore/references/gallery-index.html"
  "design-explore/references/directions.md"
  "design-explore/references/verify.md"
)
for r in "${EXPECTED_REFS[@]}"; do
  if [[ -f "$PLUGIN_DIR/skills/$r" ]]; then
    pass "references: $r exists"
  else
    fail "references: $r missing"
  fi
done

# ============================================================
# Test 7: command file points at the orchestrator
# ============================================================
echo ""
echo "Test 7: command file"
if [[ -f "$PLUGIN_DIR/commands/dev-auto.md" ]]; then
  pass "commands/dev-auto.md exists"
  if grep -q 'dev-auto:run' "$PLUGIN_DIR/commands/dev-auto.md"; then
    pass "command references dev-auto:run"
  else
    fail "command does not reference dev-auto:run"
  fi
else
  fail "commands/dev-auto.md missing"
fi

# ============================================================
# Test 8: orchestrator wires every phase skill
# ============================================================
echo ""
echo "Test 8: orchestrator wiring"
RUN="$PLUGIN_DIR/skills/run/SKILL.md"
for ref in dev-auto:spec dev-auto:review-loop dev-auto:pr-finalize \
           tsumiki:dev-context tsumiki:dev-plan tsumiki:dev-run tsumiki:dev-verify \
           tsumiki:dev-webtest-plan tsumiki:dev-webtest "tsumiki:dev-webtest retest" "tsumiki:dev-debug webtest" \
           tsumiki:dcs:feature-rubber-duck tsumiki:dcs:incremental-dev tsumiki:uat-test-design \
           "--uat" "docs/uat/" "design-system.md" "references/slicing.md" \
           "docs/dev-auto/roadmap.md" "docs/dev-auto/slices/" "分割判定" \
           "docs/dev-auto/roadmaps/" "scripts/slice-claims.sh" "関係判定" "related_roadmaps"; do
  if grep -qF -- "$ref" "$RUN"; then
    pass "run references $ref"
  else
    fail "run does not reference $ref"
  fi
done
if grep -qF '### 7. 未解決事項を引き継ぐ' "$PLUGIN_DIR/skills/pr-finalize/SKILL.md" \
  && grep -qF 'gh issue create' "$PLUGIN_DIR/skills/pr-finalize/SKILL.md" \
  && grep -qF '着手前の見直しメモ' "$PLUGIN_DIR/skills/pr-finalize/SKILL.md"; then
  pass "pr-finalize hands unresolved items off to issues or slice review notes"
else
  fail "pr-finalize does not hand unresolved items off (step 7)"
fi
if grep -qF 'code-review:code-review' "$PLUGIN_DIR/skills/pr-finalize/SKILL.md"; then
  pass "pr-finalize invokes official code-review:code-review"
else
  fail "pr-finalize does not invoke code-review:code-review"
fi
if grep -qF 'high --fix' "$PLUGIN_DIR/skills/review-loop/SKILL.md" && grep -qF 'medium --fix' "$PLUGIN_DIR/skills/review-loop/SKILL.md"; then
  pass "review-loop pins explicit code-review levels (high first, medium re-check)"
else
  fail "review-loop does not pin code-review levels"
fi

for f in spec pr-finalize; do
  if grep -qF 'roadmap.md' "$PLUGIN_DIR/skills/$f/SKILL.md"; then
    pass "$f handles the roadmap"
  else
    fail "$f does not handle the roadmap"
  fi
done
SLICING="$PLUGIN_DIR/skills/run/references/slicing.md"
for sec in "## 分割するかの判定" "## roadmap.md の形式" "## 区切りファイル" "## 続きから始めるときのルール" "## 状態を更新するタイミング" \
           "## 新しい topic か、既存の topic に足すか" "### 他で作業中かの確認" "### 旧形式"; do
  if grep -qF "$sec" "$SLICING"; then
    pass "slicing.md has '$sec'"
  else
    fail "slicing.md missing '$sec'"
  fi
done
if grep -qF 'related_roadmaps' "$PLUGIN_DIR/skills/spec/SKILL.md"; then
  pass "spec/SKILL.md mentions related_roadmaps"
else
  fail "spec/SKILL.md does not mention related_roadmaps"
fi

# ============================================================
# Test 8b: phase numbering is consistent (11 phases)
# ============================================================
echo ""
echo "Test 8b: phase numbering"
STATE_FMT="$PLUGIN_DIR/skills/run/references/state-format.md"
if grep -q '^- \[ \] 10\. uat' "$STATE_FMT" && grep -q '^- \[ \] 11\. pr' "$STATE_FMT"; then
  pass "state template lists uat (10) and pr (11)"
else
  fail "state template phase list is out of date"
fi
if grep -rn 'フェーズ 5〜10\|フェーズ 10 は PR\|フェーズ 10 から' "$PLUGIN_DIR/skills" >/dev/null; then
  fail "stale phase-10-as-PR reference remains"
else
  pass "no stale phase-10-as-PR references"
fi

# ============================================================
# Test 8c: spec skill — design system and PC/phone mockups
# ============================================================
echo ""
echo "Test 8c: spec design system and responsive mockups"
SPEC="$PLUGIN_DIR/skills/spec/SKILL.md"
for ref in "design-system.md" "mockup-viewer.html" "375px" "1280px" "WCAG AA"; do
  if grep -qF "$ref" "$SPEC"; then
    pass "spec mentions $ref"
  else
    fail "spec does not mention $ref"
  fi
done
VIEWER="$PLUGIN_DIR/skills/spec/references/mockup-viewer.html"
if grep -q 'const SCREENS' "$VIEWER" && grep -q 'width: 1280' "$VIEWER" && grep -q 'width: 375' "$VIEWER"; then
  pass "mockup viewer defines SCREENS and both device widths"
else
  fail "mockup viewer missing SCREENS or device widths"
fi
if grep -qE 'src="https?://' "$VIEWER"; then
  fail "mockup viewer loads external resources"
else
  pass "mockup viewer is self-contained"
fi

# ============================================================
# Test 8d: design-explore — board template, gallery, verification
# ============================================================
echo ""
echo "Test 8d: design-explore templates"
DX="$PLUGIN_DIR/skills/design-explore"
BOARD="$DX/references/board-template.html"
for ref in "container: app / inline-size" "@container app" 'board-frame.pc .device { width: 1280px; }' 'board-frame.sp .device { width: 375px; }' 'sp.className = "board-frame sp"' 'el.id += "-sp"' "compare-switch"; do
  if grep -qF -- "$ref" "$BOARD"; then
    pass "board-template has $ref"
  else
    fail "board-template missing $ref"
  fi
done
if grep -q 'var D = \[' "$DX/references/gallery-index.html" && grep -qF 'shots/' "$DX/references/gallery-index.html"; then
  pass "gallery-index defines the direction array and thumbnails"
else
  fail "gallery-index missing direction array or thumbnails"
fi
for ref in "scrollWidth" "minmax(0, 1fr)" "## よくある崩れ"; do
  if grep -qF -- "$ref" "$DX/references/verify.md"; then
    pass "verify.md mentions $ref"
  else
    fail "verify.md does not mention $ref"
  fi
done
for ref in "00-current.html" "references/directions.md" "references/verify.md" "WCAG AA" "docs/design/"; do
  if grep -qF -- "$ref" "$DX/SKILL.md"; then
    pass "design-explore mentions $ref"
  else
    fail "design-explore does not mention $ref"
  fi
done

# ============================================================
# Test 9: safety rules
# ============================================================
echo ""
echo "Test 9: safety rules"
# dev-retest does not exist in tsumiki; retest must go through dev-webtest
if grep -rn 'dev-retest' "$PLUGIN_DIR/skills" >/dev/null 2>&1; then
  fail "skills reference nonexistent dev-retest skill"
else
  pass "no reference to nonexistent dev-retest"
fi
# ultra review may only appear in a prohibition
if hits=$(grep -rn 'ultra' "$PLUGIN_DIR/skills" | grep -vE '使わない|起動しない|しない'); then
  fail "code-review ultra mentioned outside a prohibition:"
  echo "$hits" | head -5
else
  pass "code-review ultra only appears as a prohibition"
fi
for s in "${SKILLS[@]}"; do
  if grep -q 'git stash' "$PLUGIN_DIR/skills/$s/SKILL.md" && ! grep -qE 'git stash.*(使わない|しない)|(使わない|しない).*git stash' "$PLUGIN_DIR/skills/$s/SKILL.md"; then
    fail "$s: mentions git stash without prohibiting it"
  else
    pass "$s: no permissive git stash usage"
  fi
done

# ============================================================
# Test 9b: autonomous phase keeps going; questions use AskUserQuestion
# ============================================================
echo ""
echo "Test 9b: no-stop and AskUserQuestion rules"
POLICY="$PLUGIN_DIR/skills/run/references/autonomous-policy.md"
for sec in "## 止まらずに進めるルール" "### バックグラウンドで動くスキル・サブエージェント" "#### 止まっていないかの確認（タイマー）" "## ユーザーに確認するときの書き方"; do
  if grep -qF "$sec" "$POLICY"; then
    pass "autonomous-policy.md has '$sec'"
  else
    fail "autonomous-policy.md missing '$sec'"
  fi
done
for s in run review-loop pr-finalize; do
  if grep -qF 'ターンを終えない' "$PLUGIN_DIR/skills/$s/SKILL.md"; then
    pass "$s: forbids ending the turn on intermediate reports"
  else
    fail "$s: does not forbid ending the turn on intermediate reports"
  fi
done
for s in run spec design-explore ideate refine; do
  if grep -qF '平文で' "$PLUGIN_DIR/skills/$s/SKILL.md"; then
    pass "$s: forbids plain-text questions"
  else
    fail "$s: does not forbid plain-text questions"
  fi
done

# ============================================================
# Test 9c: fully autonomous mode (--auto)
# ============================================================
echo ""
echo "Test 9c: --auto mode"
AUTO="$PLUGIN_DIR/skills/run/references/auto-mode.md"
if [[ -f "$AUTO" ]]; then
  pass "run/references/auto-mode.md exists"
else
  fail "run/references/auto-mode.md missing"
fi
for sec in "## 開始時の確認（1回だけ）" "## 止まって訊く例外" "## refine の自動補完" "## 区切りの連続実行" "## 完了報告（全自動モード）" "AskUserQuestion" "decisions.md" "未コミットの変更" "git init"; do
  if grep -qF -- "$sec" "$AUTO" 2>/dev/null; then
    pass "auto-mode.md has '$sec'"
  else
    fail "auto-mode.md missing '$sec'"
  fi
done
for f in skills/run/SKILL.md skills/spec/SKILL.md commands/dev-auto.md README.md; do
  if grep -qF -- "--auto" "$PLUGIN_DIR/$f"; then
    pass "$f mentions --auto"
  else
    fail "$f does not mention --auto"
  fi
done
if grep -qF 'references/auto-mode.md' "$PLUGIN_DIR/skills/run/SKILL.md"; then
  pass "run references references/auto-mode.md"
else
  fail "run does not reference references/auto-mode.md"
fi
if grep -qF 'auto_approve:' "$STATE_FMT" && grep -qF 'agreed_by:' "$STATE_FMT"; then
  pass "state template has auto_approve and agreed_by"
else
  fail "state template missing auto_approve / agreed_by"
fi
if grep -qF '## 全自動モード' "$PLUGIN_DIR/skills/spec/SKILL.md" && grep -qF 'agreed_by: auto' "$PLUGIN_DIR/skills/spec/SKILL.md" && grep -qF '自己レビュー' "$PLUGIN_DIR/skills/spec/SKILL.md"; then
  pass "spec supports --auto with self-review and agreed_by: auto"
else
  fail "spec does not describe the --auto self-review agreement"
fi

# ============================================================
# Test 9d: ideate / refine sub-skills and phase-3 branching
# ============================================================
echo ""
echo "Test 9d: ideate / refine"
IDEATE="$PLUGIN_DIR/skills/ideate/SKILL.md"
REFINE="$PLUGIN_DIR/skills/refine/SKILL.md"
for s in ideate refine; do
  if grep -qF 'AskUserQuestion' "$PLUGIN_DIR/skills/$s/SKILL.md" && grep -qF '(Recommended)' "$PLUGIN_DIR/skills/$s/SKILL.md"; then
    pass "$s: asks via AskUserQuestion with a Recommended option"
  else
    fail "$s: missing AskUserQuestion / (Recommended) rule"
  fi
  if grep -qF -- '--auto' "$PLUGIN_DIR/skills/$s/SKILL.md"; then
    pass "$s: supports --auto"
  else
    fail "$s: does not mention --auto"
  fi
done
if grep -qF '選択肢は最大 4 つ' "$IDEATE" && grep -qF '2 問目' "$IDEATE" && grep -qF '最大 4 つ並べる' "$IDEATE"; then
  pass "ideate documents the 4-option AskUserQuestion limit with a second question"
else
  fail "ideate does not document the 4-option selection rule"
fi
# each numbered first-question list must have at most 4 items
if awk '/^1 問目/{c=0; inq=1; next} inq && /^[0-9]+\. /{c++; if(c>4) bad=1} inq && /^2 問目/{inq=0} END{exit bad?1:0}' "$IDEATE"; then
  pass "ideate first-question option lists have at most 4 options"
else
  fail "ideate lists more than 4 options in a question"
fi
if grep -qF 'chosen: <案ファイルのパス>' "$IDEATE" && grep -qF 'extra_option:' "$IDEATE"; then
  pass "ideate returns chosen path and extra_option"
else
  fail "ideate return contract (chosen / extra_option) missing"
fi
if grep -qiE 'hackathon|ハッカソン|審査' "$IDEATE"; then
  fail "ideate contains hackathon-specific wording"
else
  pass "ideate is free of hackathon-specific wording"
fi
for ref in "目的" "スコープ" "振る舞い" "受け入れ条件" "扱うデータ" "テーマ・評価基準との対応" "AI の役割" "デモ / 価値の見せ場" "リスクと削る順序" \
           "README.md" "採点基準" "定番" "2 案以上" "もう 1 ラウンド" "round-N" "docs/dev-auto/ideas/" "--out"; do
  if grep -qF -- "$ref" "$IDEATE"; then
    pass "ideate mentions $ref"
  else
    fail "ideate does not mention $ref"
  fi
done
for ref in "prd.md" "ある / 弱い / 無い" "最大 4 問" "やらないこと" "エンティティ名と主な項目" "検証できる" "--gate" "decisions.md" \
           "もっと深く壁打ちしたい" "tsumiki:dcs:feature-rubber-duck" "tsumiki:dcs:incremental-dev" "refine_mode" "## 仮定" "## 未決事項"; do
  if grep -qF -- "$ref" "$REFINE"; then
    pass "refine mentions $ref"
  else
    fail "refine does not mention $ref"
  fi
done
for ref in "dev-auto:ideate" "dev-auto:refine" "アイデア出しから始める（ideate）" "要件を詰める（refine）" "--gate" "★"; do
  if grep -qF -- "$ref" "$RUN"; then
    pass "run phase 3 / dispatch references $ref"
  else
    fail "run does not reference $ref"
  fi
done
for ref in "refine_mode:" "ideas_dir:" "prd_path:"; do
  if grep -qF "$ref" "$STATE_FMT"; then
    pass "state template has $ref"
  else
    fail "state template missing $ref"
  fi
done
if grep -qF 'dev-auto:refine' "$AUTO" && grep -qF 'ideate' "$AUTO"; then
  pass "auto-mode.md covers ideate / refine"
else
  fail "auto-mode.md does not cover ideate / refine"
fi
for f in README.md commands/dev-auto.md; do
  if grep -qF 'dev-auto:ideate' "$PLUGIN_DIR/$f" && grep -qF 'dev-auto:refine' "$PLUGIN_DIR/$f"; then
    pass "$f documents ideate and refine"
  else
    fail "$f does not document ideate and refine"
  fi
done
if python3 - "$REPO_ROOT/.claude-plugin/marketplace.json" <<'PY2'
import json, sys
m = json.load(open(sys.argv[1]))
d = [x for x in m["plugins"] if x["name"] == "dev-auto"][0]["description"]
sys.exit(0 if all(k in d for k in ("--auto", "ideate", "refine")) else 1)
PY2
then
  pass "marketplace description mentions --auto, ideate, refine"
else
  fail "marketplace description is stale"
fi

# ============================================================
# Test 10: detect-env.sh
# ============================================================
echo ""
echo "Test 10: detect-env.sh"
DETECT="$PLUGIN_DIR/scripts/detect-env.sh"
if bash -n "$DETECT"; then
  pass "detect-env.sh parses"
else
  fail "detect-env.sh has syntax errors"
fi
TMP_HOME="$(mktemp -d)"
trap 'rm -rf "$TMP_HOME"' EXIT
mkdir -p "$TMP_HOME/plugins"
out="$(bash "$DETECT" "$TMP_HOME")"
if grep -q '^tsumiki=missing$' <<<"$out" && grep -q '^official_code_review=missing$' <<<"$out"; then
  pass "reports missing plugins on empty config"
else
  fail "empty config not reported as missing: $out"
fi
cat >"$TMP_HOME/plugins/installed_plugins.json" <<'JSON'
{"version": 2, "plugins": {"tsumiki@tsumiki": [{}], "code-review@claude-plugins-official": [{}]}}
JSON
cat >"$TMP_HOME/settings.json" <<'JSON'
{"enabledPlugins": {"tsumiki@tsumiki": true, "code-review@claude-plugins-official": false}}
JSON
out="$(bash "$DETECT" "$TMP_HOME")"
if grep -q '^tsumiki=enabled$' <<<"$out"; then
  pass "installed + enabled → enabled"
else
  fail "tsumiki not detected as enabled: $out"
fi
if grep -q '^official_code_review=installed$' <<<"$out"; then
  pass "installed + disabled → installed"
else
  fail "official code-review not detected as installed-only: $out"
fi

# ============================================================
# Test 11: slice-claims.sh
# ============================================================
echo ""
echo "Test 11: slice-claims.sh"
CLAIMS="$PLUGIN_DIR/scripts/slice-claims.sh"
if bash -n "$CLAIMS"; then
  pass "slice-claims.sh parses"
else
  fail "slice-claims.sh has syntax errors"
fi

CLAIMS_REPO="$TMP_HOME/slice-claims-repo"
CLAIMS_WT="$TMP_HOME/slice-claims-wA"
mkdir -p "$CLAIMS_REPO"
(
  set -e
  cd "$CLAIMS_REPO"
  git init -q -b main
  git config user.name tester
  git config user.email tester@example.com
  git config commit.gpgsign false
  mkdir -p docs/dev-auto/roadmaps/list-share/slices
  cat > docs/dev-auto/roadmaps/list-share/slices/02-entry-a.md <<'EOF'
---
slice: "02"
title: entry a
status: 未着手            # comment
depends_on: ["01"]
roadmap: docs/dev-auto/roadmaps/list-share/roadmap.md
run_id:
pr:
---
body
EOF
  git add -A
  git commit -q -m init
  git switch -c wA -q
  sed -i.bak 's/status: 未着手            # comment/status: 進行中            # comment/' docs/dev-auto/roadmaps/list-share/slices/02-entry-a.md
  sed -i.bak 's/^run_id:$/run_id: 20260928-slice/' docs/dev-auto/roadmaps/list-share/slices/02-entry-a.md
  rm -f docs/dev-auto/roadmaps/list-share/slices/02-entry-a.md.bak
  git add -A
  git commit -q -m wA
  git switch main -q
  git switch -c wB -q
  sed -i.bak 's/status: 未着手            # comment/status: 進行中            # comment/' docs/dev-auto/roadmaps/list-share/slices/02-entry-a.md
  rm -f docs/dev-auto/roadmaps/list-share/slices/02-entry-a.md.bak
  git add -A
  git commit -q -m wB
  git switch main -q
  git worktree add "$CLAIMS_WT" wA -q
  # 他の clone から push された「進行中」: ローカルの wC は古い（未着手）まま、origin/wC だけが進行中
  git branch wC main
  git update-ref refs/remotes/origin/wC wB
)
claims_out="$(cd "$CLAIMS_REPO" && bash "$CLAIMS" docs/dev-auto/roadmaps/list-share/slices/02-entry-a.md)"

if grep -qE '^branch=wA .*claim=yes' <<<"$claims_out" && grep -qF 'run_id=20260928-slice' <<<"$claims_out"; then
  pass "slice-claims.sh: wA (checked out in a worktree) is claim=yes with its run_id"
else
  fail "slice-claims.sh: wA not reported as claim=yes: $claims_out"
fi
if grep -qE '^branch=wB .*claim=no' <<<"$claims_out"; then
  pass "slice-claims.sh: wB (no worktree, no PR) is claim=no"
else
  fail "slice-claims.sh: wB not reported as claim=no: $claims_out"
fi
if grep -qE '^branch=origin/wC .*status=進行中' <<<"$claims_out" && ! grep -qE '^branch=wC ' <<<"$claims_out"; then
  pass "slice-claims.sh: a stale local branch does not hide its remote copy"
else
  fail "slice-claims.sh: origin/wC not reported (or stale local wC reported): $claims_out"
fi
if grep -qE '^branch=main ' <<<"$claims_out"; then
  fail "slice-claims.sh: current/default branch main should not be reported"
else
  pass "slice-claims.sh: main is not reported"
fi

git -C "$CLAIMS_REPO" worktree remove --force "$CLAIMS_WT" >/dev/null 2>&1 || true
rm -rf "$CLAIMS_REPO" "$CLAIMS_WT"

summary
