# 第三方素材与依赖说明

## 代码与角色的许可范围

原创程序代码和文档使用根目录 [MIT License](LICENSE)。MIT 允许商业使用代码，但不授予第三方角色、商标、立绘、图标或依赖的权利。**包含初音形象的安装包限非商业使用；不能将整套安装包称为 MIT 素材。** 本项目为个人非商业、免费分发的非官方同人项目，与 Crypton 无合作或背书关系。

## 初音未来角色与立绘

Hatsune Miku, © Crypton Future Media, Inc. 2007.

This application features an adaptation of Hatsune Miku, © Crypton Future Media, Inc. 2007, licensed under CC BY-NC 3.0:
https://creativecommons.org/licenses/by-nc/3.0/
Based on a work at https://piapro.net/license .

核对日期：2026-10-24。官方依据：

- [Crypton 面向海外创作者的说明](https://piapro.net/intl/en_for_creators.html)：允许按 CC BY-NC 条件非商业使用角色原始插画；FAQ Q6 说明他人的二创另有作者权利，Q8 要求创作者为自己的角色二创采用等同非商业 CC 的条件。
- [角色使用指南](https://piapro.jp/license/character_guideline) 与 [Piapro Character License](https://piapro.jp/license/pcl)：说明非营利、无偿二创及署名等条件；商业、广告等超出范围的用途须另行处理。

项目提供者确认三套立绘为 AI 生成，报告的生成工具名称为 **GLM-5.3**。这是提供者的来源声明，并非官方素材或官方授权证明；未提供生成任务记录、参考图及具体生成服务入口，不能据此保证每张图片均有独占版权。作为平台条款核对参考，[智谱开放平台用户协议](https://docs.bigmodel.cn/cn/terms/user-agreement)（页面生效日期 2026-09-04）的知识产权条款要求用户自行判断生成内容的版权及使用，平台并不替用户解决第三方角色权利；具体服务仍以生成时接受的协议为准。

安装包中使用上述立绘及其动画图集、口型贴图和衍生图标，角色素材的使用须遵守上述非商业条件及署名要求。原图、图集、贴图及图标不单独上传公开仓库，也不提供独立素材下载。代码贡献者不能通过 MIT 许可转授 Crypton 的角色权利。商业利用代码时，请另行准备允许相应用途的角色资源。

## 语音不公开分发

项目原本地目录的 10 段 M4A 未确认可公开再分发。项目提供者要求排除它们：**v0.1.1 的 macOS / Windows 安装包与公开源码包均不包含这些语音**，相应的播放开关和演示入口在无音频时关闭。源文件仅保留在提供者本机，不因文件名或角色 CC 条款获得分发许可。官方 FAQ Q5 明确说明歌曲和音频不在角色插画 CC 许可范围内。

## 第三方软件与数据服务

- **Electron / Chromium**：Windows 安装包保留运行时随附的 `LICENSE.electron.txt`、`LICENSES.chromium.html` 及相关文件，遵循各自许可证。
- **npm 构建依赖**：实际版本由 `windows-app/package-lock.json` 固定；项目 MIT 不覆盖这些依赖。
- **NumPy / Pillow**：仅用于构建图片，桌宠运行时无需 Python；另行分发这些库时遵循其许可证。
- **Open-Meteo**：天气接口与城市搜索服务来自 [Open-Meteo](https://open-meteo.com/)。数据许可及服务使用条件见其 [文档](https://open-meteo.com/en/docs) 和 [使用条款](https://open-meteo.com/en/terms)，代码 MIT 不代表服务可无限制商用。

后续加入新素材时，应记录来源、权利人、许可链接、修改及公开分发条件和必要署名；不能把未取得的授权写成已获得。
