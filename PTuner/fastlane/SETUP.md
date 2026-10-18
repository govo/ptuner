# PTuner Fastlane 配置说明

`README.md` 由 fastlane 自动生成，不要手工编辑；本文件记录项目相关的固定配置。

## 固定标识

| 项目 | 值 |
| --- | --- |
| App Store Connect App ID | `6824013425` |
| Bundle ID | `online.c1c1.ptuner` |
| Development Team | `9RRNVTE2RE` |

不要使用同账号下 SplitJam 的 `6765638522` / `online.c1c1.stems`。

## 支持页面

隐私政策、服务协议与技术支持页面托管在 GitHub Pages：

| 页面 | 地址 |
| --- | --- |
| 隐私政策 | https://govo.github.io/jeremy-metronome-privacy/ptuner/privacy.html |
| 服务协议 | https://govo.github.io/jeremy-metronome-privacy/ptuner/terms.html |
| 技术支持 | https://govo.github.io/jeremy-metronome-privacy/ptuner/support.html |

页面源码位于 `metronome_jerry/support/jeremy-metronome-privacy/ptuner/`。ASC 中 App 信息的隐私政策 URL 与各版本本地化的支持网址均使用上述地址。

## 凭据

Fastlane 通过 App Store Connect API Key 访问 ASC，需要以下环境变量：

```bash
export APP_STORE_CONNECT_ISSUER_ID="..."
export APP_STORE_CONNECT_KEY_ID="..."
export APP_STORE_CONNECT_KEY_FILEPATH="/path/to/AuthKey_XXXXXXXXXX.p8"
```

本机可直接加载已有配置：

```bash
set -a; source ~/.app_store_connect/.env; set +a
```

`~/.appstoreconnect.env` 中的 `APPLE_ID` / `AC_PASSWORD` 只供 `build_appstore.sh` 上传使用，与 API Key 是两套凭据。

## 本机代理

本机开启了全局代理（127.0.0.1:7897），且 DNS 返回 fake-IP。Ruby 的 Faraday 不会自动读取系统代理，直连会报 `SSL_connect ... unexpected eof`。运行任何访问 ASC 的 Fastlane 命令前需要：

```bash
export SPACESHIP_PROXY=http://127.0.0.1:7897
```

如果代理对 `api.appstoreconnect.apple.com` 返回 `SSL_ERROR_SYSCALL`，换代理节点或临时改走直连即可；这属于本机网络问题，不是 Fastlane 配置问题。

## 发版约束

- 默认只上传二进制；商店元数据与截图必须显式开启。
- 截图与预览默认不删除 ASC 上已有内容，只有显式传 `overwrite: true` 才会整集覆盖。
- `fastlane/metadata` 与 `fastlane/screenshots` 目前为空。PTuner 的商店文案必须单独准备，不要从 SplitJam 复制。

## 常用 lane

```bash
# 列出所有 lane
fastlane lanes

# 校验本地元数据，不上传
fastlane ios precheck_metadata

# 只上传元数据（不动截图）
fastlane ios upload_metadata

# 上传截屏（默认不覆盖已有）
fastlane ios upload_screenshots
fastlane ios upload_screenshots overwrite:true

# 上传构建
fastlane ios upload_build ipa:"/path/to/PTuner.ipa"

# 上传构建并提交审核（默认不带元数据与截图）
fastlane ios release ipa:"/path/to/PTuner.ipa"
fastlane ios release ipa:"/path/to/PTuner.ipa" with_metadata:true with_screenshots:true

# 创建 / 补齐 PTuner Pro 三个付费点
fastlane ios create_pro_products
fastlane ios create_pro_products dry_run:true

# 查看订阅组与订阅
fastlane ios list_subscriptions
```

## PTuner Pro 付费点

`create_pro_products` lane 调用 `scripts/pro_products.rb`，可重复执行：

| 类型 | Product ID | 价格 |
| --- | --- | --- |
| 非消耗型（一次买断） | `online.c1c1.ptuner.pro.lifetime` | 9.99 USD |
| 自动续期订阅（年付） | `online.c1c1.ptuner.pro.yearly` | 4.99 USD / 年 |
| 自动续期订阅（周付） | `online.c1c1.ptuner.pro.weekly` | 0.99 USD / 周 |

年付与周付位于同一个订阅组 `PTuner Pro`。脚本会：

- 创建缺失的产品与订阅组；
- 为每个产品写入 `zh-Hans` 与 `en-US` 本地化；
- 为订阅组写入 9 种语言的显示名称（挂在订阅组版本上）；
- 设置美国基准价，并按 Apple 的 equalizations 补齐其余地区价格；
- 已存在的产品、本地化、价格会跳过，不会覆盖。

订阅组显示名称（App Store 订阅管理页中用户看到的名字）：

| Locale | 名称 |
| --- | --- |
| `en-US` / `de-DE` / `es-ES` / `fr-FR` / `it` | `PTuner Pro` |
| `zh-Hans` | `PTuner 专业版` |
| `zh-Hant` | `PTuner 專業版` |
| `ja` | `PTuner プロ版` |
| `ko` | `PTuner 프로` |

只补订阅组本地化时执行：

```bash
fastlane ios update_pro_subscription_group_localizations
```

三个产品目前在 ASC 中都是 `MISSING_METADATA` 状态。要让它们可以提交审核，还需要在 ASC 上传每个产品的审核截图。

## 打包脚本

仓库根目录的 `build_appstore.sh` 负责并行构建 iOS 与 macOS 并上传 App Store：

```bash
./build_appstore.sh            # 构建并上传两个平台
./build_appstore.sh local      # 仅本地构建 macOS 版本
```

上传账号读取 `~/.appstoreconnect.env` 中的 `APPLE_ID` 与 `AC_PASSWORD`。
