#!/bin/bash

set -e

# ============================================================
# 基础配置
# ============================================================

DATA_DIR="/app/SillyTavern/data"

EXTENSIONS_DIR="/app/SillyTavern/public/scripts/extensions/third-party"

BACKUP_EXTENSIONS_DIR="/tmp/backup_extensions"

REPO_URL="https://${BACKUP_TOKEN}@github.com/qyzzyqlqj/sillytavern_profiles.git"


echo "========================================"
echo "=== SillyTavern 自动备份 ==="
echo "========================================"

echo "开始时间：$(date '+%Y-%m-%d %H:%M:%S')"


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

    echo "[ERROR] Data目录不是Git仓库：$DATA_DIR"

    exit 1

fi


# ============================================================
# 进入 Git 工作目录
#
# 注意：
# 从这里开始直到 git push 完成，
# 不要离开 DATA_DIR。
# ============================================================

cd "$DATA_DIR"


echo ""
echo "========================================"
echo "=== Git环境 ==="
echo "========================================"

echo "当前Git工作目录：$(pwd)"

echo "Git状态："

git status --short


# ============================================================
# 配置 Git
# ============================================================

git config user.name "HF-SillyTavern"

git config user.email "backup@hf.space"


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


# 清理临时插件备份目录
#
# 注意：
# 不要 cd 到这个目录。
# 当前工作目录始终保持在 $DATA_DIR。
#

rm -rf "$BACKUP_EXTENSIONS_DIR"

mkdir -p "$BACKUP_EXTENSIONS_DIR/third-party"


if [ ! -d "$EXTENSIONS_DIR" ]; then

    echo "[WARN] 第三方插件目录不存在："

    echo "$EXTENSIONS_DIR"

else

    echo "[OK] 找到第三方插件目录："

    echo "$EXTENSIONS_DIR"


    echo ""
    echo "--- 当前插件目录 ---"


    find "$EXTENSIONS_DIR" \
        -mindepth 1 \
        -maxdepth 1 \
        -type d \
        -print \
        || true


    echo ""
    echo "=== 复制插件到临时备份目录 ==="


    cp -rf \
        "$EXTENSIONS_DIR/." \
        "$BACKUP_EXTENSIONS_DIR/third-party/"


    # ========================================================
    # 删除插件自身的 Git 信息
    #
    # 某些第三方插件本身就是 Git 仓库。
    #
    # 如果不删除：
    #
    # third-party/
    # └── plugin/
    #     └── .git/
    #
    # 外层 data Git 仓库不会正常记录插件内部文件。
    #
    # 这里只删除临时备份副本中的 .git，
    # 不会影响正在运行的插件。
    # ========================================================

    echo ""
    echo "=== 清理插件内部Git仓库 ==="


    find "$BACKUP_EXTENSIONS_DIR/third-party" \
        -type d \
        -name ".git" \
        -prune \
        -exec rm -rf {} + \
        2>/dev/null \
        || true


    find "$BACKUP_EXTENSIONS_DIR/third-party" \
        -type f \
        -name ".git" \
        -delete \
        2>/dev/null \
        || true


    echo "[OK] 插件内部Git信息清理完成"


    echo ""
    echo "--- 临时插件备份目录 ---"


    find "$BACKUP_EXTENSIONS_DIR/third-party" \
        -mindepth 1 \
        -maxdepth 2 \
        -type d \
        -print \
        || true

fi


# ============================================================
# 更新 data 中的插件备份
# ============================================================

echo ""
echo "========================================"
echo "=== 更新Git仓库中的插件备份 ==="
echo "========================================"


# 删除旧的插件备份副本
#
# 注意：
# 这里只删除：
#
# /app/SillyTavern/data/extensions
#
# 不会删除真正运行中的插件。
#

rm -rf "$DATA_DIR/extensions"


if [ -d "$BACKUP_EXTENSIONS_DIR/third-party" ]; then

    mkdir -p "$DATA_DIR/extensions"


    cp -rf \
        "$BACKUP_EXTENSIONS_DIR/third-party" \
        "$DATA_DIR/extensions/"


    echo "[OK] 新插件备份已复制到："

    echo "$DATA_DIR/extensions/third-party"

else

    echo "[WARN] 没有插件可以备份"

fi


# ============================================================
# 清理临时备份
#
# 注意：
# 这里绝对不能使用：
#
# cd /
#
# 因为后面还需要继续执行 Git 操作。
#
# 当前工作目录必须保持：
#
# /app/SillyTavern/data
# ============================================================

echo ""
echo "=== 清理临时备份目录 ==="

rm -rf "$BACKUP_EXTENSIONS_DIR"


# ============================================================
# 检查插件备份结果
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
        -print \
        || true


    echo ""
    echo "--- 插件文件（最多50个） ---"


    find "$DATA_DIR/extensions/third-party" \
        -type f \
        -print \
        | head -50 \
        || true


    echo ""
    echo "--- 插件备份大小 ---"


    du -sh "$DATA_DIR/extensions/third-party" \
        2>/dev/null \
        || true

else

    echo "[WARN] 插件备份目录不存在"

fi


# ============================================================
# 再次确认 Git 工作目录
# ============================================================

echo ""
echo "========================================"
echo "=== Git提交前检查 ==="
echo "========================================"


echo "当前工作目录：$(pwd)"


if [ "$(pwd)" != "$DATA_DIR" ]; then

    echo "[ERROR] Git工作目录错误！"

    echo "当前：$(pwd)"

    echo "应该：$DATA_DIR"

    exit 1

fi


echo ""
echo "--- Git状态 ---"


git status --short


# ============================================================
# 判断是否有修改
# ============================================================

if [ -z "$(git status --porcelain)" ]; then

    echo ""
    echo "[OK] 没有检测到新的修改"

    echo ""
    echo "=== 本次无需提交 ==="

    exit 0

fi


# ============================================================
# Git Add
# ============================================================

echo ""
echo "========================================"
echo "=== Git Add ==="
echo "========================================"


git add .


# ============================================================
# Git Commit
# ============================================================

echo ""
echo "========================================"
echo "=== Git Commit ==="
echo "========================================"


git commit \
    -m "auto backup $(date '+%Y-%m-%d %H:%M:%S')"


# ============================================================
# Git Push
# ============================================================

echo ""
echo "========================================"
echo "=== Git Push ==="
echo "========================================"


git push origin main


# ============================================================
# 完成
# ============================================================

echo ""
echo "========================================"
echo "=== 备份完成 ==="
echo "========================================"

echo "完成时间：$(date '+%Y-%m-%d %H:%M:%S')"

echo ""
echo "Git最新Commit："

git log -1 --oneline


echo ""
echo "当前工作目录：$(pwd)"

echo ""
echo "========================================"
echo "=== SillyTavern 自动备份结束 ==="
echo "========================================"
