#!/bin/bash

set -e

echo "=== Git配置 ==="

git config --global user.name "HF-SillyTavern"
git config --global user.email "backup@hf.space"

DATA_DIR="/app/SillyTavern/data"
EXTENSIONS_DIR="/app/SillyTavern/public/scripts/extensions/third-party"

BACKUP_REPO="https://${BACKUP_TOKEN}@github.com/qyzzyqlqj/sillytavern_profiles.git"
BACKUP_DIR="/tmp/profile_backup"


# ============================================================
# 插件恢复函数
# ============================================================

restore_extensions() {

    echo ""
    echo "========================================"
    echo "=== 开始恢复第三方插件 ==="
    echo "========================================"

    echo "备份插件目录：$DATA_DIR/extensions/third-party"
    echo "实际插件目录：$EXTENSIONS_DIR"

    # 检查备份目录
    if [ ! -d "$DATA_DIR/extensions/third-party" ]; then

        echo "[WARN] 未找到插件备份目录："
        echo "$DATA_DIR/extensions/third-party"

        echo ""
        echo "--- 当前 data 目录结构 ---"

        find "$DATA_DIR" \
            -maxdepth 3 \
            -type d \
            | head -100 || true

        echo ""
        echo "=== 插件恢复结束：没有找到插件备份 ==="

        return 0
    fi


    echo "[OK] 找到插件备份目录"

    echo ""
    echo "--- 备份中的插件目录 ---"

    find "$DATA_DIR/extensions/third-party" \
        -mindepth 1 \
        -maxdepth 2 \
        -type d \
        -print || true


    # 确保目标父目录存在
    mkdir -p "$(dirname "$EXTENSIONS_DIR")"


    echo ""
    echo "清理旧插件目录：$EXTENSIONS_DIR"

    rm -rf "$EXTENSIONS_DIR"


    echo "创建插件目录"

    mkdir -p "$EXTENSIONS_DIR"


    echo ""
    echo "开始复制插件..."

    cp -rf \
        "$DATA_DIR/extensions/third-party/." \
        "$EXTENSIONS_DIR/"


    echo ""
    echo "[OK] 插件复制完成"


    # ========================================================
    # 恢复结果检查
    # ========================================================

    echo ""
    echo "========================================"
    echo "=== 插件恢复结果检查 ==="
    echo "========================================"


    if [ ! -d "$EXTENSIONS_DIR" ]; then

        echo "[ERROR] 插件目标目录不存在！"
        echo "$EXTENSIONS_DIR"

        return 1

    fi


    echo "[OK] 插件目标目录存在："
    echo "$EXTENSIONS_DIR"


    echo ""
    echo "--- 实际恢复的插件目录 ---"

    find "$EXTENSIONS_DIR" \
        -mindepth 1 \
        -maxdepth 2 \
        -type d \
        -print || true


    echo ""
    echo "--- 实际恢复的插件文件（最多50个） ---"

    find "$EXTENSIONS_DIR" \
        -maxdepth 4 \
        -type f \
        -print \
        | head -50 || true


    echo ""
    echo "--- 插件目录大小 ---"

    du -sh "$EXTENSIONS_DIR" 2>/dev/null || true


    echo ""
    echo "========================================"
    echo "=== 第三方插件恢复完成 ==="
    echo "========================================"
    echo ""

}


# ============================================================
# 恢复 GitHub 备份
# ============================================================

echo ""
echo "========================================"
echo "=== 恢复GitHub备份 ==="
echo "========================================"


mkdir -p "$DATA_DIR"
mkdir -p "$EXTENSIONS_DIR"


if [ ! -d "$DATA_DIR/.git" ]; then

    echo ""
    echo "第一次启动，下载备份"


    # 确保临时目录不存在
    rm -rf "$BACKUP_DIR"


    echo ""
    echo "初始化 Git LFS"

    git lfs install


    echo ""
    echo "开始 Clone："

    git clone \
        "$BACKUP_REPO" \
        "$BACKUP_DIR"


    echo ""
    echo "进入备份目录"

    cd "$BACKUP_DIR"


    echo ""
    echo "拉取 Git LFS 文件"

    git lfs pull


    echo ""
    echo "清理默认数据目录"

    rm -rf "$DATA_DIR"/*


    echo ""
    echo "复制备份数据"


    # ========================================================
    # 复制原有酒馆 data 数据
    #
    # 你的旧备份结构是：
    #
    # sillytavern_profiles/
    # ├── characters/
    # ├── chats/
    # ├── ...
    # └── extensions/
    #
    # 因此这里仍然保持原来的结构。
    # ========================================================

    find "$BACKUP_DIR" \
        -mindepth 1 \
        -maxdepth 1 \
        ! -name ".git" \
        -exec cp -rf {} "$DATA_DIR/" \;


    echo ""
    echo "复制Git信息"

    cp -rf \
        "$BACKUP_DIR/.git" \
        "$DATA_DIR/"


    # 非常重要：
    # 删除临时目录前先离开它，
    # 避免出现：
    #
    # sh: 0: getcwd() failed
    #
    cd /


    echo ""
    echo "清理临时备份目录"

    rm -rf "$BACKUP_DIR"


else

    echo ""
    echo "已有Git仓库，拉取最新备份"


    cd "$DATA_DIR"


    echo ""
    echo "更新Git远程地址"

    git remote set-url origin \
        "$BACKUP_REPO"


    echo ""
    echo "执行 git pull"

    git pull origin main

fi


# ============================================================
# 恢复插件
# ============================================================

restore_extensions


# ============================================================
# 配置文件
# ============================================================

echo ""
echo "========================================"
echo "=== 写入SillyTavern配置 ==="
echo "========================================"

envsubst < /app/config.yaml > /app/SillyTavern/config.yaml


# ============================================================
# 安装自动备份
# ============================================================

echo ""
echo "========================================"
echo "=== 安装5分钟自动备份 ==="
echo "========================================"


chmod +x /app/backup.sh


# 删除旧的 backup 定时任务
# 防止重复添加

crontab -l 2>/dev/null \
    | grep -v "/app/backup.sh" \
    > /tmp/crontab.tmp \
    || true


echo "*/5 * * * * BACKUP_TOKEN=$BACKUP_TOKEN /app/backup.sh >> /tmp/backup.log 2>&1" \
    >> /tmp/crontab.tmp


crontab /tmp/crontab.tmp


rm -f /tmp/crontab.tmp


# ============================================================
# 启动 Cron
# ============================================================

echo ""
echo "========================================"
echo "=== 启动cron ==="
echo "========================================"

service cron start


# ============================================================
# 最终环境检查
# ============================================================

echo ""
echo "========================================"
echo "=== 启动前最终检查 ==="
echo "========================================"


echo ""
echo "--- SillyTavern目录 ---"

ls -la /app/SillyTavern \
    | head -30 || true


echo ""
echo "--- Data目录 ---"

ls -la "$DATA_DIR" \
    | head -30 || true


echo ""
echo "--- 第三方插件目录 ---"

if [ -d "$EXTENSIONS_DIR" ]; then

    echo "[OK] 插件目录存在"

    find "$EXTENSIONS_DIR" \
        -mindepth 1 \
        -maxdepth 2 \
        -type d \
        -print \
        | head -50 || true

else

    echo "[WARN] 插件目录不存在"

fi


# ============================================================
# 启动 SillyTavern
# ============================================================

echo ""
echo "========================================"
echo "=== 启动SillyTavern ==="
echo "========================================"


cd /app/SillyTavern

node server.js
