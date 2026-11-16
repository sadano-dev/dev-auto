# モックアップの検証

## 1. 配信する

Playwright は `file://` を開けないことがあるので、HTTP で配信する。

まず使うポート `<port>` を決める。8777 が空いていれば 8777、使われていれば（`lsof -i :8777` など）8778 以降の空き番号にする。このセッションで同じ出力先のサーバーをすでに立てていれば、そのポートをそのまま使う。決めたポートは覚えておき、この検証と SKILL.md 手順5（ユーザーに一覧を開く）で同じものを使う。

```bash
python3 -m http.server -d <出力先> <port>   # run_in_background で起動する
```

ブラウザのキャッシュで古い表示を見ないよう、URL に `?v=<時刻>` を付け、Playwright ではリクエストに `cache-control: no-cache` を付ける。

## 2. 機械的に確認する

Playwright（`mcp__plugin_playwright_playwright__browser_run_code_unsafe` など）で全ファイルを開き、次を確認する。ビューポートは幅 1800px 以上にする（PC とスマホの枠を横に並べるため）。

```js
async (page) => {
  await page.route('**/*', r => r.continue({ headers: { ...r.request().headers(), 'cache-control': 'no-cache' } }));
  await page.setViewportSize({ width: 1800, height: 1000 });
  const files = ['00-current.html', '01-xxx.html' /* … */];
  const out = {};
  for (const f of files) {
    const errors = [];
    page.removeAllListeners('console');
    page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
    await page.goto('http://localhost:<port>/' + f + '?v=' + Date.now());
    await page.waitForTimeout(1000);
    const overflow = await page.$$eval('.device', ds => ds
      .map((d, i) => ({ i, w: d.clientWidth, sw: d.scrollWidth }))
      .filter(x => x.sw > x.w));
    out[f] = { overflow, errors };
  }
  return out;
}
```

- `overflow` が空であること（PC 1280 / スマホ 375 の枠からはみ出していない）
- `errors` が空であること
- フィクスチャの件数（まとまりの数・項目の数）が全案で同じであること（`$$eval` で数える）

## 3. 目で確認する

各 `.device` を要素単位でスクリーンショットし、Read で見る。保存先はリポジトリの gitignore 済みディレクトリかスクラッチパッドにする。

見るところ: はみ出し・重なり、不自然な折り返し（1 文字だけの行、行頭に残った区切り記号）、縦に伸びた画像、読めないコントラスト、狙いが画面から伝わるか。

## 4. サムネイルを作る

一覧の `index.html` 用に、各案の中心画面を切り出して縮小する（例: PC は 1280×1152 → 幅 720、スマホは 375×1125 → 幅 240）。

```js
const d = await (await page.$$('.device'))[2].boundingBox();   // 対象画面の PC 枠
await page.screenshot({ path: '<tmp>/NN-pc.png', fullPage: true, clip: { x: d.x, y: d.y, width: 1280, height: 1152 } });
```

```bash
sips -s format jpeg -s formatOptions 80 --resampleWidth 720 <tmp>/NN-pc.png --out <出力先>/shots/NN-pc.jpg   # macOS
# 他の環境: magick <tmp>/NN-pc.png -resize 720x -quality 80 <出力先>/shots/NN-pc.jpg
```

案を直したら、その案のサムネイルも作り直す。

## よくある崩れ

| 症状 | 原因 | 直し方 |
|---|---|---|
| スマホ枠で横にはみ出す | grid の `1fr` は中身の最小幅より縮まない | `minmax(0, 1fr)`、子に `min-width: 0` |
| 16:9 のはずの画像が縦に伸びる | `height: 100%` が `aspect-ratio` より優先される。grid で行をまたぐと伸びる | その要素に `height: auto; align-self: start` |
| 行頭に「・」だけが残る | 区切り記号を折り返す側の要素の先頭に書いている | 区切りを `::before` にするか、折り返す位置で記号を外す |
| 見出しが 1〜2 文字だけ次の行に落ちる | 日本語の改行位置 | `word-break: auto-phrase; text-wrap: balance`、または `max-width` を ch で指定 |
| ナビの文字までアクセント色になる | `.app a` の詳細度が `.nav-link` より高い | `.app .nav-link { color: … }` |
| スマホ枠のラベルを押すと PC 枠の入力が変わる | 複製で id / name が重複 | テンプレートの複製スクリプト（id・for・name に `-sp` を付ける）を消さない |
| 並べた画面が崩れて見えるのに数値は正常 | 古いキャッシュを見ている | `?v=` と no-cache を付けて開き直す |
| 明るいアクセント色の上の白文字が読めない | 明るい色をそのまま文字・ボタン地に使っている | 文字用の濃い色（ink）を別に持つ。装飾用の明るい色は帯・枠だけに使う |
