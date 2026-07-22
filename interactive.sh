#!/data/data/com.termux/files/usr/bin/bash
# ==============================
# Shad Link Extractor — حالت تعاملی (روش ۲)
# ==============================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

LOG_DIR="$HOME/shad-extractor/logs"
mkdir -p "$LOG_DIR"
INTERACTIVE_LOG="$LOG_DIR/interactive.txt"
DATE=$(date +"%Y-%m-%d %H:%M:%S")

extract_links() {
    local input="$1"
    echo "$input" | grep -oP '(https?|ftp|shad|shadmessenger|irshad|danesh)://[^\s\'"<>\{\}\[\]\\]+' | sort -u
}

analyze_deep_link() {
    local url="$1"
    echo -e "\n${CYAN}📊 تحلیل لینک:${NC}"
    echo -e "  ${YELLOW}لینک کامل:${NC} $url"

    # استخراج پروتکل
    proto=$(echo "$url" | grep -oP '^[a-zA-Z][a-zA-Z0-9+\-.]*(?=://)')
    echo -e "  ${YELLOW}پروتکل:${NC} $proto"

    # استخراج host
    host=$(echo "$url" | grep -oP '(?<=://)([^/?#]+)')
    echo -e "  ${YELLOW}آدرس:${NC} $host"

    # استخراج path
    path=$(echo "$url" | grep -oP '(?<=://)[^/?#]+\K(/[^?#]*)?')
    [ -n "$path" ] && echo -e "  ${YELLOW}مسیر:${NC} $path"

    # استخراج پارامترها
    params=$(echo "$url" | grep -oP '\?.*')
    if [ -n "$params" ]; then
        echo -e "  ${YELLOW}پارامترها:${NC}"
        echo "$params" | tr '&' '\n' | sed 's/^?//' | while read -r param; do
            echo -e "    ${GREEN}▸${NC} $param"
        done
    fi

    # ذخیره
    echo "[$DATE] $url" >> "$INTERACTIVE_LOG"
    echo -e "\n  ${GREEN}✅ در لاگ ذخیره شد${NC}"
}

watch_clipboard() {
    echo -e "${CYAN}👀 در حال پایش Clipboard...${NC}"
    echo -e "${YELLOW}لینک را در شاد کپی کنید. برای توقف Ctrl+C بزنید.${NC}\n"
    
    LAST=""
    while true; do
        CLIP=$(termux-clipboard-get 2>/dev/null)
        if [ "$CLIP" != "$LAST" ] && [ -n "$CLIP" ]; then
            LINKS=$(extract_links "$CLIP")
            if [ -n "$LINKS" ]; then
                echo -e "\n${GREEN}🔗 لینک جدید در Clipboard:${NC}"
                echo "$LINKS" | while read -r link; do
                    analyze_deep_link "$link"
                done
            fi
            LAST="$CLIP"
        fi
        sleep 1
    done
}

main_menu() {
    while true; do
        clear
        echo -e "${GREEN}╔══════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║   🔗 Shad Link Extractor             ║${NC}"
        echo -e "${GREEN}║   حالت تعاملی                        ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${CYAN}گزینه‌ها:${NC}"
        echo -e "  ${YELLOW}[1]${NC} پایش خودکار Clipboard (لینک را در شاد کپی کنید)"
        echo -e "  ${YELLOW}[2]${NC} وارد کردن لینک دستی"
        echo -e "  ${YELLOW}[3]${NC} مشاهده لینک‌های ذخیره‌شده"
        echo -e "  ${YELLOW}[4]${NC} خروجی به دانلودها"
        echo -e "  ${YELLOW}[5]${NC} خروج"
        echo ""
        read -rp "انتخاب کنید: " opt

        case "$opt" in
            1)
                watch_clipboard
                ;;
            2)
                echo ""
                read -rp "لینک را اینجا جای‌گذاری کنید: " manual_url
                if [ -n "$manual_url" ]; then
                    LINKS=$(extract_links "$manual_url")
                    if [ -n "$LINKS" ]; then
                        echo "$LINKS" | while read -r link; do
                            analyze_deep_link "$link"
                        done
                    else
                        echo -e "${RED}❌ لینکی یافت نشد.${NC}"
                    fi
                fi
                read -rp "Enter بزنید..." _
                ;;
            3)
                echo ""
                if [ -f "$INTERACTIVE_LOG" ]; then
                    echo -e "${CYAN}لینک‌های ذخیره‌شده:${NC}"
                    cat "$INTERACTIVE_LOG"
                else
                    echo -e "${RED}هنوز لینکی ذخیره نشده.${NC}"
                fi
                read -rp "Enter بزنید..." _
                ;;
            4)
                DOWNLOAD_DIR="$HOME/storage/downloads"
                DATE2=$(date +"%Y%m%d_%H%M%S")
                EXPORT="$DOWNLOAD_DIR/shad_links_interactive_$DATE2.txt"
                if [ -f "$INTERACTIVE_LOG" ]; then
                    cp "$INTERACTIVE_LOG" "$EXPORT"
                    echo -e "${GREEN}✅ ذخیره شد: $EXPORT${NC}"
                else
                    echo -e "${RED}❌ هنوز لینکی ذخیره نشده.${NC}"
                fi
                read -rp "Enter بزنید..." _
                ;;
            5)
                echo -e "${GREEN}خداحافظ!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}گزینه نامعتبر${NC}"
                sleep 1
                ;;
        esac
    done
}

# بررسی termux-api
if ! command -v termux-clipboard-get &>/dev/null; then
    echo -e "${YELLOW}⚠️  برای روش Clipboard، Termux:API هم نصب کنید:${NC}"
    echo -e "  pkg install termux-api"
    echo ""
fi

main_menu
