# 初音桌宠 Windows 版

使用 Electron 和 HTML Canvas 实现透明悬浮桌宠，目标为 Windows 10 / 11 x64。支持三套形象、点击与拖动、动态动作、投喂、预设台词聊天、整点问候、天气 / 季节特效、托盘菜单和登录后自动启动设置。

完整项目介绍、安装及使用方法见 [根目录 README](../README.md)。macOS 原生版的功能面板、送礼物、便签和休息提醒尚未移植到 Windows 版。

公开源码不包含图片、动画、口型、语音或图标，不能直接运行完整桌宠。请先按 [资源准备说明](../docs/ASSETS.md) 配置本地资源；本机原有资源没有删除。

## 开发运行

建议使用 Node.js 22.12 或更新的受支持 LTS 版本及 npm。在本目录运行：

```sh
npm ci
npm run check
npm start
```

常规设置保存在 Electron 用户数据目录中的 `preferences.json`。互动过程中变化的心情仅在渲染进程内保留。

## 检查与构建

退出开发中的桌宠后，按需运行：

```sh
npm run smoke
npm run build:win
```

`npm run check` 检查四个脚本的语法。`npm run smoke` 需要完整 Electron 运行时及图形会话，验证立绘、720 帧动画、75 张口型资源、设置通信和绘制；无音频时检查播放无法开启。预览写入系统临时目录，可通过 `MIKU_SMOKE_OUTPUT` 覆盖。公开包不包含语音；有合法本地音频的开发环境才运行额外音频测试。

`npm run build:win` 输出 `../dist/windows/MikuDeskPet-0.1.1-Windows-x64-Setup.exe`，始终排除 `assets/sounds/` 及音频文件。包内含 Electron，用户无需 Node.js；未配置发布者签名。运行 `node ../src/verify_windows.cjs` 可核对打包代码、图片、许可文件及音频排除规则。自动化安装与卸载验证见仓库 Windows 发布 workflow。

## 天气与许可

设置中的城市名会发送到 Open-Meteo 城市搜索接口，随后使用返回的坐标查询天气，普通互动不需要联网。应用使用上下文隔离、沙箱及预加载接口，加载本地页面。

项目原创代码和文档采用 [MIT License](../LICENSE)；角色、图像、动画、音频和图标需按各自权利及条款处理，见 [第三方素材说明](../THIRD_PARTY_NOTICES.md)。`private: true` 仅用于防止误发布到 npm。

发布到 GitHub 的步骤见 [开源发布指南](../docs/OPEN_SOURCE_GUIDE.md)。
