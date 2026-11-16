# dev-auto

指示文・GitHub issue URL・メモファイルから、要件の詳細化 → 外部仕様の合意 → 実装 → テスト → 複数パスのレビュー → PR 作成までを一気通貫で進める Claude Code プラグインです。[tsumiki](https://github.com/classmethod/tsumiki) のスキルを部品として組み合わせています。

詳しい使い方とパイプラインの説明は [plugins/dev-auto/README.md](plugins/dev-auto/README.md) を見てください。

## インストール

前提として tsumiki プラグインが必要です。

```
/plugin marketplace add classmethod/tsumiki
/plugin install tsumiki@tsumiki

/plugin marketplace add sadano-dev/dev-auto
/plugin install dev-auto@dev-auto
```

次のものは任意です。入っていれば使います。

- `gh` CLI（PR の作成）
- `code-review@claude-plugins-official`（公式のコードレビュー）
- Playwright（画面のテスト）

## 使い方

```
/dev-auto:dev-auto <指示文 | GitHub issue URL | メモファイルのパス>
/dev-auto:dev-auto --auto <...>   # 承認なしで最後まで進める
```

## コントリビューションについて

個人用に作っているツールを公開しているもので、**Pull Request と Issue は受け付けていません**。fork や改変はライセンスの範囲でご自由にどうぞ。

## ライセンス

[MIT](LICENSE)
