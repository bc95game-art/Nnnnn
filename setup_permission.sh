#!/data/data/com.termux/files/usr/bin/bash
# ==============================
# یک‌بار اجرا کنید تا پروکسی خودکار کار کند
# ==============================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# ── تابع گرفتن اجازه — باید اول تعریف شود ──
grant_permission() {
    adb shell pm grant com.termux android.permission.WRITE_SECURE_SETTINGS 2>/dev/null || true

    if settings put global http_proxy "127.0.0.1:8080" 2>/dev/null; then
        settings delete global http_proxy 2>/dev/null
        echo ""
        echo -e "${GREEN}✅ موفق! پروکسی خودکار از این به بعد کار می‌کند.${NC}"
        echo -e "هم‌اکنون: ${YELLOW}bash run.sh${NC}"
    else
        echo -e "${RED}❌ هنوز کار نمی‌کند.${NC}"
        echo -e "${YELLOW}WiFi را دستی تنظیم کنید: آدرس 127.0.0.1 | پورت 8080${NC}"
    fi
}

clear
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   تنظیم اجازه پروکسی خودکار             ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""

echo -e "${CYAN}بررسی وضعیت...${NC}"

# روش ۱: آیا از قبل اجازه داریم؟
if settings put global http_proxy "127.0.0.1:8080" 2>/dev/null; then
    settings delete global http_proxy 2>/dev/null
    echo -e "${GREEN}✅ اجازه از قبل موجود است!${NC}"
    echo -e "هم‌اکنون: ${YELLOW}bash run.sh${NC}"
    exit 0
fi

# روش ۲: روت
if command -v su &>/dev/null; then
    if su -c "settings put global http_proxy '127.0.0.1:8080' && settings delete global http_proxy" 2>/dev/null; then
        echo -e "${GREEN}✅ روت — پروکسی خودکار کار می‌کند!${NC}"
        echo -e "هم‌اکنون: ${YELLOW}bash run.sh${NC}"
        exit 0
    fi
fi

# روش ۳: ADB
echo ""
echo -e "${YELLOW}یکی را انتخاب کنید:${NC}"
echo ""
echo -e "  ${YELLOW}1${NC}  ADB بی‌سیم (از همین گوشی — اندروید ۱۱+)"
echo -e "  ${YELLOW}2${NC}  ADB از PC (یک‌بار با کابل)"
echo ""
read -rp "انتخاب [1/2]: " OPT

if [ "$OPT" = "1" ]; then
    echo ""
    echo -e "${CYAN}مراحل:${NC}"
    echo -e "  ۱. تنظیمات ← درباره گوشی ← ۷ بار روی شماره ساخت"
    echo -e "  ۲. تنظیمات ← گزینه‌های توسعه‌دهنده"
    echo -e "  ۳. اشکال‌زدایی بی‌سیم را روشن کنید"
    echo -e "  ۴. روی آن بزنید ← جفت‌سازی با کد"
    echo ""
    read -rp "پورت جفت‌سازی: " PAIR_PORT
    read -rp "کد جفت‌سازی: " PAIR_CODE

    if [ -n "$PAIR_PORT" ] && [ -n "$PAIR_CODE" ]; then
        pkg install -y android-tools 2>/dev/null || true
        adb pair "127.0.0.1:$PAIR_PORT" "$PAIR_CODE"
        sleep 1
        echo ""
        echo -e "${CYAN}حالا پورت اتصال را وارد کنید${NC}"
        echo -e "${YELLOW}(از صفحه اصلی اشکال‌زدایی بی‌سیم — نه پورت جفت‌سازی)${NC}"
        read -rp "پورت اتصال: " CONN_PORT
        adb connect "127.0.0.1:$CONN_PORT"
        sleep 1
        grant_permission
    fi

elif [ "$OPT" = "2" ]; then
    echo ""
    echo -e "${CYAN}روی PC بزنید:${NC}"
    echo ""
    echo -e "  ${YELLOW}adb shell pm grant com.termux android.permission.WRITE_SECURE_SETTINGS${NC}"
    echo ""
    read -rp "بعد از اجرا Enter بزنید..." _
    grant_permission
fi
