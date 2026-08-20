---
title: SillyTavern
emoji: 🚀
colorFrom: purple
colorTo: blue
sdk: docker
app_port: 7860
---

# SillyTavern Online

在云端（Hugging Face Spaces / 任意 Docker 主机）运行 [SillyTavern](https://github.com/SillyTavern/SillyTavern)，**数据（角色卡、聊天记录、第三方插件）自动备份到你自己的 GitHub 仓库**。无需修改任何代码——**所有个性化配置都通过运行时环境变量完成**。

> 📖 本 README 是一份**完整的保姆级教程**：从零开始教你创建备份仓库、配置 Token、部署上线、验证备份。跟着步骤走即可，不需要任何编程经验。

---

## 📑 目录

1. [功能一览](#-功能一览)
2. [工作原理（3 分钟看懂）](#-工作原理3-分钟看懂)
3. [准备阶段：需要什么](#-准备阶段需要什么)
4. [详细教程 Part 1：GitHub 准备](#-详细教程-part-1github-准备)
5. [详细教程 Part 2：部署到 Hugging Face Spaces](#-详细教程-part-2部署到-hugging-face-spaces)
6. [详细教程 Part 3：本地 / 自有服务器部署](#-详细教程-part-3本地--自有服务器部署)
7. [环境变量完整参考](#-环境变量完整参考)
8. [首次使用与验证备份](#-首次使用与验证备份)
9. [数据备份结构说明](#-数据备份结构说明)
10. [常见问题 FAQ](#-常见问题-faq)
11. [安全注意事项](#-安全注意事项)

---

## ✨ 功能一览

- 🚀 一键部署 SillyTavern（官方镜像 + Node 20）
- 💾 **自动云备份**：每 5 分钟（可配置）把你的数据 commit + push 到你的 GitHub 仓库
- 🔄 **自动恢复**：容器每次启动时自动从备份仓库拉取最新数据，换机器/重建 Space 数据不丢
- 🔌 **第三方插件同步**：插件目录与备份数据自动同步，且不会产生嵌套 Git 仓库
- 🔐 **基础认证**：通过环境变量设置登录用户名 / 密码
- 🧩 **完全可泛化**：备份仓库、分支、提交身份、备份频率、端口全部可配置

---

## ⚙️ 工作原理（3 分钟看懂）

```
┌───────────────────────────────────────────────────┐
│  Docker 容器 (node:20-bookworm)                    │
│                                                   │
│  start.sh（容器入口）                              │
│    ├─ 读环境变量 + 校验                            │
│    ├─ 从备份仓库 clone / pull 数据                 │
│    │   → /app/SillyTavern/data                    │
│    │   （data 目录本身就是一个 Git 仓库）          │
│    ├─ 恢复第三方插件到运行目录                     │
│    ├─ envsubst 生成 config.yaml（端口/认证）       │
│    ├─ 安装 cron（默认每 5 分钟跑一次 backup.sh）   │
│    └─ node server.js 启动 SillyTavern             │
│                                                   │
│  backup.sh（cron 定时执行）                       │
│    ├─ 插件运行目录 → data/extensions/third-party  │
│    ├─ 清理插件内部的 .git（防嵌套仓库）            │
│    ├─ git add -f + git add -A                     │
│    └─ git commit + push → 你的备份仓库             │
└───────────────────────────────────────────────────┘
```

一句话总结：**你在 SillyTavern 里做的任何操作（聊天、建角色、装插件），最多 5 分钟后就会以一次 git 提交的形式出现在你的 GitHub 备份仓库里；容器每次重启，数据自动拉回来。**

---

## 📋 准备阶段：需要什么

| 需要 | 是否有免费方案 | 用途 |
|---|---|---|
| GitHub 账号 | ✅ 免费 | 存放备份仓库、Fork 本项目 |
| 云端docker容器账号如Hugging Face  | ✅ 免费（CPU 额度够用） | 部署 SillyTavern 在线实例 |
| （可选）Docker | ✅ 本地安装免费 | 本地 / 自有服务器部署 |
| （可选）一个 API Key（如 OpenAI / Claude / 本地 Ollama） | 视服务商而定 | 让 AI 角色真正"开口说话"（SillyTavern 本身只是前端壳子）|

> ⚠️ 注意：SillyTavern 是一个**对话前端**，不包含大模型。你需要有可用的模型 API（OpenAI 兼容接口、Claude、Gemini、本地 Ollama 等），部署好之后在页面里配置。

---

## 🛠️ 详细教程 Part 1：GitHub 准备

> 只需要做一次。后面所有部署方式都复用这些资源。

### 1.1 创建备份仓库（放你的聊天数据）

1. 登录 GitHub，点击右上角 **`+` → New repository**
2. 填写：
   - **Repository name**：`sillytavern-profiles`（可任意起名）
   - **Public / Private**：建议选 **Private**（里面会保存你的**APIKey、聊天记录、角色卡！**）
   - ⚠️ **不要**勾选 *Add a README file*、*Add .gitignore*、*Choose a license*——**保持完全空仓库**（空仓库最干净，避免无关文件混进数据目录）
3. 点击 **Create repository** 完成

### 1.2 创建 GitHub Token（授权脚本帮你自动推送备份）

1. GitHub 右上角头像 → **Settings**
2. 左侧最底部 → **Developer settings** → **Personal access tokens** → **Tokens (classic)**
3. 点击 **Generate new token** → **Generate new token (classic)**
4. 填写：
   - **Token name**：`sillytavern-backup`
   - **Expiration**：建议选 **No expiration**（否则过期后备份静默失败；也可定期更换）
   - **Repository access**：勾选 **`Only select repositories`**，然后选择你的备份仓库。
   - **Permissions**：点击**Add permission**，搜索**Contents**添加，然后将**Read-only**改为**Read and write**
5. 点击底部 **Generate token**
6. **⚠️ 立即复制并保存 Token**（形如 `github_pat_xxxx...` 或 `ghp_xxxx...`）——它**只会完整显示这一次**，关掉页面就看不到了

> 💡 小提示：fine-grained token 的 **Only select repositories** 只能选择**你自己拥有**的仓库（会限制为成员身份的仓库则不适用）；`Metadata: Read` 权限在创建时自动带上且**不能关闭**——git 仓库的正常访问依赖它，保持默认即可。

### 1.3 Fork 本项目

1. 打开本仓库页面 `https://github.com/qyzzyqlqj/SillyTavern_Online`
2. 点击右上角 **Fork** → **Create fork**（默认即可）

> 小贴士：Fork 之后，如果你愿意，可以把短名称改成自己的，例如 `MySillyTavern`，不影响使用。

---

## 🚀 详细教程 Part 2：部署到 Hugging Face Spaces

> 这是推荐路线：免费、免服务器、自动 HTTPS。若想部署在自己服务器上，跳到 [Part 3](#-详细教程-part-3本地--自有服务器部署)。

### 2.1 创建 Space

1. 打开 [huggingface.co](https://huggingface.co)，登录后点击右上角 **`+` → New Space**（或直接访问 https://huggingface.co/new-space）
2. 填写：
   - **Space name**：如 `sillytavern`（会显示在 URL 里）
   - **License**：随意，选 `mit` 即可
   - **Select the Space SDK**：选择 **`Docker`**（关键！）
   - **Hardware**：选择免费的 **CPU basic** 即可（SillyTavern 很轻量）
3. 点击 **Create Space** 🎉

### 2.2 把 Fork 的代码同步到 Space

**方式 A：网页连接 GitHub（推荐，无需命令行）**

1. 进入 Space 页面 → **Settings** 标签页
2. 找到 **Repository** 区域 → 点击 **Connect**，授权你的 GitHub 账号
3. 绑定后，在仓库选择处找到你 Fork 的仓库（`你的用户名/SillyTavern_Online`），点击 **Merge git repository**（或按页面提示选择同步方式）
4. 等待几秒，Space 的 `Files` 标签页里应能看到 `start.sh`、`backup.sh`、`Dockerfile` 等文件

**方式 B：git push（命令行）**

```bash
git clone https://huggingface.co/spaces/你的用户名/你的Space名
cd 你的Space名
git remote add source https://github.com/你的用户名/SillyTavern_Online.git
git pull source main
git push origin main
```

> 若提示需要认证：在 https://huggingface.co/settings/tokens 创建 Token（权限勾选 `Write access to your Spaces`），用 `你的用户名` + `Token` 作为 git 凭据即可。

### 2.3 配置环境变量（Secrets）

1. 进入 Space → **Settings** → **Variables and secrets**
2. 点击 **New secret**，逐个添加以下 **4 个必需变量**（值按自己的信息填）：

| 变量名 | 示例值 | 说明 |
|---|---|---|
| `BACKUP_REPO_URL` | `github.com/你的用户名/sillytavern-profiles.git` | 你在 1.1 创建的备份仓库（可带 `https://` 前缀）|
| `BACKUP_TOKEN` | `github_pat_xxxx...` | 你在 1.2 创建的 Token |
| `USERNAME` | `admin` | SillyTavern 登录用户名（自己定）|
| `TAVERN_PASSWORD` | `一串足够复杂的密码` | SillyTavern 登录密码 |

3. （可选）需要时再添加：`BACKUP_BRANCH`、`BACKUP_SCHEDULE`、`GIT_USER_NAME`、`GIT_USER_EMAIL`、`ENABLE_BACKUP`、`PORT`——完整说明见[环境变量完整参考](#-环境变量完整参考)

### 2.4 构建并启动

1. 点击页面右上角 **`⋯`（更多按钮）→ Restart Space**（或 Settings 里的 Restart）
2. 切到 **Logs** 标签页，观察构建过程：
   - 第一次构建需要几分钟（拉取官方 SillyTavern、npm install）
   - 启动成功后日志末尾会看到 `SillyTavern is listening on port 7860` 之类的输出
3. 构建完成后，直接访问你的 Space 地址：`https://huggingface.co/spaces/你的用户名/你的Space名`
4. 页面出现**登录框** → 输入 `USERNAME` / `TAVERN_PASSWORD` → 进入 SillyTavern 主界面 🎉

> 💡 如果 Space 页面内嵌显示空白，可以把 Space 的 Settings → 找到 **Direct URL** 相关选项，或直接在地址栏输入 Space 地址（去掉 `/api/...` 等后缀），用浏览器直接打开应用。

### 2.5 （此步骤可选）把 Space 置顶收藏

Space 部署好以后，每次访问 `huggingface.co/spaces/你的用户名/你的Space名` 即可。建议在浏览器收藏夹存个书签。

---

## 🐳 详细教程 Part 3：本地 / 自有服务器部署

> 适合：有自己的 VPS / 家庭 NAS / 本地电脑，不想用 HF Spaces。

### 3.1 准备

- 安装 [Docker](https://docs.docker.com/engine/install/) 与 Docker Compose（推荐）
- 完成 [Part 1](#-详细教程-part-1github-准备) 的备份仓库（1.1）和 Token（1.2）

### 3.2 构建并运行

```bash
# 克隆本项目
git clone https://github.com/你的用户名/SillyTavern_Online.git
cd SillyTavern_Online

# 构建镜像
docker build -t sillytavern-online .

# 运行容器
docker run -d \
  --name sillytavern \
  -p 7860:7860 \
  -e BACKUP_REPO_URL="github.com/你的用户名/sillytavern-profiles.git" \
  -e BACKUP_TOKEN="github_pat_xxxx..." \
  -e USERNAME="admin" \
  -e TAVERN_PASSWORD="你的密码" \
  -e BACKUP_SCHEDULE="*/5 * * * *" \
  sillytavern-online
```

访问 `http://localhost:7860`（云服务器则为 `http://服务器IP:7860`），用 `USERNAME` / `TAVERN_PASSWORD` 登录。

### 3.3 用 docker-compose 管理（更推荐）

新建 `docker-compose.yml`：

```yaml
services:
  sillytavern:
    build: .
    container_name: sillytavern
    ports:
      - "7860:7860"
    environment:
      # 必需
      BACKUP_REPO_URL: "github.com/你的用户名/sillytavern-profiles.git"
      BACKUP_TOKEN: "github_pat_xxxx..."
      USERNAME: "admin"
      TAVERN_PASSWORD: "你的密码"
      # 可选
      BACKUP_BRANCH: "main"
      BACKUP_SCHEDULE: "*/5 * * * *"
      GIT_USER_NAME: "SillyTavern Backup"
      GIT_USER_EMAIL: "backup@sillytavern.local"
      # PORT: 7860
    restart: unless-stopped
    logging:
      driver: json-file
      options:
        max-size: "10m"
```

使用：

```bash
docker compose up -d --build   # 启动（会自动构建）
docker compose logs -f         # 查看日志
docker compose down            # 停止
```

---

## 🧭 环境变量完整参考

### 必需

| 变量 | 说明 |
|---|---|
| `BACKUP_REPO_URL` | 备份 Git 仓库，如 `github.com/你的用户名/sillytavern-profiles.git`。可带 `https://` 前缀；Token 会自动注入；也可直接填已含凭据的完整 URL（如 `user:token@github.com/...`）|
| `BACKUP_TOKEN` | GitHub Personal Access Token（fine-grained：给备份仓库授 `Contents` 读写权限；或 classic：勾选 `repo`）|
| `USERNAME` | SillyTavern 登录用户名 |
| `TAVERN_PASSWORD` | SillyTavern 登录密码 |

### 可选（均有默认值）

| 变量 | 默认值 | 说明 |
|---|---|---|
| `ENABLE_BACKUP` | `true` | 是否启用备份（恢复 + 自动推送）；`false` 时使用全新数据，仅当纯部署 SillyTavern 用（不填备份变量也不会报错）|
| `BACKUP_BRANCH` | `main` | 备份仓库的分支名 |
| `BACKUP_SCHEDULE` | `*/5 * * * *` | 自动备份 cron 表达式（`*/5 * * * *` = 每 5 分钟；`0 * * * *` = 每小时）|
| `GIT_USER_NAME` | `SillyTavern Backup` | 备份提交的用户名（会显示在备份仓库的提交记录里）|
| `GIT_USER_EMAIL` | `backup@sillytavern.local` | 备份提交的邮箱 |
| `PORT` | `7860` | SillyTavern 监听端口（**Hugging Face Spaces 必须保持 7860**；本地可改）|

> 完整模板见 [`.env.example`](.env.example)。

**快速检查表**：部署前确认这四行

```text
BACKUP_REPO_URL  = 你自己的备份仓库（不是本项目！）
BACKUP_TOKEN     = 有 repo 权限的 Token
USERNAME         = 你的登录名
TAVERN_PASSWORD  = 你的登录密码
```

---

## ✅ 首次使用与验证备份

1. **登录后随便聊几句 / 建一个角色**（不配 API 也能建角色，只是没法对话）
2. **等待 5 分钟以内**，打开你的备份仓库 `sillytavern-profiles`
3. 应看到类似这样的提交记录：

   ```
   auto backup 2025-08-20 21:05:33   ← 每 5 分钟一条
   auto backup 2025-08-20 21:00:12
   auto backup 2025-08-20 20:55:47
   ```

4. 点开仓库的 `Files`，会看到 `characters/`、`chats/`、`extensions/` 等目录——**说明备份链路已经通了** 🎉

5. **测试数据恢复**：在 Space 设置里点击 **Restart Space**，重启后你的角色卡、聊天记录应该原样回来（启动日志里有 `已有Git仓库，拉取最新备份` / `执行 git pull` 字样）

---

## 📁 数据备份结构说明

备份仓库里保存的是 SillyTavern 的 `data` 目录内容，常见子目录：

| 目录 | 内容 |
|---|---|
| `characters/` | 你的角色卡（PNG 卡片文件）|
| `chats/` | 聊天记录（JSONL）|
| `group chats/` | 群聊记录 |
| `extensions/third-party/` | 第三方插件（脚本自动同步）|
| `settings/` | 界面与功能设置 |
| `instruct/`、`context/`、`assets/`、`backgrounds/` 等 | 其他数据 |

> 已配置 Git LFS（见 `gitattributes`），模型文件等大文件会自动走 LFS 存储，不会撑爆仓库。

---

## ❓ 常见问题 FAQ

**Q1：Space 一直构建失败怎么办？**
查看 **Logs** 标签页的具体报错。最常见原因是网络波动导致 clone 官方 SillyTavern 或 `npm install` 失败，点 **Restart Space** 重试即可。

**Q2：登录提示密码错误？**
检查 `USERNAME` / `TAVERN_PASSWORD` 是否填对（Settings → **Variables and secrets**），修改后 **Restart Space**（环境变量只在启动时生效）。

**Q3：备份仓库一直空 / 没有新提交？**
按顺序排查：
1. `BACKUP_TOKEN` 是否授予了备份仓库的 `Read and write`（Contents）权限；
2. Space 容器的 `/tmp/backup.log` 里有没有报错；
3. 确认容器确实在运行（HF Spaces 免费实例**休眠**后会停止 cron——访问一次页面让它醒过来）。
4. 设置 `BACKUP_SCHEDULE` 为 `*/1 * * * *`（每分钟）做测试，正常后再改回去。

**Q4：push 失败 / 远程仓库冲突？**
多实例同时写同一个备份仓库可能出现冲突（脚本 push 前没有 pull）。解决：**Restart Space 一次**，让启动脚本里的 `git pull` 合并后再继续。日常单人使用基本不会遇到。

**Q5：我本地有现成的 SillyTavern 数据，能迁移进来吗？**
可以。把本地 `data` 目录内容 push 到你的备份仓库：

```bash
cd 你的本地data目录
git init
git add -A
git commit -m "initial import"
git branch -M main
git remote add origin https://你的用户名:你的Token@github.com/你的用户名/sillytavern-profiles.git
git push -u origin main
```

之后按本教程部署，首次启动会自动拉取这些数据。

**Q6：不想用 GitHub 备份，只想部署一个在线 SillyTavern？**
设置 `ENABLE_BACKUP=false`，只填 `USERNAME` / `TAVERN_PASSWORD` 即可。注意：**不启用备份时，Space 重启会丢失数据**。

**Q7：页面空白 / 一直转圈？**
- 关闭浏览器广告拦截插件再试；
- 换一个浏览器 / 无痕模式；
- 直接把 Space 地址输入地址栏回车（部分环境 iframe 嵌入受限）。

**Q8：`BACKUP_REPO_URL` 写法有什么讲究？**
支持三种写法，效果相同：
- `github.com/用户名/仓库.git` ✅（最简）
- `https://github.com/用户名/仓库.git` ✅
- `https://用户名:Token@github.com/用户名/仓库.git` ✅（已含凭据，直接使用）
- ⚠️ 不支持 `git@github.com:...` 这种 SSH 格式（脚本会明确报错提示）。

---

## 🔒 安全注意事项

1. **备份仓库务必设为 Private**——里面是你的聊天记录和角色卡
2. **Token 最小权限**：按 1.2 教程使用 fine-grained token，只给备份仓库授 `Contents` **读写**权限（或 classic token 只勾选 `repo`），不要用全权限 Token；Token 会嵌入 Git 远程 URL（`https://<token>@github.com/...`），仅存在于容器内部
3. **Space 也建议设为私有**（Settings → 可见性），避免他人访问你的实例
4. **定期检查备份频率**：默认每 5 分钟一次提交；提交太频繁会让仓库 commit 很多，可改为 `*/15 * * * *` 等
5. **密码强度**：`TAVERN_PASSWORD` 用足够复杂的密码，且不要与其它账号共用

---

## 🛠️ 自定义与扩展

- **配置模型 API**：登录后在页面里配置 OpenAI / Claude / Gemini / 本地 Ollama 等，都支持
- **安装第三方插件**：在 SillyTavern 界面操作即可，脚本会自动纳入备份
- **更多玩法**：多用户模式（改 config.yaml 的 `enableUserAccounts`）、自定义主题、提示词模板等，均在页面里配置，全部自动备份

有任何问题，欢迎在 GitHub 提 Issue 📮

---

**PS**:目前 Hugging Face 似乎不再提供新的免费实例，可选择 Render 等其他托管平台