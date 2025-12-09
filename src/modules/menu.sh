# menu.sh - Interactive Dashboard Menu
# PHP Version Manager (PHPVM)

# Menu items configuration
declare -A MENU_ITEMS
declare -A MENU_HOTKEYS

# Initialize menu items
init_menu_items() {
    local framework="$1"

    # Clear arrays
    MENU_ITEMS=()
    MENU_HOTKEYS=()

    # Version Management
    MENU_ITEMS["[u] Switch PHP version"]="cmd_use"
    MENU_HOTKEYS["u"]="cmd_use"

    MENU_ITEMS["[i] Install PHP/extension"]="cmd_install"
    MENU_HOTKEYS["i"]="cmd_install"

    MENU_ITEMS["[l] List installed versions"]="cmd_list"
    MENU_HOTKEYS["l"]="cmd_list"

    # Configuration
    MENU_ITEMS["[c] Edit PHP configuration"]="cmd_config"
    MENU_HOTKEYS["c"]="cmd_config"

    MENU_ITEMS["[f] Manage PHP-FPM"]="cmd_fpm"
    MENU_HOTKEYS["f"]="cmd_fpm"

    MENU_ITEMS["[n] Nginx management"]="cmd_nginx"
    MENU_HOTKEYS["n"]="cmd_nginx"

    # Development
    MENU_ITEMS["[s] Start dev server"]="cmd_serve"
    MENU_HOTKEYS["s"]="cmd_serve"

    # Logs
    MENU_ITEMS["[g] Log viewer"]="cmd_logs"
    MENU_HOTKEYS["g"]="cmd_logs"

    # Info & Help
    MENU_ITEMS["[o] Show PHP info"]="cmd_info"
    MENU_HOTKEYS["o"]="cmd_info"

    MENU_ITEMS["[?] Help"]="show_help"
    MENU_HOTKEYS["?"]="show_help"

    # Quit
    MENU_ITEMS["[q] Quit"]="quit_menu"
    MENU_HOTKEYS["q"]="quit_menu"
}

# Main menu command
cmd_menu() {
    if [[ "$UI_MODE" != "gum" ]]; then
        fallback_menu
        return
    fi

    local framework
    framework=$(detect_framework 2>/dev/null)

    init_menu_items "$framework"

    while true; do
        clear

        # Print header
        print_menu_header "$framework"

        # Show menu with gum choose (supports arrow keys)
        local selected
        selected=$(show_interactive_menu "$framework")

        # Handle selection or check for quit
        if [[ -z "$selected" || "$selected" == "[q] Quit" ]]; then
            clear
            break
        fi

        # Execute selected command
        execute_menu_item "$selected"
    done
}

# Print menu header with status
print_menu_header() {
    local framework="$1"

    local version
    version=$(get_current_version 2>/dev/null)
    local full_version
    full_version=$(get_full_php_version "$version" 2>/dev/null)

    # Build status line
    local status_line="PHP ${full_version:-$version:-not installed}"

    # Add framework info
    if [[ -n "$framework" ]]; then
        local fw_name fw_version
        fw_name=$(get_framework_display_name "$framework")
        fw_version=$(get_framework_version "$framework" 2>/dev/null)
        if [[ -n "$fw_version" ]]; then
            status_line="${status_line} | ${fw_name} v${fw_version}"
        else
            status_line="${status_line} | ${fw_name}"
        fi
    fi

    # Get service status
    local nginx_status="off"
    local fpm_status="off"

    if command -v nginx &>/dev/null && pgrep -x nginx &>/dev/null; then
        nginx_status="on"
    fi

    if [[ -n "$version" ]] && pgrep -f "php-fpm${version}\|php${version}-fpm" &>/dev/null; then
        fpm_status="on"
    fi

    # Build service status line
    local services=""
    if [[ "$nginx_status" == "on" ]]; then
        services="nginx ${GREEN}●${RESET}"
    else
        services="nginx ${RED}○${RESET}"
    fi
    if [[ "$fpm_status" == "on" ]]; then
        services="${services}  fpm ${GREEN}●${RESET}"
    else
        services="${services}  fpm ${RED}○${RESET}"
    fi

    echo ""
    gum style \
        --border double \
        --border-foreground 212 \
        --padding "0 2" \
        --margin "0 2" \
        --align center \
        "$(gum style --bold --foreground 212 "PHPVM Dashboard v${PHPVM_VERSION}")" \
        "" \
        "$status_line" \
        "" \
        "$services"
    echo ""
}

# Show interactive menu with hotkey support
show_interactive_menu() {
    local framework="$1"

    # Menu items (only selectable items, borders handled separately)
    local items=(
        "[u] Switch PHP version"
        "[i] Install PHP/extension"
        "[l] List installed versions"
        "[c] Edit PHP configuration"
        "[f] Manage PHP-FPM"
        "[n] Nginx management"
        "[s] Start dev server"
        "[g] Log viewer"
        "[o] Show PHP info"
        "[?] Help"
        "[q] Quit"
    )

    # Group boundaries for visual display
    local group1_end=3   # Version items (0-2)
    local group2_end=6   # Configuration items (3-5)
    local group3_end=8   # Development items (6-7)
    # group4 is Other items (8-10)

    local current=0
    local total=${#items[@]}

    # Hide cursor
    tput civis 2>/dev/null || true

    # Cleanup on exit
    trap 'tput cnorm 2>/dev/null || true' RETURN

    while true; do
        # Move cursor to start of menu area
        # Output to /dev/tty since stdout is captured by command substitution
        tput cup 9 0 2>/dev/null || echo -en "\033[9;0H"

        # Print menu with groups (all output to /dev/tty to avoid capture)
        echo "  ${DIM}Use ↑↓ arrows or hotkeys, Enter to select${RESET}" >/dev/tty
        echo "" >/dev/tty

        # Group 1: Version
        echo "  ${DIM}┌─ Version ─────────────┐${RESET}" >/dev/tty
        for i in 0 1 2; do
            print_menu_line "$i" "$current" "${items[$i]}" >/dev/tty
        done

        # Group 2: Configuration
        echo "  ${DIM}├─ Configuration ───────┤${RESET}" >/dev/tty
        for i in 3 4 5; do
            print_menu_line "$i" "$current" "${items[$i]}" >/dev/tty
        done

        # Group 3: Development
        echo "  ${DIM}├─ Development ─────────┤${RESET}" >/dev/tty
        for i in 6 7; do
            print_menu_line "$i" "$current" "${items[$i]}" >/dev/tty
        done

        # Group 4: Other
        echo "  ${DIM}├─ Other ───────────────┤${RESET}" >/dev/tty
        for i in 8 9 10; do
            print_menu_line "$i" "$current" "${items[$i]}" >/dev/tty
        done
        echo "  ${DIM}└───────────────────────┘${RESET}" >/dev/tty

        # Read single keypress
        local key
        IFS= read -rsn1 key

        # Handle escape sequences (arrow keys)
        if [[ "$key" == $'\x1b' ]]; then
            read -rsn2 -t 0.1 key
            case "$key" in
                '[A') # Up arrow
                    ((current > 0)) && ((current--))
                    ;;
                '[B') # Down arrow
                    ((current < total - 1)) && ((current++))
                    ;;
            esac
            continue
        fi

        # Handle Enter key
        if [[ "$key" == "" ]]; then
            echo "${items[$current]}"
            return
        fi

        # Handle hotkeys
        case "$key" in
            u) echo "[u] Switch PHP version"; return ;;
            i) echo "[i] Install PHP/extension"; return ;;
            l) echo "[l] List installed versions"; return ;;
            c) echo "[c] Edit PHP configuration"; return ;;
            f) echo "[f] Manage PHP-FPM"; return ;;
            n) echo "[n] Nginx management"; return ;;
            s) echo "[s] Start dev server"; return ;;
            g) echo "[g] Log viewer"; return ;;
            o) echo "[o] Show PHP info"; return ;;
            '?') echo "[?] Help"; return ;;
            q) echo "[q] Quit"; return ;;
            # Vim-style navigation
            k) ((current > 0)) && ((current--)) ;;
            j) ((current < total - 1)) && ((current++)) ;;
        esac
    done
}

# Print a single menu line with highlighting
print_menu_line() {
    local index="$1"
    local current="$2"
    local text="$3"

    if [[ "$index" -eq "$current" ]]; then
        echo "  ${MAGENTA}▸ ${text}${RESET}"
    else
        echo "    ${text}"
    fi
}

# Execute menu item
execute_menu_item() {
    local selected="$1"

    clear

    case "$selected" in
        "[u] Switch PHP version")
            cmd_use
            wait_for_key
            ;;
        "[i] Install PHP/extension")
            cmd_install
            wait_for_key
            ;;
        "[l] List installed versions")
            cmd_list
            wait_for_key
            ;;
        "[c] Edit PHP configuration")
            cmd_config
            wait_for_key
            ;;
        "[f] Manage PHP-FPM")
            cmd_fpm
            wait_for_key
            ;;
        "[n] Nginx management")
            cmd_nginx
            wait_for_key
            ;;
        "[s] Start dev server")
            cmd_serve
            wait_for_key
            ;;
        "[g] Log viewer")
            cmd_logs
            wait_for_key
            ;;
        "[o] Show PHP info")
            cmd_info
            wait_for_key
            ;;
        "[?] Help")
            show_help
            wait_for_key
            ;;
        "[q] Quit")
            return 1
            ;;
    esac

    return 0
}

# Wait for key press
wait_for_key() {
    echo ""
    gum style --foreground 241 "Press any key to continue..."
    read -rsn1
}

# Fallback menu for non-gum environments
fallback_menu() {
    local framework
    framework=$(detect_framework 2>/dev/null)

    while true; do
        clear
        print_header

        echo ""
        echo "${BOLD}─── Version Management ───${RESET}"
        echo "  1) Switch PHP version"
        echo "  2) Install PHP/extension"
        echo "  3) List versions"
        echo ""
        echo "${BOLD}─── Configuration ───${RESET}"
        echo "  4) Edit PHP config"
        echo "  5) Manage PHP-FPM"
        echo "  6) Nginx management"
        echo ""
        echo "${BOLD}─── Development ───${RESET}"
        echo "  7) Start dev server"
        echo "  8) Log viewer"
        echo ""
        echo "${BOLD}─── Other ───${RESET}"
        echo "  9) Show PHP info"
        echo "  h) Help"
        echo "  q) Quit"
        echo ""

        local choice
        read -rp "Select [1-9/h/q]: " choice

        case "$choice" in
            1) cmd_use; read -rp "Press Enter to continue..." ;;
            2) cmd_install; read -rp "Press Enter to continue..." ;;
            3) cmd_list; read -rp "Press Enter to continue..." ;;
            4) cmd_config; read -rp "Press Enter to continue..." ;;
            5) cmd_fpm; read -rp "Press Enter to continue..." ;;
            6) cmd_nginx; read -rp "Press Enter to continue..." ;;
            7) cmd_serve; read -rp "Press Enter to continue..." ;;
            8) cmd_logs ;;
            9) cmd_info; read -rp "Press Enter to continue..." ;;
            h|H) show_help; read -rp "Press Enter to continue..." ;;
            q|Q) clear; break ;;
        esac
    done
}
