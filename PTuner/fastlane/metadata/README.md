# PTuner 商店元数据

此目录用于存放 PTuner 自己的 App Store 商店文案，目录结构遵循 `deliver` 约定：

```
metadata/
  en-US/
    description.txt
    keywords.txt
    name.txt
    promotional_text.txt
    release_notes.txt
    subtitle.txt
    support_url.txt
    marketing_url.txt
    privacy_url.txt
  zh-Hans/
    ...
```

注意：

- 当前目录为空，尚未从 App Store Connect 下载任何文案。
- 不要从 SplitJam 项目复制 `metadata`，两个 App 的商店文案不同。
- `fastlane ios download_metadata` 可以把 ASC 上现有文案下载回来，但下载会覆盖同名文件，执行前先确认。
- 上传元数据用 `fastlane ios upload_metadata`，该 lane 只上传文案，不会改动截图。

## EULA 段落（必填，App Review 3.1.2）

PTuner 含自动续期订阅，App Review 3.1.2 要求商店描述里必须能直接看到服务协议链接。
每个语言的 `description.txt` 末尾都必须保留这段（含前面的空行）：

```
服务条款（EULA）
本应用依据 Apple 标准最终用户许可协议（EULA）授权使用：
https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
```

- URL 统一用 Apple 官方原文，不要换成自建页面。
- iOS 与 macOS 共用本目录，改一次两个平台同时生效。
- `Fastfile` 里的 `upload_metadata` / `upload_metadata_macos` / `sync_app_store_metadata`
  上传前会校验该链接，任一语言缺失会直接报错并中止上传。
