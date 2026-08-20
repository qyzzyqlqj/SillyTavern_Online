#!/bin/bash

set -e

# ============================================================
# 配置
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
# 环境检查
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
# ============================================================

cd "$DATA_DIR"

echo ""
echo "========================================"
echo "=== Git环境 ==="
echo "========================================"

echo "当前工作目录：$(pwd)"

git config user.name "HF-SillyTavern"
git config user.email "backup@hf.space"

git remote set-url origin "$REPO_URL"


# ============================================================
# 检查 .gitignore
# ============================================================

echo ""
echo "========================================"
echo "=== 检查 .gitignore ==="
echo "========================================"

if [ -f "$DATA_DIR/.gitignore" ]; then

    echo "--- data/.gitignore ---"

    cat "$DATA_DIR/.gitignore"

else

    echo "[INFO] data目录没有 .gitignore"

fi


echo ""
echo "--- Git是否忽略 extensions/ ---"

if git check-ignore -v "extensions/third-party" 2>/dev/null; then

    echo "[WARN] extensions/third-party 被 .gitignore 忽略"

else

    echo "[OK] extensions/third-party 未被 .gitignore 忽略"

fi


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

    echo "[WARN] 第三方插件目录不存在："
    echo "$EXTENSIONS_DIR"

else

    echo "[OK] 找到第三方插件目录："
    echo "$EXTENSIONS_DIR"


    echo ""
    echo "--- 当前插件 ---"

    find "$EXTENSIONS_DIR" \
        -mindepth 1 \
        -maxdepth 1 \
        -type d \
        -print \
        || true


    echo ""
    echo "--- 当前插件文件数量 ---"

    SOURCE_FILE_COUNT=$(
        find "$EXTENSIONS_DIR" \
            -type f \
            2>/dev/null \
            | wc -l
    )

    echo "$SOURCE_FILE_COUNT"


    echo ""
    echo "=== 复制插件 ==="


    cp -a \
        "$EXTENSIONS_DIR/." \
        "$BACKUP_EXTENSIONS_DIR/third-party/"


    # ========================================================
    # 删除插件自身的 Git 仓库
    # ========================================================

    echo ""
    echo "=== 清理插件内部 Git 信息 ==="


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


    echo "[OK] 插件内部 Git 信息清理完成"


    # ========================================================
    # 检查复制结果
    # ========================================================

    echo ""
    echo "========================================"
    echo "=== 检查插件复制结果 ==="
    echo "========================================"


    BACKUP_FILE_COUNT=$(
        find "$BACKUP_EXTENSIONS_DIR/third-party" \
            -type f \
            2>/dev/null \
            | wc -l
    )


    echo "源插件文件数量：$SOURCE_FILE_COUNT"

    echo "备份副本文件数量：$BACKUP_FILE_COUNT"


    if [ "$SOURCE_FILE_COUNT" -gt 0 ] && [ "$BACKUP_FILE_COUNT" -eq 0 ]; then

        echo ""
        echo "[ERROR] 插件复制失败！"

        exit 1

    fi


    echo ""
    echo "--- 备份副本中的插件 ---"

    find "$BACKUP_EXTENSIONS_DIR/third-party" \
        -mindepth 1 \
        -maxdepth 2 \
        -type d \
        -print \
        || true


    echo ""
    echo "--- 备份副本中的文件（最多50个） ---"

    find "$BACKUP_EXTENSIONS_DIR/third-party" \
        -type f \
        -print \
        | head -50 \
        || true

fi


# ============================================================
# 更新 data/extensions
# ============================================================

echo ""
echo "========================================"
echo "=== 更新Git仓库中的插件备份 ==="
echo "========================================"


rm -rf "$DATA_DIR/extensions"

mkdir -p "$DATA_DIR/extensions"


if [ -d "$BACKUP_EXTENSIONS_DIR/third-party" ]; then

    cp -a \
        "$BACKUP_EXTENSIONS_DIR/third-party" \
        "$DATA_DIR/extensions/"


    echo "[OK] 插件备份已复制到："

    echo "$DATA_DIR/extensions/third-party"

else

    echo "[WARN] 没有插件可以备份"

fi


# ============================================================
# 清理临时目录
# ============================================================

rm -rf "$BACKUP_EXTENSIONS_DIR"


# ============================================================
# 检查最终备份目录
# ============================================================

echo ""
echo "========================================"
echo "=== 最终插件目录检查 ==="
echo "========================================"


if [ -d "$DATA_DIR/extensions/third-party" ]; then

    FINAL_FILE_COUNT=$(
        find "$DATA_DIR/extensions/third-party" \
            -type f \
            2>/dev/null \
            | wc -l
    )

    echo "最终插件文件数量：$FINAL_FILE_COUNT"


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

else

    echo "[WARN] extensions/third-party 不存在"

fi


# ============================================================
# Git 状态
# ============================================================

echo ""
echo "========================================"
echo "=== Git状态 ==="
echo "========================================"

echo "当前工作目录：$(pwd)"

git status --short


# ============================================================
# 强制添加插件
#
# 这里使用 git add -f。
#
# 即使 SillyTavern 的 .gitignore 写了：
#
# extensions/
#
# 插件也会被强制加入。
# ============================================================

echo ""
echo "========================================"
echo "=== 强制加入第三方插件 ==="
echo "========================================"


if [ -d "$DATA_DIR/extensions" ]; then

    git add -f extensions/

    echo "[OK] extensions/ 已强制加入 Git"

else

    echo "[WARN] extensions/ 不存在"

fi


# ============================================================
# 添加其它 Data 修改
# ============================================================

echo ""
echo "=== 添加其它Data修改 ==="

git add -A


# ============================================================
# 检查 Staged 文件
# ============================================================

echo ""
echo "========================================"
echo "=== Git Staged 文件检查 ==="
echo "========================================"


echo "--- 所有即将提交的文件 ---"

git diff --cached --name-status


echo ""
echo "--- 插件 Staged 文件数量 ---"


STAGED_EXTENSION_COUNT=$(
    git diff --cached --name-only \
        -- extensions/third-party \
        | wc -l
)


echo "$STAGED_EXTENSION_COUNT"


if [ "$FINAL_FILE_COUNT" -gt 0 ] && [ "$STAGED_EXTENSION_COUNT" -eq 0 ]; then

    echo ""
    echo "[ERROR] 插件存在，但没有进入 Git Staged 区！"

    echo ""
    echo "检查 Git 是否认为插件被忽略："

    git check-ignore -v \
        extensions/third-party/* \
        2>/dev/null \
        || true

    exit 1

fi


# ============================================================
# 判断是否有修改
# ============================================================

if [ -z "$(git diff --cached --name-only)" ]; then

    echo ""
    echo "[OK] 没有需要提交的修改"

    exit 0

fi


# ============================================================
# Commit
# ============================================================

echo ""
echo "========================================"
echo "=== Git Commit ==="
echo "========================================"


git commit \
    -m "auto backup $(date '+%Y-%m-%d %H:%M:%S')"


# ============================================================
# Push
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
echo "最新 Commit："

git log -1 --oneline

echo ""
echo "========================================"
echo "=== SillyTavern 自动备份结束 ==="
echo "========================================"
