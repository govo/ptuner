# PTuner 上线检查清单

- 基线日期：2026-10-17
- Bundle ID：`online.c1c1.ptuner`
- Bundle 显示名：`PTuner`
- 工程版本：1.0（Build 1）
- 工程部署目标：iOS 18.6 / macOS 15.6
- 工程声明平台：iphoneos、iphonesimulator、macosx、xros、xrsimulator
- 设备族：iPhone、iPad、visionOS（`TARGETED_DEVICE_FAMILY = 1,2,7`）
- 标记说明：`P0` 表示提交 TestFlight 或 App Store 审核前必须完成；`P1` 表示首发前应完成；`P2` 表示可首发后迭代。

> 本文基于 2026-10-17 对仓库的实际扫描结果整理，不是通用模板。随着工程变化，完成项请勾选并补充备注。

---

## 一、当前 P0 阻塞项（不解决无法正常提审）

### 1. App 图标
- [ ] `PTuner/PTuner/Assets.xcassets` 中只有 `AccentColor.colorset`，没有 `AppIcon.appiconset`，当前构建会使用系统默认空白图标。
- [ ] 设计或生成 1024x1024 主图标，放入 AppIcon 资源集。
- [ ] 检查 iOS 26 及以上系统的图标变体（浅色、深色、着色）是否需要提供。
- [ ] 检查 macOS 图标规格（16、32、128、256、512 及 @2x）是否齐全。
- [ ] 在真机桌面、设置页、App Store Connect 预览中确认图标无透明通道、无圆角、无文字裁切。
- [ ] 如首发 visionOS，补充 visionOS 图标规格。

### 2. 隐私清单
- [ ] 工程中没有 `PrivacyInfo.xcprivacy`。
- [ ] 添加 App 级隐私清单，声明 UserDefaults 等 Required Reason API（本工程大量使用 `UserDefaults`，至少需要 `NSPrivacyAccessedAPICategoryUserDefaults`）。
- [ ] 如使用了文件时间戳、磁盘空间等其他 Required Reason API，逐项声明。
- [ ] 检查 Sentry、RevenueCat 等第三方 SDK 自带的隐私清单与签名是否随 SPM 产物进入 App。
- [ ] 在 Xcode 中执行 Privacy Report，确认所有 App 与第三方 SDK 的隐私清单均已收集。
- [ ] 清单内容必须与 App Store Connect 的隐私问卷一致。

### 3. 服务配置仍是占位值
- [ ] `PTuner/PTuner/App/AppConfig.swift` 中 `RevenueCat.apiKeyDebug` / `apiKeyRelease` 仍是 `test_PLACEHOLDER` / `appl_PLACEHOLDER`。
- [ ] `AppConfig.Sentry.dsn` 为空，当前线上不会上报崩溃。
- [ ] 如使用 Sentry，需要创建正式项目并填入 DSN。
- [ ] 确认 Sentry 的 dSYM 上传流程；当前工程没有 Run Script 上传阶段，崩溃堆栈将无法符号化。
- [ ] 确认 Sentry 关闭 PII、设置合理的采样与告警，避免收集不必要信息。

### 4. 法律链接仍是占位值
- [ ] `AppConfig.privacyPolicyURL` 仍指向 `https://example.com/privacy`。
- [ ] `AppConfig.termsOfUseURL` 仍指向 `https://example.com/terms`。
- [ ] 隐私政策、用户协议必须部署为可公开访问的正式页面，且可在中国大陆正常访问（如面向中国大陆）。
- [ ] 为 App Store Connect 准备 Support URL、隐私政策 URL，可选 Marketing URL。
- [ ] 准备可用的支持邮箱，并在应用内“关于我们”或设置页展示。

### 5. Pro 功能边界与门控未落地
- [ ] 引导页文案已声称“多音调音与和弦识别为 Pro 功能”“自定义调弦为 Pro 功能”，但代码中 `ProGatedButton` 目前没有任何调用点，所有功能实际都可免费使用。
- [ ] 由产品确认最终免费/Pro 边界：单音调音、多音调音、和弦识别、自定义调弦、最大复音数、参考音高、显示精度等分别属于哪一档。
- [ ] 按确认结果在所有入口统一使用 `ProAccessController.isPro` 进行门控，不能只改 UI 文案。
- [ ] 确认 Debug 跳过权益开关在 Release 构建中确实不生效（当前由 `#if DEBUG` 保证，但仍需在 Release 真机验证）。
- [ ] 确认付费墙在引导结束后的自动弹出是否保留，以及是否符合 App Review 对订阅类 App 的要求。

### 6. 模型文件与依赖的可复现构建
- [ ] `.gitignore` 忽略了 `*.mlpackage/`，`Crepe.mlpackage`（约 42 MB）与 `BasicPitch.mlpackage`（约 272 KB）不在仓库中；全新 clone 后 App 可编译但运行时会模型加载失败。
- [ ] 决定模型分发方案：Git LFS、发布前脚本下载、私有制品库，或评估体积后改为入库。
- [ ] 确保发布机 / CI 上一定有这两个模型，并写入打包流程检查。
- [ ] 三个本地 SPM 包 `swift_landing`、`swift_settings`、`my_revenue_cat` 位于仓库之外（相对路径 `../../`），换机器或 CI 会直接构建失败。
- [ ] 决定依赖策略：迁入仓库、使用 Git 远程包、使用子模块，或明确记录发布机的目录约定。
- [ ] 确认 `Package.resolved` 已入库并锁定 Sentry / RevenueCat 版本。

### 7. 工程可交付性
- [ ] 当前工作区有未提交改动：`MicrophoneAudioCapture.swift`、`CustomTuningEditorView.swift`、`PolyStringSectionView.swift`、`TunerHomeView.swift`、`project.pbxproj`，以及未跟踪的 `TonePlayer.swift`、`PianoKeyboard88View.swift`。
- [ ] 完成功能自测后分批提交，确保提交历史可回溯。
- [ ] 工程没有共享 Scheme（只有 `xcuserdata` 下的用户级 scheme），建议添加并提交 `PTuner.xcscheme`，保证 CI 与其他机器可直接 `xcodebuild -scheme PTuner`。
- [ ] 确认 Bundle ID 变更后，开发者后台已注册 `online.c1c1.ptuner` App ID，Xcode 自动签名可正常生成描述文件。
- [ ] 确认 `DEVELOPMENT_TEAM = 9RRNVTE2RE` 对应账号具有发布权限，且证书未过期。

### 8. 首发平台范围
- [ ] 工程当前声明支持 iOS、iPadOS、macOS、visionOS，但 README 只描述 iOS / macOS，且代码中大量 `#if os(macOS)` 分支。
- [ ] 明确首发平台：建议先确认 iOS + iPadOS 与 macOS 是否同时首发。
- [ ] 如不发 visionOS，移除 `xros` / `xrsimulator` 与设备族 7，避免提交未经验证的平台。
- [ ] 如发 visionOS，补充空间布局适配、图标、截图与真机测试。
- [ ] 如发 macOS，确认 Mac App Store 上架、沙盒权限、窗口尺寸、Core Audio 输入设备切换均经过测试。

---

## 二、工程与构建收尾（P0 / P1）

### 1. 构建配置
- [ ] 关闭或移除仅开发使用的调试入口（Debug 跳过 Pro、调试日志、`print`）。
- [ ] 检查 Release 构建的 `SWIFT_ACTIVE_COMPILATION_CONDITIONS`，确保没有误开 DEBUG。
- [ ] 补充 `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO`（若仅使用系统 HTTPS，不涉及自定义加密），或在 App Store Connect 首次提交时选择豁免。
- [ ] 确认 `MARKETING_VERSION` 与 `CURRENT_PROJECT_VERSION` 的发版规则：每次上传 App Store Connect 的 Build 号必须递增。
- [ ] 确认麦克风用途描述 `NSMicrophoneUsageDescription` 与实际用途一致：当前为“用于实时采集音频，进行音高检测与调音”。
- [ ] 检查 macOS 沙盒 entitlements：音频输入、网络客户端、用户选择文件只读是否有必要保留。
- [ ] 确认 App Groups 是否真正使用；未使用时避免保留无意义的配置。
- [ ] 检查 Bundle ID 变更后，是否还有代码、配置、文档、脚本引用旧 Bundle ID 或 `devplaceholder`。
- [ ] 更新 README：部署目标写的是 27.0，但工程实际是 iOS 18.6 / macOS 15.6；工程当前功能状态也已明显落后于代码。

### 2. 依赖与许可
- [ ] `Resources/BasicPitch-NOTICE.txt`、`Resources/CREPE-NOTICE.txt` 已存在，但应用内“关于我们”没有开源许可入口。
- [ ] 确认 BasicPitch、CREPE 及模型权重的许可证允许商业分发（Apache 2.0 / MIT 等），并核对 NOTICE 原文是否需要完整保留。
- [ ] 在设置或关于页增加“开源许可”页面，列出 Sentry、RevenueCat、BasicPitch、CREPE 等组件与许可证。
- [ ] 确认 Sentry、RevenueCat 的许可与隐私条款允许当前商业模式。
- [ ] 若使用其他图标、字体、音频素材，逐项记录来源与授权方式。

### 3. 发布流程
- [ ] 决定使用 Xcode Organizer 还是 fastlane 做打包上传，并固定流程。
- [ ] 若使用 fastlane，建议建立 `fastlane/` 目录并锁定 lane；截图目录已按 `.gitignore` 预留。
- [ ] 准备一个可重复执行的发布检查脚本或文档：清理、归档、校验、上传、dSYM 上传。
- [ ] 归档后使用 Xcode Validate App 或 Transporter 校验，确认无缺失图标、隐私清单、签名问题。
- [ ] 备份 App Store Connect 元数据（描述、关键词、截图、IAP 配置）。

---

## 三、功能完成度与产品决策（P0 / P1）

### 1. 产品决策必须先定
- [ ] 免费与 Pro 的功能边界。
- [ ] 商业模式：自动续订订阅、终身买断，或两者并存。
- [ ] 订阅周期与价格：月付、年付、终身；是否提供免费试用或首购优惠。
- [ ] 首发地区：中国大陆、海外、全球。
- [ ] 首发语言：仅简体中文，还是同时提供英文。
- [ ] App Store 主分类：当前 `public.app-category.utilities`，调音器更贴近 Music，需要确认。
- [ ] App 名称、副标题与关键词最终文案。
- [ ] 是否首发 macOS / iPad / visionOS。
- [ ] 是否需要在 App 内展示版本更新说明或新功能提示。

### 2. 核心调音功能
- [ ] 单音调音：音名、频率、cents 偏差、指针/音准条、绿色达标状态在真机上连续稳定。
- [ ] 多音调音：最多 12 音设置下的布局、排序、延迟提示、误检过滤。
- [ ] 和弦识别：识别、未识别、等待三种状态清晰，不输出错误和弦。
- [ ] 自由调音与乐器调弦切换时，目标弦高亮与状态是否同步。
- [ ] 参考音高 400–480 Hz 对所有模式生效，并有边界值测试。
- [ ] 显示精度（整数 / 0.1 cents）持久化正确。
- [ ] 显示稳定度（快速 / 平衡 / 稳定）切换后平滑系数生效。
- [ ] 麦克风权限：首次请求时机合理；拒绝后有明确说明与“前往系统设置”入口。
- [ ] 无麦克风、麦克风被占用、输入设备断开时有可理解的状态提示。
- [ ] 音频中断恢复：来电、其他 App 播放、锁屏、切后台、拔插耳机、蓝牙耳机切换。
- [ ] 不同采样率设备（44.1 kHz / 48 kHz）下音高与音分仍准确。
- [ ] 长时间运行（30 分钟以上）无内存持续增长、无明显发热与掉帧。
- [ ] 低电量模式、后台切换、系统音频会话被抢占后的恢复行为。

### 3. 音叉发声与钢琴键盘
- [ ] 新增的 `TonePlayer.swift` 与 `PianoKeyboard88View.swift` 尚未提交，先完成功能确认。
- [ ] 发声与麦克风采集同时使用时，AVAudioSession 类别与模式是否正确，是否产生回授、音量突变或采集中断。
- [ ] 播放时是否会影响调音检测（自激、误判），需要真机音箱与耳机分别验证。
- [ ] 88 键键盘的横向滚动、点击命中区域、滑奏、多指、快速切换是否稳定。
- [ ] 蓝牙耳机延迟、静音开关、系统音量、后台播放行为是否符合预期。
- [ ] 发声结束后是否正确释放音频会话，避免抢占其他 App 音频。

### 4. 乐器与自定义调弦
- [ ] 内置乐器与调弦数据的音名、八度、MIDI 编号全部核对。
- [ ] 自定义调弦：名称长度、空名称、重复名称、弦数上下限、音高范围、cents 偏移边界。
- [ ] 编辑已有调弦、删除调弦、取消编辑、保存后立即使用等流程完整。
- [ ] 收藏、取消收藏、排序与持久化正确。
- [ ] 升级安装后旧 `UserDefaults` 数据可正常解码；未来数据模型变更需要版本化或迁移方案。
- [ ] 删除自定义调弦时若正被选中，回退到有效调弦而不是空白状态。
- [ ] 乐器搜索的拼音、大小写、空结果状态。

### 5. 设置与关于
- [ ] 设置项修改后立即生效并持久化，重启 App 后保持。
- [ ] “恢复购买”在无网络、无购买记录、已购买、订阅过期等场景下提示准确。
- [ ] 管理订阅链接可在真机打开。
- [ ] 关于页版本号读取正确，显示为 1.0 (Build 1)。
- [ ] 评分提示阈值（3 次完成、10 天冷却）符合预期，可重置测试。
- [ ] 提供“重置引导 / 清除本地数据”的调试方式（不一定要面向用户）。

### 6. 引导与首次体验
- [ ] 首次启动引导完整走通，跳过、返回、最后一页完成行为一致。
- [ ] 引导页关于 Pro、隐私、网络的文案与最终产品策略一致。
- [ ] 引导结束后自动弹付费墙是否保留；若保留，确保免费用户可以正常关闭并继续使用。
- [ ] 第二次启动不再显示引导。
- [ ] 引导中的“设备端处理”“不上传音频”等承诺与实际网络行为一致。

---

## 四、隐私、合规与法律（P0）

### 1. 隐私政策内容
- [ ] 明确说明麦克风音频仅在本机用于实时音高检测，不录制、不上传、不保存。
- [ ] 列出实际会联网的 SDK：Sentry（崩溃与诊断）、RevenueCat（订阅与权益）、App Store。
- [ ] 列出收集的数据类型、用途、保存期限、第三方接收方。
- [ ] 说明 RevenueCat 生成的匿名 App User ID、购买记录的处理方式。
- [ ] 提供用户行使查询、删除、撤回同意权利的渠道。
- [ ] 说明儿童隐私政策与年龄分级依据。
- [ ] 如面向中国大陆，补充个人信息保护相关条款、SDK 清单、权限清单与数据出境说明。

### 2. App Store 隐私问卷
- [ ] 麦克风：确认是否“收集”。若仅在设备端实时处理且不上传，通常不作为收集，但需与隐私政策保持一致。
- [ ] 购买记录：RevenueCat 会处理购买与订阅状态，按实际情况声明。
- [ ] 诊断与崩溃数据：启用 Sentry 后需要声明。
- [ ] 标识符：RevenueCat / Sentry 使用的设备或用户标识需按实际声明。
- [ ] 确认不进行跨 App 跟踪，不接入 ATT，除非后续新增广告或归因 SDK。
- [ ] 第三方 SDK 数据收集需在问卷与隐私政策中同时体现。

### 3. 中国大陆合规（如在中国大陆上架）
- [ ] 确认 App 在中国大陆区 App Store 上架所需的 ICP 备案要求，并准备备案号。
- [ ] 首次启动在初始化 Sentry / RevenueCat 等联网 SDK 前取得用户同意，或提供“同意隐私政策后进入”的流程。
- [ ] 隐私政策中完整列出 SDK 名称、运营方、收集目的、收集信息类型、隐私政策链接。
- [ ] 权限申请前说明用途，不在用户同意前读取麦克风。
- [ ] 如涉及个人信息出境，完成相应合规评估与告知。
- [ ] 确认应用内没有未经审核的境外支付引导或其他不合规内容。

### 4. 法律与协议
- [ ] 使用 Apple 标准 EULA，或提供自有使用条款并在 App Store Connect 填写链接。
- [ ] 自动续订订阅必须在付费墙或 App 内明确展示：订阅名称、时长、价格、自动续订说明、取消方式、隐私政策与使用条款链接。
- [ ] 确认“恢复购买”入口始终可用。
- [ ] 确认价格展示使用 StoreKit / RevenueCat 返回的本地化价格，不硬编码。
- [ ] 准备版权声明与商标使用说明。

---

## 五、测试与质量验证（P1）

### 1. 功能测试矩阵
- [ ] iPhone 小屏（SE 级）与大屏（Pro Max 级）布局无裁切、无遮挡。
- [ ] iPad 竖屏、横屏、分屏、台前调度布局正常。
- [ ] macOS 最小窗口 860x620、默认窗口、全屏、多显示器。
- [ ] iOS 18.6、macOS 15.6 及当前最新系统版本各测一轮。
- [ ] 至少覆盖一台较旧设备，确认模型推理性能可接受。
- [ ] 深色模式与浅色模式；本 App 以深色为主，但系统弹窗、键盘、分享面板仍会受系统外观影响。
- [ ] 动态字体放大到最大级别时关键信息仍可读、按钮可达。
- [ ] VoiceOver：调音指针、音名、音分、按钮是否需要辅助标签与动态播报。
- [ ] 减弱动态效果、增强对比度设置下的表现。
- [ ] 横竖屏旋转时调音状态不丢失。
- [ ] 冷启动、热启动、后台恢复耗时。
- [ ] 首次模型加载耗时与加载失败提示。

### 2. 异常与边界
- [ ] 无网络启动、弱网、断网重连时的 UI 状态。
- [ ] RevenueCat 初始化失败时免费功能仍可用，付费入口提示合理。
- [ ] Sentry DSN 为空或不可达时不影响启动。
- [ ] 麦克风权限被拒绝、被系统回收、在设置中被关闭后返回 App。
- [ ] 存储空间不足、UserDefaults 写入失败时的兜底。
- [ ] 系统语言、地区、24 小时制、数字格式差异。
- [ ] 后台挂起、系统杀进程后重新打开的状态恢复。

### 3. 内购测试（沙盒）
- [ ] 新用户首次购买订阅成功，权益立即生效。
- [ ] 取消购买、支付失败、网络中断后重试。
- [ ] 订阅到期、续订、退款后权益状态正确。
- [ ] 恢复购买在有记录与无记录两种情况下都提示明确。
- [ ] 升级、降级、跨产品切换，以及终身权益与订阅并存的显示。
- [ ] 同一 Apple ID 多设备同步权益。
- [ ] 家庭共享（如启用）验证。
- [ ] Debug 跳过权益开关在 Release 包中不存在且不生效。
- [ ] 付费墙关闭后免费功能不受影响。

### 4. 发布前回归
- [ ] 所有可见按钮、开关、入口都有明确功能，没有空操作。
- [ ] 没有 “敬请期待”“占位”“PLACEHOLDER”“example.com” 等文案与链接。
- [ ] 所有页面无截断、重叠、闪烁、错位。
- [ ] 崩溃率为 0 的 TestFlight 构建才提交审核。
- [ ] 在飞行模式下完整走查免费调音流程（首次启动、调音、设置、自定义调弦）。

---

## 六、App Store Connect 与账号配置（P0 / P1）

### 1. 账号与协议
- [ ] 确认 Apple Developer Program 会员有效。
- [ ] 签署 Paid Applications Agreement（如包含内购或付费下载）。
- [ ] 完成税务信息与银行账户信息。
- [ ] 确认团队角色具有 App Manager 或 Admin 权限。

### 2. App ID 与证书
- [ ] 在开发者后台注册 `online.c1c1.ptuner`。
- [ ] 确认无需额外 Capability；本 App 当前不依赖推送、登录、App Groups 等能力。
- [ ] 生成并验证 App Store 分发证书与描述文件。
- [ ] 清理本机重复或过期的签名证书。

### 3. App Store Connect 应用记录
- [ ] 创建新 App，Bundle ID 选择 `online.c1c1.ptuner`。
- [ ] 填写名称、副标题、主语言、SKU、版权。
- [ ] 选择主分类与次分类。
- [ ] 设置价格与销售范围。
- [ ] 完成年龄分级问卷。
- [ ] 完成内容版权声明。
- [ ] 完成 App 隐私问卷。
- [ ] 填写出口合规信息。
- [ ] 填写审核联系人信息与审核备注。
- [ ] 在审核备注中说明麦克风用途、音频仅在设备端处理、无账号体系、订阅如何测试。

### 4. 内购配置
- [ ] 在 App Store Connect 创建订阅组与产品，或创建非消耗型终身产品。
- [ ] 填写产品本地化名称、描述、价格、审核截图。
- [ ] 将产品状态设为“准备提交”，并随首个 App 版本一起提交审核。
- [ ] 在 RevenueCat 后台创建项目，Bundle ID 使用 `online.c1c1.ptuner`。
- [ ] 配置 App Store Connect API Key / 共享密钥。
- [ ] 创建 entitlement，确认 ID 与 `AppConfig.RevenueCat.entitlementID = "PTuner Pro"` 一致。
- [ ] 创建 Offering，确认 ID 与 `AppConfig.RevenueCat.offeringID = "default"` 一致。
- [ ] 将产品关联到 Offering 与 entitlement。
- [ ] 替换 Debug / Release API Key，并在沙盒环境完成购买与恢复购买验证。
- [ ] 配置 RevenueCat 的退款、续订、过期等 Webhook 或通知（如需要）。
- [ ] 确认订阅状态展示与 `ProInfoView` 的文案匹配。

### 5. 诊断与运营配置
- [ ] 创建 Sentry 项目，填入 DSN。
- [ ] 配置 dSYM 上传，验证崩溃堆栈可符号化。
- [ ] 配置崩溃率、卡顿、启动失败告警与通知渠道。
- [ ] 确认 Sentry 事件中不包含麦克风音频、完整个人信息或自定义调弦内容。
- [ ] 如需运营数据，确认 AppAnalytics 的事件命名与看板可用。

---

## 七、商店素材与元数据（P1）

### 1. 截图与预览
- [ ] iPhone 6.9 英寸截图（至少 3 张，建议 5–8 张）。
- [ ] iPhone 6.5 英寸截图（如 App Store Connect 仍要求）。
- [ ] iPad 13 英寸截图（如支持 iPad）。
- [ ] Mac 截图（如上架 Mac App Store，尺寸要求以 App Store Connect 实时提示为准）。
- [ ] visionOS 截图（如支持）。
- [ ] 截图内容覆盖：单音调音、多音调音、和弦识别、乐器选择、自定义调弦、设置/Pro。
- [ ] 截图无占位数据、无错误状态、无其他 App 图标、无侵权素材。
- [ ] 如需 App 预览视频，控制时长、尺寸与编码格式。
- [ ] 截图与预览的语言与首发语言一致。
- [ ] 注意：截图默认不重新上传、不删除；如已有素材，按具体发版需求逐项确认。

### 2. 文本元数据
- [ ] App 名称（30 字符以内）与副标题（30 字符以内）。
- [ ] 关键词（100 字符以内），避免堆砌竞品名与商标。
- [ ] 描述：首段说明核心价值，列出主要功能与 Pro 内容。
- [ ] 推广文本（可选，可随时更新）。
- [ ] 新功能说明（What's New）。
- [ ] 支持 URL、隐私政策 URL、营销 URL。
- [ ] 版权信息。
- [ ] 审核备注与演示说明。
- [ ] 如提供英文，准备英文元数据与本地化截图。
- [ ] 确认名称“PTuner”未被他人占用且不侵犯商标权。

---

## 八、打包、TestFlight 与审核（P0）

### 1. 归档与上传
- [ ] 使用 Release 配置归档 iOS 版本，确认无调试开关、无本机路径依赖。
- [ ] 如发 macOS，单独归档并校验 Mac App Store 分发。
- [ ] 归档前确认模型文件、Notice 文件、Assets 均进入 App 包。
- [ ] 检查 App 包体积；Crepe 模型约 42 MB，确认是否可接受，是否需要压缩或按需下载。
- [ ] 通过 Xcode Organizer 或 Transporter 上传构建。
- [ ] 上传后等待处理完成，检查 App Store Connect 是否提示缺少图标、隐私清单或出口合规信息。

### 2. TestFlight
- [ ] 内部测试：团队成员安装并完成核心流程。
- [ ] 外部测试：如需要，提交 Beta App Review，准备测试说明与联系方式。
- [ ] 测试内容覆盖购买、恢复购买、权限拒绝、音频中断、长时间运行。
- [ ] 收集崩溃、卡顿、耗电与误判反馈并修复。
- [ ] 确认测试用户不会被 Debug 跳过权益开关误导。

### 3. 提交审核
- [ ] 选择正确的构建版本。
- [ ] 确认内购产品已随版本提交。
- [ ] 确认隐私政策、使用条款、支持链接可访问。
- [ ] 填写审核备注，说明麦克风权限用途与订阅测试方式。
- [ ] 提交审核，预留至少 1–3 个工作日，首次审核可能更久。
- [ ] 准备被拒后的回复材料：录屏、说明文档、功能路径。
- [ ] 审核通过后选择发布方式：手动发布、自动发布或分阶段发布。

---

## 九、上线与上线后（P1 / P2）

### 1. 上线操作
- [ ] 确认发布日期与销售范围。
- [ ] 如采用分阶段发布，设置 7 天分阶段比例。
- [ ] 上线后 24 小时内监控崩溃率、购买成功率、评价与支持邮件。
- [ ] 准备紧急下架流程：从销售中移除、停止分阶段发布、提交修复版本。

### 2. 运营与维护
- [ ] 配置 App Store 评价提示，确认不会在调音过程中打扰用户。
- [ ] 准备常见问题与支持回复模板。
- [ ] 监控 Sentry 崩溃与卡顿告警。
- [ ] 监控 RevenueCat 的试用转化、续订、退款与恢复购买数据。
- [ ] 定期检查隐私政策与实际 SDK 行为是否一致。
- [ ] 建立 1.0.1 热修复流程：分支、版本号、构建号、提审、加速审核申请条件。

### 3. 后续规划
- [ ] 收集用户反馈，评估是否需要英文、更多乐器、更多调弦、节拍器等功能。
- [ ] 评估模型精度与延迟优化（尤其多音调音的约 2 秒延迟）。
- [ ] 评估自定义调弦的导入导出与 iCloud 同步需求。
- [ ] 评估是否加入账号体系；当前无账号，删除账号要求不适用。

---

## 十、需要产品/负责人拍板的决策

按优先级排列，建议在开始商店素材与内购配置前全部确认：

1. 首发平台：iOS + iPad 是否与 macOS 同时上线；visionOS 是否首发。
2. 首发地区：是否包含中国大陆；若包含，ICP 备案与隐私同意流程是否启动。
3. 商业模式：订阅、终身买断或两者；价格与试用策略。
4. 免费与 Pro 的功能边界，以及现有引导文案是否调整。
5. 首发语言：仅简体中文，还是中英双语。
6. App Store 主分类：Utilities 还是 Music。
7. App 正式名称与副标题是否就是 PTuner。
8. 发布方式：手动发布还是分阶段发布。

---

## 十一、建议执行顺序

### 第 1 周：收尾与配置
1. 提交当前未完成代码，完成 TonePlayer 与 88 键键盘自测。
2. 补齐 App 图标、隐私清单、共享 Scheme。
3. 确定首发平台、地区、Pro 边界与商业模式。
4. 落实模型与本地 SPM 包的可复现构建方案。

### 第 2 周：合规与服务
1. 上线隐私政策、使用条款、支持页面与支持邮箱。
2. 替换 RevenueCat、Sentry 配置，完成沙盒购买验证。
3. 完成 App Store Connect App 记录、隐私问卷、内购产品配置。
4. 补齐开源许可页与出口合规信息。

### 第 3 周：测试与素材
1. 完成真机功能矩阵、音频异常场景、内购场景回归。
2. 制作各平台截图与商店文案。
3. 归档并上传首个 TestFlight 构建，开始内部测试。

### 第 4 周：提审与上线
1. 修复 TestFlight 问题，确认崩溃率达标。
2. 提交审核并准备回复材料。
3. 审核通过后发布，按分阶段策略观察 7 天。
4. 上线后监控崩溃、购买、评价与支持邮件。

---

## 附：本次扫描确认的事实

- `PTuner/PTuner.xcodeproj/project.pbxproj`：Bundle ID 已改为 `online.c1c1.ptuner`，显示名已设为 `PTuner`。
- `PTuner/PTuner/Assets.xcassets`：仅有 `AccentColor.colorset`，无 `AppIcon.appiconset`。
- 工程中未发现 `PrivacyInfo.xcprivacy`、`Localizable.strings`、`*.xcstrings`、`*.storekit`。
- 工程只有一个 App target，无测试 target，无共享 Scheme。
- `AppConfig.swift`：RevenueCat Key、Sentry DSN、隐私政策与使用条款 URL 均为占位值。
- `ProAccessController.swift`：Debug 有跳过权益开关，Release 恒为 false。
- `ProGatedButton.swift` 已定义，但全工程没有调用点。
- `.gitignore` 忽略 `*.mlpackage/`；`Crepe.mlpackage` 约 42 MB，`BasicPitch.mlpackage` 约 272 KB。
- 三个本地 SPM 包位于仓库外：`../swift_landing`、`../swift_settings`、`../my_revenue_cat`。
- `Resources` 中已有 `BasicPitch-NOTICE.txt` 与 `CREPE-NOTICE.txt`，但应用内没有许可展示入口。
