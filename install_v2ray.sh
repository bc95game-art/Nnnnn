#!/data/data/com.termux/files/usr/bin/bash
# ==============================
# نصب V2Ray / Xray در Termux
# ==============================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}  نصب V2Ray / Xray${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""

# اول xray را امتحان می‌کنیم (نسخه جدیدتر)، بعد v2ray
V2RAY_BIN=""

echo -e "${YELLOW}[۱/۳] جستجوی xray یا v2ray...${NC}"

if command -v xray &>/dev/null; then
    V2RAY_BIN="xray"
    echo -e "${GREEN}✅ xray از قبل نصب است: $(xray version 2>&1 | head -1)${NC}"
elif command -v v2ray &>/dev/null; then
    V2RAY_BIN="v2ray"
    echo -e "${GREEN}✅ v2ray از قبل نصب است: $(v2ray version 2>&1 | head -1)${NC}"
else
    echo -e "${YELLOW}[۲/۳] در حال نصب...${NC}"
    pkg install -y xray 2>/dev/null && V2RAY_BIN="xray"
    if [ -z "$V2RAY_BIN" ]; then
        pkg install -y v2ray 2>/dev/null && V2RAY_BIN="v2ray"
    fi
    if [ -z "$V2RAY_BIN" ]; then
        echo -e "${RED}❌ نصب خودکار ناموفق بود.${NC}"
        echo -e "دستی نصب کنید: ${YELLOW}pkg install xray${NC}"
        exit 1
    fi
fi

echo -e "${YELLOW}[۳/۳] ذخیره نام باینری...${NC}"
mkdir -p ~/shad-extractor
echo "$V2RAY_BIN" > ~/shad-extractor/.v2ray_bin

echo ""
echo -e "${GREEN}✅ آماده! باینری: $V2RAY_BIN${NC}"
echo ""
echo -e "برای شروع با V2Ray: ${YELLOW}bash run.sh${NC}"
echo -e "و لینک خود را وارد کنید."
