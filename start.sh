#!/bin/bash

set -e

# ============================================================
# SillyTavern Online 启动脚本（可泛化版本）
#
# 所有可定制项均通过运行时环境变量控制，无需修改本脚本或镜像。
# 环境变量完整说明见文件底部 print_help 或项目 README。
# ============================================================

# ---------- 路径（固定安装布局，一般无需修改） ----------
DATA_DIR="/app/SillyTavern/data"
EXTENSIONS_DIR="/app/SillyTavern/public/scripts/extensions/third-party"
BACKUP_DIR="/tmp/profile_backup"

# ============================================================
# 环境变量配置
# ============================================================

# 必需：
#   BACKUP_REPO_URL  备份 Git 仓库，如 github.com/用户名/仓库名.git
#                    （可带 https:// 前缀，Token 会自动注入；
#                      也可直接提供已含凭据的完整 URL）
#   BACKUP_TOKEN     GitHub Personal Access Token（需 repo 写权限）
#   USERNAME         SillyTavern 基础认证用户名
#   TAVERN_PASSWORD  SillyTavern 基础认证密码
#
# 可选（默认值）：
#   ENABLE_BACKUP     true/false  是否启用备份（恢复+自动备份）  (true)
#   BACKUP_BRANCH     备份分支名                                (main)
#   BACKUP_SCHEDULE   cron 表达式，自动备份频率                  (*/5 * * * *)
#   GIT_USER_NAME     git 提交用户名                            (SillyTavern Backup)
#   GIT_USER_EMAIL    git 提交邮箱                              (backup@sillytavern.local)
#   PORT              SillyTavern 监听端口                      (7860)

ENABLE_BACKUP="${ENABLE_BACKUP:-true}"
BACKUP_BRANCH="${BACKUP_BRANCH:-main}"
BACKUP_SCHEDULE="${BACKUP_SCHEDULE:-*/5 * * * *}"
GIT_USER_NAME="${GIT_USER_NAME:-SillyTavern Backup}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-backup@sillytavern.local}"
export PORT="${PORT:-7860}"

# 构建带 Token 的仓库 URL（自动注入 token，兼容裸域名/带协议前缀/已含凭据）
build_repo_url() {
    local repo="$1"
    local token="$2"

    repo="${repo#https://}"
    repo="${repo#http://}"

    if [[ -z "$token" ]]; then
        echo "https://${repo}"
    elif [[ "$repo" == *"@"* ]]; then
        # URL 已包含凭据（如 user:token@host/...），直接使用
        echo "https://${repo}"
    else
        echo "https://${token}@${repo}"
    fi
}

print_help() {
    cat <<'EOF'

====================================================================
  SillyTavern Online — 环境变量说明
====================================================================
必需（对应部署平台的环境变量 / Secrets）：
  BACKUP_REPO_URL   备份 Git 仓库，例如：github.com/你的用户名/备份仓库.git
  BACKUP_TOKEN      GitHub Token（需要 repo 写权限）
  USERNAME          SillyTavern 登录用户名
  TAVERN_PASSWORD   SillyTavern 登录密码

可选（均有默认值）：
  ENABLE_BACKUP     true / false       是否启用 GitHub 备份       (true)
  BACKUP_BRANCH     备份分支名                                    (main)
  BACKUP_SCHEDULE   自动备份 cron 表达式                          (*/5 * * * *)
  GIT_USER_NAME     git 提交用户名                               (SillyTavern Backup)
  GIT_USER_EMAIL    git 提交邮箱                                 (backup@sillytavern.local)
  PORT              监听端口                                       (7860)
====================================================================
EOF
}

# ============================================================
# 参数校验
# ============================================================

if [[ "$ENABLE_BACKUP" == "true" ]]; then

    MISSING=""
    [[ -z "$BACKUP_REPO_URL" ]] && MISSING="$MISSING BACKUP_REPO_URL"
    [[ -z "$BACKUP_TOKEN" ]] && MISSING="$MISSING BACKUP_TOKEN"

    if [[ -n "$MISSING" ]]; then

        echo "[ERROR] ENABLE_BACKUP=true 但缺少必需的环境变量：$MISSING"
        echo "请通过部署平台的环境变量 / Secrets，或 docker 的 -e 参数提供。"

        print_help

        exit 1

    fi

    if [[ "$BACKUP_REPO_URL" == git@* ]]; then

        echo "[ERROR] BACKUP_REPO_URL 请使用 HTTPS 格式，例如：github.com/用户名/仓库名.git"
        echo "SSH 格式（git@...）不支持 Token 注入。"

        print_help

        exit 1

    fi

    REPO_URL="$(build_repo_url "$BACKUP_REPO_URL" "$BACKUP_TOKEN")"

    echo "备份仓库 URL 已就绪"

fi

# ============================================================
# Git 配置
# ============================================================

echo ""
echo "=== Git配置 ==="

git config --global user.name "$GIT_USER_NAME"
git config --global user.email "$GIT_USER_EMAIL"


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

if [[ "$ENABLE_BACKUP" == "true" ]]; then

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
            "$REPO_URL" \
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
            "$REPO_URL"


        echo ""
        echo "执行 git pull"

        git pull origin "$BACKUP_BRANCH"

    fi

else

    echo ""
    echo "========================================"
    echo "=== ENABLE_BACKUP=false：跳过备份恢复 ==="
    echo "（将使用全新数据，或挂载卷 / 手动放置的数据）"
    echo "========================================"

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
# 安装自动备份（仅 ENABLE_BACKUP=true 时）
# ============================================================

if [[ "$ENABLE_BACKUP" == "true" ]]; then

    echo ""
    echo "========================================"
    echo "=== 安装自动备份 ==="
    echo "========================================"


    chmod +x /app/backup.sh


    # 删除旧的 backup 定时任务
    # 防止重复添加

    crontab -l 2>/dev/null \
        | grep -v "/app/backup.sh" \
        > /tmp/crontab.tmp \
        || true


    # 把备份脚本需要的环境变量一并传给 cron 任务
    # （cron 环境不继承容器环境变量）

    echo "$BACKUP_SCHEDULE BACKUP_TOKEN='$BACKUP_TOKEN' BACKUP_REPO_URL='$BACKUP_REPO_URL' BACKUP_BRANCH='$BACKUP_BRANCH' GIT_USER_NAME='$GIT_USER_NAME' GIT_USER_EMAIL='$GIT_USER_EMAIL' /app/backup.sh >> /tmp/backup.log 2>&1" \
        >> /tmp/crontab.tmp


    crontab /tmp/crontab.tmp


    rm -f /tmp/crontab.tmp


    echo ""
    echo "自动备份计划：$BACKUP_SCHEDULE"
    echo "备份日志：/tmp/backup.log"

fi


# ============================================================
# 启动 Cron
# ============================================================

if [[ "$ENABLE_BACKUP" == "true" ]]; then

    echo ""
    echo "========================================"
    echo "=== 启动cron ==="
    echo "========================================"

    service cron start

fi


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