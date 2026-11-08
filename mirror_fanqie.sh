#!/bin/zsh
# =============================================================================
# Android → Mac 无线投屏（番茄小说短剧）：ADB 无线调试 + scrcpy
# Android → Mac wireless mirroring (Fanqie novel / short dramas): ADB wireless debugging + scrcpy
#
# 默认「独立显示」模式：番茄小说运行在手机的虚拟屏幕上，只显示在 Mac 窗口里，
#   手机实体屏幕可照常使用，互不影响（scrcpy --new-display）。
# Default "independent display" mode: the app runs on a virtual display of the phone and
#   shows only in the Mac window; the phone's physical screen stays free to use (scrcpy --new-display).
#
# --mirror 为旧的「镜像实体屏幕」模式。 / --mirror is the legacy "mirror the physical screen" mode.
# 画质优先：默认不缩放、16M 码率、60fps；--lq 可降为省带宽模式。
# Quality first: no downscale, 16M bit rate, 60 fps by default; --lq switches to a low-bandwidth mode.
#
# 依赖 / Requires: brew install scrcpy android-platform-tools（缺失时脚本可自动安装 / the script can install them)
# 用法 / Usage: ./mirror_fanqie.sh --help
# =============================================================================

PKG="${FANQIE_PKG:-com.dragon.read}"          # 番茄小说包名 / Fanqie package name
DRAMA_LABEL="${FANQIE_DRAMA_LABEL:-短剧}"      # 短剧入口的界面文字 / UI label of the drama tab
CACHE="${FANQIE_CACHE:-$HOME/.fanqie_mirror_addr}"   # 上次连接地址缓存 / last-connected address cache

# 画质默认值（画质优先；--lq 切换为省带宽）
# Quality defaults (quality first; --lq switches to low bandwidth)
MAX_SIZE=0; BIT_RATE=16M; MAX_FPS=60; H265=0       # MAX_SIZE=0 表示不缩放 / 0 = no downscale
AUDIO_BUFFER=100          # ms；Wi-Fi 下比 scrcpy 默认的 50 更稳，需实测 / more robust over Wi-Fi than the default 50; tune by ear
WITH_AUDIO=1; TRY_DRAMA=1; AUDIO_CODEC=""
MODE="${FANQIE_MODE:-independent}"; AUDIO_SRC=output; GUARD=1; RESTORE=0
GUARD_PID=""; PHYS_DISPLAYS=(); PAIR_MODE=0; PAIR_ARGS=(); DEBUG=0; ADDR_ARG=""
SERIAL_ARG="${ANDROID_SERIAL:-}"
SERIAL=""; DEV_SDK=0; DRAMA_STATE="skipped"

# 函数内的 $0 是函数名，故在顶层保存脚本名
# Inside functions $0 is the function name, so keep the script name at top level
SELF="./${0:t}"
TMPD=""

# 退出清理：停止守护、恢复屏幕、删除临时目录
# Exit cleanup: stop the guard, restore the screen, remove the temp dir
cleanup() {
  [[ -n "$GUARD_PID" ]] && kill "$GUARD_PID" 2>/dev/null
  # 若本脚本曾熄灭实体屏幕，退出时一定恢复
  # If this script ever turned the physical display off, always restore it on exit
  if (( ${#PHYS_DISPLAYS} )) && [[ -n "$SERIAL" ]]; then
    local d; for d in "${PHYS_DISPLAYS[@]}"; do adb -s "$SERIAL" shell cmd display power-reset "$d" >/dev/null 2>&1; done
  fi
  [[ -n "$TMPD" ]] && rm -rf "$TMPD"
}
trap cleanup EXIT
trap 'exit 130' INT TERM HUP   # 信号转为 exit，以触发 EXIT 清理 / turn signals into exit so the EXIT trap runs

# ---------------------------------------------------------------- 输出 / Output
log()  { print -r -- "$*"; }
warn() { print -r -- "⚠️  $*" >&2; }
dbg()  { (( DEBUG )) && print -r -- "[debug] $*" >&2; return 0; }
die()  { print -r -- "❌ $*" >&2; exit 1; }

# ---------------------------------------------------------------- 交互 / 自动安装依赖 / Prompts & auto-install
# FANQIE_FORCE_INTERACTIVE、FANQIE_BREW_PATHS 仅供测试 / for tests only
is_interactive() { [[ -n "$FANQIE_FORCE_INTERACTIVE" || -t 0 ]]; }

# 是/否提问，默认「是」；非交互环境一律视为「否」
# Yes/no prompt, default yes; non-interactive always counts as "no"
ask_yn() {
  is_interactive || return 1
  local a; read -r "a?$1 [Y/n] " || return 1
  [[ -z "$a" || "$a" == [Yy]* ]]
}

# 让当前 shell 找到 brew（Apple 芯片 /opt/homebrew，Intel /usr/local）
# Make brew visible to this shell (Apple silicon /opt/homebrew, Intel /usr/local)
brew_env() {
  local b
  for b in ${=FANQIE_BREW_PATHS:-/opt/homebrew/bin/brew /usr/local/bin/brew}; do
    [[ -x "$b" ]] && { eval "$("$b" shellenv)"; return 0; }
  done
  return 1
}

# 缺少 adb / scrcpy 时，征得同意后用 Homebrew 安装（必要时先装 Homebrew）；已安装则直接跳过
# Install adb / scrcpy via Homebrew after asking (installing Homebrew first if needed); skip if already present
install_deps() {
  local need_adb=0 need_scrcpy=0
  # 先让 shell 找到 brew 的 PATH（如从非登录终端启动），再判断是否缺失
  # Load brew's PATH first (e.g. launched from a non-login shell), then decide what is missing
  if ! command -v adb >/dev/null || ! command -v scrcpy >/dev/null; then brew_env; fi
  command -v adb >/dev/null    || need_adb=1
  command -v scrcpy >/dev/null || need_scrcpy=1
  (( need_adb + need_scrcpy == 0 )) && return 0

  local -a names; (( need_scrcpy )) && names+=(scrcpy); (( need_adb )) && names+=(android-platform-tools)
  log "缺少依赖：${names[*]}"
  ask_yn "是否用 Homebrew 自动安装？" \
    || die "请手动安装：brew install ${names[*]}（无交互终端时不会自动安装）"

  command -v brew >/dev/null || brew_env
  if ! command -v brew >/dev/null; then
    ask_yn "未检测到 Homebrew。是否先安装 Homebrew（官方脚本，过程中需输入 Mac 开机密码）？" \
      || die "请先安装 Homebrew：https://brew.sh"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
      || die "Homebrew 安装失败，请参考 https://brew.sh 手动安装。"
    brew_env || die "已安装 Homebrew，但未找到 brew，请重新打开终端后再运行。"
  fi

  (( need_scrcpy )) && { brew install scrcpy || die "scrcpy 安装失败。"; }
  (( need_adb ))    && { brew install --cask android-platform-tools || die "adb 安装失败。"; }
  hash -r
  command -v adb >/dev/null    || die "adb 仍不可用，请重新打开终端后再运行。"
  command -v scrcpy >/dev/null || die "scrcpy 仍不可用，请重新打开终端后再运行。"
  log "✅ 依赖已就绪"
}

# 帮助文本 / Help text
usage() {
  cat <<EOF
用法：
  $SELF                         自动连接已配对手机，启动番茄小说并投屏
  $SELF pair [IP:配对端口 配对码]  首次配对（不带参数则交互输入）；缺少 adb/scrcpy 时会询问是否自动安装
  $SELF IP:端口                 手动指定「无线调试」主页面显示的连接地址
  $SELF --help                  显示本帮助
  $SELF --debug                 输出详细调试信息

选项：
  -s, --serial SERIAL   指定 ADB 设备序列号（多设备时使用，也可设 ANDROID_SERIAL）
  --lq                  省带宽模式：1280 / 6M / 30fps（默认是画质优先：不缩放 / 16M / 60fps）
  --h265                使用 H.265 编码（同码率画质更好；需手机编码器支持，失败请去掉）
  --audio-buffer MS     音频缓冲毫秒，默认 $AUDIO_BUFFER；卡顿调大，延迟大则调小
  --aac                 音频改用 AAC 编码（设备无 Opus 编码器时使用）
  --no-audio            不转发音频
  --no-drama            只启动番茄小说，不尝试进入短剧板块
  --no-guard            关闭「屏幕守护」（见下；关闭后手机一熄屏，电脑上的画面会变黑）
  --restore-screen      紧急恢复：把手机实体屏幕恢复为正常显示后退出
  --mirror              镜像实体屏幕（旧模式：手机操作会同步到电脑，熄屏则投屏也黑）
  --audio-source SRC    output（默认，转发手机全部声音，手机本身静音）或
                        playback（Android 13+，只抓应用播放，应用可能禁止抓取）

屏幕守护（独立模式，Android 15+）：手机按电源键「熄屏」时，系统会进入休眠，
  虚拟屏幕随之变黑。守护会让设备保持唤醒、仅把实体屏幕熄灭，因此电脑画面不中断；
  再按一次电源键即亮屏，再按一次又熄屏。脚本退出时自动恢复正常显示。

环境变量：FANQIE_SCRCPY_ARGS（附加 scrcpy 参数）、FANQIE_PKG（包名，默认 com.dragon.read）、
          FANQIE_DRAMA_LABEL（短剧入口文字）、FANQIE_VD（虚拟屏幕尺寸，如 1080x2400/420）
EOF
}

# ---------------------------------------------------------------- 工具函数 / Helpers
# 校验 IP:端口 / Validate IP:PORT
is_ipport() { [[ "$1" =~ '^[0-9]{1,3}(\.[0-9]{1,3}){3}:[0-9]{1,5}$' ]]; }

# 带超时运行命令（macOS 无 timeout）；守护进程输出重定向，避免占住 $(...) 的管道
# Run a command with a timeout (macOS has no `timeout`); the watchdog's output is redirected
# so it does not hold the $(...) pipe open
run_to() {
  local secs=$1; shift
  "$@" &
  local pid=$!
  ( sleep "$secs"; kill "$pid" 2>/dev/null ) >/dev/null 2>&1 &
  local wd=$!
  wait "$pid" 2>/dev/null
  local rc=$?
  kill "$wd" 2>/dev/null
  return $rc
}

# 始终显式指定目标设备 / Always target the device explicitly
A() { adb -s "$SERIAL" "$@"; }

# 输出「serial state」列表 / Print "serial state" pairs
list_devices() { adb devices 2>/dev/null | awk -F'\t' 'NF==2 && $2 ~ /^(device|offline|unauthorized|no permissions.*)$/ {print $1" "$2}'; }

device_state() { adb -s "$1" get-state 2>/dev/null; }

# 连接 IP:PORT，成功返回 0（并确认状态为 device）
# Connect to IP:PORT; returns 0 on success (and confirms the state is "device")
connect_addr() {
  local addr=$1 out
  out=$(run_to 8 adb connect "$addr" 2>&1)
  dbg "adb connect $addr -> $out"
  [[ "$out" == *"connected to"* ]] || return 1
  [[ "$(device_state "$addr")" == "device" ]]
}

# 断开失效（offline）的无线连接并记下地址以便重连；绝不 kill-server，不动其他设备
# Drop stale (offline) wireless links and remember them for a retry; never kill-server, never touch other devices
OFFLINE_ADDRS=()
drop_offline_wireless() {
  local s st
  while read -r s st; do
    if [[ "$st" == "offline" && "$s" == *:* ]]; then
      dbg "断开失效连接 $s"; adb disconnect "$s" >/dev/null 2>&1; OFFLINE_ADDRS+=("$s")
    fi
  done < <(list_devices)
}

# 真实手机（排除模拟器）且在线 / Online real phones (emulators excluded)
online_phones() { list_devices | awk '$2=="device" && $1 !~ /^emulator-/ {print $1}'; }

# mDNS 搜索无线调试连接地址（只取 _adb-tls-connect._tcp，不含配对端口）
# Find wireless-debugging connect addresses via mDNS (only _adb-tls-connect._tcp, never the pairing port)
mdns_addrs() {
  adb mdns services 2>/dev/null | awk '/_adb-tls-connect\._tcp/ {print $NF}' | grep -E '^[0-9.]+:[0-9]+$' | sort -u
}

save_cache() { print -r -- "$1" > "$CACHE"; dbg "缓存已更新：$1"; }
read_cache() { [[ -f "$CACHE" ]] && head -1 "$CACHE"; }

# ---------------------------------------------------------------- 配对 / Pairing
# 配对（失败返回非 0，不退出，便于交互流程重试）。配对码不保存。
# Pair (returns non-zero on failure instead of exiting, so interactive flows can retry). The code is never stored.
pair_device() {
  is_ipport "$1" || { warn "配对地址格式应为 IP:配对端口，收到：'$1'"; return 1; }
  [[ "$2" =~ '^[0-9]{6}$' ]] || { warn "配对码应为 6 位数字"; return 1; }
  adb pair "$1" "$2" || { warn "配对失败：请确认使用的是『配对码配对』页面显示的 IP:端口，且配对码未过期。"; return 1; }
  log "✅ 配对成功。注意：配对端口 ≠ 连接端口。"
}

# 交互式输入配对信息 / Ask for pairing details interactively
prompt_pair() {
  local pa code
  log "在手机上打开：设置 → 开发者选项 → 无线调试 → 使用配对码配对设备"
  read -r "pa?请输入配对 IP:端口（弹窗里显示的）： " || return 1
  read -r "code?请输入 6 位配对码： " || return 1
  pair_device "$pa" "$code"
}

# 交互式输入连接地址 / Ask for the connect address interactively
prompt_connect() {
  local addr
  read -r "addr?请输入连接 IP:端口（「无线调试」主页面显示的，不是配对端口）： " || return 1
  is_ipport "$addr" || { warn "格式应为 IP:端口"; return 1; }
  connect_addr "$addr" || { warn "无法连接 $addr"; return 1; }
  SERIAL=$addr; save_cache "$SERIAL"; log "    已连接 $SERIAL"
}

# 自动连接失败时的交互菜单（最多 3 轮，不无限循环）
# Interactive menu when auto-connect fails (at most 3 rounds, never an endless loop)
interactive_connect() {
  local choice; local -i round=0
  while (( round++ < 3 )); do
    log ""
    log "未能自动连接手机，请选择："
    log "  1) 首次使用：输入配对码配对"
    log "  2) 已配对过：手动输入连接 IP:端口"
    log "  3) 重新自动搜索"
    log "  q) 退出"
    read -r "choice?> " || return 1
    case $choice in
      1) prompt_pair && { try_mdns && return 0; log "    配对完成，但未自动发现连接地址，请选 2 手动输入。"; };;
      2) prompt_connect && return 0;;
      3) try_mdns && return 0; warn "仍未发现手机";;
      q|Q) return 1;;
      *) warn "无效选择";;
    esac
  done
  return 1
}

# ---------------------------------------------------------------- [1/5] 检查工具 / Check tools
check_tools() {
  log "[1/5] 检查 ADB 和 scrcpy..."
  install_deps
  dbg "$(adb version | head -1)"
  dbg "$(scrcpy --version 2>&1 | head -1)"
  # 以实际安装版本的 --help 为准，检测参数是否可用
  # Rely on the installed version's --help to detect which flags exist
  SCRCPY_HELP=$(scrcpy --help 2>&1)
  if [[ "$MODE" == independent ]]; then
    [[ "$SCRCPY_HELP" == *"--new-display"* && "$SCRCPY_HELP" == *"--start-app"* ]] \
      || die "当前 scrcpy 不支持 --new-display（独立显示需要 scrcpy 3.0+）。请升级：brew upgrade scrcpy，或用 --mirror 回到镜像模式。"
  fi
  if (( WITH_AUDIO )); then
    [[ "$SCRCPY_HELP" == *"--require-audio"* && "$SCRCPY_HELP" == *"--audio-source"* ]] \
      || die "当前 scrcpy 版本不支持音频转发参数，请升级：brew upgrade scrcpy（或用 --no-audio）"
  fi
}

has_flag() { [[ "$SCRCPY_HELP" == *"$1"* ]]; }

# ---------------------------------------------------------------- [2/5] 连接手机 / Connect
# 在已在线的设备中选择目标；多台时去重并按缓存优先，否则拒绝
# Pick the target among online devices; with several, de-duplicate, prefer the cached one, else refuse
pick_among_online() {
  local phones; phones=("${(@f)$(online_phones)}")
  phones=("${(@)phones:#}")
  (( ${#phones} == 0 )) && return 1
  local cached; cached=$(read_cache)
  if (( ${#phones} > 1 )); then
    # 同一部手机可能同时以 IP:端口 和 mDNS 名称出现，按 ro.serialno 去重
    # One phone may show up as both IP:port and an mDNS name; de-duplicate by ro.serialno
    local -A seen; local -a uniq; local s id
    for s in "${phones[@]}"; do
      id=$(adb -s "$s" shell getprop ro.serialno 2>/dev/null | tr -d '\r')
      [[ -z "$id" ]] && id="$s"
      if [[ -z "${seen[$id]}" ]]; then seen[$id]=1; uniq+=("$s"); fi
    done
    phones=("${uniq[@]}")
  fi
  if (( ${#phones} > 1 )); then
    if [[ -n "$cached" && ${phones[(Ie)$cached]} -gt 0 ]]; then SERIAL=$cached; return 0; fi
    warn "检测到多台 Android 设备："
    printf '   %s\n' "${phones[@]}" >&2
    die "请用 -s SERIAL 指定目标设备（或设置 ANDROID_SERIAL）。"
  fi
  SERIAL=${phones[1]}
  return 0
}

# mDNS 自动发现并连接；有限次数，不无限重试
# Discover and connect via mDNS; bounded attempts, no endless retry
try_mdns() {
  local try addr
  local -i n=0
  local -a addrs
  for try in 1 2 3 4; do
    addrs=("${(@f)$(mdns_addrs)}"); addrs=("${(@)addrs:#}")
    (( ${#addrs} > 0 )) && break
    sleep 1
  done
  dbg "mDNS 结果：${addrs[*]:-无}"
  for addr in "${addrs[@]}"; do
    (( ++n > 8 )) && break
    if connect_addr "$addr"; then
      SERIAL=$addr; save_cache "$SERIAL"; log "    已连接 $SERIAL（mDNS 发现）"; return 0
    fi
  done
  return 1
}

# 连接策略：显式序列号 → 显式 IP:端口 → 已在线设备 → 刚断开的地址 → 缓存 → mDNS → 交互菜单
# Strategy: explicit serial → explicit IP:port → online device → just-dropped address → cache → mDNS → interactive menu
connect_phone() {
  log "[2/5] 搜索并连接 Android 手机..."
  drop_offline_wireless

  # 0) 显式序列号 / explicit serial
  if [[ -n "$SERIAL_ARG" ]]; then
    if [[ "$(device_state "$SERIAL_ARG")" != "device" ]] && is_ipport "$SERIAL_ARG"; then connect_addr "$SERIAL_ARG"; fi
    [[ "$(device_state "$SERIAL_ARG")" == "device" ]] || die "指定的设备 $SERIAL_ARG 不在线。"
    SERIAL=$SERIAL_ARG; is_ipport "$SERIAL" && save_cache "$SERIAL"; return 0
  fi

  # 1) 显式 IP:PORT / explicit IP:PORT
  if [[ -n "$ADDR_ARG" ]]; then
    connect_addr "$ADDR_ARG" || die "无法连接 $ADDR_ARG：请确认地址取自『无线调试』主页面（不是配对页面），且已配对、同一 Wi-Fi。"
    SERIAL=$ADDR_ARG; save_cache "$SERIAL"; log "    已连接 $SERIAL"; return 0
  fi

  # 2) 已在线的设备 / already-online device
  if pick_among_online; then
    log "    使用已连接设备 $SERIAL"; is_ipport "$SERIAL" && save_cache "$SERIAL"; return 0
  fi

  # 2.5) 刚断开的失效连接（IP 与端口未变时可直接恢复）
  # Just-dropped stale link (recovers directly if IP and port are unchanged)
  local oa
  for oa in "${OFFLINE_ADDRS[@]}"; do
    if connect_addr "$oa"; then SERIAL=$oa; save_cache "$SERIAL"; log "    已重新连接 $SERIAL"; return 0; fi
  done

  # 3) 缓存地址 / cached address
  local cached; cached=$(read_cache)
  if [[ -n "$cached" ]] && is_ipport "$cached"; then
    dbg "尝试缓存地址 $cached"
    if connect_addr "$cached"; then SERIAL=$cached; log "    已连接 $SERIAL（缓存）"; return 0; fi
    log "    缓存地址 $cached 已失效（端口或 IP 可能已变化），改用 mDNS 搜索..."
  fi

  # 4) mDNS 自动发现 / mDNS discovery
  try_mdns && return 0

  # 5) 有交互终端时，引导用户配对 / 手动输入
  # With an interactive terminal, guide the user to pair / enter an address
  if is_interactive && interactive_connect; then return 0; fi

  warn "自动连接失败。请检查："
  cat >&2 <<EOF
   1) 手机与 Mac 在同一 Wi-Fi，且路由器未开启「客户端/AP 隔离」
   2) 手机已开启 设置 → 开发者选项 → 无线调试
   3) 从未配对过？先运行：$SELF pair IP:配对端口 配对码
   4) 也可手动指定：$SELF IP:端口（无线调试主页面显示的地址）
   5) 加 --debug 查看详细过程
EOF
  exit 1
}

# ---------------------------------------------------------------- 设备信息 / 锁屏 / Device info & lock state
get_sdk() { DEV_SDK=$(A shell getprop ro.build.version.sdk 2>/dev/null | tr -d "\r"); [[ "$DEV_SDK" =~ "^[0-9]+$" ]] || DEV_SDK=0; dbg "Android SDK=$DEV_SDK"; }

# 是否处于锁屏（不同 ROM 可能有差异）/ Whether the keyguard is showing (ROMs may differ)
is_locked() {
  A shell dumpsys window 2>/dev/null | grep -qE 'mDreamingLockscreen=true|mShowingLockscreen=true|isKeyguardShowing=true'
}

# 唤醒屏幕（不是解锁）；若处于锁屏，请用户自行解锁，最多等待 30 秒
# Wake the screen (this is NOT unlocking); if locked, ask the user to unlock, waiting at most 30 s
ensure_unlocked() {
  A shell input keyevent KEYCODE_WAKEUP
  sleep 1
  is_locked || return 0
  warn "手机处于锁屏状态。请在手机上自行解锁（本脚本不会绕过安全锁），等待最多 30 秒..."
  local i
  for i in {1..15}; do sleep 2; is_locked || { log "    已解锁"; return 0; }; done
  return 1
}

# ---------------------------------------------------------------- [3/5] 启动 App / Launch the app
# 镜像模式：解析启动 Activity，失败则回退 monkey；独立模式只做检查，App 由 scrcpy 启动在虚拟屏幕上
# Mirror mode: resolve the launcher activity, fall back to monkey; independent mode only checks —
# scrcpy itself starts the app on the virtual display
launch_app() {
  log "[3/5] 启动番茄小说..."
  A shell pm list packages "$PKG" 2>/dev/null | tr -d '\r' | grep -qx "package:$PKG" \
    || die "手机未安装 $PKG（如包名不同，请设置 FANQIE_PKG）。"

  get_sdk
  if (( WITH_AUDIO )); then
    (( DEV_SDK > 0 && DEV_SDK < 30 )) && die "音频转发需要 Android 11 及以上（当前 SDK=$DEV_SDK）。可加 --no-audio 仅投屏画面。"
  fi

  if [[ "$MODE" == independent ]]; then
    (( DEV_SDK > 0 && DEV_SDK < 29 )) && die "独立显示需要 Android 10 及以上（当前 SDK=$DEV_SDK），可用 --mirror。"
    (( DEV_SDK > 0 && DEV_SDK < 34 )) && warn "独立显示在 Android 14 以下可能不稳定，若异常请改用 --mirror。"
    # 不点亮实体屏幕；仅 Android 11 的音频捕获要求启动时已解锁
    # Do not light the physical screen; only Android 11 audio capture needs an unlocked device at start
    if (( DEV_SDK == 30 && WITH_AUDIO )); then
      ensure_unlocked || die "Android 11 要求启动音频捕获时设备已解锁，当前仍锁屏。请解锁后重试。"
    fi
    DRAMA_STATE="manual_vd"
    log "    独立显示模式：App 将由 scrcpy 直接启动在虚拟屏幕上（不会占用手机实体屏幕）"
    return 0
  fi

  UNLOCKED=1
  if ! ensure_unlocked; then
    UNLOCKED=0
    if (( DEV_SDK == 30 && WITH_AUDIO )); then
      die "Android 11 要求启动音频捕获时设备已解锁，当前仍锁屏，无法转发音频。请解锁后重试。"
    fi
    warn "手机仍处于锁屏，跳过自动进入短剧；投屏后可在 Mac 上手动解锁操作。"
  fi

  local comp
  comp=$(A shell cmd package resolve-activity --brief -c android.intent.category.LAUNCHER "$PKG" 2>/dev/null | tr -d '\r' | tail -1)
  dbg "启动组件：$comp"
  if [[ "$comp" == */* ]] && A shell am start -n "$comp" >/dev/null 2>"${TMPD}/am.err"; then
    dbg "am start 成功"
  else
    dbg "am start 失败（$(cat "$TMPD/am.err" 2>/dev/null)），回退 monkey"
    A shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 \
      || die "无法启动 $PKG。"
  fi
  log "    已启动 $PKG（仅表示 App 已打开，不代表已进入短剧）"

  (( TRY_DRAMA && UNLOCKED )) && enter_drama
  return 0
}

# ---------- 进入短剧（仅镜像模式）/ Enter the drama tab (mirror mode only)
# 没有已确认的官方 Deep Link，因此不编造；用 uiautomator 按界面文字查找入口，
# 点击后复查是否被选中，结果如实报告。
# There is no confirmed official deep link, so none is invented; uiautomator finds the entry by its
# label, taps it, re-checks that it is selected, and the outcome is reported honestly.
ui_dump() { run_to 15 adb -s "$SERIAL" exec-out uiautomator dump /dev/tty 2>/dev/null; }
label_node() { grep -o "<node [^>]*text=\"$DRAMA_LABEL\"[^>]*>" | head -1; }

enter_drama() {
  local xml node b x1 y1 x2 y2 i
  DRAMA_STATE="notfound"
  for i in 1 2 3 4 5 6; do
    sleep 1.5
    xml=$(ui_dump); node=$(print -r -- "$xml" | label_node)
    [[ -n "$node" ]] && break
  done
  if [[ -z "$node" ]]; then
    dbg "界面中未找到文字「$DRAMA_LABEL」"; return 0
  fi
  b=$(print -r -- "$node" | sed -nE 's/.*bounds="\[([0-9]+),([0-9]+)\]\[([0-9]+),([0-9]+)\]".*/\1 \2 \3 \4/p')
  [[ -z "$b" ]] && return 0
  read -r x1 y1 x2 y2 <<<"$b"
  dbg "点击「$DRAMA_LABEL」坐标 $(( (x1+x2)/2 )),$(( (y1+y2)/2 ))（由界面实时解析）"
  A shell input tap $(( (x1+x2)/2 )) $(( (y1+y2)/2 ))
  DRAMA_STATE="tapped"
  sleep 2
  xml=$(ui_dump)
  if print -r -- "$xml" | label_node | grep -q 'selected="true"'; then DRAMA_STATE="confirmed"; fi
}

# ---------------------------------------------------------------- 屏幕守护 / Screen guard
# 实测（Android 17 / Samsung）：设备进入 Dozing 时虚拟屏幕画面变黑；
# 设备保持 Awake 且仅实体屏幕断电（cmd display power-off）时，虚拟屏幕照常渲染。
# 因此：把「电源键熄屏」转换成「保持唤醒 + 实体屏幕熄灭」，电源键再按则亮屏，如此切换。
# Measured on Android 17 / Samsung: when the device enters Dozing the virtual display goes black;
# while the device stays Awake with only the physical panel powered off (cmd display power-off)
# the virtual display keeps rendering. So a power-key "screen off" is turned into
# "stay awake + panel off", and the next press turns the screen back on, toggling between the two.
guard_supported() {
  (( DEV_SDK >= 35 )) || return 1
  A shell cmd display help 2>/dev/null | grep -q 'power-off'
}

# 读取设备唤醒状态（Awake / Dozing / Asleep）/ Read wakefulness (Awake / Dozing / Asleep)
wakefulness() { adb -s "$SERIAL" shell dumpsys power 2>/dev/null | grep -m1 -o 'mWakefulness=[A-Za-z]*' | cut -d= -f2; }

# screen_power off|on：唤醒设备，并让实体屏幕断电/恢复
# screen_power off|on: wake the device, then power the physical panel off / restore it
screen_power() {
  local d
  adb -s "$SERIAL" shell input keyevent KEYCODE_WAKEUP
  sleep 0.4
  for d in "${PHYS_DISPLAYS[@]}"; do
    if [[ "$1" == off ]]; then adb -s "$SERIAL" shell cmd display power-off "$d" >/dev/null 2>&1
    else adb -s "$SERIAL" shell cmd display power-reset "$d" >/dev/null 2>&1; fi
  done
}

# 后台循环：state=off 表示实体屏幕已被我们熄灭；on 表示用户正在使用手机。
# 设备一旦离开 Awake（电源键 / 自动熄屏）就切换到另一个状态。
# Background loop: state=off means we have powered the panel off; on means the user is using the phone.
# As soon as the device leaves Awake (power key / timeout) we flip to the other state.
screen_guard() {
  trap - EXIT INT TERM HUP     # 后台子进程：被 kill 时直接退出，恢复屏幕由主进程负责 / child: die on kill; the parent restores the screen
  local state=$1 w
  while true; do
    w=$(wakefulness)
    if [[ -n "$w" && "$w" != Awake ]]; then
      if [[ "$state" == off ]]; then screen_power on;  state=on
      else                           screen_power off; state=off; fi
    fi
    sleep 0.7
  done
}

# 列出实体（内置）屏幕 id，不含虚拟屏幕 / List physical (internal) display ids, excluding virtual ones
physical_display_ids() {
  A shell dumpsys display 2>/dev/null \
    | grep -oE 'DisplayViewport\{type=INTERNAL, valid=true, isActive=[a-z]+, displayId=[0-9]+' \
    | sed -E 's/.*displayId=//' | sort -u
}

start_guard() {
  (( GUARD )) || return 0
  [[ "$MODE" == independent ]] || return 0
  if ! guard_supported; then
    warn "屏幕守护需要 Android 15+（当前 SDK=$DEV_SDK）：手机按电源键熄屏后，电脑上的画面会变黑，亮屏后恢复。"
    return 0
  fi
  PHYS_DISPLAYS=("${(@f)$(physical_display_ids)}")
  PHYS_DISPLAYS=("${(@)PHYS_DISPLAYS:#}")
  (( ${#PHYS_DISPLAYS} )) || PHYS_DISPLAYS=(0)
  dbg "实体屏幕 id：${PHYS_DISPLAYS[*]}"
  local init=on
  if [[ "$(wakefulness)" != Awake ]]; then screen_power off; init=off; fi
  screen_guard "$init" &
  GUARD_PID=$!
  log "    屏幕守护已启用：按电源键在「亮屏 / 熄屏」之间切换；熄屏时设备保持唤醒，电脑画面不中断"
}

# 紧急恢复：把实体屏幕恢复为正常显示 / Emergency restore: bring the physical panel back to normal
restore_screen() {
  local d ids
  ids=("${(@f)$(physical_display_ids)}")
  ids=("${(@)ids:#}"); (( ${#ids} )) || ids=(0)
  for d in "${ids[@]}"; do A shell cmd display power-reset "$d" >/dev/null 2>&1; done
  A shell input keyevent KEYCODE_WAKEUP
  log "✅ 已恢复手机实体屏幕显示"
}

# ---------------------------------------------------------------- [4/5] [5/5] 启动投屏 / Start mirroring
run_scrcpy() {
  log "[4/5] 初始化视频和音频..."
  local -a args
  # 画质优先：MAX_SIZE=0 不缩放；码率/帧率见顶部默认值
  # Quality first: MAX_SIZE=0 means no downscale; bit rate / fps come from the defaults at the top
  args=(-s "$SERIAL" --window-title "番茄短剧"
        --max-size "$MAX_SIZE" --video-bit-rate "$BIT_RATE" --max-fps "$MAX_FPS")
  if (( H265 )); then
    has_flag "--video-codec" && args+=(--video-codec=h265) \
      || warn "当前 scrcpy 不支持 --video-codec，已忽略 --h265。"
  fi

  if [[ "$MODE" == independent ]]; then
    # 虚拟屏幕：不关实体屏、不保持唤醒；FANQIE_VD 可自定义尺寸，如 1080x1920/420
    # Virtual display: don't blank the panel or force wake; FANQIE_VD sets a custom size, e.g. 1080x1920/420
    args+=("--new-display${FANQIE_VD:+=$FANQIE_VD}" --start-app="+$PKG")
  else
    args+=(--turn-screen-off --stay-awake)
    # 防休眠：--keep-active 仅较新 scrcpy 支持，按实际 --help 检测
    # Anti-sleep: --keep-active exists only in newer scrcpy; detect it from the real --help
    if has_flag "--keep-active"; then args+=(--keep-active)
    else warn "当前 scrcpy 不支持 --keep-active，无法模拟活动防休眠；建议 brew upgrade scrcpy。"; fi
    # 临时延长系统熄屏超时，scrcpy 退出时自动恢复原值
    # Temporarily extend the system screen-off timeout; scrcpy restores the original value on exit
    has_flag "--screen-off-timeout" && args+=(--screen-off-timeout 3600)
  fi

  if (( WITH_AUDIO )); then
    args+=(--audio-source="$AUDIO_SRC" --require-audio --audio-buffer="$AUDIO_BUFFER")
    [[ -n "$AUDIO_CODEC" ]] && args+=(--audio-codec="$AUDIO_CODEC")
  else
    args+=(--no-audio)
  fi
  (( DEBUG )) && args+=(--verbosity=debug)
  # 独立模式 + 守护：用 --keep-active 防止「熄屏状态下」被系统超时休眠（否则会被误判为按了电源键）
  # Independent mode + guard: --keep-active stops the idle timeout from sleeping the device while the
  # panel is off (it would otherwise be mistaken for a power-key press)
  if [[ "$MODE" == independent ]] && (( GUARD )) && guard_supported; then
    has_flag "--keep-active" && args+=(--keep-active) \
      || warn "scrcpy 不支持 --keep-active，熄屏状态下设备可能因超时休眠。"
  fi
  [[ -n "$FANQIE_SCRCPY_ARGS" ]] && args+=(${=FANQIE_SCRCPY_ARGS})
  dbg "scrcpy ${args[*]}"

  if [[ "$MODE" == independent ]]; then log "[5/5] 开始独立投屏（手机实体屏幕可自由使用）..."
  else log "[5/5] 手机熄屏，开始投屏..."; fi
  case $DRAMA_STATE in
    confirmed) log "    ✅ 已进入「$DRAMA_LABEL」板块（已确认标签处于选中状态）";;
    tapped)    log "    ⚠️  已点击「$DRAMA_LABEL」，但无法确认是否进入，请在投屏窗口检查";;
    notfound)  log "    ⚠️  未找到「$DRAMA_LABEL」入口，已停在番茄小说当前界面，请在 Mac 上手动进入短剧";;
    manual_vd) log "    ℹ️  独立显示模式不自动点击：番茄小说会打开在 Mac 窗口里，请在窗口中点一次「$DRAMA_LABEL」";;
    skipped)   log "    已跳过自动进入短剧，请在 Mac 上手动进入";;
  esac
  if (( WITH_AUDIO )); then
    if [[ "$AUDIO_SRC" == output ]]; then log "    音频：转发手机全部输出到 Mac（手机本身会静音；如不希望，可用 --audio-source playback）"
    else log "    音频：只抓取应用播放声音（若番茄小说禁止抓取，将没有声音）"; fi
  fi
  if [[ "$MODE" == independent ]]; then
    log "    说明：关闭 scrcpy 窗口或 Ctrl-C 结束；虚拟屏幕上的 App 随之关闭，手机实体屏幕不受影响。"
  else
    log "    说明：实体屏幕熄灭 ≠ 系统安全锁定，手机并未锁屏。关闭 scrcpy 窗口或按 Ctrl-C 结束。"
  fi

  start_guard
  scrcpy "${args[@]}" 2> >(tee "$TMPD/scrcpy.err" >&2)
  local rc=$?
  sleep 0.3
  if (( rc != 0 )); then
    warn "scrcpy 异常退出（代码 $rc）。"
    if grep -qiE 'audio/opus|Failed to initialize audio' "$TMPD/scrcpy.err"; then
      warn "音频编码器初始化失败：可尝试 --aac。"
    elif grep -qi 'audio' "$TMPD/scrcpy.err"; then
      warn "音频捕获失败：Android 11 需解锁后启动；个别应用/ROM 可能禁止音频捕获，此时无法转发其声音。可用 --no-audio 仅投屏画面。"
    elif (( H265 )) && grep -qiE 'h265|hevc|video' "$TMPD/scrcpy.err"; then
      warn "视频编码器初始化失败：手机可能不支持 H.265，请去掉 --h265 重试。"
    fi
    exit $rc
  fi
}

# ---------------------------------------------------------------- 参数解析与主流程 / Argument parsing & main flow
parse_args() {
  if [[ "$1" == "pair" ]]; then
    if (( $# == 3 )); then PAIR_ARGS=("$2" "$3")
    elif (( $# == 1 )); then PAIR_ARGS=()   # 交互输入 / interactive input
    else die "用法：$SELF pair [IP:配对端口 配对码]"; fi
    PAIR_MODE=1; return 0
  fi
  while (( $# )); do
    case $1 in
      -h|--help) usage; exit 0;;
      --debug) DEBUG=1;;
      --lq) MAX_SIZE=1280; BIT_RATE=6M; MAX_FPS=30;;      # 省带宽 / low bandwidth
      --hq) MAX_SIZE=0; BIT_RATE=16M; MAX_FPS=60;;        # 兼容旧选项，等同默认 / legacy alias of the default
      --h265) H265=1;;
      --no-audio) WITH_AUDIO=0;;
      --no-drama) TRY_DRAMA=0;;
      --mirror) MODE=mirror;;
      --no-guard) GUARD=0;;
      --restore-screen) RESTORE=1;;
      --audio-source) shift; [[ "$1" == output || "$1" == playback ]] || die "--audio-source 只能是 output 或 playback"; AUDIO_SRC=$1;;
      --aac) AUDIO_CODEC=aac;;
      --audio-buffer) shift; [[ "$1" =~ '^[0-9]+$' ]] || die "--audio-buffer 需要毫秒整数"; AUDIO_BUFFER=$1;;
      -s|--serial) shift; [[ -n "$1" ]] || die "$SELF: -s 需要序列号"; SERIAL_ARG=$1;;
      -*) die "未知选项：$1（见 --help）";;
      *) is_ipport "$1" || die "参数格式错误：'$1'，应为 IP:端口"
         [[ -z "$ADDR_ARG" ]] || die "只能指定一个 IP:端口"; ADDR_ARG=$1;;
    esac
    shift
  done
}

main() {
  parse_args "$@"
  TMPD=$(mktemp -d) || die "无法创建临时目录"
  if (( PAIR_MODE )); then
    install_deps
    if (( ${#PAIR_ARGS} == 2 )); then pair_device "${PAIR_ARGS[@]}" || exit 1
    else is_interactive || die "无交互终端，请使用：$SELF pair IP:配对端口 配对码"; prompt_pair || exit 1; fi
    log "现在直接运行 $SELF 即可自动连接。"
    exit 0
  fi
  check_tools
  connect_phone
  if (( RESTORE )); then restore_screen; exit 0; fi
  launch_app
  run_scrcpy
}

# 测试时可 source 本文件而不执行 main / Set MIRROR_FANQIE_SOURCE_ONLY to source without running main
[[ -n "$MIRROR_FANQIE_SOURCE_ONLY" ]] || main "$@"
