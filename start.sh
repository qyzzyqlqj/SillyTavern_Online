#!/bin/bash

set -e

echo "=== Git配置 ==="

git config --global user.name "HF-SillyTavern"
git config --global user.email "backup@hf.space"

DATA_DIR="/app/SillyTavern/data"
EXTENSIONS_DIR="/app/SillyTavern/public/scripts/extensions/third-party"

BACKUP_REPO="https://${BACKUP_TOKEN}@github.com/qyzzyqlqj/sillytavern_profiles.git"
BACKUP_DIR="/tmp/profile_backup"

echo "=== 恢复GitHub备份 ==="

mkdir -p "$DATA_DIR"
mkdir -p "$EXTENSIONS_DIR"

if [ ! -d "$DATA_DIR/.git" ]; then

    echo "第一次启动，下载备份"

    rm -rf "$BACKUP_DIR"

    git lfs install

    git clone \
        "$BACKUP_REPO" \
        "$BACKUP_DIR"

    cd "$BACKUP_DIR"

    git lfs pull

    echo "清理默认数据目录"

    rm -rf "$DATA_DIR"/*

    echo "复制备份数据"

    # 只复制备份仓库中的数据内容到 data
    # 排除 extensions，因为插件需要恢复到真正的插件目录
    if [ -d "$BACKUP_DIR/data" ]; then
        cp -rf "$BACKUP_DIR/data/." "$DATA_DIR/"
    else
        # 兼容当前仓库旧结构：
        # 旧版本仓库的内容本身就是 data
        find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 \
            ! -name ".git" \
            ! -name "extensions" \
            -exec cp -rf {} "$DATA_DIR/" \;
    fi

    echo "复制Git信息"

    cp -rf "$BACKUP_DIR/.git" "$DATA_DIR/"

    echo "恢复第三方插件"

    if [ -d "$BACKUP_DIR/extensions/third-party" ]; then
        rm -rf "$EXTENSIONS_DIR"
        mkdir -p "$(dirname "$EXTENSIONS_DIR")"

        cp -rf "$BACKUP_DIR/extensions/third-party" "$EXTENSIONS_DIR"

        echo "第三方插件恢复完成"
    else
        echo "备份中没有第三方插件，跳过"
    fi

    rm -rf "$BACKUP_DIR"

else

    echo "已有Git仓库，拉取最新备份"

    cd "$DATA_DIR"

    git remote set-url origin \
        "$BACKUP_REPO"

    git pull origin main

    echo "恢复第三方插件"

    # 从 data 所在Git仓库的上级临时目录获取 extensions
    rm -rf "$BACKUP_DIR"

    git clone \
        --depth 1 \
        "$BACKUP_REPO" \
        "$BACKUP_DIR"

    cd "$BACKUP_DIR"

    git lfs pull

    if [ -d "$BACKUP_DIR/extensions/third-party" ]; then
        rm -rf "$EXTENSIONS_DIR"
        mkdir -p "$(dirname "$EXTENSIONS_DIR")"

        cp -rf "$BACKUP_DIR/extensions/third-party" "$EXTENSIONS_DIR"

        echo "第三方插件恢复完成"
    else
        echo "备份中没有第三方插件，跳过"
    fi

    rm -rf "$BACKUP_DIR"

fi


echo "=== 写入SillyTavern配置 ==="

envsubst < /app/config.yaml > /app/SillyTavern/config.yaml


echo "=== 安装5分钟自动备份 ==="

chmod +x /app/backup.sh

# 删除旧的backup定时任务，防止重复
crontab -l 2>/dev/null | grep -v "/app/backup.sh" > /tmp/crontab.tmp || true

echo "*/5 * * * * BACKUP_TOKEN=$BACKUP_TOKEN /app/backup.sh >> /tmp/backup.log 2>&1" \
>> /tmp/crontab.tmp

crontab /tmp/crontab.tmp

rm -f /tmp/crontab.tmp


echo "=== 启动cron ==="

service cron start


echo "=== 启动SillyTavern ==="

cd /app/SillyTavern

node server.js
