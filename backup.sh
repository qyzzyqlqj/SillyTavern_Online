#!/bin/bash

set -e

DATA_DIR="/app/SillyTavern/data"
EXTENSIONS_DIR="/app/SillyTavern/public/scripts/extensions/third-party"

BACKUP_EXTENSIONS_DIR="/tmp/backup_extensions"

REPO_URL="https://${BACKUP_TOKEN}@github.com/qyzzyqlqj/sillytavern_profiles.git"


echo "========================================"
echo "=== SillyTavern 自动备份 ==="
echo "========================================"

echo "开始时间：$(date '+%Y-%m-%d %H:%M:%S')"

echo ""
echo "Data目录："
echo "$DATA_DIR"

echo ""
echo "插件目录："
echo "$EXTENSIONS_DIR"


# ============================================================
# 检查环境
# ============================================================

if [ -z "$BACKUP_TOKEN" ]; then
    echo "[ERROR] BACKUP_TOKEN 未设置"
    exit 1
fi

if [ ! -d "$DATA_DIR" ]; then
    echo "[ERROR] Data目录不存在：$DATA_DIR"
    exit 1
fi

if [ ! -d "$DATA_DIR/.git" ]; then
    echo "[ERROR] Data目录不是Git仓库"
    exit 1
fi


# ============================================================
# 进入 Data Git 仓库
# ============================================================

cd "$DATA_DIR"


echo ""
echo "=== 配置Git远程仓库 ==="

git remote set-url origin "$REPO_URL"


# ============================================================
# 准备插件备份
# ============================================================

echo ""
echo "========================================"
echo "=== 准备第三方插件备份 ==="
echo "========================================"


rm -rf "$BACKUP_EXTENSIONS_DIR"

mkdir -p "$BACKUP_EXTENSIONS_DIR/third-party"


if [ ! -d "$EXTENSIONS_DIR" ]; then

    echo "[WARN] 第三方插件目录不存在"

else

    echo "[OK] 找到第三方插件目录"


    echo ""
    echo "--- 当前插件 ---"

    find "$EXTENSIONS_DIR" \
        -mindepth 1 \
        -maxdepth 1 \
        -type d \
        -print || true


    echo ""
    echo "复制插件到临时备份目录..."


    cp -rf \
        "$EXTENSIONS_DIR/." \
        "$BACKUP_EXTENSIONS_DIR/third-party/"


    # ========================================================
    # 非常重要
    #
    # 某些 SillyTavern 插件自身就是 Git 仓库。
    #
    # 如果直接把它们放进外层 Git 仓库：
    #
    # extensions/
    # └── third-party/
    #     └── plugin/
    #         └── .git/
    #
    # 外层 Git 不会正常保存插件内部文件。
    #
    # 因此只删除「临时备份副本」里的 .git。
    #
    # 不会影响真正运行中的插件。
    # ========================================================

    echo ""
    echo "清理插件内部Git仓库..."


    find "$BACKUP_EXTENSIONS_DIR/third-party" \
        -type d \
        -name ".git" \
        -prune \
        -exec rm -rf {} + \
        2>/dev/null || true


    # 某些情况下插件可能存在 .git 文件
    find "$BACKUP_EXTENSIONS_DIR/third-party" \
        -type f \
        -name ".git" \
        -delete \
        2>/dev/null || true


    echo ""
    echo "[OK] 插件临时备份准备完成"


    echo ""
    echo "--- 临时备份中的插件 ---"

    find "$BACKUP_EXTENSIONS_DIR/third-party" \
        -mindepth 1 \
        -maxdepth 2 \
        -type d \
        -print || true


fi


# ============================================================
# 更新 Git 仓库中的 extensions
# ============================================================

echo ""
echo "========================================"
echo "=== 更新插件备份 ==="
echo "========================================"


# 删除旧的插件备份
#
# 注意：
# 这里只删除 Git 仓库里的副本。
# 不会删除真正运行中的插件。
#

rm -rf "$DATA_DIR/extensions"


if [ -d "$BACKUP_EXTENSIONS_DIR/third-party" ]; then

    mkdir -p "$DATA_DIR/extensions"

    cp -rf \
        "$BACKUP_EXTENSIONS_DIR/third-party" \
        "$DATA_DIR/extensions/"


    echo "[OK] 新插件备份已经复制到："

    echo "$DATA_DIR/extensions/third-party"

else

    echo "[WARN] 没有插件可以备份"

fi


# ============================================================
# 清理临时文件
# ============================================================

cd /

rm -rf "$BACKUP_EXTENSIONS_DIR"


# ============================================================
# 检查插件实际备份结果
# ============================================================

echo ""
echo "========================================"
echo "=== 检查插件备份结果 ==="
echo "========================================"


if [ -d "$DATA_DIR/extensions/third-party" ]; then

    echo ""
    echo "--- 插件目录 ---"

    find "$DATA_DIR/extensions/third-party" \
        -mindepth 1 \
        -maxdepth 2 \
        -type d \
        -print || true


    echo ""
    echo "--- 插件文件（最多50个） ---"

    find "$DATA_DIR/extensions/third-party" \
        -type f \
        -print \
        | head -50 || true


    echo ""
    echo "--- 插件备份大小 ---"

    du -sh "$DATA_DIR/extensions/third-party" \
        2>/dev/null || true

else

    echo "[WARN] 插件备份目录不存在"

fi


# ============================================================
# Git 状态
# ============================================================

echo ""
echo "========================================"
echo "=== 检查Git修改 ==="
echo "========================================"


git status --short


if [ -z "$(git status --porcelain)" ]; then

    echo ""
    echo "[OK] 没有新的修改"

    echo "=== 备份结束 ==="

    exit 0

fi


# ============================================================
# Git Add
# ============================================================

echo ""
echo "=== 添加修改 ==="

git add .


# ============================================================
# Git Commit
# ============================================================

echo ""
echo "=== 创建Commit ==="

git commit \
    -m "auto backup $(date '+%Y-%m-%d %H:%M:%S')"


# ============================================================
# Git Push
# ============================================================

echo ""
echo "========================================"
echo "=== 推送到GitHub ==="
echo "========================================"


git push origin main


echo ""
echo "========================================"
echo "=== 备份完成 ==="
echo "========================================"

echo "完成时间：$(date '+%Y-%m-%d %H:%M:%S')"
