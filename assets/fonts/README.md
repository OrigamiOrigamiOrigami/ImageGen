# 内嵌字体说明

ImageGen 使用 **本地 TTF**，不联网拉字。`pubspec.yaml` 里 `family` 须与 `AppTypography.family` 一致。

## 当前默认：MiSans（推荐）

| 特点 | 说明 |
|------|------|
| 风格 | 无衬线，笔画偏圆、现代 |
| 中英文 | 简中 + 拉丁都很好 |
| 授权 | 小米 HyperOS 字体，**可免费商用**（见官网协议） |
| 下载 | https://hyperos.mi.com/font/download |

解压后复制到本目录（`pubspec.yaml` 已登记）：

| 文件名 | 字重 |
|--------|------|
| `MiSans-Regular.ttf` | 400 |
| `MiSans-Medium.ttf` | 500 |
| `MiSans-Semibold.ttf` | 600 |

```powershell
cd d:\work\shengtu\imagegen_flutter
flutter pub get
flutter run -d windows
```

---

## 其它「圆滑无衬线 + 中英文」备选

若 MiSans 仍不喜欢，可换下面任一套（均需自行下载 TTF 并改 `pubspec` + `AppTypography.family`）：

| 字体 | 气质 | 下载 |
|------|------|------|
| **HarmonyOS Sans SC** 鸿蒙 Sans | 与 MiSans 接近，略更「系统 UI」 | https://github.com/Huawei/HarmonyOS-Sans |
| **阿里巴巴普惠体 3** | 友好、略圆，偏产品宣传感 | https://www.alibabafonts.com |
| **得意黑 Smiley Sans** | 圆角很明显、有个性 | https://github.com/atelier-anchor/smiley-sans |
| **霞鹜新晰黑** LXGW Neo XiHei | 开源、柔和黑体，耐看 | https://github.com/lxgw/LxgwNeoXiHei |

不太符合「圆滑」但中英文极好：**思源黑体 / Noto Sans SC**（更中性、偏办公）。

---

## 切换字体步骤

1. 把 `.ttf` 放进本目录  
2. 修改 `pubspec.yaml` 的 `family` 与 `asset` 路径  
3. 修改 `lib/theme/app_typography.dart` 的 `AppTypography.family`  
4. `flutter pub get` 后 **大写 R** 热重启

## 版权

请勿将未授权字体提交公开仓库（`*.ttf` 已在 `.gitignore` 忽略）。
