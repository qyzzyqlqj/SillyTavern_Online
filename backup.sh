#!/bin/bash

set -e

DATA_DIR="/app/SillyTavern/data"
EXTENSIONS_DIR="/app/SillyTavern/public/scripts/extensions/third-party"
BACKUP_EXTENSIONS_DIR="/tmp/backup_extensions"

echo "=== 自动备份开始 $(date '+%Y-%m-%d %H:%M:%S') ==="

cd "$DATA_DIR"

# 确认Git仓库存在
if [ ! -d ".git" ]; then
    echo "错误：data目录不是Git仓库"
    exit 1
fi

# 重新设置远程地址，确保有Token
git remote set-url origin \
    https://${BACKUP_TOKEN}@github.com/qyzzyqlqj/sillytavern_profiles.git


echo "=== 准备插件备份 ==="

rm -rf "$BACKUP_EXTENSIONS_DIR"

if [ -d "$EXTENSIONS_DIR" ]; then

    mkdir -p "$BACKUP_EXTENSIONS_DIR/third-party"

    cp -rf "$EXTENSIONS_DIR/." \
        "$BACKUP_EXTENSIONS_DIR/third-party/"

    echo "第三方插件已复制到临时备份目录"

else

    echo "未找到第三方插件目录"

fi


echo "=== 更新Git备份目录 ==="

# --------------------------------------------------
# 这里保持你原来的 data Git 仓库结构不变。
#
# Git仓库最终结构：
#
# sillytavern_profiles/
# ├── data内容...
# └── extensions/
#     └── third-party/
#
# --------------------------------------------------

rm -rf "$DATA_DIR/extensions"

if [ -d "$BACKUP_EXTENSIONS_DIR/third-party" ]; then

    mkdir -p "$DATA_DIR/extensions"

    cp -rf "$BACKUP_EXTENSIONS_DIR/third-party" \
        "$DATA_DIR/extensions/"

    echo "插件备份目录更新完成"

fi

rm -rf "$BACKUP_EXTENSIONS_DIR"


echo "=== 检查是否有修改 ==="

if [ -z "$(git status --porcelain)" ]; then

    echo "没有变化，跳过备份"

    exit 0

fi


echo "发现修改，开始备份"


git add .


git commit \
    -m "auto backup $(date '+%Y-%m-%d %H:%M:%S')"


git push origin main


echo "=== 自动备份完成 ==="
