# PTuner

面向音乐爱好者与专业音乐人的专业调音器应用，同时支持 iOS 与 macOS。

产品支持单音调音、多音同时调音、和弦识别以及自定义调弦，目标是在保持专业调音设备级视觉反馈的同时，提供简洁、直观的操作体验。

完整产品需求见 [doc/PR.md](doc/PR.md)。

## 产品定位

- 平台：iOS / macOS
- 核心场景：快速、准确地完成乐器调音
- 视觉语言：专业调音单块、机架式调音设备与现代数字音频软件
- 交互目标：打开即可调音，常用调弦快速切换，复杂配置集中管理

## 核心功能

1. 单音调音：检测单个音高，显示音名、频率与音准偏差。
2. 多音调音：同时检测多个音高，分别显示各音的音准状态。
3. 和弦识别：识别当前演奏的和弦并显示和弦名称与组成音。
4. 乐器调音：根据所选乐器及调弦方式显示对应的目标音高。
5. 自由调音：不限定乐器与弦数，识别任意音高。
6. 自定义调弦：创建、编辑、保存任意弦数与音高的调弦配置。
7. 乐器管理：管理内置乐器、自定义调弦与收藏。
8. 专业设置：参考音高、显示精度、指示器样式、稳定度与音频输入设备。
9. Pro 状态：展示当前权益、订阅类型、有效期及恢复购买入口。

## 页面结构

| 页面 | 作用 |
| --- | --- |
| 调音器主页 | 核心操作页，集音准可视化、乐器选择与多音控制于一体 |
| 乐器选择页面 | 按分类与收藏快速切换乐器及调弦 |
| 乐器管理页面 | 管理内置调弦、自定义调弦与收藏 |
| 自定义调弦编辑页面 | 设置名称、弦数、每根弦的音高与音分偏移 |
| 设置页面 | 参考音高、显示精度、稳定度、音频输入与 Pro 信息 |
| Pro 信息页面 | 展示权益状态、升级入口与恢复购买 |
| 音频输入设备选择页面 | macOS 下选择 Core Audio 输入设备 |

调音器主页是核心页面，用户应能在此直接完成调音，不需要频繁进入其他页面。

## 调音模式

### 单音调音

以大型音准指示器为主要视觉元素，显示当前音名、频率、音准偏差与指针或动态指示条。音准偏低时指示器向左偏移，偏高时向右偏移，接近目标音准时给出明确的绿色反馈。

选择具体乐器时，按该乐器的调弦配置显示目标音，并在检测到某根弦时自动突出对应弦位。自由调音模式下则不限定乐器与目标弦。

### 多音调音

同时展示多个检测到的音高，每个音高拥有独立的音名、频率、偏差与状态指示器。布局随检测音数自动调整。用户可设置最大同时检测音数，界面最多展示该数量的有效结果。

选择乐器时优先按该乐器的目标调弦顺序排列；自由调音模式下按音高由低到高排列。

### 和弦识别

作为独立显示模式，实时展示识别到的和弦名称、组成音与识别状态。无法确定和弦时显示等待识别或未识别状态，不强制输出错误和弦。

## 跨平台适配

macOS 与 iOS 保持一致的功能结构与视觉语言，并针对桌面操作进行适配：

- 主界面可使用更宽布局，多音检测结果可横向排列。
- 乐器选择与设置可采用侧边栏或弹出面板。
- 提供清晰的 Core Audio 输入设备选择与不可用提示。
- 窗口缩放时自动调整音准指示器布局，重要信息始终可见。

## 视觉与交互原则

- 优先采用深色界面，强调高对比度、易读性与弱光环境可用性。
- 音准正确使用绿色；存在偏差使用黄色或橙色；偏差较大使用红色；选中状态与主要交互使用青色。
- 颜色不是唯一判断依据，需结合位置、数字与其他视觉状态。
- 调音优先：打开应用即可开始调音。
- 状态明确：始终可见当前乐器、调弦方式与多音状态。
- 模式一致：单音、多音与和弦识别使用统一视觉语言。
- 专业但不复杂：普通用户可直接使用，高级用户可进一步调整参数。

## 当前工程状态

已完成工程初始化与基础服务集成：

- iOS + macOS 多平台 Xcode 工程，部署目标 27.0。
- 引导页 / 落地页、网络与隐私说明页。
- RevenueCat 内购管理、全局付费墙与 Pro 入口。
- 设置页组件、应用评分提示。
- Sentry 崩溃上报、埋点与诊断统一出口。
- 深色主题与调音器主页占位界面。
- 调音器核心模块：麦克风采集、CREPE 单音检测、Basic Pitch 多音检测与 `TunerController` 可观察封装。

待后续迭代实现：

- 和弦识别算法。
- 调音器界面与音高曲线绘制。
- 乐器、调弦与收藏的数据模型及持久化。
- 乐器选择、乐器管理、自定义调弦编辑等页面。
- macOS Core Audio 输入设备选择。

当前多音调音与和弦识别入口使用 Pro 占位逻辑，最终 Pro 功能范围由产品确定。

## 项目结构

```text
ptuner/
├── .gitignore
├── README.md
├── doc/
│   └── PR.md                    产品需求文档
└── PTuner/
    ├── PTuner.xcodeproj         Xcode 工程
    └── PTuner/
        ├── App/
        │   ├── PTunerApp.swift  应用入口、Sentry 与全局环境
        │   ├── RootView.swift   引导页分流与付费墙挂载
        │   ├── AppConfig.swift  服务配置（占位值集中于此）
        │   ├── AppTheme.swift   全局主题色
        │   ├── AppAnalytics.swift  埋点统一出口
        │   └── AppDiagnostics.swift  诊断与面包屑
        ├── Core/
        │   └── Tuner/
        │       ├── Audio/       麦克风采集与双采样率重采样
        │       ├── CREPE/       单音音高模型、解码与常数
        │       ├── Polyphonic/  Basic Pitch 多音模型、后处理与滑窗追踪
        │       ├── TunerEngine.swift      实时分析引擎
        │       ├── TunerController.swift  可观察状态封装
        │       ├── TunerModels.swift      对外数据模型
        │       └── CoreMLModelLocator.swift
        ├── Features/
        │   ├── Onboarding/      引导页
        │   └── Settings/        设置页
        ├── Resources/
        │   └── Models/          Crepe / BasicPitch 模型与许可说明
        ├── ContentView.swift    调音器主页占位
        └── Assets.xcassets
```

## 调音器核心

核心模块不依赖任何界面，界面层只需持有 `TunerController`：

```swift
@StateObject private var tuner = TunerController()

var body: some View {
    VStack(spacing: 12) {
        Text(tuner.liveNoteName ?? "--")
        Text(tuner.liveCents.map { String(format: "%+.1f cents", $0) } ?? "等待声音")
        Text(tuner.liveStatusText)
        Button(tuner.isRunning ? "停止" : "开始") { tuner.toggle() }
        Toggle("多音识别", isOn: Binding(
            get: { tuner.polyphonicEnabled },
            set: { tuner.setPolyphonicEnabled($0) }
        ))
    }
}
```

分工：

- `MicrophoneAudioCapture`：AVAudioEngine 采集，重采样为 CREPE 需要的 16 kHz 与 Basic Pitch 需要的 22050 Hz，音频时间轴由采样计数推导。
- `TunerEngine`：CREPE 50 ms 流式推理产出连续音高与音分；Basic Pitch 2 秒滑窗产出复音音符。
- `TunerController`：主线程状态、权限、启停、多音开关与展示用平滑，全部通过 `@Published` 暴露。

CREPE 的模型输入为 1024 采样（64 ms 窗）、hop 160（10 ms），因此单音通道约有 100 ms 延迟；Basic Pitch 输入固定 2 秒，多音结果天然有约 2 秒延迟，这是模型结构决定的。

模型包位于 `PTuner/PTuner/Resources/Models`。按工程 `.gitignore` 策略，`*.mlpackage` 不入库；clone 后需要从参考工程或 `core_ml` 母本复制 `Crepe.mlpackage` 与 `BasicPitch.mlpackage`，否则 App 可编译但运行时会报模型加载失败。

## 开发与构建

### 环境要求

- Xcode 27 或更高版本
- iOS 27.0 / macOS 27.0 部署目标
- Swift Package Manager

### 依赖

远程依赖：

- [sentry-cocoa](https://github.com/getsentry/sentry-cocoa)

本地公共包（需与 `ptuner` 目录同级存放）：

- `swift_landing`：OnboardingFlowKit，引导页与落地页
- `swift_settings`：AppSupportKit，设置组件与评分提示
- `my_revenue_cat`：RevenueCatPaywallKit，内购与付费墙

目录关系示例：

```text
cursor/
├── ptuner/
├── swift_landing/
├── swift_settings/
└── my_revenue_cat/
```

### 构建

打开 `PTuner/PTuner.xcodeproj`，选择 `PTuner` scheme 后运行，或使用命令行：

```bash
# iOS 模拟器
xcodebuild -project PTuner/PTuner.xcodeproj \
  -scheme PTuner \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  build

# macOS
xcodebuild -project PTuner/PTuner.xcodeproj \
  -scheme PTuner \
  -configuration Debug \
  -destination 'generic/platform=macOS' \
  build
```

## 配置

RevenueCat、Sentry 与法律链接当前使用占位值，统一放在：

`PTuner/PTuner/App/AppConfig.swift`

发布前需要替换：

- `RevenueCat.entitlementID`
- `RevenueCat.apiKeyDebug` / `RevenueCat.apiKeyRelease`
- `RevenueCat.offeringID`
- `Sentry.dsn`（留空则跳过 Sentry 初始化）
- `privacyPolicyURL` / `termsOfUseURL`

## 开发原则

- 以用户操作流程组织页面与功能。
- 保持调音器主页简洁，复杂配置放在乐器管理与设置页面。
- 所有调弦配置使用一致的展示方式。
- 单音、多音与和弦识别之间的切换应清晰。
- 高级功能不得影响基础调音体验。
- 所有可见按钮、开关与入口必须具备明确功能。
- 不添加 PRD 未定义的复杂功能；未明确的行为先确认，不自行扩大范围。
