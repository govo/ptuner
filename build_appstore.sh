#!/bin/bash
set -euo pipefail

# ============================================================
# PTuner - 并行构建 + 自动上传 App Store
# ============================================================

show_help() {
    echo ""
    echo -e "${BOLD}用法:${NC}"
    echo "  ./build_appstore.sh [选项] [版本号] [build号]"
    echo "  ./build_appstore.sh local [版本号] [build号]"
    echo ""
    echo -e "${BOLD}参数:${NC}"
    echo "  版本号              指定 MARKETING_VERSION (默认读取 Xcode 项目)"
    echo "  build号             指定 CURRENT_PROJECT_VERSION (默认自动 +1)"
    echo ""
    echo -e "${BOLD}构建模式:${NC}"
    echo "  local              构建本地 macOS .app（开发签名，直接运行）"
    echo "                      可省略 -p 参数，自动仅构建 macOS"
    echo "  -i, --incremental  增量构建：保留 DerivedData 编译缓存，跳过源码扩展属性"
    echo "                      清理，加速重复打包；版本号和 Build 仍会正常更新"
    echo "  -u, --upload-only  仅上传：跳过构建（archive/export/productbuild），"
    echo "                      基于现有标记文件直接重试上传。需先完整跑过一次。"
    echo ""
    echo -e "${BOLD}上传选项:${NC}"
    echo "  -r, --retry <次数>  上传失败时自动重试次数（默认 3，0 表示不重试）"
    echo "                      仅对网络/服务端瞬时错误生效，BUILD 冲突不计入"
    echo ""
    echo -e "${BOLD}平台选项:${NC}"
    echo "  -p, --platform <目标>  指定构建平台: ios | macos | all (默认: all)"
    echo "  -h, --help             显示此帮助"
    echo ""
    echo -e "${BOLD}示例:${NC}"
    echo "  ./build_appstore.sh                  # 全平台构建, 自动 +1 build"
    echo "  ./build_appstore.sh -p ios           # 仅 iOS"
    echo "  ./build_appstore.sh -p macos 1.4.0   # 仅 macOS, 指定版本号"
    echo "  ./build_appstore.sh 1.4.0 150        # 全平台, 指定版本号和 build"
    echo "  ./build_appstore.sh -p ios 1.4.0 150 # 仅 iOS, 指定版本号和 build"
    echo "  ./build_appstore.sh local            # 本地 macOS 构建 (开发签名)"
    echo "  ./build_appstore.sh local 1.4.0      # 指定版本号"
    echo "  ./build_appstore.sh -i               # 增量构建（保留缓存，版本号/Build 仍更新）"
    echo "  ./build_appstore.sh -u -r 5          # 仅重试上传，自动重试最多 5 次"
    echo "  ./build_appstore.sh -u               # 仅重试上传，使用默认重试次数 3"
    echo ""
    echo -e "${BOLD}前置条件:${NC} ~/.appstoreconnect.env（local 模式不需要）"
    echo '  APPLE_ID="你的AppleID@邮箱"'
    echo '  AC_PASSWORD="xxxx-xxxx-xxxx-xxxx"'
    echo ""
}

# ---- 平台选项解析 ----
PLATFORM="all"
INCREMENTAL=false
UPLOAD_ONLY=false
RETRY=3
POSITIONAL=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--platform)
            PLATFORM="${2:-}"
            if [[ -z "$PLATFORM" || ! "$PLATFORM" =~ ^(ios|macos|all)$ ]]; then
                # 颜色变量尚未定义, 先设置临时值
                RED='\033[0;31m' NC='\033[0m'
                echo -e "${RED}错误: --platform 参数必须是 ios、macos 或 all${NC}"
                exit 1
            fi
            shift 2
            ;;
        -i|--incremental)
            INCREMENTAL=true
            shift
            ;;
        -u|--upload-only)
            UPLOAD_ONLY=true
            shift
            ;;
        -r|--retry)
            RETRY="${2:-}"
            if [[ -z "$RETRY" || ! "$RETRY" =~ ^[0-9]+$ ]]; then
                # 颜色变量尚未定义, 先设置临时值
                RED='\033[0;31m' NC='\033[0m'
                echo -e "${RED}错误: --retry 参数必须是非负整数${NC}"
                exit 1
            fi
            shift 2
            ;;
        -h|--help)
            # 颜色变量尚未定义, 先设置临时值
            BOLD='\033[1m' RED='\033[0;31m' NC='\033[0m'
            show_help
            exit 0
            ;;
        *)
            POSITIONAL+=("$1")
            shift
            ;;
    esac
done

set -- "${POSITIONAL[@]+"${POSITIONAL[@]}"}"

# upload-only 模式不接受位置参数（不重新打包，版本号/BUILD 由现有产物决定）
if $UPLOAD_ONLY && [ ${#POSITIONAL[@]} -gt 0 ]; then
    # 颜色变量尚未定义, 先设置临时值
    YELLOW='\033[1;33m' NC='\033[0m'
    echo -e "${YELLOW}警告: --upload-only 模式忽略位置参数 (${POSITIONAL[*]})${NC}"
    POSITIONAL=()
    set --
fi

# ---- Local 模式 ----
LOCAL_MODE=false
if [ "${1:-}" = "local" ]; then
    LOCAL_MODE=true
    shift
fi

PROJECT_DIR="$(cd "$(dirname "$0")/PTuner" && pwd)"
PROJECT="$PROJECT_DIR/PTuner.xcodeproj"
SCHEME="PTuner"
APP_BUNDLE_ID="online.c1c1.ptuner"

# Ctrl+C 时确保所有子进程全部终止，不留孤儿进程
cleanup() {
    echo ""
    echo "[cleanup] 终止所有构建进程 ..."
    # 杀掉本进程组内所有进程（包括后台 xcodebuild/altool/productbuild）
    kill -TERM 0 2>/dev/null
    sleep 1
    # 如果还有残留，强制杀掉
    pkill -9 -P $$ 2>/dev/null
    pkill -9 -f "xcodebuild.*PTuner" 2>/dev/null
    pkill -9 -f "altool.*PTuner" 2>/dev/null
    pkill -9 -f "productbuild.*PTuner" 2>/dev/null
    wait 2>/dev/null
    echo "[cleanup] 已终止"
    # 打印已进行到的阶段（中断时让用户清楚进展到哪步）
    if [ -n "${SCRIPT_START_EPOCH:-}" ]; then
        local elapsed=$(( $(date +%s) - SCRIPT_START_EPOCH ))
        echo ""
        echo "[cleanup] 已运行 $(format_duration $elapsed), 在 ${SCRIPT_START_HUMAN} 启动"
        [ "${BUILD_START_EPOCH:-0}" -gt 0 ] && echo "[cleanup] 构建阶段已开始 (但不完整)"
        [ "${BUILD_END_EPOCH:-0}" -gt 0 ] && echo "[cleanup] 构建阶段已结束"
        [ "${UPLOAD_START_EPOCH:-0}" -gt 0 ] && echo "[cleanup] 上传阶段已开始"
    fi
}
trap cleanup INT TERM

# 隔离不兼容工具：xcodebuild 内部某些步骤依赖 macOS 原生工具链，
# Homebrew 安装的 rsync 等 GNU 版本不兼容 Apple 扩展参数（如 -E），导致构建失败。
# 把 Homebrew 目录放在 PATH 后段：系统 bin 优先（rsync 等仍走 macOS 原版），
# 但 sentry-cli（仅在 Homebrew）也能被 Xcode 的 Run Script 找到，从而把 dSYM 推到 Sentry。
# 参考: https://developer.apple.com/forums/thread/705329
_ORIG_PATH="$PATH"
cleanup_path() { export PATH="$_ORIG_PATH"; }
trap 'cleanup_path' EXIT
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

log()  { echo -e "${CYAN}[$(date +%H:%M:%S)]${NC} $*"; }
ok()   { echo -e "${GREEN}[$(date +%H:%M:%S)] ✓${NC} $*"; }
warn() { echo -e "${YELLOW}[$(date +%H:%M:%S)] ⚠${NC} $*"; }
fail() { echo -e "${RED}[$(date +%H:%M:%S)] ✗${NC} $*"; }

# 把秒数格式化为可读时长 (例如 1h23m04s / 5m12s / 47s)
format_duration() {
    local secs=$1
    if ! [[ "$secs" =~ ^[0-9]+$ ]]; then echo "${secs}s"; return; fi
    if [ $secs -ge 3600 ]; then
        printf "%dh%02dm%02ds" $((secs/3600)) $((secs%3600/60)) $((secs%60))
    elif [ $secs -ge 60 ]; then
        printf "%dm%02ds" $((secs/60)) $((secs%60))
    else
        printf "%ds" $secs
    fi
}

# analyze_upload_error <日志文件>
#   根据 altool 输出分析错误类型并填充以下全局变量：
#     ERROR_KIND       network | apple_service | auth | build_conflict | unknown
#     ERROR_SUMMARY    一句话错误总结
#     ERROR_REASON     详细原因说明
#     ERROR_SUGGESTION 处理建议
analyze_upload_error() {
    local logfile="$1"
    ERROR_KIND="unknown"
    ERROR_SUMMARY="未知错误"
    ERROR_REASON="未能从日志中匹配已知错误模式"
    ERROR_SUGGESTION="完整日志请见 $logfile"

    [ ! -f "$logfile" ] && { ERROR_REASON="日志文件不存在: $logfile"; return; }

    # 1) BUILD 冲突（最优先 — 已是独立处理流程，但仍记录原因便于诊断）
    if is_build_conflict "$logfile"; then
        ERROR_KIND="build_conflict"
        ERROR_SUMMARY="BUILD 数值已被 App Store Connect 占用"
        ERROR_REASON="你此次上传的 CFBundleVersion 在 ASC 上已经被使用或低于已存在的最大值。"
        ERROR_SUGGESTION="脚本已自动把 Xcode 项目的 BUILD 同步提升；请重新跑一次完整构建以生成新 BUILD 的 .ipa/.pkg。"
        return
    fi

    # 1.5) MARKETING_VERSION 冲突：CFBundleShortVersionString 必须高于已批准版本
    if is_version_conflict "$logfile"; then
        ERROR_KIND="version_conflict"
        local current_version=""
        local approved_version=""
        current_version=$(parse_version_conflict_current "$logfile")
        approved_version=$(parse_version_conflict_approved "$logfile")
        ERROR_SUMMARY="版本号 (CFBundleShortVersionString) 未高于 App Store Connect 已批准版本"
        if [ -n "$current_version" ] && [ -n "$approved_version" ]; then
            ERROR_REASON="你本次上传的版本号 ${current_version} 没有超过 ASC 上已批准的版本 ${approved_version}。"
            ERROR_SUGGESTION="将 MARKETING_VERSION 提升到高于 ${approved_version} 的值（如 ${approved_version}.1 或 $(next_patch_version "$approved_version")），然后重新构建上传。命令示例：\n  cd PTuner && agvtool new-marketing-version '$(next_patch_version "$approved_version")'\n或直接运行：\n  ./build_appstore.sh '$(next_patch_version "$approved_version")' ${BUILD_NUMBER}"
        else
            ERROR_REASON="Info.plist 中的 CFBundleShortVersionString 必须包含比之前已批准版本更高的版本号。"
            ERROR_SUGGESTION="提升 MARKETING_VERSION 后再重新构建上传。命令示例：\n  cd PTuner && agvtool new-marketing-version 'X.Y.Z'"
        fi
        return
    fi

    # 2) 鉴权失败
    if grep -qiE "(invalid credentials|authentication failed|invalid[[:space:]]*(username|password|token)|App-specific password.*invalid|not[[:space:]]+authorized|NOT_AUTHORIZED|JWT.*invalid|401[[:space:]]+(Unauthorized|Forbidden)|403[[:space:]]+Forbidden)" "$logfile" 2>/dev/null; then
        ERROR_KIND="auth"
        ERROR_SUMMARY="Apple ID 鉴权失败"
        ERROR_REASON="应用专用密码、JWT 或 Apple ID 无效/过期，altool 无法登录 App Store Connect。"
        ERROR_SUGGESTION="检查 ~/.appstoreconnect.env 的 APPLE_ID 和 AC_PASSWORD；如失效在 appleid.apple.com 重新生成专用密码（注意带空格）。"
        return
    fi

    # 3) 网络/TLS 错误
    if grep -qiE "(NSURLErrorDomain|kCFErrorDomainCFNetwork|TLS error|SSL error|secure connection.*(fail|fault)|Could not resolve host|connection[[:space:]]+(was lost|reset|refused|closed|failed)|Network is unreachable|Network request failed|request[[:space:]]+timed out|operation couldn't be completed)" "$logfile" 2>/dev/null; then
        ERROR_KIND="network"
        local net_code
        net_code=$(grep -oE "Code=[-]?[0-9]+" "$logfile" 2>/dev/null | head -1 | grep -oE "[-]?[0-9]+")
        case "${net_code:-}" in
            -1200) ERROR_SUMMARY="TLS 握手失败 (NSURLError -1200)"
                    ERROR_REASON="本机到 contentdelivery.itunes.apple.com 的 HTTPS 链路异常，常见于网络代理/VPN/防火墙阻断或证书链异常。"
                    ERROR_SUGGESTION="关闭 VPN/代理、检查系统日期时间、或在钥匙串中查看根证书是否被禁用；之后用 --upload-only --retry N 重试。" ;;
            -1001) ERROR_SUMMARY="连接超时 (NSURLError -1001)"
                    ERROR_REASON="altool 在限定时间内未能与服务端建立连接。"
                    ERROR_SUGGESTION="通常为网络抖动，等几分钟后用 --upload-only --retry N 重试。" ;;
            -1005) ERROR_SUMMARY="连接中断 (NSURLError -1005)"
                    ERROR_REASON="传输过程中连接被服务端或中间链路关闭。"
                    ERROR_SUGGESTION="多为网络瞬时问题，用 --upload-only --retry N 自动重试即可。" ;;
            -1009) ERROR_SUMMARY="无可用网络 (NSURLError -1009)"
                    ERROR_REASON="本地网络断开或 DNS 不可达。"
                    ERROR_SUGGESTION="检查 Wi-Fi/网线/VPN，等网络恢复后用 --upload-only --retry N 重试。" ;;
            -1202) ERROR_SUMMARY="证书链校验失败 (NSURLError -1202)"
                    ERROR_REASON="本机根证书无法验证苹果服务端的证书链。"
                    ERROR_SUGGESTION="在钥匙串访问中确认所有 Apple Root CA 证书未被禁用或标记为不可信。" ;;
            *)      ERROR_SUMMARY="网络错误 (NSURLError ${net_code:-?})"
                    ERROR_REASON="本机到 Apple 服务器的网络/HTTPS 链路异常，但未匹配到具体子类型。"
                    ERROR_SUGGESTION="等网络恢复后用 --upload-only --retry N 重试；持续失败请检查代理/VPN/系统日期。" ;;
        esac
        return
    fi

    # 4) 苹果业务错误 ITMS-*
    if grep -qiE "ERROR ITMS-[0-9]+" "$logfile" 2>/dev/null; then
        ERROR_KIND="apple_service"
        local itms_codes
        itms_codes=$(grep -oiE "ITMS-[0-9]+" "$logfile" 2>/dev/null | sort -u | tr '\n' ',' | sed 's/,$//')
        ERROR_SUMMARY="App Store Connect 业务校验失败 (${itms_codes})"
        local reason_list=""
        for code in $(echo "$itms_codes" | tr ',' ' '); do
            case "$code" in
                ITMS-90163|ITMS-90164) reason_list+="$code 证书/描述文件过期或无效；" ;;
                ITMS-90165)            reason_list+="$code 签名身份无效；" ;;
                ITMS-9089|ITMS-9087)   reason_list+="$code Info.plist 缺少必需键；" ;;
                ITMS-90682)            reason_list+="$code Info.plist 含非法键；" ;;
                ITMS-42210)            reason_list+="$code 应用图标缺失；" ;;
                ITMS-42211)            reason_list+="$code 应用启动图缺失；" ;;
                ITMS-42212)            reason_list+="$code Info.plist 字段类型错误；" ;;
                ITMS-42213)            reason_list+="$code 主版本号非法；" ;;
                ITMS-9080)             reason_list+="$code 包结构/解压/签名异常；" ;;
                ITMS-9000)             reason_list+="$code altool 通用错误；" ;;
                ITMS-4238)             reason_list+="$code BUILD 已被使用；" ;;
                ITMS-3170)             reason_list+="$code 启动图/截图缺失；" ;;
                *)                     reason_list+="$code 见 altool 详细日志；" ;;
            esac
        done
        ERROR_REASON="$reason_list"
        ERROR_SUGGESTION="多数 ITMS 错误需修复 Xcode 工程或账号配置后重新构建，单独重传无效。"
        return
    fi

    # 5) altool 自身失败（无 ITMS 编号）
    if grep -qiE "(altool.*error|product-archive.*failed|upload.*failed)" "$logfile" 2>/dev/null; then
        ERROR_KIND="unknown"
        ERROR_SUMMARY="altool 上传未完成（无明确错误码）"
        ERROR_REASON="altool 进程未返回成功结果，日志中无 ITMS 错误码。"
        ERROR_SUGGESTION="可能是 Apple 端临时故障，稍后用 --upload-only --retry N 重试；如持续失败需联系 Apple Developer Support。"
        return
    fi

    ERROR_REASON="日志中未匹配到已知错误模式。原始日志请见 $logfile。"
    ERROR_SUGGESTION="请把完整日志提供给开发者排查。"
}

# ---- 时间与统计变量 ----
SCRIPT_START_EPOCH=$(date +%s)
SCRIPT_START_HUMAN="$(date '+%Y-%m-%d %H:%M:%S')"
BUILD_START_EPOCH=0
BUILD_END_EPOCH=0
BUILD_DURATION=0
UPLOAD_START_EPOCH=0
UPLOAD_END_EPOCH=0
UPLOAD_DURATION=0
IOS_RESULT="未执行"
IOS_ATTEMPTS=0
IOS_DURATION=0
MAC_RESULT="未执行"
MAC_ATTEMPTS=0
MAC_DURATION=0

# 阶段汇总报告 — 在脚本末尾打印总用时/各阶段用时/各平台尝试次数与结果
print_summary_report() {
    local end_epoch=$(date +%s)
    local end_human="$(date '+%Y-%m-%d %H:%M:%S')"
    local total=$((end_epoch - SCRIPT_START_EPOCH))

    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║  阶段汇总                                                     ║${NC}"
    echo -e "${BOLD}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BOLD}║${NC}  脚本启动 : ${CYAN}${SCRIPT_START_HUMAN}${NC}"
    echo -e "${BOLD}║${NC}  脚本结束 : ${CYAN}${end_human}${NC}"
    echo -e "${BOLD}║${NC}  总用时   : ${CYAN}$(format_duration $total)${NC}"
    if [ $BUILD_DURATION -gt 0 ]; then
        echo -e "${BOLD}║${NC}  构建用时 : ${CYAN}$(format_duration $BUILD_DURATION)${NC}"
    fi
    if [ $UPLOAD_DURATION -gt 0 ]; then
        echo -e "${BOLD}║${NC}  上传用时 : ${CYAN}$(format_duration $UPLOAD_DURATION)${NC}  (含重试退避)"
    fi
    echo -e "${BOLD}╠══════════════════════════════════════════════════════════════╣${NC}"
    if $BUILD_IOS; then
        local ios_dur=""
        [ $IOS_DURATION -gt 0 ] && ios_dur=", 用时 $(format_duration $IOS_DURATION)"
        echo -e "${BOLD}║${NC}  iOS  : 尝试 ${CYAN}${IOS_ATTEMPTS}${NC} 次, 状态 ${CYAN}${IOS_RESULT}${NC}${ios_dur}"
    fi
    if $BUILD_MACOS; then
        local mac_dur=""
        [ $MAC_DURATION -gt 0 ] && mac_dur=", 用时 $(format_duration $MAC_DURATION)"
        echo -e "${BOLD}║${NC}  macOS: 尝试 ${CYAN}${MAC_ATTEMPTS}${NC} 次, 状态 ${CYAN}${MAC_RESULT}${NC}${mac_dur}"
    fi
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
}

# ---- 分支检测 ----
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
if [ "$CURRENT_BRANCH" = "local_releases" ] && ! $LOCAL_MODE; then
    echo ""
    echo -e "${YELLOW} 当前分支是 'local_releases'，此分支标记为本地构建/测试用途${NC}"
    echo -e "${YELLOW}  构建产物不会上传到 App Store Connect${NC}"
    echo ""
    read -p "$(echo -e ${BOLD}"是否继续本地构建? [y/N] "${NC})" -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}已取消${NC}"
        exit 1
    fi
fi

# ---- 认证 ----
if ! $LOCAL_MODE; then
    if [ -f "$HOME/.appstoreconnect.env" ]; then
        source "$HOME/.appstoreconnect.env"
    fi
    if [ -z "${APPLE_ID:-}" ] || [ -z "${AC_PASSWORD:-}" ]; then
        fail "缺少认证信息"
        echo "  创建 ~/.appstoreconnect.env:"
        echo '    APPLE_ID="你的AppleID"'
        echo '    AC_PASSWORD="xxxx-xxxx-xxxx-xxxx"'
        echo "  应用专用密码: https://appleid.apple.com"
        exit 1
    fi
else
    log "Local 模式：跳过 App Store Connect 认证检查"
fi

# ---- 版本 ----
# 使用 POSITIONAL 数组中的位置参数 (已被 set -- 重置)
XCODE_VERSION=$(xcodebuild -showBuildSettings -project "$PROJECT" -scheme "$SCHEME" 2>/dev/null | grep MARKETING_VERSION | head -1 | awk '{print $3}' || echo "")
XCODE_BUILD=$(xcodebuild -showBuildSettings -project "$PROJECT" -scheme "$SCHEME" 2>/dev/null | grep CURRENT_PROJECT_VERSION | head -1 | awk '{print $3}' || echo "")
VERSION="${1:-${XCODE_VERSION:-1.0.0}}"
BUILD_NUMBER="${2:-$XCODE_BUILD}"

if $UPLOAD_ONLY; then
    log "upload-only 模式：跳过版本号/BUILD 自动更新（使用 Xcode 项目当前值）"
else
    if [ -z "${2:-}" ]; then
        NEW_BUILD=$((BUILD_NUMBER + 1))
        log "自动递增 Build: $BUILD_NUMBER → $NEW_BUILD"
        cd "$PROJECT_DIR"
        agvtool new-version -all "$NEW_BUILD" > /dev/null 2>&1 || log "(agvtool 跳过，手动改也可)"
        cd - > /dev/null
        BUILD_NUMBER="$NEW_BUILD"
    fi
    if [ -n "${1:-}" ] && [ "$VERSION" != "$XCODE_VERSION" ]; then
        log "更新版本号: $XCODE_VERSION → $VERSION"
        cd "$PROJECT_DIR"
        agvtool new-marketing-version "$VERSION" > /dev/null 2>&1 || log "(agvtool 跳过)"
        cd - > /dev/null
    fi
fi

# ---- 平台开关 ----
$LOCAL_MODE && PLATFORM="macos" && log "Local 模式：仅构建 macOS"
BUILD_IOS=false
BUILD_MACOS=false

case "$PLATFORM" in
    ios)   BUILD_IOS=true ;;
    macos) BUILD_MACOS=true ;;
    all)   BUILD_IOS=true; BUILD_MACOS=true ;;
esac

BUILD_DIR="$PROJECT_DIR/build/AppStore"
CORES=$(sysctl -n hw.ncpu 2>/dev/null || echo 8)
JOBS=$((CORES / 2 - 1))
[ $JOBS -lt 2 ] && JOBS=2

log "清理旧构建产物 ..."
if $UPLOAD_ONLY; then
    log "upload-only 模式：保留所有构建产物与标记文件，不清理"
    # 兜底：确保 BUILD_DIR 存在（标记文件读取的前置条件）
    mkdir -p "$BUILD_DIR"
else
    # DerivedData 是编译缓存，incremental 模式下保留以加速增量编译
    if $INCREMENTAL; then
        log "incremental 模式：保留 DerivedData 编译缓存"
    else
        rm -rf "$PROJECT_DIR/build/DerivedData"
    fi
    # 清理旧的 xcarchive 和 Export 目录（输出产物，非编译缓存）
    rm -rf "$BUILD_DIR"/*.xcarchive
    rm -rf "$BUILD_DIR"/*-Export
    rm -rf "$BUILD_DIR"/*-Local
    rm -f  "$BUILD_DIR"/*_archive "$BUILD_DIR"/*_pkg "$BUILD_DIR"/ExportOptions-*.plist
fi

# 日志：每次构建写入 logs/current，成功删除，失败保留为 <时间>_FAILED
# upload-only 模式写入独立时间戳目录，保留 logs/current 历史日志便于回溯
if $UPLOAD_ONLY; then
    LOG_DIR="$BUILD_DIR/logs/upload-only-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$LOG_DIR"
    log "upload-only 日志目录: $LOG_DIR"
else
    LOG_DIR="$BUILD_DIR/logs/current"
    rm -rf "$LOG_DIR"
    mkdir -p "$LOG_DIR"
fi

if $UPLOAD_ONLY; then
    log "upload-only 模式：跳过源码扩展属性清理"
elif $INCREMENTAL; then
    log "incremental 模式：跳过源码扩展属性清理（首次全量构建已清除）"
else
    log "清除文件扩展属性 (com.apple.quarantine) ..."
    # 清除项目源码目录（包含 .mlpackage 等资源）
    xattr -cr "$PROJECT_DIR" 2>/dev/null || true
    # 清除 Models 目录（如有独立的模型文件）
    MODELS_DIR="$(dirname "$PROJECT_DIR")/Models"
    [ -d "$MODELS_DIR" ] && xattr -cr "$MODELS_DIR" 2>/dev/null || true
    ok "扩展属性已清除"
fi

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  PTuner  App Store  构建 + 上传          ║${NC}"
echo -e "${BOLD}╠══════════════════════════════════════════════╣${NC}"
echo -e "${BOLD}║${NC}  Version: ${GREEN}$VERSION${NC}   Build: ${GREEN}$BUILD_NUMBER${NC}"
echo -e "${BOLD}║${NC}  平台: ${GREEN}$PLATFORM${NC}  (iOS:${BUILD_IOS} macOS:${BUILD_MACOS})"
echo -e "${BOLD}║${NC}  增量构建: ${GREEN}${INCREMENTAL}${NC}"
echo -e "${BOLD}║${NC}  Apple ID: ${APPLE_ID:-（未设置，上传将失败）}"
echo -e "${BOLD}║${NC}  构建产物: $BUILD_DIR"
echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"
echo ""

# ---- 上传函数 ----

# BUILD 冲突自动修复辅助函数：
#   is_build_conflict     检测 altool 错误消息是否为 BUILD 数值过低 (CFBundleVersion 已被更高版本覆盖)
#   parse_build_conflict  从错误消息里解析 App Store Connect 当前最高的 BUILD 数值
# 调用方拿到数值后应 +1，并通过 agvtool 同步到 Xcode 项目，然后重新运行脚本即可完成上传

is_build_conflict() {
    local logfile="$1"
    if [ ! -f "$logfile" ]; then return 1; fi
    # 关键字共现：版本号上下文 + 冲突词汇
    # 覆盖 ITMS-4090 / ITMS-9000 / ITMS-4238 / "minimum required" / "must be greater than" 等场景
    if grep -qiE "build[[:space:]]*(version|number|CFBundleVersion).{0,80}(too low|invalid|higher|greater|minimum required|must be at least|already submitted|already exists|already uploaded)" "$logfile" 2>/dev/null; then
        return 0
    fi
    if grep -qiE "(bundle version|CFBundleVersion).{0,80}(too low|invalid|higher|greater|minimum|must be at least|already exists)" "$logfile" 2>/dev/null; then
        return 0
    fi
    if grep -qiE "version[[:space:]]*['(]?[0-9]+[')]?[[:space:]]+already[[:space:]]+(exists|submitted|uploaded)" "$logfile" 2>/dev/null; then
        return 0
    fi
    if grep -qiE "build version.{0,80}is[[:space:]]+(invalid|too low)" "$logfile" 2>/dev/null; then
        return 0
    fi
    return 1
}

# 从 altool 错误日志里提取 App Store Connect 当前最大的 BUILD 数值
# 成功：打印数字到 stdout, return 0；失败：return 1
parse_build_conflict() {
    local logfile="$1"
    local v=""
    if [ ! -f "$logfile" ]; then return 1; fi

    # 1) "minimum required build version/number is X"  -- version 后可夹 "is"
    v=$(grep -ioE "minimum required build[[:space:]]+(version|number)[^0-9]*[0-9]+" "$logfile" 2>/dev/null \
        | grep -oE "[0-9]+$" | tail -1) || true

    # 2) "(build|bundle) version 'X' must be greater/higher/larger than ... version 'Y'"  → Y 是必须 ≥ 的值
    if [ -z "$v" ]; then
        v=$(grep -ioE "(build|bundle)[[:space:]]+version[[:space:]]+'?[0-9]+'?[[:space:]]+must be[[:space:]]+(greater|higher|larger) than.{0,100}(version|number)[[:space:]]+'?[0-9]+" "$logfile" 2>/dev/null \
            | grep -oE "[0-9]+$" | tail -1) || true
    fi

    # 2b) "1.0.0 (X)" / "1.0.0 (Y)" semver 形式 — 在含 build/version 上下文中取最大括号内的数字
    if [ -z "$v" ]; then
        v=$(grep -iE "(build|bundle|version|upload)" "$logfile" 2>/dev/null \
            | grep -oE "\([0-9]+\)" | grep -oE "[0-9]+" | sort -rn | head -1) || true
    fi

    # 3) "version 'X' / version (X) / version X  already exists/submitted/uploaded"
    if [ -z "$v" ]; then
        v=$(grep -ioE "version[[:space:]]*['(]?[0-9]+[')]?[[:space:]]+already[[:space:]]+(exists|submitted|uploaded)" "$logfile" 2>/dev/null \
            | grep -oE "[0-9]+" | sort -rn | head -1) || true
    fi

    # 4) "must be at least X"
    if [ -z "$v" ]; then
        v=$(grep -ioE "must be at least[[:space:]]+[0-9]+" "$logfile" 2>/dev/null \
            | grep -oE "[0-9]+" | tail -1) || true
    fi

    # 5) 兜底：在含 build/version/CFBundle 关键字的行（排除 ITMS-XXXX 错误码本身）中找最大数字
    if [ -z "$v" ]; then
        v=$(grep -iE "(build|version|CFBundleVersion)" "$logfile" 2>/dev/null \
            | grep -ivE "ITMS[- ]?[0-9]{4}" \
            | grep -oE "[0-9]+" | sort -rn | head -1) || true
    fi

    if [ -n "$v" ]; then
        if [ "$v" -gt 0 ] 2>/dev/null; then
            echo "$v"
            return 0
        fi
    fi
    return 1
}

# 检测日志中是否为 MARKETING_VERSION / CFBundleShortVersionString 过低
is_version_conflict() {
    local logfile="$1"
    [ ! -f "$logfile" ] && return 1
    if grep -qiE "CFBundleShortVersionString" "$logfile" 2>/dev/null \
        && grep -qiE "(previously approved version|higher version than|must contain a higher version|higher than the latest version|must be greater than the current version|approved version|90062)" "$logfile" 2>/dev/null; then
        return 0
    fi
    # 兼容纯文本："version ... must be higher than ... previously approved"
    if grep -qiE "version[[:space:]]+[^[:space:]]+.{0,60}(must be|needs to be|should be).{0,60}higher" "$logfile" 2>/dev/null \
        && grep -qiE "previously approved" "$logfile" 2>/dev/null; then
        return 0
    fi
    return 1
}

# 从版本号冲突日志中提取"本次上传"的版本号
parse_version_conflict_current() {
    local logfile="$1"
    [ ! -f "$logfile" ] && return 1
    local v=""
    # CFBundleShortVersionString [2.0.0] ... previously approved version [2.0.0]
    # 取第一个 [x.y.z]
    v=$(grep -oiE "CFBundleShortVersionString[[:space:]]*\[[^]]+\]" "$logfile" 2>/dev/null \
        | head -1 | grep -oE "\[[^]]+\]" | tr -d '[]') || true
    # 兜底：匹配 "The value for key ... [x.y.z]"
    if [ -z "$v" ]; then
        v=$(grep -oiE "value for key[^[]*\[[0-9]+(\.[0-9]+)*\]" "$logfile" 2>/dev/null \
            | head -1 | grep -oE "\[[0-9]+(\.[0-9]+)*\]" | tr -d '[]') || true
    fi
    if [ -n "$v" ]; then
        echo "$v"
        return 0
    fi
    return 1
}

# 从版本号冲突日志中提取"已批准"的版本号
parse_version_conflict_approved() {
    local logfile="$1"
    [ ! -f "$logfile" ] && return 1
    local v=""
    # previously approved version [2.0.0]
    v=$(grep -oiE "previously approved[^[]*\[[0-9]+(\.[0-9]+)*\]" "$logfile" 2>/dev/null \
        | head -1 | grep -oE "\[[0-9]+(\.[0-9]+)*\]" | tr -d '[]') || true
    # latest version / approved version
    if [ -z "$v" ]; then
        v=$(grep -oiE "(latest|approved|existing|current)[[:space:]]+version[^[]*\[[0-9]+(\.[0-9]+)*\]" "$logfile" 2>/dev/null \
            | head -1 | grep -oE "\[[0-9]+(\.[0-9]+)*\]" | tr -d '[]') || true
    fi
    if [ -n "$v" ]; then
        echo "$v"
        return 0
    fi
    return 1
}

# 输入 x.y.z，输出 x.y.(z+1)；如果输入不是三段式，追加 .1
next_patch_version() {
    local ver="$1"
    local major minor patch
    if [[ "$ver" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
        major="${BASH_REMATCH[1]}"
        minor="${BASH_REMATCH[2]}"
        patch="${BASH_REMATCH[3]}"
        echo "${major}.${minor}.$((patch + 1))"
    elif [[ "$ver" =~ ^([0-9]+)\.([0-9]+)$ ]]; then
        major="${BASH_REMATCH[1]}"
        minor="${BASH_REMATCH[2]}"
        echo "${major}.${minor}.1"
    else
        echo "${ver}.1"
    fi
}

upload_pkg() {
    local file="$1" type="$2"
    # 总尝试次数 = 首次 + 重试次数
    local max_attempts=$((RETRY + 1))
    local retry_delay=30  # 重试间隔（秒），固定值
    local attempt=0
    local upload_log=""
    local attempt_start=0 attempt_end=0 attempt_duration=0
    local phase_start=$(date +%s)

    while true; do
        attempt=$((attempt + 1))
        # 首次与重试分别落盘独立日志，便于排查每次尝试的 altool 原始输出
        if [ $attempt -eq 1 ]; then
            upload_log="$LOG_DIR/upload-${type}.log"
        else
            upload_log="$LOG_DIR/upload-${type}-retry$((attempt - 1)).log"
        fi

        log "上传 $type (尝试 $attempt/$max_attempts, 起点 $(date '+%H:%M:%S')) ..."
        log "  文件: $file"
        log "  大小: $(du -h "$file" 2>/dev/null | cut -f1 || echo '?')"

        attempt_start=$(date +%s)
        xcrun altool --upload-app \
            --file "$file" --type "$type" \
            --username "$APPLE_ID" --password "$AC_PASSWORD" \
            2>&1 | tee "$upload_log"
        local rc=${PIPESTATUS[0]}
        attempt_end=$(date +%s)
        attempt_duration=$((attempt_end - attempt_start))

        if [ $rc -eq 0 ]; then
            ok "${type} 上传成功 (尝试 $attempt/$max_attempts, 用时 $(format_duration $attempt_duration), 终点 $(date '+%H:%M:%S'))"
            if [ "$type" = "ios" ]; then
                IOS_RESULT="成功"
                IOS_ATTEMPTS=$attempt
                IOS_DURATION=$attempt_duration
            else
                MAC_RESULT="成功"
                MAC_ATTEMPTS=$attempt
                MAC_DURATION=$attempt_duration
            fi
            return 0
        fi

        fail "${type} 上传失败 (exit $rc, 尝试 $attempt/$max_attempts, 用时 $(format_duration $attempt_duration), 时间 $(date '+%H:%M:%S'))"

        # ---- 错误分类与原因总结（先输出分类，再输出原始日志） ----
        analyze_upload_error "$upload_log"
        echo ""
        warn "  [错误分类] $ERROR_SUMMARY"
        warn "  [原因]     $ERROR_REASON"
        warn "  [建议]     $ERROR_SUGGESTION"
        echo ""
        echo "  ─── 完整日志 ($upload_log) ───"
        cat "$upload_log" 2>/dev/null | while read line; do echo "  | $line"; done
        echo "  ─── END ───"

        # ---- 版本号冲突：不可自动修复，直接给出明确提示 ----
        if [ "$ERROR_KIND" = "version_conflict" ]; then
            local phase_dur=$(( $(date +%s) - phase_start ))
            if [ "$type" = "ios" ]; then
                IOS_RESULT="版本号冲突（需手动提升 MARKETING_VERSION）"
                IOS_ATTEMPTS=$attempt
                IOS_DURATION=$phase_dur
            else
                MAC_RESULT="版本号冲突（需手动提升 MARKETING_VERSION）"
                MAC_ATTEMPTS=$attempt
                MAC_DURATION=$phase_dur
            fi
            # 版本号属于工程决策，不能自动 bump；返回失败，让外层统一打印建议
            return 1
        fi

        # ---- BUILD 冲突自动修复 ----
        # altool 报 BUILD 过低时，从错误消息里解析 App Store Connect 现存的最高 BUILD
        # 并立即把当前项目的 BUILD 设置为 最高 + 1（同步 agvtool）
        # 注意：BUILD 冲突不计入自动重试 —— 同一份 .pkg 重新上传必然再次冲突，
        # 必须重新构建才能换 BUILD。直接返回特殊退出码，让上层提示用户重跑脚本。
        if [ "$ERROR_KIND" = "build_conflict" ] && is_build_conflict "$upload_log"; then
            local highest_build
            if highest_build=$(parse_build_conflict "$upload_log"); then
                local new_build=$((highest_build + 1))
                warn "检测到 BUILD 冲突：App Store Connect 当前最高 BUILD ≥ $highest_build"
                warn "  自动更新 Xcode 项目 BUILD: $BUILD_NUMBER → $new_build"
                log "运行 agvtool new-version -all $new_build ..."
                (
                    cd "$PROJECT_DIR"
                    if agvtool new-version -all "$new_build" > /dev/null 2>&1; then
                        ok "Xcode 项目 BUILD 已更新为 $new_build"
                    else
                        fail "agvtool 更新失败，请手动设置 CURRENT_PROJECT_VERSION=$new_build"
                    fi
                )
                BUILD_NUMBER="$new_build"
                XCODE_BUILD="$new_build"
                local phase_dur=$(( $(date +%s) - phase_start ))
                if [ "$type" = "ios" ]; then
                    IOS_RESULT="BUILD冲突已修复 (新BUILD=$new_build)"
                    IOS_ATTEMPTS=$attempt
                    IOS_DURATION=$phase_dur
                else
                    MAC_RESULT="BUILD冲突已修复 (新BUILD=$new_build)"
                    MAC_ATTEMPTS=$attempt
                    MAC_DURATION=$phase_dur
                fi
                return 2  # 特殊退出码：BUILD 冲突已处理，需重新运行脚本完成上传
            else
                warn "检测到 BUILD 冲突但无法解析最高 BUILD 数值，请手动调整"
                local phase_dur=$(( $(date +%s) - phase_start ))
                if [ "$type" = "ios" ]; then
                    IOS_RESULT="BUILD冲突解析失败"
                    IOS_ATTEMPTS=$attempt
                    IOS_DURATION=$phase_dur
                else
                    MAC_RESULT="BUILD冲突解析失败"
                    MAC_ATTEMPTS=$attempt
                    MAC_DURATION=$phase_dur
                fi
                return 1
            fi
        fi

        # 非 BUILD 冲突：判断是否还有重试次数
        if [ $attempt -lt $max_attempts ]; then
            warn "等待 ${retry_delay} 秒后重试 (Ctrl+C 可中断) ..."
            sleep "$retry_delay" || {
                warn "等待被中断，停止重试"
                local phase_dur=$(( $(date +%s) - phase_start ))
                if [ "$type" = "ios" ]; then
                    IOS_RESULT="用户中断"
                    IOS_ATTEMPTS=$attempt
                    IOS_DURATION=$phase_dur
                else
                    MAC_RESULT="用户中断"
                    MAC_ATTEMPTS=$attempt
                    MAC_DURATION=$phase_dur
                fi
                return 1
            }
            continue
        fi

        fail "已达到最大重试次数 ($max_attempts)，放弃上传"
        local phase_dur=$(( $(date +%s) - phase_start ))
        if [ "$type" = "ios" ]; then
            IOS_RESULT="失败（$ERROR_KIND, 已重试 $RETRY 次）"
            IOS_ATTEMPTS=$attempt
            IOS_DURATION=$phase_dur
        else
            MAC_RESULT="失败（$ERROR_KIND, 已重试 $RETRY 次）"
            MAC_ATTEMPTS=$attempt
            MAC_DURATION=$phase_dur
        fi
        return 1
    done
}

# ---- 构建函数 ----
run_archive() {
    local platform="$1" dest="$2" name="$3"; shift 3
    local archive="$BUILD_DIR/$name.xcarchive"
    local log="$LOG_DIR/${name}.log"

    log "${name} 开始归档 ..."
    echo "  destination: $dest"
    echo "  archive:     $archive  (jobs: $JOBS)"

    xcodebuild archive \
        -jobs $JOBS \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -configuration Release \
        -destination "$dest" \
        -archivePath "$archive" \
        -derivedDataPath "$BUILD_DIR/DerivedData-${name}" \
        -allowProvisioningUpdates \
        -showBuildTimingSummary \
        CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
        MARKETING_VERSION="$VERSION" \
        "$@" \
        2>&1 | tee "$log"

    local rc=${PIPESTATUS[0]}
    if [ $rc -ne 0 ]; then
        fail "${name} 归档失败 (exit $rc)"
        echo ""
        echo -e "${RED}━━━ 错误摘要 ━━━${NC}"
        grep -iE "error:|❌|failed|EXPIRED|revoked|missing|not found" "$log" | tail -15 || true
        return 1
    fi
    ok "${name} 归档完成"
    echo "$archive" > "$BUILD_DIR/${name}_archive"
    return 0
}

run_export() {
    local name="$1" method="$2"
    local archive="$BUILD_DIR/$name.xcarchive"
    local export_dir="$BUILD_DIR/${name}-Export"
    local log="$LOG_DIR/${name}_export.log"
    mkdir -p "$export_dir"

    log "${name} 导出 (method=$method, archive=$archive) ..."

    local teamID=$(xcodebuild -showBuildSettings -project "$PROJECT" -scheme "$SCHEME" 2>/dev/null | grep DEVELOPMENT_TEAM | head -1 | awk '{print $3}' || echo "")

    # PTuner 使用 Xcode 自动签名（CODE_SIGN_STYLE = Automatic）。
    # 不再从本机 Provisioning Profiles 里手动挑 mobileprovision：
    # - iOS 与 macOS 的 App Store 导出都由 -allowProvisioningUpdates 自动解析；
    # - macOS 没有 .mobileprovision，强行写 provisioningProfiles 会导出失败。
    if [ "$method" = "app-store-connect" ]; then
        cat > "$BUILD_DIR/ExportOptions-${name}.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>method</key><string>app-store-connect</string>
    <key>teamID</key><string>${teamID}</string>
    <key>signingStyle</key><string>automatic</string>
    <key>uploadSymbols</key><true/>
</dict></plist>
PLIST
    else
        cat > "$BUILD_DIR/ExportOptions-${name}.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>method</key><string>${method}</string>
    <key>destination</key><string>export</string>
    <key>teamID</key><string>${teamID}</string>
    <key>signingStyle</key><string>automatic</string>
</dict></plist>
PLIST
    fi

    xcodebuild -exportArchive \
        -archivePath "$archive" \
        -exportPath "$export_dir" \
        -exportOptionsPlist "$BUILD_DIR/ExportOptions-${name}.plist" \
        -allowProvisioningUpdates \
        2>&1 | tee "$log"

    local rc=${PIPESTATUS[0]}
    if [ $rc -ne 0 ]; then
        fail "${name} 导出失败 (exit $rc)"
        grep -iE "error:|❌|failed|EXPIRED|revoked|missing" "$log" | tail -10 || true
        return 1
    fi

    # 产物路径
    log "${name} 查找导出产物 (method=$method, dir=$export_dir) ..."
    local pkg=""
    if [ "$method" = "app-store" ] || [ "$method" = "app-store-connect" ]; then
        pkg=$(/usr/bin/find "$export_dir" \( -name "*.ipa" -o -name "*.pkg" \) | head -1)
        log "  find *.ipa/*.pkg → ${pkg:-未找到}"
    fi
    if [ "$method" = "mac-application" ]; then
        pkg=$(/usr/bin/find "$export_dir" -name "*.pkg" -o -name "*.app" | head -1)
        log "  find *.pkg/*.app → ${pkg:-未找到}"
    fi
    if [ -z "$pkg" ]; then
        fail "${name} 导出完成但未找到产物文件"
        warn "  目录内容:"
        ls -la "$export_dir/" 2>&1 | while read line; do warn "    $line"; done
        return 1
    fi
    ok "${name} 导出完成: $pkg"
    local marker="$BUILD_DIR/${name}_pkg"
    echo "$pkg" > "$marker"
    log "  标记文件已写入: $marker → $pkg"
    return 0
}

run_mac_package() {
    local name="$1"
    local export_dir="$BUILD_DIR/${name}-Export"
    local app=$(/usr/bin/find "$export_dir" -name "*.app" | head -1)
    local pkg="$export_dir/${name}.pkg"
    local log="$LOG_DIR/${name}_package.log"

    [ -z "$app" ] && { fail "${name} 未找到 .app"; return 1; }

    log "${name} productbuild 打包 .pkg ..."
    local rc=0
    local macInstallerCert=$(security find-identity -v 2>/dev/null | grep "3rd Party Mac Developer Installer" | grep -oE '"[^"]+"' | head -1 | tr -d '"')
    if [ -z "$macInstallerCert" ]; then
        fail "缺少 '3rd Party Mac Developer Installer' 证书"
        echo "  请在 Xcode → Settings → Accounts → Manage Certificates"
        echo "  点 + 创建 'Mac Installer Distribution' 证书"
        return 1
    fi
    productbuild --component "$app" /Applications --sign "$macInstallerCert" "$pkg" 2>&1 | tee "$log"
    rc=${PIPESTATUS[0]}
    [ $rc -ne 0 ] && { fail "${name} productbuild 失败"; return 1; }

    ok "${name} .pkg 打包完成: $pkg"
    echo "$pkg" > "$BUILD_DIR/${name}_pkg"
    return 0
}

run_local_export() {
    local name="$1"
    local archive="$BUILD_DIR/$name.xcarchive"
    local log="$LOG_DIR/${name}_local_copy.log"

    log "${name} 从 Archive 直接拷贝 .app（不打 pkg，不改包名，相当于 Xcode Organizer 的 Copy App）"

    # xcarchive 中 Products/Applications 下有完整签名的 .app
    local app_src="$archive/Products/Applications"
    local apps=$(ls "$app_src"/*.app 2>/dev/null || true)
    if [ -z "$apps" ]; then
        fail "${name} Archive 中未找到 .app (Products/Applications/)"
        ls -la "$app_src/" 2>&1 | while read line; do warn "    $line"; done
        return 1
    fi

    # 取第一个 .app，保留原始包名（不修改 CFBundleName）
    local app=""
    for a in "$app_src"/*.app; do app="$a"; break; done
    local app_name=$(basename "$app")
    local final_app="$BUILD_DIR/$app_name"

    rm -rf "$final_app"
    cp -R "$app" "$final_app"

    # 清除 quarantine 属性
    xattr -cr "$final_app" 2>/dev/null || true

    ok "${name} 本地构建完成: $final_app"
    echo "$final_app" > "$BUILD_DIR/${name}_local_app"
    return 0
}

# ---- 主流程 ----
echo ""

IOS_OK=0 MAC_OK=0

if $UPLOAD_ONLY; then
    log "upload-only 模式：跳过构建阶段，直接复用现有产物标记"
    # 校验各平台标记文件存在且指向真实产物
    if $BUILD_IOS; then
        marker="$BUILD_DIR/PTuner-iOS_pkg"
        IPA=$(cat "$marker" 2>/dev/null || echo "")
        if [ -n "$IPA" ] && [ -f "$IPA" ]; then
            log "  iOS 产物:    $IPA"
            log "            $(du -h "$IPA" 2>/dev/null | cut -f1 || echo '?')"
            IOS_OK=1
        else
            fail "iOS 产物标记缺失或产物文件不存在: $marker → ${IPA:-（空）}"
            warn "    请先跑一次完整构建: ./build_appstore.sh -p ios"
            warn "    或全平台构建:       ./build_appstore.sh"
        fi
    fi
    if $BUILD_MACOS; then
        marker="$BUILD_DIR/PTuner-macOS_pkg"
        PKG=$(cat "$marker" 2>/dev/null || echo "")
        if [ -n "$PKG" ] && [ -f "$PKG" ]; then
            log "  macOS 产物:  $PKG"
            log "            $(du -h "$PKG" 2>/dev/null | cut -f1 || echo '?')"
            MAC_OK=1
        else
            fail "macOS 产物标记缺失或产物文件不存在: $marker → ${PKG:-（空）}"
            warn "    请先跑一次完整构建: ./build_appstore.sh -p macos"
            warn "    或全平台构建:       ./build_appstore.sh"
        fi
    fi
else
    BUILD_START_EPOCH=$(date +%s)
    log "构建阶段开始: $(date '+%Y-%m-%d %H:%M:%S')"
    log "开始并行构建 ..."
    echo -e "  iOS:   ${BUILD_IOS:+${GREEN}ON${NC}}${BUILD_IOS:-${RED}OFF${NC}}"
    echo -e "  macOS: ${BUILD_MACOS:+${GREEN}ON${NC}}${BUILD_MACOS:-${RED}OFF${NC}}"
    echo -e "  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # ---- iOS ----
    if $BUILD_IOS; then
    (
        run_archive "ios" "generic/platform=iOS" "PTuner-iOS" && \
        run_export "PTuner-iOS" "app-store-connect"
    ) &
    PID_IOS=$!
    else
        log "跳过 iOS 构建"
        PID_IOS=0
        IOS_OK=1
    fi

    # ---- macOS ----
    if $BUILD_MACOS; then
    if $LOCAL_MODE; then
        (
            run_archive "mac" "generic/platform=macOS" "PTuner-macOS" \
                INFOPLIST_KEY_CFBundlePackageType="APPL" \
                INFOPLIST_KEY_LSApplicationCategoryType="public.app-category.music" && \
            run_local_export "PTuner-macOS"
        ) &
    else
        (
            run_archive "mac" "generic/platform=macOS" "PTuner-macOS" \
                INFOPLIST_KEY_CFBundlePackageType="APPL" \
                INFOPLIST_KEY_LSApplicationCategoryType="public.app-category.music" && \
            run_export "PTuner-macOS" "app-store-connect"
        ) &
    fi
    PID_MAC=$!
    else
        log "跳过 macOS 构建"
        PID_MAC=0
        MAC_OK=1
    fi

    # 等待所有子进程
    [ "$PID_IOS" != "0" ] && wait $PID_IOS && IOS_OK=1 || true
    [ "$PID_MAC" != "0" ] && wait $PID_MAC && MAC_OK=1 || true
    BUILD_END_EPOCH=$(date +%s)
    BUILD_DURATION=$((BUILD_END_EPOCH - BUILD_START_EPOCH))
    log "构建阶段结束: $(date '+%Y-%m-%d %H:%M:%S'), 用时 $(format_duration $BUILD_DURATION)"
fi

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if $UPLOAD_ONLY; then
    log "产物校验完成"
else
    log "构建阶段完成"
fi
echo ""

# iOS 结果
if $BUILD_IOS; then
    if [ $IOS_OK -eq 1 ]; then
        if $UPLOAD_ONLY; then ok "iOS  产物已就绪"
        else ok "iOS  构建成功"; fi
    else
        if $UPLOAD_ONLY; then fail "iOS  产物不可用"
        else fail "iOS  构建失败"; fi
        say "iOS 失败" 2>/dev/null || true
    fi
else
    warn "iOS  已跳过 (BUILD_IOS=false)"
fi

# macOS 结果
if $BUILD_MACOS; then
    if [ $MAC_OK -eq 1 ]; then
        if $UPLOAD_ONLY; then ok "macOS 产物已就绪"
        else ok "macOS 构建成功"; fi
    else
        if $UPLOAD_ONLY; then fail "macOS 产物不可用"
        else fail "macOS 构建失败"; fi
        say "macOS 失败" 2>/dev/null || true
    fi
else
    warn "macOS 已跳过 (BUILD_MACOS=false)"
fi

# 所有实际构建的平台都失败了才退出
ALL_FAILED=true
$BUILD_IOS   && [ $IOS_OK -eq 0 ] || ALL_FAILED=false
$BUILD_MACOS && [ $MAC_OK -eq 0 ] || ALL_FAILED=false
# 如果两个都没构建，也不算失败
! $BUILD_IOS && ! $BUILD_MACOS && ALL_FAILED=false

if $ALL_FAILED; then
    echo ""
    fail "所有构建的平台均失败"
    $BUILD_IOS   && echo "    iOS:   $LOG_DIR/PTuner-iOS.log"
    $BUILD_IOS   && echo "    iOS:   $LOG_DIR/PTuner-iOS_export.log"
    $BUILD_MACOS && echo "    macOS: $LOG_DIR/PTuner-macOS.log"
    $BUILD_MACOS && echo "    macOS: $LOG_DIR/PTuner-macOS_export.log"
    say "构建失败" 2>/dev/null || true
    FAILED_LOG="$BUILD_DIR/logs/$(date +%Y%m%d_%H%M%S)_FAILED"
    mv "$LOG_DIR" "$FAILED_LOG" 2>/dev/null || true
    echo "  日志已保存: $FAILED_LOG"
    print_summary_report
    exit 1
fi

# ---- 上传 ----
if ! $LOCAL_MODE; then
echo ""
UPLOAD_START_EPOCH=$(date +%s)
log "上传阶段开始: $(date '+%Y-%m-%d %H:%M:%S')"
log "上传到 App Store Connect ..."
IOS_UPLOAD_OK=0
MAC_UPLOAD_OK=0
HAS_FAILURE=0
BUILD_BUMPED=0           # 标记是否因 BUILD 冲突自动 bump 过
BUILD_NEW_VALUE=""        # bump 后的新 BUILD 数值

if $BUILD_IOS; then
    if [ $IOS_OK -eq 1 ]; then
        MARKER="$BUILD_DIR/PTuner-iOS_pkg"
        IPA=$(cat "$MARKER" 2>/dev/null || echo "")
        if [ -n "$IPA" ]; then
            upload_rc=0
            upload_pkg "$IPA" "ios" || upload_rc=$?
            if [ $upload_rc -eq 0 ]; then
                IOS_UPLOAD_OK=1
            elif [ $upload_rc -eq 2 ]; then
                # BUILD 冲突已自动修复
                BUILD_BUMPED=1
                BUILD_NEW_VALUE="$BUILD_NUMBER"
                warn "iOS 上传因 BUILD 冲突中止（已自动更新 BUILD）"
            fi
        else
            fail "iOS 标记文件缺失或为空: $MARKER"
            warn "  当前产物目录文件列表:"
            ls -la "$BUILD_DIR/" 2>&1 | while read line; do warn "    $line"; done
        fi
    else
        if $UPLOAD_ONLY; then warn "iOS 产物不可用，跳过上传"
        else warn "iOS 构建失败，跳过上传"; fi
    fi
fi

if $BUILD_MACOS; then
    if [ $MAC_OK -eq 1 ]; then
        MARKER="$BUILD_DIR/PTuner-macOS_pkg"
        PKG=$(cat "$MARKER" 2>/dev/null || echo "")
        if [ -n "$PKG" ]; then
            # 若 BUILD 已因前面失败而自动 bump，跳过 macOS 上传（同一 BUILD 必然冲突）
            if [ "$BUILD_BUMPED" = "1" ]; then
                warn "macOS 上传已跳过（BUILD 已被自动更新，需重新运行脚本）"
            else
                upload_rc=0
                upload_pkg "$PKG" "macos" || upload_rc=$?
                if [ $upload_rc -eq 0 ]; then
                    MAC_UPLOAD_OK=1
                elif [ $upload_rc -eq 2 ]; then
                    BUILD_BUMPED=1
                    BUILD_NEW_VALUE="$BUILD_NUMBER"
                    warn "macOS 上传因 BUILD 冲突中止（已自动更新 BUILD）"
                fi
            fi
        else
            fail "macOS 标记文件缺失或为空: $MARKER"
            warn "  当前产物目录文件列表:"
            ls -la "$BUILD_DIR/" 2>&1 | while read line; do warn "    $line"; done
        fi
    else
        if $UPLOAD_ONLY; then warn "macOS 产物不可用，跳过上传"
        else warn "macOS 构建失败，跳过上传"; fi
    fi
fi

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
log "最终结果"

if $BUILD_IOS; then
    if [ $IOS_OK -eq 1 ] && [ $IOS_UPLOAD_OK -eq 1 ]; then
        if $UPLOAD_ONLY; then ok "iOS  上传成功"
        else ok "iOS  构建成功，上传成功"; fi
    elif [ $IOS_OK -eq 1 ] && [ "$BUILD_BUMPED" = "1" ]; then
        if $UPLOAD_ONLY; then warn "iOS  上传因 BUILD 冲突中止（见下方提示）"
        else warn "iOS  构建成功，但因 BUILD 冲突中止上传（见下方提示）"; fi
    elif [ $IOS_OK -eq 1 ]; then
        fail "iOS  上传失败"
        HAS_FAILURE=1
    else
        fail "iOS  不可用"
        HAS_FAILURE=1
    fi
else
    warn "iOS  已跳过"
fi

if $BUILD_MACOS; then
    if [ $MAC_OK -eq 1 ] && [ $MAC_UPLOAD_OK -eq 1 ]; then
        if $UPLOAD_ONLY; then ok "macOS 上传成功"
        else ok "macOS 构建成功，上传成功"; fi
    elif [ $MAC_OK -eq 1 ] && [ "$BUILD_BUMPED" = "1" ]; then
        if $UPLOAD_ONLY; then warn "macOS 上传因 BUILD 冲突中止（见下方提示）"
        else warn "macOS 构建成功，但因 BUILD 冲突中止上传（见下方提示）"; fi
    elif [ $MAC_OK -eq 1 ]; then
        fail "macOS 上传失败"
        HAS_FAILURE=1
    else
        fail "macOS 不可用"
        HAS_FAILURE=1
    fi
else
    warn "macOS 已跳过"
fi

echo ""
if [ "$BUILD_BUMPED" = "1" ]; then
    echo ""
    echo -e "${YELLOW}${BOLD}╔══════════════════════════════════════════════╗${NC}"
    if $UPLOAD_ONLY; then
        echo -e "${YELLOW}${BOLD}║  BUILD 已自动更新，需重新构建才能上传        ║${NC}"
    else
        echo -e "${YELLOW}${BOLD}║  BUILD 已自动更新，请重新运行脚本            ║${NC}"
    fi
    echo -e "${YELLOW}${BOLD}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    warn "上传失败：App Store Connect 上 BUILD 数值高于本次构建。"
    warn "已自动把 Xcode 项目的 CURRENT_PROJECT_VERSION 同步提升为:"
    echo -e "  ${GREEN}${BOLD}$BUILD_NEW_VALUE${NC}"
    if $UPLOAD_ONLY; then
        warn "upload-only 模式下 .ipa/.pkg 仍是旧 BUILD，重复上传必然冲突。"
        warn "请重新跑一次完整构建: ${BOLD}$0 -p ios -r $RETRY${NC}（不带 -u）"
    else
        warn "请直接重新运行 ${BOLD}$0${NC}（保持原参数），脚本会读到这个新 BUILD 并完成构建上传"
    fi
    say "BUILD 冲突已自动修复" 2>/dev/null || true
    FAILED_LOG="$BUILD_DIR/logs/$(date +%Y%m%d_%H%M%S)_BUILD_BUMPED"
    mv "$LOG_DIR" "$FAILED_LOG" 2>/dev/null || true
    echo "  日志已保存: $FAILED_LOG"
    UPLOAD_END_EPOCH=$(date +%s)
    UPLOAD_DURATION=$((UPLOAD_END_EPOCH - UPLOAD_START_EPOCH))
    print_summary_report
    exit 1
fi

if [ $HAS_FAILURE -eq 1 ]; then
    fail "部分平台未完成，请检查上方结果和日志"
    warn "  BUILD_IOS=$BUILD_IOS IOS_OK=$IOS_OK IOS_UPLOAD_OK=$IOS_UPLOAD_OK BUILD_MACOS=$BUILD_MACOS MAC_OK=$MAC_OK MAC_UPLOAD_OK=$MAC_UPLOAD_OK"
    say "部分平台失败" 2>/dev/null || true
    FAILED_LOG="$BUILD_DIR/logs/$(date +%Y%m%d_%H%M%S)_FAILED"
    mv "$LOG_DIR" "$FAILED_LOG" 2>/dev/null || true
    echo "  日志已保存: $FAILED_LOG"
    UPLOAD_END_EPOCH=$(date +%s)
    UPLOAD_DURATION=$((UPLOAD_END_EPOCH - UPLOAD_START_EPOCH))
    print_summary_report
    exit 1
fi

echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════╗${NC}"
if $UPLOAD_ONLY; then
    echo -e "${GREEN}${BOLD}║  upload-only 全部完成，上传均成功             ║${NC}"
else
    echo -e "${GREEN}${BOLD}║  全部完成，所选平台构建和上传均成功          ║${NC}"
fi
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  成功打包版本: ${GREEN}${BOLD}${VERSION}${NC}  (Build ${GREEN}${BOLD}${BUILD_NUMBER}${NC})"
echo ""
echo "  查看/发布: https://appstoreconnect.apple.com/apps"
UPLOAD_END_EPOCH=$(date +%s)
UPLOAD_DURATION=$((UPLOAD_END_EPOCH - UPLOAD_START_EPOCH))
# 构建成功，日志已无保留价值
# upload-only 模式保留上传日志，便于排查重试过程
if $UPLOAD_ONLY; then
    log "upload-only 日志已保留: $LOG_DIR"
else
    rm -rf "$LOG_DIR" 2>/dev/null || true
fi
print_summary_report
say "构建并上传全部完成" 2>/dev/null || true
# 自动在 Finder 中打开产物目录
log "在 Finder 中打开产物目录 ..."
open "$BUILD_DIR" 2>/dev/null || true

else
    # ---- Local 模式结果 ----
    echo ""
    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║  Local 构建完成                              ║${NC}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  成功打包版本: ${GREEN}${BOLD}${VERSION}${NC}  (Build ${GREEN}${BOLD}${BUILD_NUMBER}${NC})"
    echo ""

    local_app=$(cat "$BUILD_DIR/PTuner-macOS_local_app" 2>/dev/null || echo "")
    if [ -n "$local_app" ] && [ -d "$local_app" ]; then
        echo "  应用路径: $local_app"
        echo "  大小:     $(du -sh "$local_app" 2>/dev/null | cut -f1 || echo '?')"
        echo ""
        echo "  直接拖到 /Applications 文件夹即可使用"
        echo "  或运行:"
        echo "    open \"$local_app\""
        echo ""
        echo "  如果 macOS 提示"无法验证开发者"，请运行:"
        echo "    sudo xattr -rd com.apple.quarantine \"$local_app\""
        echo ""
        # 自动在 Finder 中定位产物
        log "在 Finder 中打开产物目录 ..."
        open -R "$local_app" 2>/dev/null || open "$BUILD_DIR" 2>/dev/null || true
    else
        fail "未找到本地构建产物"
    fi

    # 构建成功，清理日志
    rm -rf "$LOG_DIR" 2>/dev/null || true
    print_summary_report
fi
