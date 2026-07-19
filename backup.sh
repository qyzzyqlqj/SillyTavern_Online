#!/bin/bash

set -e


DATA_DIR="/app/SillyTavern/data"


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



# 检查是否有修改

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