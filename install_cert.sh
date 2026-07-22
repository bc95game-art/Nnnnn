#!/data/data/com.termux/files/usr/bin/bash
# ==============================
# نصب گواهی SSL برای mitmproxy
# ==============================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}  نصب گواهی SSL${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""

CERT_DIR="$HOME/.mitmproxy"

# اول باید mitmproxy یک بار اجرا شود تا گواهی بسازد
if [ ! -f "$CERT_DIR/mitmproxy-ca-cert.pem" ]; then
    echo -e "${YELLOW}در حال ساخت گواهی...${NC}"
    mitmdump --listen-port 8888 &
    MITM_PID=$!
    sleep 3
    kill $MITM_PID 2>/dev/null
fi

if [ ! -f "$CERT_DIR/mitmproxy-ca-cert.pem" ]; then
    echo -e "${RED}❌ خطا در ساخت گواهی. مطمئن شوید mitmproxy نصب است.${NC}"
    exit 1
fi

# کپی گواهی به دانلودها
CERT_DEST="$HOME/storage/downloads/mitmproxy-cert.pem"
cp "$CERT_DIR/mitmproxy-ca-cert.pem" "$CERT_DEST"

echo -e "${GREEN}✅ گواهی در دانلودها ذخیره شد:${NC}"
echo -e "   $CERT_DEST"
echo ""
echo -e "${CYAN}مراحل نصب روی اندروید:${NC}"
echo -e "${YELLOW}─────────────────────────────────────${NC}"
echo -e "۱. فایل مدیر (Files) گوشی را باز کنید"
echo -e "۲. به پوشه‌ی دانلودها بروید"
echo -e "۳. روی فایل ${YELLOW}mitmproxy-cert.pem${NC} ضربه بزنید"
echo -e "۴. اگر پرسیده شد: نام گواهی را ${YELLOW}mitmproxy${NC} بگذارید"
echo -e "۵. نوع استفاده: ${YELLOW}VPN و برنامه‌ها${NC}"
echo -e "۶. تأیید را بزنید"
echo ""
echo -e "${YELLOW}─────────────────────────────────────${NC}"
echo -e "${CYAN}اگر روی اندروید ۱۴+ هستید:${NC}"
echo -e "تنظیمات ← امنیت ← رمزگذاری و اعتبارنامه"
echo -e "← نصب گواهی ← CA Certificate"
echo ""
echo -e "${GREEN}بعد از نصب گواهی، دوباره:${NC}"
echo -e "  ${YELLOW}bash run.sh${NC}"
