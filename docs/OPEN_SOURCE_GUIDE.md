# 将 MikuDeskPet 发布为 GitHub 开源项目

## 1. “把文件变成开源”的含义

开源不需要转换 Swift、JavaScript 或其他文件格式。它是把可阅读、可修改的源代码公开，并附上明确的许可，使别人知道可以做什么、需要遵守什么条件。

| 内容 | 作用 |
| --- | --- |
| 源码（`src/`、`windows-app/`） | 让他人阅读、修改和构建程序 |
| `LICENSE` | 说明对原创代码及文档采用 MIT 授权 |
| `README.md` | 帮助使用者了解真实功能、安装、使用及构建方式 |
| `THIRD_PARTY_NOTICES.md` | 区分项目代码与第三方素材、依赖的权利和条款 |
| `.gitignore` | 避免把本机依赖、缓存、备份和构建产物加入 Git |
| GitHub 仓库 | 保存源码与修改历史，接收 Issues / Pull Requests |
| GitHub Releases | 按版本发布已经构建和验证的安装包 |

公开源码但不附许可证，不等于授予别人自由修改和分发的权利；只上传安装包，也不能让别人从源码构建软件。

## 2. 本项目已经准备了什么

- 根目录 README 包含两版真实功能差异、安装方法、使用方法、开发依赖、构建命令与验证范围。
- LICENSE 使用标准 MIT 正文，版权行以已有项目名署名：`Copyright (c) 2026 MikuDeskPet contributors`。如需使用自己的姓名或组织名，应在首次发布前核实并修改这一行；不要把第三方素材权利人写成代码作者。
- `.gitignore` 排除本机依赖、缓存、备份、应用和安装包，以及尚未核实公开授权的图片、音频和图标；保留程序代码、文档和依赖锁文件。本地资源保留在原目录。
- Windows 包元数据声明代码许可为 MIT；`private: true` 仍保留，它只防止误发布到 npm，不妨碍 GitHub 仓库开源。
- 素材说明列出角色、图片、语音和图标目前缺少的来源 / 授权记录。

这些是本地发布准备，不代表已建立远程仓库、已上传代码或已发布安装包。

## 3. 先处理素材的公开分发条件

MIT 允许别人使用、修改和商业使用代码，前提是保留版权及许可证声明；代码按现状提供，不作担保。MIT 正文没有“禁止商用”条件。不能在标准 MIT 后再附上“整个项目禁止商用”，却仍称整个项目为 MIT 开源。

当前桌宠包含初音角色图片、派生动画、图标和语音，旧文件有“个人非商业使用”说明，但没有完整的第三方授权记录。公开上传这些文件和发布含有这些文件的安装包都属于分发，需要先核对相应权利。

1. 逐项阅读根目录 `THIRD_PARTY_NOTICES.md` 的素材清单。
2. 找到原始来源、作者或权利人及适用条款，核实是否允许公开分发、改作和你的使用场景。
3. 将确认过的来源、许可证、署名要求记录到该文件，并保留允许公开的授权材料。
4. 缺乏授权时，用自己拥有权利或明确许可的素材替换。两版各有素材目录，派生动画、口型和图标也需要对应更新。
5. 当前采用只公开代码和文档的方式。README 已说明下载源码后需要准备本地资源，具体文件布局见 [资源准备说明](ASSETS.md)。

当前 `.gitignore` **默认排除运行素材**；源码导出脚本也只收录明确列出的代码和文档。已有 Git 历史的项目仍需自行检查是否曾经跟踪这些文件；忽略规则不会从历史中删除它们。未来取得素材公开分发授权后，再按实际授权更新排除规则。

## 4. 本地检查与构建

先按 README 安装开发依赖，并按 [资源准备说明](ASSETS.md) 放置有权使用的本地资源；公开代码包不包含这些资源。

macOS 在项目根目录执行：

```sh
source .venv/bin/activate
bash src/build.sh
open MikuDeskPet.app
```

如果还没有 `.venv`，先按 README 创建并安装 NumPy、Pillow。检查点击、拖动、切换形象、语音口型、设置、天气及退出。`src/build.sh` 只构建当前架构的 `.app`；现有 Universal DMG 的构建没有可复用脚本，不能把本次单架构构建直接宣传为 Universal。

Electron 版在项目根目录执行：

```sh
cd windows-app
npm ci
npm run check
node -e "require('node:fs').mkdirSync('../分享安装包/.build', {recursive: true})"
npm run smoke
npm run build:win
cd ..
```

`npm run smoke` 需要 Electron 运行时及图形会话。随后仍需在目标 Windows 电脑上检查安装、启动、声音、托盘、设置保存、自动启动和卸载。发布说明应写清实际验证的平台，不把 macOS 上的 Electron 检查等同于 Windows 实机通过。

新的 macOS 构建脚本会把 MIT 和素材说明复制到应用资源目录，Windows 打包配置会将它们放入 `resources/`。分发时仍需保留 Electron 等依赖的许可证，并确认素材许可允许该次分发。旧安装包不会因配置更新而自动改变；当前保留的旧包仅供本地使用，不能直接当作已完成授权核实的新发布包。

只需要分享源码时，在根目录运行 `python3 src/export_source.py`。输出的 `dist/MikuDeskPet-source.zip` 使用代码和文档白名单，排除了素材、本机配置、依赖、缓存、备份及安装包，不执行 Git。请使用这个源码包，避免直接压缩整个工作目录。

## 5. 在本机建立 Git 仓库

Git 记录文件和每次变更的历史；GitHub 托管这份历史。下列命令是操作示例，需要在终端执行；本次文档整理没有自动执行提交和推送。

在终端从项目父目录进入项目文件夹（文件夹名称不同时自行替换；已在根目录时跳过 `cd`）：

```sh
cd MikuDeskPet
git init -b main
git status --short --untracked-files=all
```

`git init -b main` 在本地创建仓库，不会上传文件。若已存在 Git 仓库，保留原有仓库并检查当前分支即可，不要重新覆盖历史。

首次使用 Git 时，按实际身份配置此仓库的提交者信息：

```sh
git config user.name "你的署名"
git config user.email "你的 GitHub noreply 邮箱或希望公开的邮箱"
```

提交邮箱会出现在 Git 历史中。GitHub 的邮箱设置中可以找到用于隐藏真实邮箱的 noreply 地址；请替换示例文字。

确认只发布代码和文档、所需素材均被排除后，将需要发布的文件加入暂存区并检查：

```sh
git add .
git diff --cached --stat
git diff --cached --name-only
git diff --cached --check
```

确认依赖、个人配置、备份、签名证书、密钥和安装包没有被加入。`.gitignore` 只影响尚未跟踪的文件；已经被 Git 跟踪的文件不会因为新加忽略规则而退出历史。如果密钥已经提交过，应先撤销密钥并处理历史，仅删除当前文件不足以清除历史中的内容。

当前 macOS DMG 约 143 MB，超过普通 Git 上传的单文件 100 MiB 限制；安装包目录已统一忽略，使用 Releases 分发，不要强制 `git add -f`。大型必需素材可按实际需要考虑 Git LFS；启用后要确保贡献者安装 LFS 并能获取资源。

确认暂存内容后提交：

```sh
git commit -m "Prepare MikuDeskPet for open source release"
```

提交只是生成本机快照，仍未公开到 GitHub。

## 6. 在 GitHub 创建并上传仓库

1. 登录 [GitHub](https://github.com/)，点击右上角“+” → **New repository**。
2. 仓库名可填 `MikuDeskPet`，简介可填“支持 macOS 与 Windows 的初音主题桌面宠物”。
3. 确认仓库只包含已审查的代码和文档后，可以选择 **Public**。包含素材的完整应用需要先解决素材分发授权。如还在整理，可先创建 **Private** 仓库；私有并不自动授予素材分发权。
4. 本地已有 README、LICENSE 和 `.gitignore`，创建远程仓库时不要再勾选自动生成这些文件，以免产生独立的初始提交。
5. 点击 **Create repository**，复制自己的 HTTPS 仓库地址。

回到本机项目根目录，将示例地址中的 `YOUR_GITHUB_NAME` 替换为实际账号名，然后执行：

```sh
git remote add origin https://github.com/YOUR_GITHUB_NAME/MikuDeskPet.git
git push -u origin main
```

`git remote add` 只是记住远程地址；`git push` 才会上传已提交文件。认证可使用 GitHub CLI 的 `gh auth login`（需先安装 CLI）、Git 凭据管理器或已配置的 SSH；GitHub HTTPS Git 操作不接受账号密码。不要把令牌写进仓库文件或远程 URL。

如果本地已配置 `origin`，先用 `git remote -v` 核对，不要覆盖其他项目地址。上传后刷新仓库页面，检查 README、LICENSE、源码目录、文档链接以及 GitHub 的许可证识别结果。

## 7. 发布安装包到 Releases

源码仓库供开发者阅读与构建，Releases 供普通用户下载安装包。

1. 确认上传代码与安装包相对应，素材许可记录完整，安装包包含所需许可证文件。
2. 核对版本号：macOS 在 `src/Info.plist`；Windows 在 `windows-app/package.json` 及锁文件。Windows 安装包名通过 `build.win.artifactName` 的 `${version}` 自动使用应用版本。更新版本后重新构建，不只给旧包改文件名。
3. 在仓库打开 **Releases → Draft a new release**，选择已验证的提交，创建标签，例如 `v0.1.0`。
4. 填写版本说明，包含功能、系统要求、安装步骤、签名情况、已验证平台和已知限制。将 MIT、素材说明及平台所需第三方许可包含在发布归档中。
5. 上传实际完成构建和检查的 macOS / Windows 发布产物。GitHub 自动生成的 Source code 压缩包不等于安装包。
6. 预览后点击 **Publish release**，再将 README 的安装说明更新为实际 Release 链接。

当前没有自动发布 workflow、自动生成 Universal DMG 或自动签名、公证配置。

当前 v0.1.0 是首次源码发布，只提供代码和文档，不提供安装包；发布说明见 [v0.1.0](releases/v0.1.0.md)。完整应用的素材分发授权和目标系统实机验证仍需补齐。

## 8. 后续维护方式

修改代码后，在本地检查、提交，再推送：

```sh
git status --short
git add README.md
git diff --cached
git commit -m "Update project documentation"
git push
```

这里以修改 README 为例；改其他文件时按实际路径暂存。修复功能后同步修改文档；发布新安装包时创建新版本 Release。保留 MIT 及第三方署名，避免把他人的素材重新标为自己拥有。

其他人可以通过 Issues 提问、Fork 仓库修改，再提交 Pull Request。维护者审查变更、运行检查后决定是否合并；合并后的代码进入后续版本。
