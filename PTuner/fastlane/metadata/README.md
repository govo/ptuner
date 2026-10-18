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
