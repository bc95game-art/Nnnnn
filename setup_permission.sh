#!/data/data/com.termux/files/usr/bin/bash
# ==============================
# تنظیم پروکسی خودکار
# ==============================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

test_proxy_permission() {
    if settings put global http_proxy "127.0.0.1:8080" 2>/dev/null; then
        settings delete global http_proxy 2>/dev/null
        return 0
    fi
    return 1
}

connect_adb() {
    echo ""
    echo -e "${CYAN}مراحل:${NC}"
    echo -e "  ۱. تنظیمات ← درباره گوشی ← ۷ بار روی شماره ساخت"
    echo -e "  ۲. تنظیمات ← گزینه‌های توسعه‌دهنده"
    echo -e "  ۳. اشکال‌زدایی بی‌سیم را روشن کنید"
    echo -e "  ۴. روی آن بزنید ← جفت‌سازی با کد"
    echo ""
    read -rp "پورت جفت‌سازی: " PAIR_PORT
    read -rp "کد جفت‌سازی: " PAIR_CODE

    pkg install -y android-tools 2>/dev/null | tail -1
    adb pair "127.0.0.1:$PAIR_PORT" "$PAIR_CODE" 2>&1

    echo ""
    echo -e "${YELLOW}برگردید به صفحه اصلی اشکال‌زدایی بی‌سیم — پورت کنار آدرس IP:${NC}"
    read -rp "پورت اتصال: " CONN_PORT
    adb connect "127.0.0.1:$CONN_PORT" 2>&1
    sleep 1
}

clear
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   تنظیم پروکسی خودکار                   ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""

echo -e "${CYAN}بررسی وضعیت...${NC}"

# روش ۱: اجازه مستقیم
if test_proxy_permission; then
    echo -e "${GREEN}✅ اجازه از قبل موجود است!${NC}"
    echo -e "اجرا کنید: ${YELLOW}bash run.sh${NC}"
    exit 0
fi

# روش ۲: روت
if command -v su &>/dev/null; then
    if su -c "settings put global http_proxy '127.0.0.1:8080'" 2>/dev/null; then
        su -c "settings delete global http_proxy" 2>/dev/null
        echo -e "${GREEN}✅ روت — کار می‌کند!${NC}"
        echo -e "اجرا کنید: ${YELLOW}bash run.sh${NC}"
        exit 0
    fi
fi

# روش ۳: ADB shell مستقیم (بدون grant)
echo ""
echo -e "${YELLOW}گزینه:${NC}"
echo -e "  ${YELLOW}1${NC}  ADB بی‌سیم (از همین گوشی — اندروید ۱۱+)"
echo -e "  ${YELLOW}2${NC}  ADB از PC"
echo ""
read -rp "انتخاب [1/2]: " OPT

# اگر ADB از قبل وصل است تست می‌کنیم
if command -v adb &>/dev/null && adb devices 2>/dev/null | grep -q "device$"; then
    echo -e "${CYAN}ADB از قبل وصل است — تست...${NC}"
else
    if [ "$OPT" = "1" ]; then
        connect_adb
    else
        echo ""
        echo -e "روی PC بزنید:"
        echo -e "  ${YELLOW}adb shell pm grant com.termux android.permission.WRITE_SECURE_SETTINGS${NC}"
        read -rp "بعد Enter بزنید..." _
    fi
fi

# ── تنظیم پروکسی مستقیم از طریق ADB shell ──
echo ""
echo -e "${CYAN}تنظیم پروکسی از طریق ADB...${NC}"
ADB_RESULT=$(adb shell settings put global http_proxy 127.0.0.1:8080 2>&1)

if [ -z "$ADB_RESULT" ] || echo "$ADB_RESULT" | grep -q "^$"; then
    echo -e "${GREEN}✅ پروکسی از طریق ADB تنظیم شد!${NC}"
    adb shell settings delete global http_proxy 2>/dev/null
    
    # حالا grant هم بدهیم
    adb shell pm grant com.termux android.permission.WRITE_SECURE_SETTINGS 2>/dev/null || true
    
    if test_proxy_permission; then
        echo -e "${GREEN}✅ Termux هم اجازه گرفت — کاملاً خودکار!${NC}"
    else
        echo -e "${YELLOW}⚠️  Termux اجازه نگرفت — ولی ADB کار می‌کند.${NC}"
        echo -e "${YELLOW}    run.sh از ADB استفاده می‌کند.${NC}"
    fi
    
    echo ""
    echo -e "اجرا کنید: ${YELLOW}bash run.sh${NC}"
else
    echo -e "${RED}❌ ADB هم کار نکرد: $ADB_RESULT${NC}"
    echo ""
    echo -e "${YELLOW}راه‌حل: WiFi را دستی تنظیم کنید:${NC}"
    echo -e "  تنظیمات WiFi ← پروکسی دستی"
    echo -e "  آدرس: 127.0.0.1"
    echo -e "  پورت: 8080"
    echo ""
    echo -e "سپس: ${YELLOW}bash run.sh${NC}"
fi
