#!/data/data/com.termux/files/usr/bin/bash
# ==============================
# یک‌بار اجرا کنید تا پروکسی خودکار کار کند
# ==============================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

clear
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   تنظیم اجازه پروکسی خودکار             ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""

# ── بررسی وضعیت فعلی ──
echo -e "${CYAN}بررسی وضعیت...${NC}"

# روش ۱: آیا از قبل اجازه داریم؟
if settings put global http_proxy "127.0.0.1:8080" 2>/dev/null; then
    settings delete global http_proxy 2>/dev/null
    echo -e "${GREEN}✅ اجازه از قبل موجود است — نیازی به کار اضافه نیست!${NC}"
    echo -e "هم‌اکنون ${YELLOW}bash run.sh${NC} را اجرا کنید."
    exit 0
fi

# روش ۲: روت
if command -v su &>/dev/null; then
    if su -c "settings put global http_proxy '127.0.0.1:8080' && settings delete global http_proxy" 2>/dev/null; then
        echo -e "${GREEN}✅ روت تشخیص داده شد — پروکسی خودکار کار می‌کند!${NC}"
        echo -e "هم‌اکنون ${YELLOW}bash run.sh${NC} را اجرا کنید."
        exit 0
    fi
fi

# روش ۳: ADB wireless
echo -e "${YELLOW}برای تنظیم خودکار، یکی از دو مسیر را انتخاب کنید:${NC}"
echo ""
echo -e "  ${YELLOW}1${NC}  ADB بی‌سیم (از همین گوشی — اندروید ۱۱+)"
echo -e "  ${YELLOW}2${NC}  ADB از PC (یک‌بار با کابل)"
echo ""
read -rp "انتخاب [1/2]: " OPT

if [ "$OPT" = "1" ]; then
    echo ""
    echo -e "${CYAN}مراحل:${NC}"
    echo -e "  ۱. تنظیمات ← درباره گوشی ← ۷ بار روی شماره ساخت ضربه بزنید"
    echo -e "  ۲. تنظیمات ← گزینه‌های توسعه‌دهنده"
    echo -e "  ۳. ${YELLOW}اشکال‌زدایی بی‌سیم${NC} را روشن کنید"
    echo -e "  ۴. روی آن ضربه بزنید ← ${YELLOW}با کد QR جفت کنید${NC}"
    echo ""
    read -rp "پورت جفت‌سازی را وارد کنید (از صفحه اشکال‌زدایی): " PAIR_PORT
    read -rp "کد جفت‌سازی را وارد کنید: " PAIR_CODE

    if [ -n "$PAIR_PORT" ] && [ -n "$PAIR_CODE" ]; then
        pkg install -y android-tools 2>/dev/null
        adb pair "127.0.0.1:$PAIR_PORT" "$PAIR_CODE"
        sleep 1
        # پورت اتصال را بگیریم
        read -rp "پورت اتصال ADB را وارد کنید (از همان صفحه): " CONN_PORT
        adb connect "127.0.0.1:$CONN_PORT"
        sleep 1
        _grant_permission
    fi

elif [ "$OPT" = "2" ]; then
    echo ""
    echo -e "${CYAN}روی PC این دستور را بزنید:${NC}"
    echo ""
    echo -e "  ${YELLOW}adb shell pm grant com.termux android.permission.WRITE_SECURE_SETTINGS${NC}"
    echo ""
    echo -e "بعد Enter بزنید تا تست کنیم..."
    read -r _
    _grant_permission
fi

_grant_permission() {
    # تلاش برای گرفتن اجازه از طریق ADB
    adb shell pm grant com.termux android.permission.WRITE_SECURE_SETTINGS 2>/dev/null

    # تست نهایی
    if settings put global http_proxy "127.0.0.1:8080" 2>/dev/null; then
        settings delete global http_proxy 2>/dev/null
        echo ""
        echo -e "${GREEN}✅ موفق! پروکسی خودکار از این به بعد کار می‌کند.${NC}"
        echo -e "هم‌اکنون ${YELLOW}bash run.sh${NC} را اجرا کنید."
    else
        echo -e "${RED}❌ هنوز کار نمی‌کند. WiFi را دستی تنظیم کنید.${NC}"
    fi
}
