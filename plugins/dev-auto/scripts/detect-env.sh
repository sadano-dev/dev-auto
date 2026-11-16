#!/usr/bin/env bash
# detect-env.sh — dev-auto の前提環境を検出して key=value で出力する
#
# 出力キー:
#   tsumiki=enabled|installed|missing
#   official_code_review=enabled|installed|missing   (code-review@claude-plugins-official)
#   gh=ok|unauthenticated|missing
#   git_repo=yes|no
#   default_branch=<name>
#   current_branch=<name>
#   remote=yes|no
#
# 使い方: bash detect-env.sh [CLAUDE_HOME]   (既定: ~/.claude)

set -uo pipefail

CLAUDE_HOME="${1:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}}"
INSTALLED="$CLAUDE_HOME/plugins/installed_plugins.json"

# plugin_state <plugin-key> — enabledPlugins をユーザー/プロジェクト設定から見て判定する
plugin_state() {
  local key="$1" installed="no" enabled="no" f
  if [[ -f "$INSTALLED" ]] && python3 - "$INSTALLED" "$key" <<'PY' 2>/dev/null; then
import json, sys
d = json.load(open(sys.argv[1]))
plugins = d.get("plugins", d)
sys.exit(0 if sys.argv[2] in plugins else 1)
PY
    installed="yes"
  fi
  for f in "$CLAUDE_HOME/settings.json" ".claude/settings.json" ".claude/settings.local.json"; do
    [[ -f "$f" ]] || continue
    if python3 - "$f" "$key" <<'PY' 2>/dev/null; then
import json, sys
d = json.load(open(sys.argv[1]))
sys.exit(0 if d.get("enabledPlugins", {}).get(sys.argv[2]) is True else 1)
PY
      enabled="yes"
    fi
  done
  if [[ "$installed" == "yes" && "$enabled" == "yes" ]]; then
    echo "enabled"
  elif [[ "$installed" == "yes" ]]; then
    echo "installed"
  else
    echo "missing"
  fi
}

echo "tsumiki=$(plugin_state 'tsumiki@tsumiki')"
echo "official_code_review=$(plugin_state 'code-review@claude-plugins-official')"

if ! command -v gh >/dev/null 2>&1; then
  echo "gh=missing"
elif gh auth status >/dev/null 2>&1; then
  echo "gh=ok"
else
  echo "gh=unauthenticated"
fi

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "git_repo=yes"
  default_branch="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')"
  if [[ -z "$default_branch" ]]; then
    for b in main master; do
      git show-ref --verify --quiet "refs/heads/$b" && { default_branch="$b"; break; }
    done
  fi
  echo "default_branch=${default_branch:-main}"
  echo "current_branch=$(git branch --show-current 2>/dev/null)"
  if git remote get-url origin >/dev/null 2>&1; then echo "remote=yes"; else echo "remote=no"; fi
else
  echo "git_repo=no"
fi
