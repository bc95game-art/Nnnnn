#!/data/data/com.termux/files/usr/bin/bash
# ==============================
# Shad Link Extractor — اجرا
# با پشتیبانی از V2Ray / Xray
# ==============================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$HOME/shad-extractor/logs"
mkdir -p "$LOG_DIR"

V2RAY_PID_FILE="$HOME/shad-extractor/.v2ray.pid"
MITM_PID_FILE="$HOME/shad-extractor/.mitm.pid"
V2RAY_CONFIG="$HOME/shad-extractor/v2ray_config.json"
SOCKS_PORT=1080
MITM_PORT=8080

# ── پاک‌سازی هنگام خروج ──
cleanup() {
    echo ""
    echo -e "${YELLOW}در حال توقف سرویس‌ها...${NC}"
    if [ -f "$V2RAY_PID_FILE" ]; then
        kill "$(cat "$V2RAY_PID_FILE")" 2>/dev/null
        rm -f "$V2RAY_PID_FILE"
        echo -e "  ${GREEN}✅ V2Ray متوقف شد${NC}"
    fi
    if [ -f "$MITM_PID_FILE" ]; then
        kill "$(cat "$MITM_PID_FILE")" 2>/dev/null
        rm -f "$MITM_PID_FILE"
    fi
    echo -e "${GREEN}برای خروجی لینک‌ها: ${YELLOW}bash export_links.sh${NC}"
    exit 0
}
trap cleanup SIGINT SIGTERM

# ─────────────────────────────────────────
# تابع: راه‌اندازی V2Ray
# ─────────────────────────────────────────

start_v2ray() {
    local link="$1"

    # شناسایی باینری
    V2RAY_BIN=""
    if [ -f "$HOME/shad-extractor/.v2ray_bin" ]; then
        V2RAY_BIN=$(cat "$HOME/shad-extractor/.v2ray_bin")
    fi
    if [ -z "$V2RAY_BIN" ] || ! command -v "$V2RAY_BIN" &>/dev/null; then
        if command -v xray  &>/dev/null; then V2RAY_BIN="xray";
        elif command -v v2ray &>/dev/null; then V2RAY_BIN="v2ray";
        else
            echo -e "${RED}❌ xray/v2ray نصب نیست. اجرا کنید: bash install_v2ray.sh${NC}"
            return 1
        fi
    fi

    echo -e "${CYAN}🔧 پارس لینک V2Ray...${NC}"
    RESULT=$(python3 "$SCRIPT_DIR/v2ray_proxy.py" "$link" "$SOCKS_PORT" 1081 2>&1)

    if echo "$RESULT" | grep -q "^ERR|"; then
        ERR_MSG=$(echo "$RESULT" | sed 's/^ERR|//')
        echo -e "${RED}❌ خطا در پارس لینک: $ERR_MSG${NC}"
        return 1
    fi

    # اطلاعات سرور
    PROTO=$(echo "$RESULT"  | cut -d'|' -f2)
    SERVER=$(echo "$RESULT" | cut -d'|' -f3)
    NAME=$(echo "$RESULT"   | cut -d'|' -f4)

    echo -e "${GREEN}✅ سرور: ${YELLOW}${NAME}${NC} — $PROTO — $SERVER"

    # اجرای v2ray در پس‌زمینه
    "$V2RAY_BIN" run -config "$V2RAY_CONFIG" > "$LOG_DIR/v2ray.log" 2>&1 &
    V2RAY_PID=$!
    echo "$V2RAY_PID" > "$V2RAY_PID_FILE"

    # انتظار برای آماده شدن
    sleep 2
    if ! kill -0 "$V2RAY_PID" 2>/dev/null; then
        echo -e "${RED}❌ V2Ray راه‌اندازی نشد. لاگ:${NC}"
        tail -5 "$LOG_DIR/v2ray.log"
        return 1
    fi

    echo -e "${GREEN}✅ V2Ray فعال — SOCKS5 روی 127.0.0.1:${SOCKS_PORT}${NC}"
    return 0
}

# ─────────────────────────────────────────
# شروع اصلی
# ─────────────────────────────────────────

clear
echo -e "${GREEN}╔══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   🔗 Shad Link Extractor             ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════╝${NC}"
echo ""

# بررسی mitmproxy
if ! command -v mitmdump &>/dev/null; then
    echo -e "${RED}❌ mitmproxy نصب نیست. اول: bash install.sh${NC}"
    exit 1
fi

# ── انتخاب حالت پروکسی ──
echo -e "${CYAN}آیا می‌خواهید ترافیک از طریق V2Ray عبور کند؟${NC}"
echo -e "  ${YELLOW}1${NC} - بله، لینک V2Ray دارم"
echo -e "  ${YELLOW}2${NC} - خیر، اتصال مستقیم"
echo ""
read -rp "انتخاب [1/2]: " MODE

USE_V2RAY=0

if [ "$MODE" = "1" ]; then
    echo ""
    echo -e "${CYAN}لینک V2Ray را وارد کنید:${NC}"
    echo -e "(پشتیبانی از: vmess:// | vless:// | trojan:// | ss://)"
    echo ""
    read -rp "لینک: " V2RAY_LINK

    if [ -z "$V2RAY_LINK" ]; then
        echo -e "${YELLOW}⚠️ لینک خالی — ادامه با اتصال مستقیم${NC}"
    else
        if start_v2ray "$V2RAY_LINK"; then
            USE_V2RAY=1
        else
            echo -e "${YELLOW}⚠️ خطا در V2Ray — ادامه با اتصال مستقیم${NC}"
        fi
    fi
fi

# ── آدرس برای تنظیم WiFi ──
LOCAL_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7}' | head -1)
[ -z "$LOCAL_IP" ] && LOCAL_IP="127.0.0.1"

echo ""
echo -e "${YELLOW}┌─────────────────────────────────────┐${NC}"
echo -e "${YELLOW}│  تنظیم WiFi گوشی:                  │${NC}"
echo -e "${YELLOW}│  آدرس پروکسی: $LOCAL_IP          │${NC}"
echo -e "${YELLOW}│  پورت        : $MITM_PORT                │${NC}"
if [ "$USE_V2RAY" = "1" ]; then
echo -e "${YELLOW}│  🔒 V2Ray فعال — ترافیک رمزشده     │${NC}"
fi
echo -e "${YELLOW}└─────────────────────────────────────┘${NC}"
echo ""

if [ -z "$(ls "$LOG_DIR/mitmproxy-ca-cert.pem" 2>/dev/null)" ] && \
   [ -z "$(ls "$HOME/.mitmproxy/mitmproxy-ca-cert.pem" 2>/dev/null)" ]; then
    echo -e "${YELLOW}💡 اگر اول بار است: bash install_cert.sh${NC}"
    echo ""
fi

echo -e "${GREEN}▶ در حال ضبط... برای توقف Ctrl+C${NC}"
echo -e "${CYAN}──────────────────────────────────────────${NC}"

# ── اجرای mitmproxy ──
if [ "$USE_V2RAY" = "1" ]; then
    # ترافیک از طریق V2Ray
    mitmdump \
        --listen-host 0.0.0.0 \
        --listen-port "$MITM_PORT" \
        --mode "upstream:socks5h://127.0.0.1:${SOCKS_PORT}" \
        --script "$SCRIPT_DIR/shad_capture.py" \
        --ssl-insecure \
        --set flow_detail=1 \
        2>&1
else
    # اتصال مستقیم
    mitmdump \
        --listen-host 0.0.0.0 \
        --listen-port "$MITM_PORT" \
        --script "$SCRIPT_DIR/shad_capture.py" \
        --set flow_detail=1 \
        2>&1
fi
