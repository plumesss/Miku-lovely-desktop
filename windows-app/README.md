# 初音桌宠 Windows 版

使用 Electron 和 HTML Canvas 实现透明悬浮桌宠，目标为 Windows 10 / 11 x64。支持三套形象、点击与拖动、动态动作、投喂、预设台词聊天、本地语音及口型、整点问候、天气 / 季节特效、托盘菜单和登录后自动启动设置。

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
node -e "require('node:fs').mkdirSync('../分享安装包/.build', {recursive: true})"
npm run smoke
npm run build:win
```

`npm run check` 检查四个 JavaScript / CommonJS 文件的语法。`npm run smoke` 需要完整 Electron 安装及图形会话，使用独立的临时用户数据目录和隐藏窗口，验证图片、720 帧动画、75 张口型、10 段音频解码、静音播放的口型同步、设置通信及绘制，并输出预览图到 `../分享安装包/.build/windows-preview.png`。该检查不能代替 Windows 实机测试。

`npm run build:win` 使用 electron-builder 构建 x64 NSIS 安装包，输出至 `../分享安装包/windows/`。安装包内含 Electron，使用者不需要安装 Node.js。当前未配置发布者代码签名。

## 天气与许可

设置中的城市名会发送到 Open-Meteo 城市搜索接口，随后使用返回的坐标查询天气，普通互动不需要联网。应用使用上下文隔离、沙箱及预加载接口，加载本地页面。

项目原创代码和文档采用 [MIT License](../LICENSE)；角色、图像、动画、音频和图标需按各自权利及条款处理，见 [第三方素材说明](../THIRD_PARTY_NOTICES.md)。`private: true` 仅用于防止误发布到 npm。

发布到 GitHub 的步骤见 [开源发布指南](../docs/OPEN_SOURCE_GUIDE.md)。
