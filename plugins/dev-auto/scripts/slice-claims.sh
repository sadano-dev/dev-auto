#!/usr/bin/env bash
# slice-claims.sh — 区切りファイルが、今のブランチ以外で着手済みかを調べる
#
# 他の worktree で進めている区切りの状態は、そのブランチにしかコミットされていない。
# そこで、ローカルとリモートの全ブランチ（リモートは origin/<name> のように ref 名で出す）について区切りファイルの中身を読み、
# status が「進行中」または「PR 作成済み」のものを1行ずつ出力する。
# ブランチ名の規則には頼らない（worktree のブランチ名は dev-auto/* とは限らない）。
#
# 出力（1ブランチ1行、該当が無ければ何も出さない）:
#   branch=<ref> status=<status> run_id=<id|-> worktree=<path|-> open_pr=<number|-|unknown> claim=yes|no
#
#   claim=yes は「他で作業中」とみなすもの:
#     - 進行中: ブランチがどこかの worktree で checkout されているか、open の PR がある
#     - PR 作成済み: open の PR がある（gh が使えないときは checkout されていれば yes）
#   claim=no は、ブランチに記録が残っているだけ（マージ済みで状態の更新が遅れている、
#   作業を放棄したブランチなど）。既定ブランチと今のブランチは調べない。
#
# 使い方: bash slice-claims.sh <区切りファイルのリポジトリルートからのパス>
#   例: bash slice-claims.sh docs/dev-auto/roadmaps/list-share/slices/02-entry-a.md

set -uo pipefail

path="${1:?usage: slice-claims.sh <slice file path from repo root>}"

current="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
default="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
default="${default#origin/}"
if [[ -z "$default" ]]; then
  for b in main master; do
    git show-ref --verify --quiet "refs/heads/$b" && { default="$b"; break; }
  done
fi

# macOS 標準の bash 3.2 でも動くよう、連想配列の代わりに「キー<TAB>値」の行で持つ
lookup() { awk -F'\t' -v k="$2" '$1 == k { print $2; exit }' <<<"$1"; }

# branch<TAB>worktree のパス
worktrees="$(git worktree list --porcelain 2>/dev/null | awk '
  /^worktree / { p = substr($0, 10) }
  /^branch refs\/heads\// { print substr($0, 19) "\t" p }')"

# head branch<TAB>open PR 番号（gh が使えなければ unknown）
prs="" pr_state="unknown"
if command -v gh >/dev/null 2>&1 && prs="$(gh pr list --state open --limit 200 \
    --json number,headRefName --jq '.[] | "\(.headRefName)\t\(.number)"' 2>/dev/null)"; then
  pr_state="ok"
fi

# ローカルブランチとリモートブランチを「ref<TAB>branch」で並べる。同じ名前でも両方読む
# （他の clone から push された「進行中」が、古いローカルブランチに隠れないように）
refs="$(
  git for-each-ref --format='%(refname:short)' refs/heads | awk '{ print $0 "\t" $0 }'
  git for-each-ref --format='%(refname:short)' refs/remotes | while IFS= read -r r; do
    [[ "$r" == */HEAD || "$r" != */* ]] && continue
    printf '%s\t%s\n' "$r" "${r#*/}"
  done
)"

# frontmatter から key の値を取り出す（行末の # コメントと引用符は外す）
fm() {
  awk -v key="$1" '
    NR == 1 && $0 == "---" { infm = 1; next }
    infm && $0 == "---" { exit }
    infm && index($0, key ":") == 1 {
      v = substr($0, length(key) + 2)
      sub(/[ \t]+#.*$/, "", v); gsub(/^[ \t"]+|[ \t"]+$/, "", v)
      print v; exit
    }'
}

while IFS=$'\t' read -r ref branch; do
  [[ -z "$ref" || "$branch" == "$current" || "$branch" == "$default" ]] && continue
  content="$(git show "$ref:$path" 2>/dev/null)" || continue
  status="$(fm status <<<"$content")"
  [[ "$status" == "進行中" || "$status" == "PR 作成済み" ]] || continue
  run_id="$(fm run_id <<<"$content")"
  wt=""
  [[ "$ref" == "$branch" ]] && wt="$(lookup "$worktrees" "$branch")"   # worktree はローカルブランチだけ
  if [[ "$pr_state" == "ok" ]]; then pr="$(lookup "$prs" "$branch")"; pr="${pr:--}"; else pr="unknown"; fi
  # 進行中: worktree で checkout されているか open PR がある
  # PR 作成済み: open PR がある（PR の状態が分からないときは checkout されているか）
  claim="no"
  if [[ "$pr" != "-" && "$pr" != "unknown" ]]; then
    claim="yes"
  elif [[ -n "$wt" && ( "$status" == "進行中" || "$pr" == "unknown" ) ]]; then
    claim="yes"
  fi
  echo "branch=$ref status=$status run_id=${run_id:--} worktree=${wt:--} open_pr=$pr claim=$claim"
done <<<"$refs"
