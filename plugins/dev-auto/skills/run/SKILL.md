---
name: run
description: This skill should be used when the user asks to "dev-auto", "全自動で開発", "issue を実装して PR まで", "このメモを実装して", "要件から PR まで自動化", "auto develop", "implement this issue end to end". 指示文・GitHub issue URL・メモファイルを入力に、要件の詳細化（足りなければ dev-auto:ideate でアイデア出し / dev-auto:refine で要件を詰める）→ 外部仕様の合意 → tsumiki の dev-plan / dev-run / dev-verify → （画面開発なら）dev-webtest と dev-debug / retest の反復 → 複数パスのコードレビューと修正 → PR 作成 → 公式 code-review と結果コメント投稿までを一気通貫で実行するオーケストレーター。
---

# dev-auto: 全自動開発パイプライン

入力（指示文 / GitHub issue URL / メモファイル）を受け取り、PR を出して公式コードレビューを済ませるところまでを1本で進めるスキル。tsumiki のスキルを部品として順番に呼び出す。

パイプラインには **対話フェーズ** と **自律フェーズ** がある。

- **対話フェーズ**（フェーズ 1〜4）: 要件の詳細化と外部仕様の合意。ここではユーザーに質問してよい。外部仕様（機能一覧・画面遷移・HTML モックアップ・データモデルなど）に明示的な合意を得るまで、実装には進まない。全自動モード（`--auto`）では、ここでの判断も Claude が推奨案で決め、外部仕様は自己レビューを経て自動で合意扱いにする（`references/auto-mode.md`）
- **自律フェーズ**（フェーズ 5〜11）: 合意後はユーザーに質問せず、PR 作成と公式レビューまで止まらずに進む（spec で `hands_on: true` に合意したときの、フェーズ 8 の人による動作確認だけは例外）。tsumiki のスキルが質問してきたら `references/autonomous-policy.md` に従って Claude が決め、`decisions.md` に記録して進む

どちらのフェーズでも、ユーザーに判断を求めるときは **必ず AskUserQuestion を使う**（推奨の選択肢を先頭に「(Recommended)」付きで置く）。「〜しますか？」「進めてよいですか？」と平文で書いてターンを終えない。

## いつ使うか

- `/dev-auto:dev-auto <指示文 | issue URL | メモファイル>` で新しい run を始めるとき
- `/dev-auto:dev-auto`（引数なし）で、途中で止まった run を再開するとき。止まった run が無く、ロードマップ（`docs/dev-auto/roadmaps/<topic>/roadmap.md`）に着手できる区切りがあれば、次の区切りを始める（topic が複数なら選んでもらう）
- `/dev-auto:dev-auto <topic>` で、その topic の次の区切りを始めるとき
- `/dev-auto:dev-auto docs/dev-auto/roadmaps/<topic>/slices/<NN>-<slug>.md` で、分割した区切りを指定して始めるとき（旧形式の `docs/dev-auto/roadmap.md` / `docs/dev-auto/slices/` も同じように使える）
- `--uat` を付けると、PR の前に受け入れ試験（UAT）の項目一覧も作る（例: `/dev-auto:dev-auto --uat <指示>`）。付けなくても、入力に「UAT」「受け入れ試験」を作ってほしいという明示があれば同じ扱いにする
- `--auto` を付けると **全自動モード** になる（例: `/dev-auto:dev-auto --auto <指示>`）。最初に1回だけ確認したら、対話フェーズの判断（要件の補完・関係判定・分割・外部仕様の合意）も Claude が推奨案で決めて decisions.md に記録し、ロードマップの全区切りの PR まで止まらずに進む。「全自動で最後まで」「承認なしで」などの明示も同じ扱いにする。詳細は `references/auto-mode.md`

前提（フェーズ 1 の冒頭で確認する）:

- tsumiki プラグインが有効であること。`bash "${CLAUDE_PLUGIN_ROOT}/scripts/detect-env.sh"` の `tsumiki=` が `enabled` でなければ、「tsumiki が必要です: `/plugin marketplace add classmethod/tsumiki` → `/plugin install tsumiki@tsumiki`」と伝えて終了する
- git リポジトリであること（`git_repo=no` なら `git init` してよいか AskUserQuestion で確認する）
- `gh=ok` であること。そうでなければ「PR 作成に gh の認証が必要です。`! gh auth login` を実行してください」と1行伝え、回答を待たずにそのまま進める。対話フェーズの間に解決しなければ、フェーズ 11 は PR 作成をスキップして手順だけ残す

## 進め方

最初に `references/state-format.md` と `references/autonomous-policy.md` を Read する。state.md（または引数）で全自動モード（`auto_approve: true`）なら `references/auto-mode.md` も Read し、以下の各フェーズで AskUserQuestion を出す箇所は、auto-mode.md の表に従って推奨案を採って decisions.md に記録する（auto-mode.md の「止まって訊く例外」だけは訊く）。ロードマップが絡む場合（引数なし・topic 名・roadmap.md・区切りファイルが入力のとき、ロードマップがあるリポジトリで refine まで進んだとき、または分割判定で分割すると決まったとき）は `references/slicing.md` も Read する。以後、各フェーズの終わりに state.md を更新してコミットする（state-format.md の「更新ルール」）。

自律フェーズ（フェーズ 5〜11）では、autonomous-policy.md の「止まらずに進めるルール」に従う。呼び出したスキル（`security-review`・`code-review`・`simplify`・tsumiki の各スキルなど）が最後にユーザー向けの報告を出したら、そのスキルは終わっている。記録したら同じターンのまま次の手順に進み、フェーズ 11 の完了報告まで止まらない。バックグラウンドで動くスキルやサブエージェント（組み込みの `code-review` など）は、結果が `Agent "..." finished` の完了通知で後から届く。この通知は1回きりの最終結果なので、届いたらすぐ処理して次へ進む。待つ間は「止まっていないかの確認（タイマー）」を仕掛けておき、応答が無いまま終わらないものは声をかけ、それでも駄目なら未完了として先へ進む（autonomous-policy.md の「バックグラウンドで動くスキル・サブエージェント」）。

作業はサブエージェントに積極的に切り出す。調べものや定型的な取得には haiku、モックアップ作成や webtest には sonnet、計画・設計判断・レビュー修正には opus を目安に選ぶ。ただし **tsumiki のスキル自体はメインコンテキストで Skill ツールから呼ぶ**（dev-run などは内部でサブエージェントを使うため、サブエージェントの中からは呼べない）。サブエージェントへのプロンプトには「`git stash` を使わない」と必ず書く。

### 0. 再開判定

`/dev-auto:dev-auto` が唯一の入口。どの分岐でも、作業を始める前に次の形で現在地を 1 回だけ表示する（質問ではなく表示。表示したらそのまま進む）。

```
dev-auto パイプライン（★ = 今ここ）
  1 intake → 2 context → 3 要件（★ ideate | refine）→ 4 spec 合意 → 5〜11 自動（plan → 実装 → 検証 → 画面確認 → レビュー → UAT → PR）
  run: <run-id>   モード: 通常 | 全自動（--auto）   区切り: <topic> <NN>（あれば）
  判定: <なぜここから始めるか 1 行。例: 入力がテーマだけで具体的な機能が無いため、アイデア出しから>
```

再開時は `current_phase` に ★ を付け、フェーズ 3 の途中なら state.md の `refine_mode`・`ideas_dir`・`prd_path` から ideate / refine のどちらにいるかを示す。

- 引数なし: `docs/dev-auto/*/state.md` のうち、フェーズ 11 が未チェックのものを更新日時が新しい順に探す（今のブランチにあるものだけなので、この worktree の run だけが見つかる）。見つかれば「<run-id>（現在: <current_phase>）を再開します」と1行伝えて、`current_phase` から続ける。見つからなければ、slicing.md の「続きから始めるときのルール」で全 topic（`docs/dev-auto/roadmaps/*/roadmap.md` と旧形式の `docs/dev-auto/roadmap.md`）から着手できる区切りを集める。1つならそれを、複数なら AskUserQuestion で選んだものを入力として新しい run を始める。無ければ、使い方（`/dev-auto:dev-auto <指示文 | issue URL | メモファイル | topic>`）を1行示して終了する
- 引数が既存の topic 名（`docs/dev-auto/roadmaps/<topic>/` の名前）と完全に一致: その topic の着手できる区切りを入力として新しい run を始める（slicing.md の「続きから始めるときのルール」）
- それ以外の引数: 新しい run を始める。ただし未完了の run があれば、AskUserQuestion で「新規に開始する（Recommended） / 既存の <run-id> を再開する」を選んでもらう

### 1. intake（入力の正規化）

1. `bash "${CLAUDE_PLUGIN_ROOT}/scripts/detect-env.sh"` で環境を確認する（前提は上記）
2. 入力の種類を判定し、内容を取得する
   - `https://github.com/<owner>/<repo>/issues/<n>` の形 → `gh issue view <url> --json number,title,body,labels,comments` で取得する。`issue_number` を控える
   - topic 名、`docs/dev-auto/roadmaps/<topic>/roadmap.md`（旧形式の `docs/dev-auto/roadmap.md` も）、または「次の区切り」「続き」という指示 → slicing.md の「着手できる区切り」で選んだ区切りファイルを入力にする
   - 区切りファイル（`docs/dev-auto/roadmaps/<topic>/slices/NN-*.md`、旧形式の `docs/dev-auto/slices/NN-*.md`。frontmatter に `slice:` がある）→ その区切りを入力にする
   - 区切りファイルを入力にするときは、まず slicing.md の「他で作業中かの確認」（`scripts/slice-claims.sh` で全ブランチを調べる）を行い、作業中なら着手しない。続けて「着手するとき」の手順1〜2（前提の区切りの確認、共通の決定との突き合わせ）を行い、このフェーズの手順5でブランチを用意したら「着手するとき」の手順3（状態を「進行中」にしてすぐコミット）を行う。state.md に `roadmap`（区切りファイルの frontmatter の値）と `slice` を記入する。前の区切りのブランチに積むと決まった場合は、そのブランチを `base_branch` にする
   - 既存のファイルパス → Read する（画像や PDF も可）
   - それ以外 → 指示文そのもの
3. タイトルから英小文字ケバブの slug（3〜5語。区切りなら `<topic>-<NN>-<区切りの slug>`、旧形式の区切りなら `<NN>-<区切りの slug>`。topic が違えば同じ番号・名前の区切りがあり得るので、`plan_name` が重ならないよう topic を前に付ける）を作り、`run_id = YYYYMMDD-<slug>`、`plan_name = <slug>` とする
4. `docs/dev-auto/<run-id>/input.md` に、出典・原文・（issue ならコメントも）をそのまま保存する
5. ブランチを用意する
   - 未コミットの変更がある場合 → AskUserQuestion で「いったん止める（Recommended） / この run のブランチに含めてコミットする」を訊く。`git stash` は使わない
   - 現在のブランチが既定ブランチ → `git switch -c dev-auto/<run-id>`
   - それ以外のブランチで、既定ブランチより先行するコミットが無い → そのブランチを使う
   - 先行コミットがある → AskUserQuestion で「既定ブランチから新しいブランチを切る（Recommended） / このブランチで続ける」を訊く
6. `ui` を判定する。画面・ページ・フォーム・UI・デザイン・レイアウト・フロントエンドへの言及がある、またはリポジトリがフロントエンドを含み変更が表示に関わる → `ui: true`。あわせて、画面がどこで動くか（`ui_runtime`）を判定する
   - Web フロントエンド（ブラウザで描画する）→ `browser`（迷ったらこれ。従来どおり）
   - デスクトップアプリ・モバイルネイティブ・ゲームエンジン・組み込みなど、ブラウザ外で描画する → `native`
   - `ui: false` → `none`
7. `project_kind` を判定する。ソースコードやパッケージマニフェストがほぼ無い → `greenfield`、それ以外は `existing`
8. 引数に `--uat` がある（または入力で UAT 作成が明示されている）なら `uat: true`、それ以外は `uat: false` とする。`--uat` は入力本文から取り除いておく
9. 引数に `--auto` がある（または入力で全自動が明示されている）なら `auto_approve: true`、それ以外は `false` とする。`--auto` は入力本文から取り除いておく。`true` のときの開始時の確認は auto-mode.md の「開始時の確認」（detect-env の直後、手順2より前に行う）
10. state.md を作成する（テンプレートは state-format.md）

### 2. context（プロジェクト把握）

- `greenfield` でマニフェストが無い → `tsumiki:dev-init` を実行する（対話あり。技術スタックを決めてスキャフォールドする）
- `docs/dev/context.md` が無い、または30日以上更新されていない → `tsumiki:dev-context` を実行する
- 既に新しい context.md がある → skip

### 3. refine（要件の詳細化）

入力の **形ではなく中身** で分岐する（issue URL・メモ・指示文のどれでも同じ扱い）。

1. 区切りファイルが入力なら、5点はそろっているはずなので skip する（`prd_path` に区切りファイル、`refine_mode: skip`。足りなければ区切りファイル自体を直す）
2. input.md を次の5点で、ある / 弱い / 無いに評価する（基準は dev-auto:refine の手順 2）
   1. 目的（誰の何を解決するか）
   2. スコープ（やること / やらないこと）
   3. 振る舞い（主要なユースケースと、その入出力・画面の動き）
   4. 受け入れ条件（完了を判断できる基準）
   5. 扱うデータ（何を保存・表示・変更するか）
3. 結果で分岐する
   - 5点とも「ある」→ `dev-auto:refine` を `<run-id> --gate docs/dev-auto/<run-id>/input.md` で呼び、品質チェックだけ通す（通れば質問なしで `prd_path` に input.md、`refine_mode: gate`）
   - それ以外 → AskUserQuestion で 1 回訊く。推奨は中身から決める: テーマ・課題だけで具体的な機能が無い → ideate を先頭に、具体的な機能・変更がある → refine を先頭に（「(Recommended)」付き）
     - 「アイデア出しから始める（ideate）」（説明: 方向性の違う 5 案と比較表を作って 1 案を選びます）
     - 「要件を詰める（refine）」（説明: 足りない点だけを選択式で訊いて PRD にします）
   - 全自動モードでは訊かずに推奨を採る（decisions.md に記録）
4. ideate を選んだ → `dev-auto:ideate` を `<run-id>`（全自動なら `<run-id> --auto`）で呼ぶ。出力先は既定の `docs/dev-auto/ideas/<slug>/`（state.md の `ideas_dir`）。戻ってきた案ファイルを `dev-auto:refine` に `<run-id> --gate <案ファイル>` で渡し、品質チェックを通す（通れば質問なし）
5. refine を選んだ → `dev-auto:refine` を `<run-id>`（全自動なら `<run-id> --auto`）で呼ぶ。足りない点だけを AskUserQuestion で訊き、`docs/dev-auto/<run-id>/prd.md` を作る。ユーザーが「もっと深く壁打ちしたい」を選んだときだけ、refine の中で `tsumiki:dcs:feature-rubber-duck`（新しいアイデア）/ `tsumiki:dcs:incremental-dev`（既存コードの改修）を使う
6. refine が state.md に書いた `prd_path` と `refine_mode` を確かめる。以後の関係判定・分割判定・spec はこの `prd_path` を要件として扱う

続けて **関係判定** をする（区切りファイルが入力の run では行わない）。ロードマップ（`docs/dev-auto/roadmaps/*/roadmap.md` または旧形式の `docs/dev-auto/roadmap.md`）が1つでもあれば、slicing.md の「新しい topic か、既存の topic に足すか（関係判定）」に従う。関係しそうな未完了の topic があれば、要件の大きさにかかわらず AskUserQuestion で「新しく始める / <topic> に区切りを足す」を訊く。

- 新しく始める → 関係しそうだった topic の roadmap.md を state.md の `related_roadmaps` に書き、分割判定へ進む
- <topic> に区切りを足す → state.md の `roadmap` にその roadmap.md を書く。分割判定の結果にかかわらず、その topic に区切りを足す（下の「分割に合意したら」の手順を、既存の roadmap.md への追記として行う。分割しない大きさなら区切りは1つ）

続けて **分割判定** をする（区切りファイルが入力の run と、既存 topic に足すと決まって区切りが1つで済む run では行わない）。`references/slicing.md` の「分割するかの判定」に当てはまるかを見る。

- 当てはまらない → topic は作らず、そのまま spec へ進む
- 当てはまる → slicing.md の「区切り方」で分割案を作り、ユーザーに区切りの表（# / 区切り / 範囲 / 前提）と topic 名の候補（slug から作る。slicing.md の「ファイル構成」）を見せて、AskUserQuestion で訊く
  - 選択肢1:「この分割で進める（Recommended）」（説明: topic `<topic>` としてロードマップと区切りファイルを作り、この run では 01 だけを作る）
  - 選択肢2:「分け方か topic 名を変える」（説明: 次の入力で変えたい点を書いてください）
  - 選択肢3:「分割せず1本で進める」（説明: PR が大きくなり、レビューと仕様確認の負担が増えます）
- 分割に合意したら、`docs/dev-auto/roadmaps/<topic>/roadmap.md` と `docs/dev-auto/roadmaps/<topic>/slices/NN-<slug>.md` を slicing.md の形式で **すべて** 作る。区切りファイルには refine の5点を書き、次の run でそのまま入力にできるようにする。既存の topic に足すときは、その roadmap.md に行を足し、区切りファイルを最後の番号の続きから作る
- この run の範囲を最初の区切り（新しい topic なら 01）に絞る。state.md に `roadmap: docs/dev-auto/roadmaps/<topic>/roadmap.md`、`slice: "<NN>"` を記入し、`prd_path` をその区切りファイルにする。その区切りファイルと roadmap.md の状態を「進行中」にする
- コミットする（`docs(dev-auto): <run-id> roadmap and slices`）。以後の spec・plan はこの区切りの範囲だけを扱う
- ユーザーに「続きは、この PR のあとに `/dev-auto:dev-auto <topic>` で次の区切りから始まります」と1行伝える

### 4. spec（外部仕様の作成と合意）

`dev-auto:spec` スキルを Skill ツールで呼ぶ。引数は `<run-id>`（`auto_approve: true` なら `<run-id> --auto`。spec はユーザーの承認の代わりに自己レビュー1回で合意扱いにする）。このスキルが次を担当する。

- 既存資料を探して、足りない外部仕様資料（機能一覧・画面一覧と遷移図・HTML モックアップ・データモデル・外部 IF）だけを作る
- ユーザーに見せて、明示的な合意（「承認」）を得るまで修正を繰り返す

戻ってきたら state.md の `spec_status` が `agreed` になっていることを確認する。なっていなければ先へ進まない。

合意を確認したら、state.md を `autonomous: true` にしてコミットし、ユーザーに次のように1回だけ伝える。

> 外部仕様の合意が取れたので、ここから PR 作成と公式レビューまで自動で進めます。途中で自動判断した内容は `docs/dev-auto/<run-id>/decisions.md` に記録します。

`hands_on: true` なら、続けて「画面の動作確認のところで一度、実際に動かして確認していただきます」と1文添える。

**ここから先はユーザーに質問せず、フェーズ 11 の完了報告まで1つのターンで進める**（例外は autonomous-policy.md の原則4と、spec で合意した `hands_on: true` のときのフェーズ 8 の人による動作確認だけ）。この一文を伝えたあとも、ターンを終えずにそのままフェーズ 5 に入る。

### 5. plan（実装計画）

1. `docs/dev-auto/<run-id>/plan-input.md` を作る（200行以内）。内容は次のとおり
   - 目的とスコープ（input.md / PRD の要約）
   - 「外部仕様は `docs/dev-auto/<run-id>/spec/` で合意済み。この仕様を変えずに実装する」という一文
   - spec/features.md の機能一覧（ID と名前と受け入れ条件）
   - `ui: true` のとき: 画面一覧と、各画面の実装は `spec/mockups/<screen-id>.html` の構成・文言・レイアウトに合わせること。表示する幅は `target_devices` に合わせて次の一文にする
     - `pc+phone`: 「PC 幅とスマホ幅の両方でモックアップどおりに表示すること」
     - `pc_only`: 「PC 幅でモックアップどおりに表示すること（スマホ幅は対象外）」
     - `fixed:<WxH>`: 「基準解像度 <W>×<H> でモックアップどおりに表示すること。ウィンドウの大きさが違うときは縦横比を保って拡大縮小する」
   - `ui: true` で `mockup_style: wireframe` のとき: 「モックアップに合わせるのは要素・配置・文言・状態で、見た目（色・装飾）は design-system.md の仮テーマ。見た目は合意の対象外」という一文
   - spec/README.md に「HTML 非対応画面」があるとき: その画面は参照画像・要素の一覧・パラメータ表に合わせること
   - `ui: true` のとき: 「配色・文字・余白は `spec/design-system.md` のトークン（CSS 変数）を使い、色コードを直接書かない」という一文（`ui_runtime: native` で CSS が無いときは、「トークンの値を 1 か所の定義（テーマ・定数など）にまとめて参照し、値を直接書かない」とする）
   - spec/data-model.md のエンティティ一覧
   - PRD のパス（詳細は PRD を参照）
2. `tsumiki:dev-plan` を引数 `<plan_name> docs/dev-auto/<run-id>/plan-input.md` で呼ぶ。途中の質問には autonomous-policy.md の表で答える（`ui: true` なら Full-spec）
3. 出力 `docs/dev/plans/<plan_name>/plan.md` と `tasks/` ができたことを確認する
4. `ui: true` なら、続けて `tsumiki:dev-screen-spec from-plan <plan_name>` を呼び、画面仕様を実装前に作っておく（衝突時は plan-wins）

### 6. implement（実装）

1. `docs/dev/plans/<plan_name>/tasks/` のファイル名から、最小と最大のタスク ID（`NNN`）を求める
2. `tsumiki:dev-run <plan_name> <最小ID> <最大ID>` を呼ぶ
3. エスカレーションは autonomous-policy.md の表で処理する。`blocked` のタスクが残ったら state.md のログと PR 本文用メモ（`pr.md` の「未解決事項」）に書く

### 7. verify（検証）

`tsumiki:dev-verify <plan_name>` を呼ぶ。レポートで失敗があれば `tsumiki:dev-debug` を実行してから、もう一度 verify する（最大2回）。それでも残る失敗は pr.md の「未解決事項」に書いて先へ進む。

### 8. webtest（画面の動作確認。`ui: false` なら skip）

`ui_runtime` で進め方を分ける（項目が無い state.md は `browser` として扱う）。

| `ui_runtime` | やること |
|---|---|
| `browser` | 下の「ブラウザで動く画面」（dev-webtest の流れ） |
| `native` | 下の「ブラウザ外で動く画面」（代替の確認） |
| `none` | skip |

どちらの場合も、`hands_on: true` なら自動の確認のあとに「人による動作確認」を行う。

#### ブラウザで動く画面（`browser`）

1. アプリを起動する。起動コマンドは `docs/dev/context.md` の dev コマンド（無ければ package.json の `dev` / `start` 等）を使い、Bash の `run_in_background` で起動する。URL が応答するまでの確認は、同じターンの中で `curl` のリトライループ（autonomous-policy.md の「バックグラウンドで動くスキル・サブエージェント」の5）で行い、待つためにターンを終えない。起動できなければ `run` スキルの手順を参考にする
2. `tsumiki:dev-webtest-plan <plan_name>` でテスト計画を作る
3. `tsumiki:dev-webtest <plan_name>` を実行する
4. `docs/dev/webtests/errors/*/error.md` に `status: open` が残っている間、次を最大3回繰り返す
   1. `tsumiki:dev-debug webtest` で修正する
   2. `tsumiki:dev-webtest retest` で再確認する
   3. 回数・open 件数・直した内容を `webtest-log.md` に1ブロック追記する
5. 3回で解消しなかった error は pr.md の「未解決事項」にパス付きで書く
6. モックアップとの見た目の差は、`tsumiki:dev-webtest check <url>` のスクリーンショットと `spec/mockups/*.html` を比べて確認する。構成・文言が大きく違う画面は直す（`mockup_style: wireframe` なら、比べるのは要素・配置・文言・状態だけ）
7. 起動したアプリのプロセスを止める（`hands_on: true` なら、人による動作確認が終わるまで止めない）

#### ブラウザ外で動く画面（`native`）

dev-webtest（Playwright）は使えないので、次の代替で確認する。

1. 入力やイベント（キー・クリック・タップ・画面の遷移指示など）をアプリに送る統合テストを書き、主要な画面遷移（spec/screen-flow.md の遷移）と、各画面の状態（通常・空・エラーなど）を確認する。プロジェクトのテストの仕組み（エンジンやフレームワークのテストランナー、ヘッドレス実行など）に合わせる
2. ウィンドウを出して実行できる環境なら、各画面を基準の大きさ（`target_devices`）で撮影し、`spec/mockups/*.html` と要素・配置・文言を比べる。大きく違う画面は直す。「HTML 非対応画面」は参照画像・要素の一覧・パラメータ表と比べる
3. 失敗や差は、直してから同じ確認をもう一度流す（最大3回）。回数・失敗件数・直した内容・撮影した画像のパスを `webtest-log.md` に1ブロックずつ追記する
4. 撮影できない環境（GUI が無い、ヘッドレスでしか動かない等）なら、統合テストだけで確認し、`webtest-log.md` と pr.md に「画面の撮影比較は未実施（理由）」と書く
5. 3回で解消しなかった失敗・差は pr.md の「未解決事項」に書く

#### 人による動作確認（`hands_on: true` のときだけ）

spec で「実装後に自分で動かして確認する」と合意した場合だけ行う。手触り・使い勝手のように自動で確かめにくい点を、人が触って確かめる。

1. アプリを起動する（Bash の `run_in_background`。上の確認で起動したままならそれを使う）。ユーザーの手元でしか起動できないもの（実機・特定の端末など）は、起動コマンドと手順を示す
2. spec/features.md の受け入れ条件と、spec/screen-flow.md の画面の状態から、確認チェックリスト（10 項目以内。「<画面> で <操作> すると <結果>」の形）を作って示す。`webtest-log.md` にも書く
3. AskUserQuestion で結果を受け取る
   - 質問:「チェックリストのとおりに動かして確認できましたか？」
   - 選択肢1:「問題なし（Recommended）」
   - 選択肢2:「直してほしい点がある」（説明: Other に、どの画面で何が気になったかを書いてください）
   - 選択肢3:「今回は確認しない」（説明: 確認しないまま PR まで進めます）
4. 「直してほしい点がある」→ 仕様（spec/）の範囲内で直せる指摘をまとめて 1 回修正し、テストを流してから、もう一度チェックリストを示して手順 3 を訊く（確認は最大 2 往復）。仕様を変えないと直せない指摘は直さず、pr.md の「未解決事項」に書く
5. 2 往復で残った指摘と「今回は確認しない」を選んだことは、pr.md の「未解決事項」に書く。やりとりの結果を `webtest-log.md` に1ブロック追記する
6. 起動したアプリのプロセスを止める。回答を受けたら、そのまま同じターンでフェーズ 9 へ進む

### 9. review（PR 前のコードレビュー）

`dev-auto:review-loop` スキルを引数 `<run-id>` で呼ぶ。観点を変えながらレビューと修正を繰り返し、指摘が出なくなったら戻ってくる。

### 10. uat（受け入れ試験項目。`uat: false` なら skip）

1. 対象を決める。spec/features.md で区分が「新規 / 変更」の機能と、関連する画面・API を対象範囲とする
2. `tsumiki:uat-test-design` を呼ぶ。引数（または冒頭のヒアリングへの回答）で、対象範囲を上の機能に絞り、形式は markdown、出力先は既定の `docs/uat/<yyyymmdd>/` とする（autonomous-policy.md の表どおり）
3. 出力先ディレクトリを state.md のログと pr.md に書く（`uat_dir`）。件数サマリ（L1 / L2 / L3 / gaps）も pr.md に写す
4. `docs/uat/<yyyymmdd>/` をコミットする（`docs(uat): <run-id> acceptance test items`）。成果物はリポジトリに残し、PR には要約とパスだけを載せる

### 11. pr（PR 作成と公式レビュー）

`dev-auto:pr-finalize` スキルを引数 `<run-id>` で呼ぶ。PR を作り、公式 code-review プラグインがあれば実行し、結果を PR にコメントする。区切りの run なら、pr-finalize が roadmap.md と区切りファイルの状態も更新して同じ PR に含める。

### 完了報告

state.md のフェーズがすべてチェック済みであることを確認し、ユーザーに次を短く報告する（`auto_approve: true` なら、先に auto-mode.md の「区切りの連続実行」を行い、報告には同じファイルの「完了報告（全自動モード）」の項目も加える）。

- PR の URL
- CI の結果（pass / 失敗を修正して pass / 未解決の失敗あり / 未設定・無効で未確認）
- 公式 code-review の結果（問題なし / 指摘 N 件を修正 / 未実行とその理由）
- decisions.md で自動決定した件数と、特に確認してほしい決定（最大3件）
- 未解決事項（あれば）と、その引き継ぎ先（pr.md の「引き継ぎ」: 作った issue の番号、書き足した区切り）
- 区切りの run なら: ロードマップの進み具合（例: 01 PR 作成済み / 02〜05 未着手）と、次に打つコマンド（「次の区切り 02 <タイトル> は、この PR のマージ後に `/dev-auto:dev-auto <topic>` で始まります」。旧形式なら区切りファイルのパスを示す）

## 成果物

- `docs/dev-auto/<run-id>/`（state.md, input.md, prd.md, decisions.md, spec/, plan-input.md, webtest-log.md, review-log.md, pr.md）
- ideate を使ったとき: `docs/dev-auto/ideas/<slug>/`（案ファイルと比較表）
- 分割したとき: `docs/dev-auto/roadmaps/<topic>/roadmap.md` と `docs/dev-auto/roadmaps/<topic>/slices/NN-<slug>.md`（続きの入口）
- `uat: true` のとき: `docs/uat/<yyyymmdd>/`（受け入れ試験項目。tsumiki:uat-test-design の既定の出力先）
- tsumiki の成果物: `docs/dev/context.md`, `docs/dev/plans/<plan_name>/`, `docs/dev/screen-specs/`, `docs/dev/webtests/`, `.dcs/`（refine で「もっと深く壁打ちしたい」を選んだときだけ）
- 実装コードとテスト、作業ブランチ、PR、PR 上のレビューコメント

## 完了チェックリスト

- [ ] 外部仕様に明示的な合意を得てから実装を始めた（全自動モードでは、spec の自己レビューを経た自動合意を記録してから）
- [ ] 全自動モードでは、開始時の確認と auto-mode.md の「止まって訊く例外」以外で質問せず、自動で決めたことを decisions.md に残し、完了報告で確認してほしい決定を示した
- [ ] ロードマップがあるときは関係判定をし、関係しそうな topic があれば新しく始めるか足すかを訊いた
- [ ] 要件が大きいときは分割と topic 名に合意を取り、roadmap.md と全区切りファイルを作った。区切りの run では、着手前に他で作業中でないことを確かめ、roadmap.md と区切りファイルの状態を PR に含めて更新した
- [ ] 合意後はユーザーに質問せず、自動で決めたことを decisions.md に残した
- [ ] 自律フェーズでは、スキルの報告や進捗報告のところでターンを終えず、完了報告まで続けて進めた
- [ ] dev-verify のテスト・ビルド・Lint が通っている（通らないものは未解決事項に書いた）
- [ ] `ui: true` のとき、`ui_runtime` に合わせて画面の動作確認をした（`browser`: webtest → debug → retest を回し、open の error が無い / `native`: 入力を送る統合テストと、撮影できればモックアップとの比較をした。どちらも残りは未解決事項に書いた）
- [ ] `hands_on: true` のとき、確認チェックリストを示して人による動作確認の結果を受け取り、指摘を反映した（残りは未解決事項に書いた）
- [ ] review-loop を最後まで回し、最終パスで修正すべき指摘が出なかった
- [ ] `uat: true` のとき、受け入れ試験項目を `docs/uat/` にコミットし、PR 本文に要約とパスを載せた
- [ ] PR を作成し、公式 code-review の実行結果（問題なしを含む）が PR コメントに残っている
- [ ] 未解決事項を PR 本文に書いただけで終えず、issue・区切りの見直しメモに移した（pr-finalize の手順 7）
- [ ] state.md の全フェーズにチェックが付いている

## 次のステップ

- PR をレビューしてマージする。decisions.md の自動決定に違和感があれば PR にコメントする
- 仕様変更が必要になったら、新しい `/dev-auto:dev-auto` を仕様変更の内容で始める（spec フェーズで差分だけ作り直す）

## やらないこと

- 外部仕様の合意前に、実装コードを書いたりコミットしたりしない
- `--auto` が無いのに全自動モードの扱い（自動合意・推奨案の自動採用）をしない。全自動モードでも、未コミットの変更を勝手に run に含めたり、`git init` を確認なしで行ったりしない
- 合意後に、仕様の解釈や内部設計をユーザーに訊かない（autonomous-policy.md の原則4の場合だけ例外。spec で合意した `hands_on` の確認は質問ではなく合意済みの工程として行う）
- 平文の質問でユーザーの返事を待たない（確認は AskUserQuestion で行う）
- 自律フェーズで、スキルの報告や進捗を出しただけでターンを終えない
- バックグラウンドのスキル・サブエージェントの完了通知を途中報告とみなして待ち続けない
- `git stash`、force push、既定ブランチへの直接コミット・push をしない
- `code-review ultra`（ユーザーが起動する有料のクラウドレビュー）を起動しない
- PR をマージしない
