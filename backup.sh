#!/bin/bash

set -e

# ============================================================
# SillyTavern 自动备份
#
# 实际运行中的第三方插件：
# /app/SillyTavern/public/scripts/extensions/third-party
#
# Git 仓库中的备份：
# /app/SillyTavern/data/extensions/third-party
#
# GitHub：
# qyzzyqlqj/sillytavern_profiles
# ============================================================


# ============================================================
# 配置
# ============================================================

DATA_DIR="/app/SillyTavern/data"

# SillyTavern 实际运行的第三方插件目录
EXTENSIONS_DIR="/app/SillyTavern/public/scripts/extensions/third-party"

# GitHub 备份仓库
REPO_URL="https://${BACKUP_TOKEN}@github.com/qyzzyqlqj/sillytavern_profiles.git"


# ============================================================
# 开始
# ============================================================

echo ""
echo "========================================"
echo "=== SillyTavern 自动备份 ==="
echo "========================================"

echo "开始时间：$(date '+%Y-%m-%d %H:%M:%S')"


# ============================================================
# 检查环境
# ============================================================

echo ""
echo "========================================"
echo "=== 环境检查 ==="
echo "========================================"


if [ -z "$BACKUP_TOKEN" ]; then

    echo "[ERROR] BACKUP_TOKEN 未设置"

    exit 1

fi


if [ ! -d "$DATA_DIR" ]; then

    echo "[ERROR] Data目录不存在："
    echo "$DATA_DIR"

    exit 1

fi


if [ ! -d "$DATA_DIR/.git" ]; then

    echo "[ERROR] Data目录不是Git仓库："
    echo "$DATA_DIR"

    exit 1

fi


if [ ! -d "$EXTENSIONS_DIR" ]; then

    echo "[WARN] 第三方插件目录不存在："
    echo "$EXTENSIONS_DIR"

fi


# ============================================================
# 进入 Git 仓库
# ============================================================

cd "$DATA_DIR"


echo ""
echo "========================================"
echo "=== Git环境 ==="
echo "========================================"

echo "当前工作目录："
pwd


# ============================================================
# Git 用户信息
# ============================================================

git config user.name "SillyTavern Backup"

git config user.email "backup@sillytavern.local"


# ============================================================
# 设置远程仓库
# ============================================================

git remote set-url origin "$REPO_URL"


# ============================================================
# 检查 Git 远程仓库
# ============================================================

echo ""
echo "=== Git Remote ==="

git remote -v


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
echo "--- 检查 extensions 是否被忽略 ---"


if git check-ignore -v \
    "extensions/third-party" \
    2>/dev/null; then

    echo "[WARN] extensions/third-party 被Git忽略"

else

    echo "[OK] extensions/third-party 没有被Git忽略"

fi


# ============================================================
# 检查实际插件目录
# ============================================================

echo ""
echo "========================================"
echo "=== 检查实际第三方插件 ==="
echo "========================================"


if [ -d "$EXTENSIONS_DIR" ]; then

    echo "实际插件目录："
    echo "$EXTENSIONS_DIR"


    echo ""
    echo "--- 插件目录 ---"


    find "$EXTENSIONS_DIR" \
        -mindepth 1 \
        -maxdepth 1 \
        -type d \
        -print \
        || true


    echo ""
    echo "--- 插件文件数量 ---"


    SOURCE_FILE_COUNT=$(
        find "$EXTENSIONS_DIR" \
            -type f \
            2>/dev/null \
            | wc -l
    )


    echo "$SOURCE_FILE_COUNT"


    echo ""
    echo "--- 插件文件（最多50个） ---"


    find "$EXTENSIONS_DIR" \
        -type f \
        -print \
        | head -50 \
        || true


else

    SOURCE_FILE_COUNT=0

    echo "[WARN] 实际插件目录不存在"

fi


# ============================================================
# Git 备份插件目录
# ============================================================

BACKUP_EXTENSIONS_DIR="$DATA_DIR/extensions/third-party"


echo ""
echo "========================================"
echo "=== 准备插件备份目录 ==="
echo "========================================"

echo "插件源："
echo "$EXTENSIONS_DIR"

echo ""

echo "插件备份目标："
echo "$BACKUP_EXTENSIONS_DIR"


# ============================================================
# 删除旧插件备份
#
# 注意：
# 这里删除的是 data/extensions/third-party
# 不会删除 public/scripts/extensions/third-party
# ============================================================

rm -rf "$BACKUP_EXTENSIONS_DIR"


mkdir -p "$BACKUP_EXTENSIONS_DIR"


# ============================================================
# 复制实际插件
# ============================================================

echo ""
echo "========================================"
echo "=== 复制第三方插件 ==="
echo "========================================"


if [ "$SOURCE_FILE_COUNT" -gt 0 ]; then

    echo "开始复制："

    echo "$EXTENSIONS_DIR/."

    echo ""

    echo "复制到："

    echo "$BACKUP_EXTENSIONS_DIR/"


    # ========================================================
    # 关键：
    #
    # 复制 third-party 里面的“内容”
    #
    # 而不是复制 third-party 目录本身
    #
    # 因此不会产生：
    #
    # extensions/third-party/third-party
    # ========================================================

    cp -a \
        "$EXTENSIONS_DIR/." \
        "$BACKUP_EXTENSIONS_DIR/"


    echo ""
    echo "[OK] 插件复制完成"


else

    echo "[WARN] 没有发现插件文件"

fi


# ============================================================
# 删除插件内部 Git 信息
# ============================================================

echo ""
echo "========================================"
echo "=== 清理插件内部 Git 信息 ==="
echo "========================================"


# 某些第三方插件自身就是 Git 仓库。
#
# 不能让插件内部的 .git 成为我们 data 仓库中的
# 嵌套 Git 仓库。
#
# 这里只清理备份副本。
#
# 不会影响实际运行中的插件。
# ============================================================


find "$BACKUP_EXTENSIONS_DIR" \
    -type d \
    -name ".git" \
    -prune \
    -exec rm -rf {} + \
    2>/dev/null \
    || true


find "$BACKUP_EXTENSIONS_DIR" \
    -type f \
    -name ".git" \
    -delete \
    2>/dev/null \
    || true


# 如果插件备份里面存在 .gitmodules，也删除
if [ -f "$BACKUP_EXTENSIONS_DIR/.gitmodules" ]; then

    rm -f "$BACKUP_EXTENSIONS_DIR/.gitmodules"

fi


echo "[OK] 插件内部 Git 信息清理完成"


# ============================================================
# 检查插件备份结果
# ============================================================

echo ""
echo "========================================"
echo "=== 检查插件备份结果 ==="
echo "========================================"


BACKUP_FILE_COUNT=$(
    find "$BACKUP_EXTENSIONS_DIR" \
        -type f \
        2>/dev/null \
        | wc -l
)


echo "源插件文件数量："
echo "$SOURCE_FILE_COUNT"


echo ""

echo "备份插件文件数量："
echo "$BACKUP_FILE_COUNT"


# ============================================================
# 插件复制失败检查
# ============================================================

if [ "$SOURCE_FILE_COUNT" -gt 0 ] && \
   [ "$BACKUP_FILE_COUNT" -eq 0 ]; then

    echo ""
    echo "[ERROR] 插件复制失败！"

    echo ""
    echo "源目录："
    echo "$EXTENSIONS_DIR"

    echo ""
    echo "目标目录："
    echo "$BACKUP_EXTENSIONS_DIR"

    exit 1

fi


# ============================================================
# 显示备份插件目录
# ============================================================

echo ""
echo "--- 备份插件目录 ---"


find "$BACKUP_EXTENSIONS_DIR" \
    -mindepth 1 \
    -maxdepth 2 \
    -type d \
    -print \
    2>/dev/null \
    || true


echo ""
echo "--- 备份插件文件（最多50个） ---"


find "$BACKUP_EXTENSIONS_DIR" \
    -type f \
    -print \
    | head -50 \
    || true


# ============================================================
# Git 状态
# ============================================================

echo ""
echo "========================================"
echo "=== Git状态 ==="
echo "========================================"


echo "当前目录："

pwd


echo ""

git status --short


# ============================================================
# 添加插件
# ============================================================

echo ""
echo "========================================"
echo "=== 添加插件到 Git ==="
echo "========================================"


# 强制添加插件。
#
# 即使 SillyTavern 的 .gitignore 忽略：
#
# extensions/
#
# 也强制加入 Git。
# ============================================================


if [ -d "$DATA_DIR/extensions/third-party" ]; then

    git add -f extensions/third-party

    echo "[OK] extensions/third-party 已加入暂存区"

else

    echo "[WARN] extensions/third-party 不存在"

fi


# ============================================================
# 添加其它 Data 修改
# ============================================================

echo ""
echo "=== 添加其它 Data 修改 ==="


git add -A


# ============================================================
# 检查 Git 是否真正追踪插件
#
# 注意：
#
# 这里不能使用 git diff --cached 判断“插件是否存在”。
#
# 因为：
#
# 插件已经在 HEAD
# +
# 本次没有变化
#
# git diff --cached = 0
#
# 这是正常情况。
#
# 所以这里使用 git ls-files。
# ============================================================

echo ""
echo "========================================"
echo "=== 检查 Git 插件追踪状态 ==="
echo "========================================"


TRACKED_EXTENSION_COUNT=$(
    git ls-files \
        extensions/third-party \
        | wc -l
)


echo "Git 当前追踪的插件文件数量："

echo "$TRACKED_EXTENSION_COUNT"


# ============================================================
# 插件存在但 Git 完全没有追踪
# ============================================================

if [ "$SOURCE_FILE_COUNT" -gt 0 ] && \
   [ "$TRACKED_EXTENSION_COUNT" -eq 0 ]; then

    echo ""
    echo "[ERROR] 插件存在，但是 Git 没有追踪插件文件！"

    echo ""
    echo "--- 检查 Git 忽略规则 ---"


    find extensions/third-party \
        -type f \
        2>/dev/null \
        | head -20 \
        | while read -r file
        do

            git check-ignore -v "$file" 2>/dev/null || true

        done


    exit 1

fi


# ============================================================
# 检查本次提交变化
# ============================================================

echo ""
echo "========================================"
echo "=== 检查本次备份变化 ==="
echo "========================================"


STAGED_FILE_COUNT=$(
    git diff --cached --name-only \
        | wc -l
)


echo "本次待提交文件数量："

echo "$STAGED_FILE_COUNT"


echo ""
echo "--- 本次待提交文件 ---"


git diff --cached --name-status || true


# ============================================================
# 没有变化
# ============================================================

if [ "$STAGED_FILE_COUNT" -eq 0 ]; then

    echo ""
    echo "========================================"
    echo "=== 没有新的修改 ==="
    echo "========================================"


    echo ""
    echo "[OK] 本次没有需要提交的变化"


    echo ""
    echo "插件已经正常存在于 Git 中。"


    echo ""
    echo "Git 追踪插件文件数量："

    echo "$TRACKED_EXTENSION_COUNT"


    exit 0

fi


# ============================================================
# Commit
# ============================================================

echo ""
echo "========================================"
echo "=== Git Commit ==="
echo "========================================"


COMMIT_MESSAGE="auto backup $(date '+%Y-%m-%d %H:%M:%S')"


git commit \
    -m "$COMMIT_MESSAGE"


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


echo "完成时间："

echo "$(date '+%Y-%m-%d %H:%M:%S')"


echo ""
echo "最新 Commit："


git log -1 --oneline


echo ""
echo "========================================"
echo "=== SillyTavern 自动备份结束 ==="
echo "========================================"
