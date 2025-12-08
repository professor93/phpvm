# menu.sh - Interactive Dashboard with Hotkey Support
# PHP Version Manager (PHPVM)

# Terminal size
TERM_LINES=""
TERM_COLS=""

# Update terminal size
update_term_size() {
    TERM_LINES=$(tput lines 2>/dev/null || echo 24)
    TERM_COLS=$(tput cols 2>/dev/null || echo 80)
}

# Clear screen and move to top
clear_screen() {
    printf '\033[2J\033[H'
}

# Hide/show cursor
hide_cursor() { printf '\033[?25l'; }
show_cursor() { printf '\033[?25h'; }

# Move cursor
move_cursor() { printf '\033[%d;%dH' "$1" "$2"; }

# Read single key - use ui_read_key from ui.sh
read_key() {
    ui_read_key
}

# Main menu command
cmd_menu() {
    # Check for gum
    if [[ "$UI_MODE" != "gum" ]]; then
        fallback_menu
        return
    fi

    update_term_size
    trap 'show_cursor; clear_screen' EXIT

    local framework
    framework=$(detect_framework 2>/dev/null)

    while true; do
        clear_screen
        hide_cursor

        if ! dashboard_main "$framework"; then
            break
        fi
    done

    show_cursor
    clear_screen
}

# Dashboard main screen
dashboard_main() {
    local framework="$1"

    update_term_size
    local height=$((TERM_LINES - 2))

    # Print header
    print_dashboard_header "$framework"

    # Print menu with hotkeys
    print_hotkey_menu "$framework"

    # Print footer
    print_footer

    # Wait for key
    local key
    key=$(read_key)

    # Handle key
    handle_hotkey "$key" "$framework"
}

# Print dashboard header
print_dashboard_header() {
    local framework="$1"

    local version
    version=$(get_current_version 2>/dev/null)
    local full_version
    full_version=$(get_full_php_version "$version" 2>/dev/null)

    local project_info=""
    if [[ -n "$framework" ]]; then
        local project_name
        project_name=$(get_project_name 2>/dev/null)
        project_info=" │ $(get_framework_display_name "$framework"): ${project_name}"
    fi

    # Get nginx status
    local nginx_status=""
    if command -v nginx &>/dev/null; then
        if pgrep -x nginx &>/dev/null; then
            nginx_status="${GREEN}●${RESET}"
        else
            nginx_status="${RED}●${RESET}"
        fi
    fi

    # Get FPM status
    local fpm_status=""
    if [[ -n "$version" ]]; then
        if pgrep -f "php-fpm${version}\|php${version}-fpm" &>/dev/null; then
            fpm_status="${GREEN}●${RESET}"
        else
            fpm_status="${RED}●${RESET}"
        fi
    fi

    echo ""
    gum style \
        --border double \
        --border-foreground 212 \
        --padding "0 2" \
        --margin "0 1" \
        --bold \
        "PHPVM Dashboard v${PHPVM_VERSION}" \
        "PHP ${full_version:-$version}${project_info}" \
        "nginx $nginx_status  fpm $fpm_status"
    echo ""
}

# Print menu with hotkeys
print_hotkey_menu() {
    local framework="$1"

    # Calculate available height
    local menu_height=$((TERM_LINES - 15))
    [[ $menu_height -lt 10 ]] && menu_height=10

    # Build menu items with hotkeys
    local items=()

    # Version Management
    items+=("${BOLD}${CYAN}Version Management${RESET}")
    items+=("  ${YELLOW}[u]${RESET} use         Switch PHP version")
    items+=("  ${YELLOW}[i]${RESET} install     Install PHP or extension")
    items+=("  ${YELLOW}[l]${RESET} list        List installed versions")

    items+=("")
    items+=("${BOLD}${CYAN}Configuration${RESET}")
    items+=("  ${YELLOW}[c]${RESET} config      Edit PHP configuration")
    items+=("  ${YELLOW}[f]${RESET} fpm         Manage PHP-FPM")
    items+=("  ${YELLOW}[n]${RESET} nginx       Nginx management")

    items+=("")
    items+=("${BOLD}${CYAN}Logs & Monitoring${RESET}")
    items+=("  ${YELLOW}[g]${RESET} logs        Log viewer")
    items+=("  ${YELLOW}[t]${RESET} tail        Follow logs")
    items+=("  ${YELLOW}[p]${RESET} processes   Backend processes")

    # Framework-specific
    if [[ -n "$framework" ]]; then
        items+=("")
        items+=("${BOLD}${CYAN}$(get_framework_display_name "$framework") Commands${RESET}")
        items+=("  ${YELLOW}[s]${RESET} serve       Start dev server")
        items+=("  ${YELLOW}[w]${RESET} worker      Queue workers")
        items+=("  ${YELLOW}[r]${RESET} cron        Scheduled tasks")

        case "$framework" in
            laravel)
                items+=("  ${YELLOW}[a]${RESET} artisan     Run artisan command")
                has_horizon 2>/dev/null && items+=("  ${YELLOW}[H]${RESET} horizon     Start Horizon")
                has_octane 2>/dev/null && items+=("  ${YELLOW}[o]${RESET} octane      Start Octane")
                ;;
            symfony)
                items+=("  ${YELLOW}[a]${RESET} console     Run console command")
                ;;
            yii)
                items+=("  ${YELLOW}[a]${RESET} yii         Run yii command")
                ;;
        esac
    fi

    items+=("")
    items+=("${BOLD}${CYAN}Other${RESET}")
    items+=("  ${YELLOW}[?]${RESET} help        Show help")
    items+=("  ${YELLOW}[U]${RESET} update      Update PHPVM")
    items+=("  ${YELLOW}[q]${RESET} quit        Exit dashboard")

    # Print items
    for item in "${items[@]}"; do
        echo -e "$item"
    done
}

# Print footer with key hints
print_footer() {
    local footer_line=$((TERM_LINES - 1))

    echo ""
    echo "${DIM}Press hotkey to select │ Ctrl-C to exit │ ? for help${RESET}"
}

# Handle hotkey
handle_hotkey() {
    local key="$1"
    local framework="$2"

    show_cursor

    case "$key" in
        # Ctrl-C or q to quit
        $'\x03'|q|Q)
            return 1
            ;;

        # Version Management
        u|U)
            clear_screen
            cmd_use
            wait_for_key
            ;;
        i|I)
            clear_screen
            cmd_install
            wait_for_key
            ;;
        l|L)
            clear_screen
            cmd_list
            wait_for_key
            ;;

        # Configuration
        c|C)
            clear_screen
            cmd_config
            wait_for_key
            ;;
        f|F)
            clear_screen
            cmd_fpm
            wait_for_key
            ;;
        n|N)
            clear_screen
            nginx_submenu
            ;;

        # Logs & Monitoring
        g|G)
            clear_screen
            cmd_logs
            ;;
        t|T)
            clear_screen
            tail_submenu
            ;;
        p|P)
            clear_screen
            show_backend_processes
            wait_for_key
            ;;

        # Framework commands
        s|S)
            if [[ -n "$framework" ]]; then
                clear_screen
                cmd_serve
                wait_for_key
            fi
            ;;
        w|W)
            if [[ -n "$framework" ]]; then
                clear_screen
                cmd_worker
                wait_for_key
            fi
            ;;
        r|R)
            if [[ -n "$framework" ]]; then
                clear_screen
                cmd_cron
                wait_for_key
            fi
            ;;
        a|A)
            if [[ -n "$framework" ]]; then
                clear_screen
                run_framework_console_interactive "$framework"
                wait_for_key
            fi
            ;;
        H)
            if [[ "$framework" == "laravel" ]] && has_horizon 2>/dev/null; then
                clear_screen
                run_horizon
            fi
            ;;
        o|O)
            if [[ "$framework" == "laravel" ]] && has_octane 2>/dev/null; then
                clear_screen
                run_octane
            fi
            ;;

        # Other
        \?|h)
            clear_screen
            show_help
            wait_for_key
            ;;
        U)
            clear_screen
            cmd_self_update
            wait_for_key
            ;;

        # Info shortcut
        "")
            clear_screen
            cmd_info
            wait_for_key
            ;;
    esac

    return 0
}

# Wait for key press
wait_for_key() {
    echo ""
    echo "${DIM}Press any key to continue...${RESET}"
    read -rsn1
}

# Nginx submenu with hotkeys
nginx_submenu() {
    while true; do
        clear_screen
        echo ""
        gum style \
            --border rounded \
            --border-foreground 99 \
            --padding "0 2" \
            --bold \
            "Nginx Management"
        echo ""

        echo "${BOLD}${CYAN}Commands${RESET}"
        echo "  ${YELLOW}[i]${RESET} info        Show configuration info"
        echo "  ${YELLOW}[v]${RESET} view        View configuration"
        echo "  ${YELLOW}[e]${RESET} edit        Edit configuration"
        echo "  ${YELLOW}[g]${RESET} generate    Generate new config"
        echo "  ${YELLOW}[r]${RESET} reload      Reload nginx"
        echo "  ${YELLOW}[R]${RESET} restart     Restart nginx"
        echo "  ${YELLOW}[t]${RESET} test        Test configuration"
        echo "  ${YELLOW}[p]${RESET} processes   Show backends"
        echo "  ${YELLOW}[m]${RESET} templates   Manage templates"
        echo ""
        echo "  ${YELLOW}[b]${RESET} back        Return to dashboard"
        echo "  ${YELLOW}[q]${RESET} quit        Exit"
        echo ""
        echo "${DIM}Press hotkey to select${RESET}"

        local key
        key=$(read_key)

        case "$key" in
            $'\x03'|q|Q) return 1 ;;
            b|B|\x1b) return 0 ;;
            i|I)
                show_nginx_info
                wait_for_key
                ;;
            v|V)
                view_nginx_config
                wait_for_key
                ;;
            e|E)
                local config_file
                config_file=$(select_nginx_config 2>/dev/null)
                [[ -n "$config_file" ]] && run_privileged "${EDITOR:-nano}" "$config_file"
                ;;
            g|G)
                generate_nginx_config
                wait_for_key
                ;;
            r)
                if gum_confirm "Reload nginx configuration?"; then
                    nginx_reload
                fi
                wait_for_key
                ;;
            R)
                if gum_confirm "Restart nginx service?"; then
                    nginx_restart
                fi
                wait_for_key
                ;;
            t|T)
                run_privileged nginx -t
                wait_for_key
                ;;
            p|P)
                show_backend_processes
                wait_for_key
                ;;
            m|M)
                templates_submenu
                ;;
        esac
    done
}

# Templates submenu
templates_submenu() {
    while true; do
        clear_screen
        echo ""
        gum style \
            --border rounded \
            --border-foreground 99 \
            --padding "0 2" \
            --bold \
            "Template Management"
        echo ""

        echo "  ${YELLOW}[l]${RESET} list        List templates"
        echo "  ${YELLOW}[a]${RESET} add         Add template"
        echo "  ${YELLOW}[e]${RESET} edit        Edit template"
        echo "  ${YELLOW}[d]${RESET} delete      Delete template"
        echo ""
        echo "  ${YELLOW}[b]${RESET} back        Return"
        echo ""
        echo "${DIM}Press hotkey to select${RESET}"

        local key
        key=$(read_key)

        case "$key" in
            $'\x03'|q|Q) return 1 ;;
            b|B|\x1b) return 0 ;;
            l|L)
                list_custom_templates
                wait_for_key
                ;;
            a|A)
                add_custom_template
                wait_for_key
                ;;
            e|E)
                edit_custom_template
                wait_for_key
                ;;
            d|D)
                delete_custom_template
                wait_for_key
                ;;
        esac
    done
}

# Tail submenu with log type selection
tail_submenu() {
    while true; do
        clear_screen
        echo ""
        gum style \
            --border rounded \
            --border-foreground 99 \
            --padding "0 2" \
            --bold \
            "Tail Logs"
        echo ""

        echo "  ${YELLOW}[1]${RESET} app         Application log"
        echo "  ${YELLOW}[2]${RESET} access      Nginx access log"
        echo "  ${YELLOW}[3]${RESET} error       Nginx error log"
        echo "  ${YELLOW}[4]${RESET} worker      Supervisor log"
        echo "  ${YELLOW}[5]${RESET} fpm         PHP-FPM log"
        echo "  ${YELLOW}[a]${RESET} all         All logs"
        echo "  ${YELLOW}[s]${RESET} split       Split screen (tmux)"
        echo ""
        echo "  ${YELLOW}[b]${RESET} back        Return"
        echo ""
        echo "${DIM}Press number or letter to select${RESET}"

        local key
        key=$(read_key)

        case "$key" in
            $'\x03'|q|Q) return 1 ;;
            b|B|\x1b) return 0 ;;
            1)
                follow_log "app"
                ;;
            2)
                follow_log "access"
                ;;
            3)
                follow_log "error"
                ;;
            4)
                follow_log "worker"
                ;;
            5)
                follow_log "fpm"
                ;;
            a|A)
                follow_all_logs
                ;;
            s|S)
                split_screen_viewer
                ;;
        esac
    done
}

# Run framework console interactively
run_framework_console_interactive() {
    local framework="$1"
    local php_bin
    php_bin=$(get_php_binary)

    local prompt=""
    local cmd_prefix=""

    case "$framework" in
        laravel)
            prompt="artisan command:"
            cmd_prefix="artisan"
            ;;
        symfony)
            prompt="console command:"
            cmd_prefix="bin/console"
            ;;
        yii)
            prompt="yii command:"
            cmd_prefix="yii"
            ;;
    esac

    local cmd
    cmd=$(gum_input "$prompt" "")

    if [[ -n "$cmd" ]]; then
        "$php_bin" $cmd_prefix $cmd
    fi
}

# Run Laravel Horizon
run_horizon() {
    local php_bin
    php_bin=$(get_php_binary)

    echo ""
    info_log "Starting Laravel Horizon..."
    echo "${DIM}Press Ctrl+C to stop${RESET}"
    echo ""

    "$php_bin" artisan horizon
}

# Run Laravel Octane
run_octane() {
    serve_octane "$(get_php_binary)"
}

# Fallback menu for non-gum environments
fallback_menu() {
    local framework
    framework=$(detect_framework 2>/dev/null)

    while true; do
        clear
        print_header

        echo ""
        echo "${BOLD}Commands:${RESET}"
        echo "  1) Switch PHP version"
        echo "  2) Install PHP/extension"
        echo "  3) List versions"
        echo "  4) PHP info"
        echo "  5) Edit config"
        echo "  6) Manage FPM"
        echo "  7) Nginx management"
        echo "  8) View logs"

        if [[ -n "$framework" ]]; then
            echo ""
            echo "${BOLD}$(get_framework_display_name "$framework"):${RESET}"
            echo "  s) Start dev server"
            echo "  w) Manage workers"
            echo "  c) Manage cron"
        fi

        echo ""
        echo "  h) Help"
        echo "  q) Quit"
        echo ""

        local choice
        read -rp "Select: " choice

        case "$choice" in
            1) cmd_use; read -rp "Press Enter..." ;;
            2) cmd_install; read -rp "Press Enter..." ;;
            3) cmd_list; read -rp "Press Enter..." ;;
            4) cmd_info; read -rp "Press Enter..." ;;
            5) cmd_config; read -rp "Press Enter..." ;;
            6) cmd_fpm; read -rp "Press Enter..." ;;
            7) cmd_nginx; read -rp "Press Enter..." ;;
            8) cmd_logs; read -rp "Press Enter..." ;;
            s|S) [[ -n "$framework" ]] && { cmd_serve; read -rp "Press Enter..."; } ;;
            w|W) [[ -n "$framework" ]] && { cmd_worker; read -rp "Press Enter..."; } ;;
            c|C) [[ -n "$framework" ]] && { cmd_cron; read -rp "Press Enter..."; } ;;
            h|H) show_help; read -rp "Press Enter..." ;;
            q|Q) break ;;
        esac
    done
}

# Hotkey-enabled list selection (generic)
# Usage: hotkey_select "Header" "item1" "item2" ...
# Returns selected item or empty on cancel
hotkey_select() {
    local header="$1"
    shift
    local items=("$@")
    local count=${#items[@]}

    if [[ $count -eq 0 ]]; then
        return 1
    fi

    echo ""
    echo "${BOLD}$header${RESET}"
    echo ""

    local i=1
    for item in "${items[@]}"; do
        if [[ $i -le 9 ]]; then
            echo "  ${YELLOW}[$i]${RESET} $item"
        else
            echo "      $item"
        fi
        ((i++))
    done

    echo ""
    echo "  ${YELLOW}[b]${RESET} Back/Cancel"
    echo ""
    echo "${DIM}Press number to select${RESET}"

    local key
    key=$(read_key)

    case "$key" in
        $'\x03'|b|B|q|Q|\x1b)
            return 1
            ;;
        [1-9])
            local idx=$((key - 1))
            if [[ $idx -lt $count ]]; then
                echo "${items[$idx]}"
                return 0
            fi
            ;;
    esac

    return 1
}

# Hotkey-enabled confirmation - use hotkey_confirm_yesno from ui.sh
hotkey_confirm() {
    hotkey_confirm_yesno "$@"
}
