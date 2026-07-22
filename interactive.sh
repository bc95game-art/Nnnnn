#!/data/data/com.termux/files/usr/bin/bash
# ==============================
# Shad Link Extractor — حالت تعاملی (روش ۲)
# ==============================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

LOG_DIR="$HOME/shad-extractor/logs"
mkdir -p "$LOG_DIR"
INTERACTIVE_LOG="$LOG_DIR/interactive.txt"

URL_PATTERN='https?://[^[:space:]"'"'"'<>{}\\]+'
DEEP_PATTERN='[a-zA-Z][a-zA-Z0-9+\-.]*://[^[:space:]"'"'"'<>{}\\]+'

extract_links() {
    local input="$1"
    echo "$input" | grep -oE "$URL_PATTERN" | sort -u
}

extract_deep_links() {
    local input="$1"
    echo "$input" | grep -oE "$DEEP_PATTERN" | grep -vE '^https?://' | sort -u
}

analyze_link() {
    local url="$1"
    local ts
    ts=$(date +"%Y-%m-%d %H:%M:%S")

    echo -e "\n${CYAN}────────────────────────────────────────${NC}"
    echo -e "${GREEN}🔗 لینک یافت شد:${NC}"
    echo -e "  ${YELLOW}${url}${NC}"

    proto=$(echo "$url" | grep -oE '^[a-zA-Z][a-zA-Z0-9+\-.]*(?=://)')
    echo -e "  پروتکل : $proto"

    host=$(echo "$url" | sed 's|.*://||' | cut -d'/' -f1 | cut -d'?' -f1)
    echo -e "  آدرس   : $host"

    path=$(echo "$url" | sed 's|.*://[^/]*||' | cut -d'?' -f1)
    [ -n "$path" ] && echo -e "  مسیر   : $path"

    params=$(echo "$url" | grep -oE '\?.*')
    if [ -n "$params" ]; then
        echo -e "  پارامترها:"
        echo "$params" | tr '&?' '\n' | grep '=' | while IFS='=' read -r key val; do
            echo -e "    ${GREEN}▸${NC} $key = $val"
        done
    fi

    echo "[$ts] $url" >> "$INTERACTIVE_LOG"
    echo -e "${GREEN}  ✅ ذخیره شد${NC}"
    echo -e "${CYAN}────────────────────────────────────────${NC}"
}

watch_clipboard() {
    echo -e "${CYAN}در حال پایش Clipboard...${NC}"
    echo -e "${YELLOW}لینک را در شاد کپی کنید. برای توقف Ctrl+C بزنید.${NC}\n"

    LAST=""
    while true; do
        CLIP=$(termux-clipboard-get 2>/dev/null)
        if [ -n "$CLIP" ] && [ "$CLIP" != "$LAST" ]; then
            extract_links "$CLIP" | while read -r link; do
                analyze_link "$link"
            done
            extract_deep_links "$CLIP" | while read -r link; do
                analyze_link "$link"
            done
            LAST="$CLIP"
        fi
        sleep 1
    done
}

manual_entry() {
    echo ""
    echo -e "${YELLOW}لینک یا متن حاوی لینک را وارد کنید:${NC}"
    read -r input
    if [ -z "$input" ]; then
        return
    fi

    found=0
    while read -r link; do
        analyze_link "$link"
        found=1
    done < <(extract_links "$input")

    while read -r link; do
        analyze_link "$link"
        found=1
    done < <(extract_deep_links "$input")

    if [ "$found" -eq 0 ]; then
        echo -e "${RED}❌ هیچ لینکی در متن یافت نشد.${NC}"
    fi

    read -rp "Enter بزنید..." _
}

view_saved() {
    echo ""
    if [ -f "$INTERACTIVE_LOG" ] && [ -s "$INTERACTIVE_LOG" ]; then
        COUNT=$(wc -l < "$INTERACTIVE_LOG")
        echo -e "${CYAN}لینک‌های ذخیره‌شده (${COUNT} مورد):${NC}"
        cat "$INTERACTIVE_LOG"
    else
        echo -e "${RED}هنوز لینکی ذخیره نشده.${NC}"
    fi
    read -rp "Enter بزنید..." _
}

export_to_downloads() {
    DLOAD="$HOME/storage/downloads"
    DATE=$(date +"%Y%m%d_%H%M%S")
    OUT="$DLOAD/shad_interactive_${DATE}.txt"
    if [ -f "$INTERACTIVE_LOG" ] && [ -s "$INTERACTIVE_LOG" ]; then
        cp "$INTERACTIVE_LOG" "$OUT"
        echo -e "${GREEN}✅ ذخیره شد: $OUT${NC}"
    else
        echo -e "${RED}❌ هنوز لینکی ذخیره نشده.${NC}"
    fi
    read -rp "Enter بزنید..." _
}

main_menu() {
    while true; do
        clear
        echo -e "${GREEN}╔══════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║   Shad Link Extractor                ║${NC}"
        echo -e "${GREEN}║   حالت تعاملی                        ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${CYAN}گزینه‌ها:${NC}"
        echo -e "  ${YELLOW}1${NC} - پایش Clipboard شاد"
        echo -e "  ${YELLOW}2${NC} - وارد کردن لینک دستی"
        echo -e "  ${YELLOW}3${NC} - مشاهده لینک‌های ذخیره‌شده"
        echo -e "  ${YELLOW}4${NC} - خروجی به دانلودها"
        echo -e "  ${YELLOW}5${NC} - خروج"
        echo ""
        read -rp "انتخاب: " opt

        case "$opt" in
            1) watch_clipboard ;;
            2) manual_entry ;;
            3) view_saved ;;
            4) export_to_downloads ;;
            5) echo -e "${GREEN}خداحافظ!${NC}"; exit 0 ;;
            *) echo -e "${RED}گزینه نامعتبر${NC}"; sleep 1 ;;
        esac
    done
}

if ! command -v termux-clipboard-get &>/dev/null; then
    echo -e "${YELLOW}نکته: برای پایش Clipboard، Termux:API را نصب کنید:${NC}"
    echo -e "  pkg install termux-api"
    echo ""
fi

main_menu
