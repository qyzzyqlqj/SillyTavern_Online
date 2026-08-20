#!/bin/bash

set -e

echo "=== Git配置 ==="

git config --global user.name "HF-SillyTavern"
git config --global user.email "backup@hf.space"

DATA_DIR="/app/SillyTavern/data"
EXTENSIONS_DIR="/app/SillyTavern/public/scripts/extensions/third-party"

BACKUP_REPO="https://${BACKUP_TOKEN}@github.com/qyzzyqlqj/sillytavern_profiles.git"

echo "=== 恢复GitHub备份 ==="

mkdir -p "$DATA_DIR"
mkdir -p "$EXTENSIONS_DIR"


restore_extensions() {
    echo "=== 检查第三方插件 ==="

    if [ -d "$DATA_DIR/extensions/third-party" ]; then

        echo "发现插件备份，开始恢复"

        rm -rf "$EXTENSIONS_DIR"

        mkdir -p "$(dirname "$EXTENSIONS_DIR")"

        cp -rf \
            "$DATA_DIR/extensions/third-party" \
            "$EXTENSIONS_DIR"

        echo "插件恢复完成"

    else

        echo "未发现插件备份"

    fi
}


if [ ! -d "$DATA_DIR/.git" ]; then

    echo "第一次启动，下载备份"

    rm -rf /tmp/profile_backup

    git lfs install

    git clone \
        "$BACKUP_REPO" \
        /tmp/profile_backup

    cd /tmp/profile_backup

    git lfs pull

    echo "清理默认数据目录"

    rm -rf "$DATA_DIR"/*

    echo "复制备份数据"

    cp -rf /tmp/profile_backup/* "$DATA_DIR/"

    echo "复制Git信息"

    cp -rf /tmp/profile_backup/.git "$DATA_DIR/"

    rm -rf /tmp/profile_backup

else

    echo "已有Git仓库，拉取最新备份"

    cd "$DATA_DIR"

    git remote set-url origin \
        "$BACKUP_REPO"

    git pull origin main

fi


restore_extensions


echo "=== 写入SillyTavern配置 ==="

envsubst < /app/config.yaml > /app/SillyTavern/config.yaml


echo "=== 安装5分钟自动备份 ==="

chmod +x /app/backup.sh

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
