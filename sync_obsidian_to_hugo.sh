#!/bin/bash

# Obsidian ▶ Hugo 同期スクリプト
# ---------------------------------
# 1. 画像コピー          : obsidian_masBlog/images/* → hugo_masBlog/static/images/
# 2. Markdown 変換       : obsidian_to_hugo
# 3. 後処理              :
#    • type: articles を追加
#    • ![[img]] → ![img](/images/img)
#    • {{< ref "img" >}} → /images/img
#    • 画像パス内のスペースを %20 に置換

set -euo pipefail

work_root="$(cd "$(dirname "$0")" && pwd)"
OBSIDIAN_VAULT_DIR="$work_root/../obsidian_masBlog/articles"
OBSIDIAN_IMAGE_DIR="$work_root/../obsidian_masBlog/images"
HUGO_CONTENT_DIR="$work_root/content/articles"
HUGO_STATIC_IMAGE_DIR="$work_root/static/images"

printf '\n🔄  Obsidian ➜ Hugo 同期開始\n'

# 1. 画像コピー ------------------------------------------------------------
printf '📁 画像コピー ... '
mkdir -p "$HUGO_STATIC_IMAGE_DIR"
img_list=$(find "$OBSIDIAN_IMAGE_DIR" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.gif' \))
if [ -n "$img_list" ]; then
  echo "$img_list" | xargs -I{} cp "{}" "$HUGO_STATIC_IMAGE_DIR/"
  echo "完了"
else
  echo "画像なし (skip)"
fi

# 2. Obsidian → Hugo 変換 ---------------------------------------------------
printf '📝 Markdown 変換 ... '
python3 -m obsidian_to_hugo \
  --obsidian-vault-dir "$OBSIDIAN_VAULT_DIR" \
  --hugo-content-dir   "$HUGO_CONTENT_DIR"  >/dev/null
echo "完了"

# 3. 後処理 ---------------------------------------------------------------
printf '🔧 後処理 (Front-Matter & 画像リンク) ...\n'
find "$HUGO_CONTENT_DIR" -type f -name '*.md' ! -name '_index.md' | while read -r md; do
  perl -0777 -pi -e '
    # --- Front-Matter ---
    if (/\A(---\n)(.*?\n)(---\n)/s) {
      my ($head1,$fm,$head2) = ($1,$2,$3);
      $fm .= "type: articles\n" unless ($fm =~ /^type:/m);
      $_ = "$head1$fm$head2" . substr($_, length($head1.$2.$head2));
    }
    # Obsidian 画像リンク
    s{!\[\[([^\]]+\.(?:png|jpe?g|gif))\]\]}{
      my $f=$1; (my $e=$f)=~s/ /%20/g; "![${f}](/images/${e})"}ge;
    # ref ショートコード
    s{\{\{<\s*ref\s+"([^"]+\.(?:png|jpe?g|gif))"\s*>\}\}}{
      my $f=$1; (my $e=$f)=~s/ /%20/g; "/images/${e}"}ge;
  ' "$md"
  echo "  ✔ $(basename "$md")"
done

echo '✅  同期完了'

# セクション _index.md が無ければ自動生成
INDEX_MD="$HUGO_CONTENT_DIR/_index.md"
[ -f "$INDEX_MD" ] || printf '%s\n' '---' 'title: 記事一覧' '---' > "$INDEX_MD" 