---
name: pr-finalize
description: This skill should be used when the user asks to "PR を作って公式レビューまで", "PR を作成して code-review を流して", "公式 code-review の結果を PR にコメント", "finalize PR", "open PR and run official code review", "dev-auto pr". 作業ブランチを push して PR を作成し、Claude 公式プラグインの code-review（code-review@claude-plugins-official）が入っていれば PR に対して実行する。指摘があれば修正して push し、問題がなければその旨を PR コメントに投稿して、レビュー済みであることを PR 上で確認できるようにする。
---

# PR 作成と公式レビュー（pr-finalize）

作業ブランチから PR を作り、公式の code-review プラグインで PR をレビューし、結果を必ず PR コメントに残すスキル。公式 code-review は「指摘なし」のときに何もコメントしないので、そのときはこのスキルが「問題なし」をコメントする。これで PR を見ればレビュー済みかどうかが分かる。

## いつ使うか

- dev-auto:run のフェーズ 11 から、引数 `<run-id>` 付きで呼ばれたとき
- 単独で「PR を作って公式レビューまでやって」と言われたとき（run-id が無ければ、PR 本文は `git log` と差分から作る）

前提:

- `bash "${CLAUDE_PLUGIN_ROOT}/scripts/detect-env.sh"` で `gh=ok` かつ `remote=yes` であること。満たさない場合は PR 作成をスキップし、`pr.md` に「PR 未作成（理由）」と手動で作るためのコマンド（`git push -u origin <branch>` と `gh pr create ...`）を書いて戻る
- 既定ブランチ上にいないこと（いたら何もせず、その旨を伝えて戻る）

## 進め方

### 1. 最終確認

1. 未コミットの変更があればコミットする
2. テストを1回流す（コマンドは `docs/dev/context.md`）。失敗したら `tsumiki:dev-debug` で直してコミットする。直らなければ PR 本文の「未解決事項」に書く
3. 区切りの run（state.md に `roadmap` と `slice` がある）なら、push する前にロードマップを更新する。区切りファイルを `status: PR 作成済み` にし、roadmap.md のこの区切りの行の状態を「PR 作成済み」、run 列を `<run-id>` にする。PR 番号はまだ無いので、PR を作ったあと（手順2の6）で `pr` と PR 列を記入し、追加コミットとして push する。どちらの更新もこの PR に含める

### 2. PR を作る

1. `git push -u origin <branch>`（force push はしない）
2. 同じブランチの PR が既にあるかを `gh pr view --json number,url,isDraft` で確かめる。あれば本文を更新して使い、無ければ作る
3. PR は **ドラフトにしない**（公式 code-review はドラフトをレビューしないため）
4. タイトル: Conventional Commits 形式で70文字以内（例: `feat(tasks): タスク共有機能を追加`）
5. 本文（`gh pr create --base <base_branch> --title ... --body-file <一時ファイル>`）:

```markdown
## 概要
<目的と変更内容を3〜5行>

Closes <issue の完全な URL>   ← issue 入力のときだけ（別リポジトリの issue でも正しく紐づくよう、`#番号` ではなく URL で書く）

## 外部仕様（合意済み）
- 機能一覧: docs/dev-auto/<run-id>/spec/features.md
- 画面遷移 / モックアップ: docs/dev-auto/<run-id>/spec/screen-flow.md, spec/mockups/
- データモデル: docs/dev-auto/<run-id>/spec/data-model.md

## 実装したこと
- F-01 <機能名>: <要点>
- ...

## 検証
- テスト / ビルド / Lint: <dev-verify レポートの要約とパス>
- Web テスト: <実施結果。未実施なら理由>
- 事前レビュー: <パス数と観点、修正件数>（docs/dev-auto/<run-id>/review-log.md）

## 受け入れ試験項目   ← uat: true のときだけ
- 置き場所: docs/uat/<yyyymmdd>/（index.md から参照）
- 件数: L1 <n> / L2 <n> / L3 <n> / gaps <n>

## 自動で決めたこと
<decisions.md の件数と、特に確認してほしいもの最大3件>

## ロードマップ   ← 区切りの run のときだけ
- この PR: 区切り <NN> <タイトル>（<state.md の `roadmap` と同じ topic の slices>/<NN>-<slug>.md）
- 進み具合: <例: 01 マージ済み / 02 この PR / 03〜05 未着手>（state.md の `roadmap` のパスの roadmap.md）
- 次の区切り: <NN> <タイトル>。この PR のマージ後に `/dev-auto:dev-auto <topic>`（旧形式なら次の区切りファイルのパス）で始まります

## 未解決事項
<pr.md に溜めたもの。無ければ「なし」>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

6. PR 番号と URL を state.md（`pr_number` / `pr_url`）と `pr.md` に書く。区切りの run なら、区切りファイルの `pr` と roadmap.md の PR 列にも `#<番号>` を書き、コミットして push する

### 3. CI の結果を確かめる

PR を作ると GitHub Actions などの CI が走る。公式 code-review は CI の結果を見ないので、ここで必ず確かめる。CI が失敗のまま「問題なし」と報告しない。

1. まず `gh workflow list --all` で、有効なワークフローがあるかを見る。無い（または全て `disabled_manually` などで無効）なら「CI 未設定 / 無効のため未確認」と控えて手順 4 へ進む（失敗扱いにしない。通ったことにもしない）
2. `gh pr checks <n> --watch --fail-fast` で結果を待つ
   - チェックが登録されるまで少し時間がかかる。最初に `no checks reported` と出たら、30 秒ほど待って数回やり直す
   - 待つ時間は最大 15 分程度。Bash のタイムアウト上限（最大 10 分）に注意し、`timeout` を付けるか `run_in_background` で動かす。バックグラウンドで動かしたときは、ターンを終える前に dev-auto:run の `references/autonomous-policy.md` の「止まっていないかの確認（タイマー）」を仕掛ける。15 分たっても終わらないチェックは「時間切れで未完了」として控える
3. 失敗したら `gh run view <run-id> --log-failed` で原因を読み、`tsumiki:dev-debug` で直してコミットし、push して、もう一度待つ（最大 2 回）。CI 設定ファイル（`.github/workflows/` など）自体の誤りも直してよい。それでも失敗するものは、`pr.md` と PR 本文の「未解決事項」に書く（失敗したチェック名と run の URL を添える）
4. 結果を次のどれかで控える（手順 6 のコメントと手順 8 の記録で使う）

| 結果 | 意味 |
|---|---|
| pass | すべてのチェックが通った |
| 失敗を修正して pass | 失敗したが直して通った（修正のコミット SHA を添える） |
| 未解決の失敗あり | 2 回直しても失敗が残った、または時間切れ（チェック名と run の URL を添える） |
| 未設定・無効で未確認 | 有効なワークフローが無かった |

### 4. 公式 code-review を実行する

1. 公式プラグインが使えるかを判定する。次の両方を満たせば「使える」
   - `detect-env.sh` の `official_code_review=enabled`
   - Skill 一覧に `code-review:code-review` がある
2. 使えない場合 → 手順 6 の「未導入」コメントを投稿して手順 7 へ（手順 7・8 はレビューの結果によらず行う）
3. 実行直前の時刻と HEAD の SHA を控える（`date -u +%Y-%m-%dT%H:%M:%SZ`、`git rev-parse HEAD`）
4. Skill ツールで `code-review:code-review` を、引数に PR の URL を渡して呼ぶ。手順どおり最後まで実行させる。公式 code-review が最後に結果を報告しても、ターンを終えずにそのまま手順 5〜8 に進む。バックグラウンドで動いて `Agent "..." finished` の完了通知で結果が届いた場合も、その通知が最終結果なので、届いたらすぐ手順 5 に進む（dev-auto:run の `references/autonomous-policy.md` の「バックグラウンドで動くスキル・サブエージェント」）。公式 code-review は観点ごとにエージェントを並列に起動し、そのうちの1つが応答なしのまま終わらないことがある。完了通知を待ってターンを終える前に、同じ節の「止まっていないかの確認（タイマー）」を必ず仕掛ける。時間切れで未完了になった観点があれば、手順 6 のコメントに「観点 <名前> は時間切れで未完了」と1行足し、その観点を問題なしとは書かない

### 5. 結果を判定する

`gh pr view <n> --json comments` で、控えた時刻より後に投稿された、本文が `### Code review` で始まるコメントを探す。

| 状況 | 判定 |
|---|---|
| `Found N issues` のコメントがある | 指摘あり |
| `No issues found` のコメントがある | 問題なし（公式がコメント済み） |
| コメントが無く、レビューが最後まで進んだ（80点以上の指摘が無く終了した） | 問題なし（公式はコメントしない） |
| コメントが無く、手順1の適格性チェックで中断した（closed / draft / 自明な変更 / レビュー済み） | 対象外（中断の理由を控える） |

### 6. PR にコメントする

判定ごとに `gh pr comment <n> --body-file <一時ファイル>` で投稿する。どの場合も、PR を見ればレビュー状況が分かるようにする。各コメントの「- CI: <結果>」には手順 3 の結果を書く（pass / 失敗を修正して pass（SHA）/ 未解決の失敗あり（チェック名と run の URL）/ 未設定・無効で未確認）。CI が失敗のままのときは、「問題なし」だけを書かず、CI の失敗が未解決であることを必ず書く。

**問題なし（公式がコメントしていない場合だけ投稿。公式の `No issues found` があれば重ねて投稿しない）**

```markdown
### Code review

No issues found. 公式 code-review プラグイン（code-review@claude-plugins-official）を実行し、確信度 80 以上の指摘はありませんでした。

- レビュー対象: <HEAD の完全な SHA>
- 事前レビュー（dev-auto）: <パス数> パス / 観点: バグ・仕様適合・セキュリティ・簡潔さ
- CI: <結果>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

**指摘あり** → 各指摘を実際のコードで確かめ、正しいものを直す（誤検知は理由を残す）。テストを流してコミットし、push してから投稿する。公式 code-review は「自分のレビュー済み」の PR を再レビューしないため、再実行はしない。

```markdown
### Code review 対応

公式 code-review の指摘 <N> 件に対応しました。

1. <指摘の要約> → 修正（<コミット SHA>）
2. <指摘の要約> → 対応不要: <理由>

- 修正後の対象: <HEAD の完全な SHA>
- テスト: pass
- CI: <結果>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

**対象外**

```markdown
### Code review

公式 code-review プラグインを実行しましたが、レビュー対象外と判定されたためレビューは行われませんでした（理由: <理由>）。

- 事前レビュー（dev-auto）: <パス数> パス / 最終パスで指摘なし
- CI: <結果>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

**未導入**

```markdown
### Code review

公式 code-review プラグイン（code-review@claude-plugins-official）が導入されていないため、公式レビューは実行していません。

- 事前レビュー（dev-auto）: <パス数> パス / 観点: バグ・仕様適合・セキュリティ・簡潔さ / 最終パスで指摘なし
- CI: <結果>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

### 7. 未解決事項を引き継ぐ

`pr.md` と PR 本文の「未解決事項」は、PR をマージすると誰も読み返さない。残したままにすると、同じ指摘が次の区切りでも、その次でも「未解決事項」に書かれ続ける。そうならないよう、1 件ずつ行き先を決めて移し、移した先を書き添える。自律フェーズなのでユーザーには訊かずに決める。

1. 項目ごとに種類を決め、次の表で行き先を選ぶ

| 種類 | 例 | 行き先 |
|---|---|---|
| バグ・セキュリティ・性能や負荷 | 入力によって 500 になる、ヘッダーが無い、回数の制限が無い | GitHub issue |
| コードの外の作業（公開前・運用） | 外部 API の申請や規約の確認、本番の設定、手作業のマイグレーション | GitHub issue（題名に「公開前」「運用」と付ける） |
| 仕様の見直し候補・ユーザーの判断待ち | 合意した仕様と違う形にしたので確認してほしい、どちらにするか決めてほしい | GitHub issue（ラベルがあれば `question`） |
| 見た目・操作の手直し | 画面の細部、文言、フォーカスの動き | ロードマップがあれば、扱う区切り（未着手で、範囲が最も近いもの）の区切りファイルの「着手前の見直しメモ」に 1 行足す。合う区切りが無ければ GitHub issue |
| 記録だけで行動が要らないもの | 開発環境の注意、手元のブランチの状態、レビューの起点の説明 | 移さない（「記録のみ」と書き添える） |

2. issue を作る前に、同じ内容の issue が無いかを `gh issue list --state open --search "<要点の語>"` で確かめる。あれば新しく作らず、`gh issue comment <番号>` で「<run-id> / PR #<番号> でも見つかった」と経緯と範囲（今回見つかった場所）を足す
3. 前の run の `docs/dev-auto/*/pr.md` の未解決事項に同じ内容があり、まだ行き先が書かれていなければ、作った issue にその run も出どころとして書く（何度も持ち越されている指摘を 1 本にまとめるため）
4. issue は `gh issue create --title <題名> --label <ラベル> --body-file <一時ファイル>` で作る。ラベルはリポジトリにあるもの（`gh label list`）だけを使い、無ければ付けない。本文には、何が起きるか（再現手順）・影響・直し方の案・出どころ（run-id と PR 番号、`review-log.md` などのパス）を書く
5. 移した先を書き添える。`pr.md` と PR 本文（`gh pr edit <n> --body-file`）の各項目の末尾に「→ #<issue 番号>」「→ 区切り <NN> の着手前の見直しメモ」「→ 記録のみ」のどれかを付ける。区切りファイルを書き換えたときは、この PR のブランチにコミットして push する
6. 作った issue と書き足した区切りを `pr.md` の「引き継ぎ」に一覧で書く（dev-auto:run の完了報告で使う）

### 8. 記録する

`pr.md` に PR の URL、CI の結果（手順 3 の 4 つのどれか。失敗があれば、チェック名・run の URL・直した内容）、公式レビューの判定、投稿したコメントの URL（`gh pr view <n> --json comments` の最後の `url`）を書く。state.md のフェーズ 11 にチェックを付けてログに1行足し、コミットして push する。

## 成果物

- push 済みの作業ブランチと PR（ドラフトではない）
- PR 上のコメント（`### Code review` で始まるもの）
- `docs/dev-auto/<run-id>/pr.md`
- 未解決事項から作った GitHub issue（または既存の issue へのコメント）と、書き足した区切りファイルの「着手前の見直しメモ」

## 完了チェックリスト

- [ ] PR 本文に外部仕様・検証結果・自動決定・未解決事項が書かれ、末尾に生成元の表記がある
- [ ] CI の結果を確かめた（失敗は直したか、未解決事項に書いた。未設定・無効なら未確認と記録した）
- [ ] 公式 code-review が使える場合は実行した
- [ ] レビュー結果（問題なし / 指摘対応 / 対象外 / 未導入）が PR コメントに残っている
- [ ] 指摘を直した場合は push 済みで、テストが通っている
- [ ] 未解決事項の各項目に行き先（issue・区切りの見直しメモ・記録のみ）を書き添え、issue を作った・既存の issue に足した
- [ ] pr.md と state.md を更新した
- [ ] 区切りの run なら、roadmap.md と区切りファイルの状態・PR 番号を更新し、この PR に含めた

## 次のステップ

- ユーザーが PR をレビューしてマージする
- マージ後は `commit-commands:clean_gone` で消えたブランチを片付けられる

## やらないこと

- PR をマージしない。ドラフトで作らない
- force push しない。既定ブランチへ直接 push しない
- `code-review ultra` や `--post` 付きのクラウドレビューを起動しない
- 公式 code-review の指摘を、確かめずにすべて鵜呑みにして直さない
- CI の失敗を確かめないまま公式レビューの結果だけで問題なしと報告しない
- 未解決事項を PR 本文と pr.md に書いただけで終えない（手順 7 で行き先を決めて移す）
- dev-auto:run から呼ばれたとき、途中の報告でターンを終えない。ユーザーに質問しない（手順 8 まで続けて進めて、dev-auto:run の完了報告に戻る）
