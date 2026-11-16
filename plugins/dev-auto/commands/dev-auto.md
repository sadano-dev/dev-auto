---
description: Run the full autonomous dev pipeline (spec agreement → plan → implement → test → review → PR) from an instruction, issue URL, or memo file
argument-hint: '[--auto] [--uat] <指示文 | GitHub issue URL | メモファイルのパス | topic 名> （省略時は実行中の run を再開、無ければ次の区切りを選ぶ）'
allowed-tools: [Skill, Agent, Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion, ToolSearch]
---

Use the Skill tool to invoke the `dev-auto:run` skill, passing the user's input as args: $ARGUMENTS

This is the single entry point. The run skill normalizes the input, checks it for the five points (purpose, scope, behavior, acceptance criteria, data) and — only when they are not all present — asks once whether to start from ideas (`dev-auto:ideate`: N diverse, scored ideas to pick from) or refine requirements (`dev-auto:refine`: asks only about the gaps and writes a PRD), runs refine's quality gate, gets the user's agreement on the external specification (via `dev-auto:spec`), then autonomously plans, implements, tests, reviews (via `dev-auto:review-loop`), and opens a PR with official code-review (via `dev-auto:pr-finalize`). Passing a topic name (matching a `docs/dev-auto/roadmaps/<topic>/` directory) starts that topic's next startable slice. With no arguments it resumes the latest unfinished run in this worktree; if there is none, it collects the next startable slice across all topics and starts it (asking you to choose if there are several).

With `--auto` (or phrases like "全自動で最後まで" / "承認なしで"), the run asks for one confirmation at the start and then makes every decision itself — requirement gaps, topic/slice choices, and external-spec agreement (via a self-review, recorded as `agreed_by: auto`) — logging them to `decisions.md`, and keeps going through every remaining slice of the roadmap. It still stops to ask when there are uncommitted changes, when the directory is not a git repository, or when a destructive/irreversible action is unavoidable. See `skills/run/references/auto-mode.md`.
