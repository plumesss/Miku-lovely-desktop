# 本地资源准备与公开范围

公开源码只包含程序和文档，**不包含角色图片、动画、口型、语音及图标，不能直接启动完整桌宠**。这些文件的公开再分发授权尚未核实，当前本机副本保留用于本地开发，并通过 `.gitignore` 和源码导出白名单排除。

请自行准备有权使用的资源。不要从旧安装包提取素材后直接重新公开；获得允许公开分发的授权后，再更新 `THIRD_PARTY_NOTICES.md` 和发布规则。

## macOS 所需资源

| 位置 | 文件要求 |
| --- | --- |
| `assets/` | 三个前缀 `miku`、`miku_chibi`、`miku_crayon`，各自对应 `idle`、`blink`、`happy`、`sad`、`sleep` 五个状态的透明 PNG，共 15 张；例如 `miku_idle.png` |
| `sounds/` | `voice_selfep_piapro_21_01.m4a` 至 `voice_selfep_piapro_21_10.m4a` 共 10 段有效 M4A；名称是现有代码约定，不代表音频授权 |
| `src/AppIcon.icns` | macOS 应用图标，可用有权使用的图片运行 `make_icon.py` 生成 |

`bash src/build.sh` 会先检查以上输入，缺少时给出资源说明并退出；检查通过后才生成图集、口型并替换应用。它只读取项目内音频，不搜索临时下载目录。生成的 `assets/animation/` 和 `assets/mouths/` 也是本地资源，不随源码导出。

动画脚本按原立绘布局生成图集；口型脚本中的 `POLYS`、`RIGS`、`DONORS` 是针对原画校准的像素位置。换用其他图片时，需要同步修改 `src/make_motion.py` 和 `src/make_mouths.py` 的布局参数，不能只改图片文件名就保证动画和口型正确。

## 可选的绿幕处理与图标生成

正常构建直接使用上述透明 PNG，无需重新处理绿幕。需要处理时，为标准版和 Q 版分别准备输入文件夹，每个文件夹包含 `idle.png`、`blink.png`、`happy.png`、`sad.png`、`sleep.png`：

```sh
python3 src/chroma_key.py --input-dir ./local-art/standard
python3 src/chroma_key_chibi.py --input-dir ./local-art/chibi
```

两个脚本默认输出到项目的 `assets/`，分别命名为 `miku_*.png` 和 `miku_chibi_*.png`。可通过 `--output-dir` 指定其他目录，通过 `--previews` 显式生成预览图。`local-art/` 是本地输入目录，已在 `.gitignore` 中排除，不包含在公开源码中。

macOS 图标生成命令：

```sh
python3 src/make_icon.py --input ./assets/miku_idle.png
```

默认生成 `src/AppIcon.iconset/` 和 `src/AppIcon.icns`。可使用 `--output-dir` 更换输出目录，使用 `--preview` 指定可选预览图的输出位置。该脚本需要 macOS 的 `iconutil`；生成的 ICNS 不等于 Windows ICO。

## Windows 所需资源

`windows-app/assets/` 是独立资源副本；根目录资源不会自动同步。按以下结构准备文件：

- 顶层使用 `standard`、`chibi`、`crayon` 三个前缀和上述五个状态，共 15 张 PNG。标准版从根目录的 `miku_*.png` 对应到 `standard_*.png`，另外两版分别对应 `chibi_*.png`、`crayon_*.png`。
- `animation/`：复制生成的 15 张图集和 `manifest.json`。
- `mouths/`：复制生成的 75 张口型图及 `manifest.json`。
- `sounds/`：放置 `voice_01.m4a` 至 `voice_10.m4a`，对应已准备的十段本地音频。
- 打包所需图标放在 `windows-app/app.ico`，使用自行拥有使用权的有效 ICO 文件。

资源准备完成后再执行 `npm start`、`npm run smoke` 或 `npm run build:win`。原来的本机资源仍在原目录，因此本次公开范围调整不会删除本机桌宠素材。

## 导出可公开的代码包

在项目根目录运行：

```sh
python3 src/export_source.py
```

输出为 `dist/MikuDeskPet-source.zip`。脚本使用明确的代码和文档白名单，不执行 Git，不加入本机路径元数据、素材、安装包、依赖、备份或测试输出。新增公开文件时需审查后更新脚本中的 `PUBLIC_FILES`。

导出包只解决本次已识别文件的公开范围，不等于对后续代码变更或第三方权利的自动认证。请勿把整个工作目录直接压缩上传；本机保留的历史文件不属于公开源码包。
