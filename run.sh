#!/data/data/com.termux/files/usr/bin/bash
# ==============================
# Shad Link Extractor — اجرا
# ==============================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$HOME/shad-extractor/logs"
mkdir -p "$LOG_DIR"

clear
echo -e "${GREEN}╔══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   🔗 Shad Link Extractor             ║${NC}"
echo -e "${GREEN}║   ابزار استخراج لینک شاد             ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════╝${NC}"
echo ""

# بررسی نصب mitmproxy
if ! command -v mitmdump &> /dev/null; then
    echo -e "${RED}❌ mitmproxy نصب نیست. اول install.sh را اجرا کنید${NC}"
    exit 1
fi

LOCAL_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7}' | head -1)
if [ -z "$LOCAL_IP" ]; then
    LOCAL_IP="127.0.0.1"
fi

echo -e "${CYAN}📡 پروکسی روی پورت 8080 راه‌اندازی می‌شود...${NC}"
echo ""
echo -e "${YELLOW}┌─────────────────────────────────────┐${NC}"
echo -e "${YELLOW}│  تنظیم WiFi گوشی:                  │${NC}"
echo -e "${YELLOW}│  آدرس پروکسی : $LOCAL_IP          │${NC}"
echo -e "${YELLOW}│  پورت        : 8080                │${NC}"
echo -e "${YELLOW}└─────────────────────────────────────┘${NC}"
echo ""
echo -e "${CYAN}💡 راهنما:${NC}"
echo -e "  ۱. WiFi ← شبکه‌ی متصل ← پیشرفته"
echo -e "  ۲. پروکسی: دستی (Manual)"
echo -e "  ۳. آدرس: $LOCAL_IP"
echo -e "  ۴. پورت: 8080"
echo ""
echo -e "  اگر اول بار است: ${YELLOW}bash install_cert.sh${NC} را هم اجرا کنید"
echo ""
echo -e "${GREEN}▶ در حال ضبط... برای توقف Ctrl+C بزنید${NC}"
echo -e "${CYAN}─────────────────────────────────────────${NC}"
echo ""

# اجرای mitmproxy
mitmdump \
    --listen-host 0.0.0.0 \
    --listen-port 8080 \
    --script "$SCRIPT_DIR/shad_capture.py" \
    --set flow_detail=1 \
    2>&1

echo ""
echo -e "${GREEN}✅ ضبط متوقف شد.${NC}"
echo -e "برای مشاهده لینک‌ها: ${YELLOW}bash export_links.sh${NC}"
