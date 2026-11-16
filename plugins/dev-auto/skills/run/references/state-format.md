# dev-auto の run ディレクトリと state.md の形式

1回の `/dev-auto:dev-auto` 実行を「run」と呼ぶ。run ごとに作業ディレクトリを1つ作り、すべての中間成果物と進捗をそこに置く。コンテキストが圧縮されても、`state.md` を読めば続きから再開できる。

## ディレクトリ構成

```
docs/dev-auto/<run-id>/
├── state.md              # フェーズ進捗・主要パラメータ（このファイルが唯一の正）
├── input.md              # 正規化した入力（指示文 / issue 本文 / メモ内容）
├── decisions.md          # 自律モードで Claude が代わりに決めた事項の記録
├── prd.md                # dev-auto:refine が作る PRD（5点・仮定・未決事項）
├── spec/                 # 外部仕様（dev-auto:spec が作成）
│   ├── README.md         # 仕様パッケージの目次と合意状況
│   ├── features.md       # 機能一覧
│   ├── screen-flow.md    # 画面一覧・画面遷移図（UI あり時）
│   ├── design-system.md  # 配色・文字・余白のトークン（UI あり時）
│   ├── mockups/*.html    # 画面 HTML モックアップ（UI あり時。index.html で対象デバイスの幅を切り替え）
│   ├── data-model.md     # データモデル（ER 図・エンティティ定義）
│   └── api.md            # 外部インターフェース（API / CLI / イベント。該当時）
├── webtest-log.md        # 画面の動作確認の記録（UI あり時。webtest → debug → retest、ブラウザ外の UI の代替確認、人による動作確認）
├── review-log.md         # 事前レビューの各パスの記録（dev-auto:review-loop）
└── pr.md                 # PR 番号・URL・公式レビュー結果（dev-auto:pr-finalize）

docs/dev-auto/ideas/<slug>/<idea>.md, README.md     # dev-auto:ideate の案ファイルと比較表（ideate を使ったとき。ラウンドを重ねたら round-N/）
docs/dev-auto/roadmaps/<topic>/roadmap.md          # 分割したときだけ。区切りの一覧・状態・共通の決定（references/slicing.md）
docs/dev-auto/roadmaps/<topic>/slices/NN-<slug>.md # 区切りファイル。次の run の入力になる
docs/dev-auto/roadmap.md, docs/dev-auto/slices/    # 旧形式（topic なし）。あれば1つの topic として読む
```

- `<run-id>` は `YYYYMMDD-<英小文字ケバブの slug>`（例: `20260923-todo-share`）。slug は `plan-name` にも使う
- tsumiki 側の成果物（`docs/dev/context.md`, `docs/dev/plans/<plan-name>/`, `docs/dev/webtests/`, `.dcs/`, `docs/uat/<yyyymmdd>/`）は tsumiki の既定パスのまま置く。state.md からパスで参照する

## state.md のテンプレート

```markdown
---
run_id: 20260923-todo-share
plan_name: todo-share
source_type: text | issue | file
source_ref: <issue URL / ファイルパス / "inline">
issue_number: 123            # issue 入力時のみ
branch: dev-auto/20260923-todo-share
base_branch: main
ui: true | false             # 画面開発を含むか
ui_runtime: browser | native | none   # 画面がどこで動くか（intake で判定。既定 browser、ui: false なら none）
target_devices: pc+phone | pc_only | fixed:<WxH>   # 対象デバイス（spec で決める。既定 pc+phone）
mockup_style: designed | wireframe   # モックアップで見た目まで合意するか（spec で決める。既定 designed）
hands_on: false | true       # 実装後に人が動かして確認するか（spec で決める。既定 false）
uat: true | false            # 受け入れ試験項目を作るか（--uat）
uat_dir:                     # uat: true のとき docs/uat/<yyyymmdd>/
roadmap:                     # 分割した / 区切りの run のとき、その topic の roadmap.md のパス
related_roadmaps: []         # 関係判定で「新しく始める」を選んだとき、関係しそうだった topic の roadmap.md のパス（spec が共通の決定を参照する）
slice:                       # 区切りの run のとき区切り番号（例: "02"）
project_kind: existing | greenfield
prd_path: docs/dev-auto/20260923-todo-share/prd.md   # 要件の正。5点がそろっていれば input.md、ideate の案がそのまま通れば案ファイル、区切りの run なら区切りファイル
refine_mode:                 # skip（区切りファイル）| gate（5点がそろい品質チェックだけ）| asked（refine で質問）| auto（全自動で補完）| deep-dive（tsumiki で壁打ち）
ideas_dir:                   # ideate を使ったとき、案ファイルの出力先（例: docs/dev-auto/ideas/todo-share/）
spec_status: pending | drafting | agreed
autonomous: false | true     # spec 合意後に true
auto_approve: false | true   # 全自動モード（--auto）。対話フェーズも推奨案で自動決定する（references/auto-mode.md）
agreed_by:                   # 全自動モードで spec を自動合意したとき auto
current_phase: intake
pr_number:
pr_url:
---

# dev-auto run: <タイトル>

## フェーズ進捗

- [ ] 1. intake（入力の正規化・ブランチ作成）
- [ ] 2. context（tsumiki:dev-context）
- [ ] 3. refine（5点の確認 → ideate / refine → 品質チェック → 関係判定・分割判定）
- [ ] 4. spec（外部仕様の作成と合意） ← ここまで対話あり
- [ ] 5. plan（tsumiki:dev-plan）
- [ ] 6. implement（tsumiki:dev-run）
- [ ] 7. verify（tsumiki:dev-verify）
- [ ] 8. webtest（画面の動作確認。UI ありのみ: browser は dev-webtest-plan → dev-webtest → dev-debug webtest → dev-webtest retest、native は統合テストと画面撮影の代替確認。hands_on: true なら続けて人による動作確認）
- [ ] 9. review（dev-auto:review-loop）
- [ ] 10. uat（uat: true のみ: tsumiki:uat-test-design → docs/uat/<yyyymmdd>/）
- [ ] 11. pr（dev-auto:pr-finalize: PR 作成 → 公式 code-review → PR コメント）

## ログ

- <ISO8601> intake: 入力を issue #123 から取得
```

## 画面まわりの項目

| 項目 | 値 | 決めるところ | 既定 |
|---|---|---|---|
| `ui_runtime` | `browser`: Web フロントエンド（ブラウザで描画）/ `native`: デスクトップアプリ・モバイルネイティブ・ゲームエンジン・組み込みなど、ブラウザ外で描画 / `none`: 画面なし | intake の手順 6（`ui` と同時） | `browser`（`ui: false` なら `none`） |
| `target_devices` | `pc+phone`: PC とスマホの両方 / `pc_only`: PC のみ / `fixed:<WxH>`: 固定解像度の画面（例: `fixed:1280x720`） | spec の手順 3 | `pc+phone` |
| `mockup_style` | `designed`: 見た目まで合意する / `wireframe`: 要素・配置・文言・状態だけ合意し、見た目は仮テーマ | spec の手順 3 | `designed` |
| `hands_on` | `true`: 実装後、フェーズ 8 の自動確認のあとに人が動かして確認する / `false`: PR まで自動 | spec の手順 5（`ui: true` のとき） | `false` |

項目が無い古い state.md は、既定の値として読む（`ui: true` なら `browser`・`pc+phone`・`designed`・`false`）。`auto_approve` が無ければ `false`。`refine_mode`・`ideas_dir` が無ければ空として読む（以前の run は `prd_path` だけを使う）。

## 更新ルール

- フェーズを終えるたびに、チェックを付け、`current_phase` を次へ進め、ログに1行追記する
- スキップしたフェーズもチェックを付け、ログに「skip: <理由>」と書く
- フェーズの終わりごとに `git add -A && git commit` する（メッセージ例: `chore(dev-auto): <run-id> phase 5 plan`）。コミットは tsumiki 側の成果物と実装を含めてよい
- 再開時は `state.md` を Read し、`current_phase` から続ける。完了済みフェーズはやり直さない
