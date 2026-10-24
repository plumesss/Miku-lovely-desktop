# MikuDeskPet · 初音桌宠

一个以初音未来为主题的桌面宠物项目。桌宠通过透明悬浮窗口显示在桌面上，可以点击互动、拖动位置、切换形象、投喂大葱，并播放本地语音及对应口型动画。

项目包含两个独立实现：macOS 使用 **Swift / AppKit**，Windows 使用 **Electron / HTML Canvas**。动画由现有图片生成的二维变形图集驱动。

> 项目代码以 [MIT License](LICENSE) 授权。角色、立绘、语音和图标等素材不因此获得 MIT 授权；仓库中尚缺完整的素材来源及公开再分发授权记录，详见 [第三方素材说明](THIRD_PARTY_NOTICES.md)。本项目为非官方桌宠项目。

**公开源码默认不包含运行素材，不能直接启动完整桌宠。** 本机已有资源保留，但不进入公开源码包。构建前请按 [资源准备说明](docs/ASSETS.md) 放置有权使用的图片、音频及图标。下表描述资源齐备时的现有程序功能。

当前开源版本为 **0.1.0**，定位为首次源码发布。下载及发布说明见 [v0.1.0 Release](https://github.com/plumesss/Miku-lovely-desktop/releases/tag/v0.1.0)；本版只提供源码包，需要自行准备已授权素材。

## 主要功能

| 功能 | macOS 原生版 | Windows Electron 版 |
| --- | --- | --- |
| 透明悬浮窗口、点击互动、拖动移动 | 支持 | 支持；提供系统托盘入口 |
| 三套形象 | 标准、Q 版、蜡笔 | 标准、Q 版、蜡笔 |
| 动态动作、表情和语音口型 | 支持；可关闭动态模式 | 支持；可关闭动态模式 |
| 投喂大葱、预设台词聊天 | 支持 | 支持 |
| 心情变化 | 点击、投喂、送礼物提升；随时间下降，保存到本地 | 点击、投喂提升；随时间下降，互动后的心情不持久保存 |
| 夜间睡眠表情、整点问候 | 支持；在预设的部分整点问候 | 支持；每次检测到小时变化时问候 |
| 大小、透明度、语音开关及音量 | 支持 | 支持 |
| 登录后自动启动 | 设置中开启，使用 LaunchAgent | 设置中开启，使用 Electron 登录项接口 |
| 实时天气 | 系统定位后向 Open-Meteo 查询 | 设置中手动输入城市，向 Open-Meteo 查询 |
| 天气 / 季节特效 | 晴天、雨、雪、流星、樱花、枫叶；提供演示和自动场景选择 | 同类特效可手动选择；天气查询会选择相应天气特效 |
| 功能面板、送礼物、便签、50 分钟休息提醒 | 支持；便签需点击保存 | 尚未实现 |

“聊聊天”从本地预设台词中选择内容，目前没有接入大模型、自由对话、语音识别或语音合成服务。语音来自项目内的 10 段音频文件，口型随播放音量变化。常规互动可离线使用，天气查询需要联网。

## 安装方法

### 使用安装包

项目正式发布安装包前，需要先解决所包含素材的分发授权。目前工作目录保留以下旧构建产物，仅供本地使用和核对；它们不进入公开源码包，也不属于 v0.1.0 Release 附件。文件名中的 1.0 是旧本地构建版本，与当前开源版本 0.1.0 不同。

| 系统 | 安装包 | 安装步骤 |
| --- | --- | --- |
| macOS 13 及以上 | `MikuDeskPet-1.0-macOS-Universal.dmg` | 打开 DMG，将应用拖入“应用程序”，再从“应用程序”启动 |
| Windows 10 / 11 x64 | `MikuDeskPet-1.0.0-Windows-x64-Setup.exe` | 运行安装向导，选择目录，使用桌面快捷方式启动 |

现有安装说明记录 macOS 分享包包含 Apple Silicon 和 Intel 架构，但尚未在 Intel Mac 或 macOS 13 实机验证；Windows 安装包也尚未完成 Windows 实机验证。Windows ARM 的 x64 模拟运行未经验证，未提供 Linux 版。

现有 macOS 分享包仅作本地临时签名，未经过 Apple 开发者签名和公证；Windows 包未配置发布者代码签名。如系统拦截，请先核实下载来源，并按系统提示处理。更新前请先右键桌宠选择“退出”。

### 从源码构建 macOS 版

需要 macOS 13 及以上、Xcode Command Line Tools（提供 Swift 编译器和系统 SDK）、Python 3、NumPy、Pillow 及 [已准备的本地素材](docs/ASSETS.md)。以下命令在项目根目录运行；尚未安装开发工具时，可先执行 `xcode-select --install` 并完成系统安装流程。

```sh
python3 -m venv .venv
source .venv/bin/activate
python -m pip install numpy Pillow
bash src/build.sh
open MikuDeskPet.app
```

构建脚本先检查本地资源，缺少时退出并提示资源说明；资源齐备后会生成动画和口型素材、编译 Swift、重新组装根目录的 `MikuDeskPet.app`，并尝试本地临时签名。它会覆盖根目录同名应用和可执行文件。正常构建无需运行 `chroma_key*.py` 或 `make_icon.py`；可选的绿幕处理和图标生成方式见资源准备说明。

`src/build.sh` 默认只编译当前 Mac 的架构，没有生成 Universal 应用或 DMG 的自动化流程。音频只从项目内的 `sounds/voice_selfep_piapro_21_01.m4a` 至 `10.m4a` 读取，并统一命名为应用内的 `voice_01.m4a` 至 `10.m4a`。

### 从源码运行 / 构建 Windows 版

建议使用 **Node.js 22.12 或更新的受支持 LTS 版本**及 npm；Electron 与打包工具版本由 `windows-app/package-lock.json` 固定。开发工具首次安装和打包时需要下载依赖。

先按 [资源准备说明](docs/ASSETS.md) 配置 `windows-app/assets/` 及打包所需图标，再在项目根目录打开终端，依次运行：

```sh
cd windows-app
npm ci
npm run check
npm start
```

退出开发中的桌宠后，生成 Windows x64 NSIS 安装程序：

```sh
npm run build:win
```

默认输出目录为根目录的 `分享安装包/windows/`。安装包已包含 Electron 运行环境，最终用户无需安装 Node.js。该子项目目标平台是 Windows；macOS 上运行开发界面或冒烟检查不能代替 Windows 实机验证。

可选冒烟检查（在 `windows-app/` 中执行）：

```sh
node -e "require('node:fs').mkdirSync('../分享安装包/.build', {recursive: true})"
npm run smoke
```

现有检查会通过隐藏窗口验证图片、15 个图集对应的 720 帧动画、75 张口型、10 段音频解码、静音播放的口型同步、设置通信和桌宠绘制，并输出预览图到 `分享安装包/.build/windows-preview.png`。它需要完整的 Electron 安装和图形会话；不覆盖安装、卸载和系统自启动的实机行为。

## 使用方法

1. **互动与移动**：左键点击角色触发台词和表情；按住角色拖动以移动位置。
2. **打开菜单**：右键点击角色，可以投喂大葱、聊天、切换形象、演示语音口型和动作，也可以进入设置或退出。
3. **调整外观与声音**：在“设置”中调整大小、透明度、语音开关和音量；动态模式可在右键菜单切换。两版均会自动保存常规设置。
4. **启用自动启动**：在设置中勾选“开机自动启动”。macOS 请先把应用放到固定位置（推荐“应用程序”），再开启；移动应用后需重新设置。
5. **使用天气**：macOS 启动时会尝试请求定位，也可通过“打开功能面板 → 更新天气”重试；Windows 在设置中输入城市并结束编辑后查询。两版都可以手动演示天气或季节特效。
6. **macOS 额外功能**：右键选择“打开功能面板”，可以送礼物、查看心情、打开便签和开启休息提醒。便签内容需点击“保存便签”，休息提醒只在本次应用运行期间生效。
7. **找回或退出 Windows 桌宠**：在系统托盘右键图标，选择“显示桌宠”使其回到主屏幕；选择“退出”结束应用。卸载通过 Windows“设置 → 应用”完成。

macOS 作为辅助类应用运行，不显示常规 Dock 图标；主要入口为角色的右键菜单。

## 数据与联网

- macOS 使用 `UserDefaults` 保存设置、心情和已保存的便签；自动启动配置位于 `~/Library/LaunchAgents/com.miku.deskpet.plist`。
- Windows 将常规设置保存在 Electron 用户数据目录下的 `preferences.json`；互动心情仅在当前渲染进程内变化，不会随互动立即写回此文件。
- 天气由 [Open-Meteo](https://open-meteo.com/) 提供。macOS 向天气接口发送定位坐标；Windows 先向城市搜索接口发送城市名，再使用返回的坐标查询天气。无需账号或 API Key。
- 拒绝定位或天气查询失败时，仍可使用本地桌宠互动。天气数据与接口使用条件以 [Open-Meteo 使用条款](https://open-meteo.com/en/terms) 为准。

## 项目结构

```text
MikuDeskPet/
├── README.md                 # 项目介绍、安装与使用
├── LICENSE                   # MIT 许可证正文
├── THIRD_PARTY_NOTICES.md     # 素材和第三方授权说明
├── .gitignore                # 排除依赖、备份与安装包
├── docs/OPEN_SOURCE_GUIDE.md  # GitHub 开源发布操作说明
├── docs/ASSETS.md             # 本地资源放置与公开范围
├── src/                      # macOS Swift 源码和素材生成脚本
├── assets/                   # 本地 macOS 素材（不公开）
├── sounds/                   # 本地音频（不公开）
└── windows-app/              # Windows Electron 代码与独立素材副本
```

`windows-app/assets/` 是独立副本，修改根目录素材后不会自动同步到 Windows 版；两个目录都需要保留各自运行所需的文件。

## 许可证与参与贡献

项目原创代码及文档采用 [MIT License](LICENSE)：允许使用、修改、再分发及商业使用代码，分发时需保留版权和许可证声明，软件按现状提供。MIT 不授予第三方角色、商标、图片、音频或其他素材的权利，也不替代依赖自身的许可证。详见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

欢迎通过本仓库的 Issues 和 Pull Requests 报告问题、改进功能及文档。报告问题时请注明系统版本、应用版本、复现步骤和相关日志；修改功能时请同步更新本 README。贡献素材时请提供来源和明确的授权依据。

准备首次发布或维护后续版本，请阅读 [GitHub 开源发布操作指南](docs/OPEN_SOURCE_GUIDE.md)。运行 `python3 src/export_source.py` 可生成只含代码和文档的 `dist/MikuDeskPet-source.zip`，不执行 Git。
