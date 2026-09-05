# ImageGen (Flutter)

AI 图片生成桌面客户端，由 Electron 版迁移而来。支持 Windows（主平台），亦可扩展 Android。

## 功能

- 多 API 配置（grsai / OpenAI 兼容 / Gemini 兼容）
- GPT Images、Nano Banana 等模型与 SSE 流式进度
- 历史图片网格、灯箱预览、复制到剪贴板
- 参考图上传 / 拖放 / 粘贴
- 5 套主题、并发任务队列
- 无边框窗口（最小化 / 最大化 / 关闭）
- 自动迁移 Electron 版 `%APPDATA%\imagegen-origami\config.json`

## 环境要求

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.22+（推荐 3.35+）
- Windows 10/11，已启用「桌面开发」工作负载

## 首次初始化

在项目目录执行：

```powershell
cd d:\work\shengtu\imagegen_flutter

# 若还没有 windows/ 等平台目录，先生成：
flutter create . --org com.origami --project-name imagegen --platforms=windows,android

flutter pub get
```

## 运行（开发）

```powershell
flutter run -d windows
```

## 打包

详细说明（绿色版 / 单文件 exe / 安装包 / 更新日志）见 **[说明.md](说明.md)**。

快速命令：

```powershell
flutter build windows --release          # 标准 Release 文件夹
.\tool\build_portable.ps1                # 绿色版（文件夹 + zip）
.\tool\build_single.ps1                  # 单文件 exe（推荐便携）
.\tool\build_installer.ps1               # Setup 安装包（需 Inno Setup）
```

标准 Release 输出：`build\windows\x64\runner\Release\`

## 配置与数据目录

详见 [说明.md](说明.md#数据与配置目录)。摘要：

| 项目 | 路径 |
|------|------|
| 主配置 | `%APPDATA%\com.origami.imagegen\config.json` |
| 历史（按周） | `%APPDATA%\com.origami.imagegen\history\` |
| Electron 旧配置 | `%APPDATA%\imagegen-origami\`（首次启动可自动迁移） |
| 生成图片 | 配置中的 `imagesDir`，默认在应用数据下的 `images\` |

## 项目结构

```
lib/
  main.dart              # 入口、无边框窗口
  models/app_models.dart # 类型定义
  services/              # 配置、API、图片、任务队列
  themes/app_themes.dart # 主题色
  screens/home_screen.dart
  widgets/               # UI 组件
```

## 与 Electron 版差异

- 剪贴板复制图片：Windows 下通过 PowerShell `Set-Clipboard -Path` 实现
- 无边框窗口使用 `window_manager` 插件
- UI 为 Flutter Material 自绘，视觉与 Web 版接近但非像素级一致

原 Electron 项目仍保留在仓库根目录，可并行使用直至完全切换。
