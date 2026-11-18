#!/bin/bash
# PTuner App Store 原始截图工具（iPhone Duo / 折叠态外屏）。
#
# 纯脚本采集：一张图 = 一次 `simctl launch`（启动参数决定场景与 tab）
# + 一段固定等待 + 一次 `simctl io screenshot`。
# 不模拟点击、不发 UI 事件、不用 osascript，可重复、可批量、可跨语言。
#
# 截图语义等同模拟器窗口上的「截图」按钮：只取当前点亮屏幕的 framebuffer，
# 不叠机身边框、不补挖孔 / 灵动岛 / 摄像头开孔、不裁剪、不合成。
#
# 依赖 App 的 DEBUG 构建里 ScreenshotDemo.swift 提供的启动参数：
#   -screenshotScene single|multi|library|custom|chord
#   -screenshotTab   tuner|chord|instruments|settings
# 语言经 UserDefaults["ptuner.language"] + AppleLanguages/AppleLocale 注入，
# 与 L10n.effectiveCode 的解析顺序一致。
#
# 用法：
#   ./tools/duo-shot.sh status                    # 看设备、App、注入能力
#   ./tools/duo-shot.sh capture                   # 全语言 × 全场景采集
#   ./tools/duo-shot.sh capture zh-Hans           # 只跑一种语言
#   ./tools/duo-shot.sh capture en single         # 只跑一张
#
# 可覆写环境变量：
#   DM_UDID=...        指定设备（缺省自动找 iPhone Duo）
#   DM_OUT=...         输出目录（缺省 doc/screenshots-raw/duo）
#   DM_STATUS_BAR=0    不统一状态栏（缺省统一成 9:41 / 满格）
#   DM_KEEP_LAUNCHED=1 采集结束后不 terminate App
set -u

BUNDLE="online.c1c1.ptuner"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${DM_OUT:-$ROOT/doc/screenshots-raw/duo}"
# 折叠外屏的唯一合法尺寸；展开内屏是 2007×2853。
FOLDED_W=1398
FOLDED_H=2034

# ---------- 设备 ----------

find_udid() {
  local udid="${DM_UDID:-}"
  if [ -z "$udid" ]; then
    udid=$(xcrun simctl list devices available | grep -F "    iPhone Duo (" | \
      sed -E 's/.*\(([0-9A-Fa-f-]{36})\).*/\1/' | head -1)
  fi
  printf '%s' "$udid"
}

require_device() {
  UDID="${UDID:-$(find_udid)}"
  if [ -z "$UDID" ]; then
    echo "! 找不到 iPhone Duo 模拟器。" >&2
    exit 1
  fi
  local state
  state=$(xcrun simctl list devices | grep -F "$UDID" | sed -E 's/.*\((Booted|Shutdown|Booting)\).*/\1/')
  if [ "$state" != "Booted" ]; then
    echo "! iPhone Duo 未启动（当前 $state）。先在 Simulator 里启动它，再跑本脚本。" >&2
    exit 1
  fi
}

app_path() {
  xcrun simctl get_app_container "$UDID" "$BUNDLE" app 2>/dev/null
}

# 截图能力靠 -screenshotScene 启动参数触发。Debug 构建的真实代码在
# <App>.debug.dylib 里，主可执行只是 stub，因此两个都要查。
has_harness() {
  local app
  app=$(app_path) || return 1
  find "$app" -maxdepth 1 -type f \( -name "*.dylib" -o -perm -111 \) \
    -exec grep -l "screenshotScene" {} \; 2>/dev/null | head -1 | grep -q .
}

# 折叠态只有外屏在渲染。逐块试截，挑「竖屏 1398×2034 且非纯黑」的那块。
# 展开态下内屏是 2007×2853，会被这里判定为「不是折叠外屏」而直接拒绝。
pick_display() {
  local id tmp w h bytes dims
  for id in 1 2 3 4; do
    tmp="$(mktemp -u).png"
    if ! xcrun simctl io "$UDID" screenshot --display="$id" --type=png "$tmp" >/dev/null 2>&1; then
      rm -f "$tmp"; continue
    fi
    w=$(sips -g pixelWidth "$tmp" 2>/dev/null | awk '/pixelWidth/{print $2}')
    h=$(sips -g pixelHeight "$tmp" 2>/dev/null | awk '/pixelHeight/{print $2}')
    bytes=$(stat -f %z "$tmp" 2>/dev/null || echo 0)
    rm -f "$tmp"
    dims="${w}x${h}"
    if [ "$dims" = "${FOLDED_W}x${FOLDED_H}" ] && [ "$bytes" -gt 60000 ]; then
      DISPLAY_ID="$id"
      return 0
    fi
    echo "  · 跳过屏幕 ${id}（${dims}，${bytes}B）"
  done
  return 1
}

# 状态栏统一成「9:41 / 满格」，避免每张图时间电量都不一样。
status_bar_override() {
  [ "${DM_STATUS_BAR:-1}" = "0" ] && return 0
  xcrun simctl status_bar "$UDID" override \
    --time "9:41" \
    --dataNetwork wifi --wifiMode active --wifiBars 3 \
    --cellularMode active --cellularBars 4 \
    --batteryState charged --batteryLevel 100 >/dev/null 2>&1 || true
}

status_bar_clear() {
  [ "${DM_STATUS_BAR:-1}" = "0" ] && return 0
  xcrun simctl status_bar "$UDID" clear >/dev/null 2>&1 || true
}

# 一次性标记 onboarding 已完成，避免落到 LandingView 引导页。
ensure_onboarded() {
  xcrun simctl spawn "$UDID" defaults write "$BUNDLE" hasCompletedOnboarding -bool true >/dev/null 2>&1 || true
}

# ---------- 场景与语言 ----------

# 场景|tab|短名|启动后等待秒数
# tab 由源码确认：single/multi -> tuner，library/custom -> instruments，chord -> chord
SLOTS=(
  "single|tuner|single|10"
  "multi|tuner|multi|10"
  "library|instruments|library|10"
  "custom|instruments|custom|14"
  "chord|chord|chord|10"
)

# 输出目录名:App 内的语言 code（与 L10n.supportedCodes 一致）
LOCALES=("en:en" "zh-Hans:zh-Hans" "zh-Hant:zh-Hant" "ja:ja" "ko:ko" "de:de" "es:es" "fr:fr" "it:it")

# SF Symbols 里有少数符号按**系统语言**本地化（例如 textformat 在中文下渲染成「格式」）。
# 只切 App 内语言会出现「英文界面里冒出一枚中文图标」，所以同时把进程的
# AppleLanguages / AppleLocale 钉到同一语言。
apple_locale_for() {
  case "$1" in
    en)      echo "en en_US" ;;
    zh-Hans) echo "zh-Hans zh_CN" ;;
    zh-Hant) echo "zh-Hant zh_TW" ;;
    ja)      echo "ja ja_JP" ;;
    ko)      echo "ko ko_KR" ;;
    es)      echo "es es_ES" ;;
    de)      echo "de de_DE" ;;
    fr)      echo "fr fr_FR" ;;
    it)      echo "it it_IT" ;;
    *)       echo "$1 $1" ;;
  esac
}

shoot() {
  local dest="$1" w h bytes
  rm -f "$dest"
  if ! xcrun simctl io "$UDID" screenshot --display="$DISPLAY_ID" --type=png "$dest" >/dev/null 2>&1 \
    && [ ! -f "$dest" ]; then
    # 刚启动时模拟器偶发拿不到 framebuffer，隔 2 秒重试一次即可。
    sleep 2
    xcrun simctl io "$UDID" screenshot --display="$DISPLAY_ID" --type=png "$dest" >/dev/null 2>&1
  fi
  if [ ! -f "$dest" ]; then
    echo "  ! 截图命令失败（已重试）：$dest" >&2
    return 1
  fi
  w=$(sips -g pixelWidth "$dest" 2>/dev/null | awk '/pixelWidth/{print $2}')
  h=$(sips -g pixelHeight "$dest" 2>/dev/null | awk '/pixelHeight/{print $2}')
  bytes=$(stat -f %z "$dest" 2>/dev/null || echo 0)
  if [ "$bytes" -lt 60000 ]; then
    echo "  ! 疑似黑帧（${bytes}B）：$dest" >&2
    return 1
  fi
  if [ "${w}x${h}" != "${FOLDED_W}x${FOLDED_H}" ]; then
    echo "  ! 尺寸 ${w}x${h} 不符合期望 ${FOLDED_W}x${FOLDED_H}：${dest}" >&2
    return 1
  fi
  echo "  ${w}x${h}  ${bytes}B"
}

# 一次采集 = terminate → 写语言默认值 → launch（带场景/tab/语言参数）→ 等固定时长 → 抓外屏。
capture_one() {
  local locale="$1" lang="$2" scene="$3" tab="$4" wait="$5" dest="$6"
  local apple_lang apple_locale
  read -r apple_lang apple_locale <<<"$(apple_locale_for "$lang")"

  xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1
  sleep 1
  # L10n.effectiveCode 优先读 UserDefaults["ptuner.language"]，再回退系统语言。
  xcrun simctl spawn "$UDID" defaults write "$BUNDLE" ptuner.language "$lang" >/dev/null 2>&1 || true

  echo "→ $locale / $scene"
  xcrun simctl launch "$UDID" "$BUNDLE" \
    -screenshotScene "$scene" \
    -screenshotTab "$tab" \
    -AppleLanguages "($apple_lang)" \
    -AppleLocale "$apple_locale" >/dev/null 2>&1 || {
    echo "  ! 启动失败：$scene" >&2
    return 1
  }
  sleep "$wait"
  shoot "$dest"
}

# ---------- 子命令 ----------

cmd_status() {
  echo "设备      : $(find_udid)"
  UDID="${UDID:-$(find_udid)}"
  if [ -z "$UDID" ]; then echo "设备      : 未找到 iPhone Duo"; return; fi
  echo "设备状态  : $(xcrun simctl list devices | grep -F "$UDID" | sed -E 's/.*\((Booted|Shutdown|Booting)\).*/\1/')"
  if app_path >/dev/null 2>&1; then
    echo "App       : $(app_path)"
    echo "版本      : $(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$(app_path)/Info.plist" 2>/dev/null) ($(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$(app_path)/Info.plist" 2>/dev/null))"
    echo "带注入能力 : $(has_harness && echo yes || echo no)"
  else
    echo "App       : 未安装"
  fi
}

cmd_capture() {
  require_device
  if ! has_harness; then
    echo "! 已安装的 App 不带截图注入能力，请用带 ScreenshotDemo 的 Debug 构建。" >&2
    exit 1
  fi

  DISPLAY_ID=""
  echo "设备：iPhone Duo（${UDID}）"
  if ! pick_display; then
    echo "! 没有找到折叠外屏（${FOLDED_W}x${FOLDED_H} 竖屏）。" >&2
    echo "  iPhone Duo 需处于【折叠态】再截图；展开态下外屏不渲染，只能截到内屏。" >&2
    exit 1
  fi
  echo "屏幕：${DISPLAY_ID}（折叠外屏 ${FOLDED_W}x${FOLDED_H} 竖屏）"

  ensure_onboarded
  status_bar_override

  local only_locale="${1:-}" only_scene="${2:-}" fail=0
  local pair locale lang entry scene tab name wait dest
  for pair in "${LOCALES[@]}"; do
    locale="${pair%%:*}"; lang="${pair##*:}"
    if [ -n "$only_locale" ] && [ "$only_locale" != "$locale" ]; then continue; fi
    mkdir -p "$OUT/$locale"
    for entry in "${SLOTS[@]}"; do
      IFS='|' read -r scene tab name wait <<< "$entry"
      if [ -n "$only_scene" ] && [ "$only_scene" != "$scene" ]; then continue; fi
      dest="$OUT/$locale/$scene.png"
      capture_one "$locale" "$lang" "$scene" "$tab" "$wait" "$dest" || fail=$((fail + 1))
    done
  done

  status_bar_clear
  if [ -z "${DM_KEEP_LAUNCHED:-}" ]; then
    xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1
  fi
  if [ "$fail" -gt 0 ]; then
    echo "完成，但有 $fail 张失败。" >&2
    exit 2
  fi
  echo "全部完成：$OUT"
}

case "${1:-status}" in
  status)  cmd_status ;;
  capture) shift; cmd_capture "$@" ;;
  *)
    sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
