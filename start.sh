#!/bin/bash

set -e


echo "=== Git配置 ==="


git config --global user.name "HF-SillyTavern"

git config --global user.email "backup@hf.space"



DATA_DIR="/app/SillyTavern/data"



echo "=== 恢复GitHub备份 ==="



mkdir -p "$DATA_DIR"



if [ ! -d "$DATA_DIR/.git" ]; then


    echo "第一次启动，下载备份"



    rm -rf /tmp/profile_backup


	git lfs install
	
    git clone \
	https://${BACKUP_TOKEN}@github.com/qyzzyqlqj/sillytavern_profiles.git \
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
    https://${BACKUP_TOKEN}@github.com/qyzzyqlqj/sillytavern_profiles.git



    git pull origin main


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