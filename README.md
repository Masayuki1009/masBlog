# masBlog / Hugo サイト構築手順

##概要
**Hugo + PaperMod** テーマで生成される静的サイトを格納するディレクトリ
記事の執筆は Obsidian 上で行い、`obsidian_to_hugo` を用いて Markdown を Hugo 形式へ変換、その後 Netlify へ自動デプロイするワークフローを採用。

---
## ディレクトリ構成
```
masBlog/
├─ obsidian_masBlog/          # Obsidian Vault（記事 & 画像）
│   ├─ articles/              # 記事 Markdown (Obsidian 形式)
│   └─ images/                # 画像ファイル
└─ hugo_masBlog/              # Hugo プロジェクト（本ディレクトリ）
    ├─ content/articles/      # 変換後の Markdown (Hugo 形式)
    ├─ static/images/         # 公開用画像
    └─ themes/PaperMod/       # テーマ（サブモジュール）
```

---
## 前提ソフトウェア
| ツール | バージョン例 | 用途 |
|--------|--------------|------|
| Python | 3.9 以上     | `obsidian_to_hugo` を実行 |
| Hugo   | 0.146 以上   | サイト生成 (`brew install hugo`) |
| Make   | 任意         | Makefile でタスク実行 |

> Netlify へデプロイする場合は Netlify CLI または GitHub Actions + Netlify の設定が必要です。

---
## 手順概要
1. **Obsidian で記事執筆**  
   - `obsidian_masBlog/articles/` に Markdown を作成  
   - 画像は `obsidian_masBlog/images/` に保存（ファイル名にスペース禁止 or URL エンコード `%20`）
2. **変換 & 同期**（ローカル）  
   - hugo_masBlog配下で `./sync_obsidian_to_hugo.sh` もしくは `make sync` を実行  
   - 処理内容:
     1. 画像を `hugo_masBlog/static/images/` へコピー
     2. `obsidian_to_hugo` で Markdown を変換
     3. 画像リンク中のスペースを `%20` へ自動置換
3. **ローカル確認**  
   - `cd hugo_masBlog`  
   - `make serve` (または `hugo server -D`)  
   - ブラウザで `http://localhost:1313` を開き動作確認
4. **コミット & プッシュ**  
   - GitHub へプッシュすると GitHub Actions が変換〜Netlify デプロイまで自動実行

---
## 主要スクリプト / コマンド
### sync_obsidian_to_hugo.sh
```bash
./sync_obsidian_to_hugo.sh
```
- 画像コピー → Markdown 変換 → 画像リンク修正 を一括実行

### Makefile タスク
| コマンド       | 説明 |
|----------------|------|
| `make sync`    | `sync_obsidian_to_hugo.sh` と同等処理 |
| `make serve`   | ローカルサーバー起動（変換 → `hugo server -D`） |
| `make build`   | 本番ビルド (`hugo --minify`) |
| `make clean`   | `public/` を削除 |

---
## よくあるエラーと解決策
| 症状 | 原因 | 解決策 |
|------|------|--------|
| 画像が表示されない | 画像リンクの URL にスペースが含まれている | スクリプトで `%20` へエンコード／ファイル名をリネーム |
| トップページに記事が出ない | `mainSections` に section が含まれていない | `hugo.toml` の `[params] mainSections` を更新 |
| `REF_NOT_FOUND` エラー | 画像を `static/images/` に置いていない | `make sync` で画像コピー |



---
## 参考リンク
- Hugo: https://gohugo.io/
- PaperMod Theme: https://github.com/adityatelange/hugo-PaperMod
- obsidian_to_hugo: https://github.com/Jonty/obsidian-to-hugo 

### 変換コマンドが 2 種類ある理由
| 実行方法 | 想定ユースケース | 補足 |
|-----------|----------------|------|
| `./sync_obsidian_to_hugo.sh` | **シェルスクリプト単体で素早く実行したい**とき。CI や自動化ジョブでも使いやすい | プロジェクトルートで実行する前提。処理内容を Bash で明示的に記述しているのでタスク内容を確認しやすい |
| `make sync` | **Makefile 管理の他タスクと組み合わせたい / 依存関係を自動解決したい**とき | `make build` や `make serve` など他ターゲットで `sync` が前処理として呼ばれるため、誤操作を防げる |

---
## 作業手順
1. **記事を編集**（obsidian_masBlog/articles配下）

2. **ターミナルで Hugo プロジェクトへ移動**
```bash
cd masBlog/hugo_masBlog
```

3. **変換＋同期**（画像コピー／Front-Matter補正などすべて自動）
```bash
make sync
```

4. **ローカルで確認**
```bash
make serve   # = sync + hugo server -D
```

(終了は Ctrl+C)

5. **デプロイ**
```bash
make build   # 必要に応じて
cd ..        # プロジェクトルート
git add . && git commit -m "Add article" && git push
```
GitHub Actions 経由で Netlify に自動デプロイされます。