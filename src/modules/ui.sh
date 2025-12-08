# ui.sh - User Interface with Gum
# PHP Version Manager (PHPVM)

# Check if gum is installed and meets minimum version
check_gum() {
    if ! command_exists gum; then
        return 1
    fi

    local current_version
    current_version=$(gum --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)

    if [[ -z "$current_version" ]]; then
        return 1
    fi

    version_gte "$current_version" "$GUM_MIN_VERSION"
}

# Install gum from GitHub releases
install_gum_github() {
    local arch
    case "$(uname -m)" in
        x86_64)  arch="amd64" ;;
        aarch64) arch="arm64" ;;
        armv7l)  arch="armv7" ;;
        *)       return 1 ;;
    esac

    info_log "Installing gum from GitHub releases..."

    local tmp_dir
    tmp_dir=$(mktemp -d)
    local latest_url="https://api.github.com/repos/${GUM_GITHUB_REPO}/releases/latest"

    # Get latest release info
    local download_url
    download_url=$(curl -fsSL "$latest_url" | grep -oE "https://[^\"]+Linux_${arch}\.(tar\.gz|deb|rpm)" | head -1)

    if [[ -z "$download_url" ]]; then
        rm -rf "$tmp_dir"
        return 1
    fi

    local filename="${download_url##*/}"

    if ! curl -fsSL -o "${tmp_dir}/${filename}" "$download_url"; then
        rm -rf "$tmp_dir"
        return 1
    fi

    # Install based on file type
    case "$filename" in
        *.deb)
            run_privileged dpkg -i "${tmp_dir}/${filename}"
            ;;
        *.rpm)
            run_privileged rpm -i "${tmp_dir}/${filename}"
            ;;
        *.tar.gz)
            tar -xzf "${tmp_dir}/${filename}" -C "$tmp_dir"
            local gum_bin=$(find "$tmp_dir" -name "gum" -type f -executable | head -1)
            if [[ -n "$gum_bin" ]]; then
                run_privileged install -m 755 "$gum_bin" /usr/local/bin/gum
            else
                rm -rf "$tmp_dir"
                return 1
            fi
            ;;
    esac

    rm -rf "$tmp_dir"

    if check_gum; then
        success "gum installed successfully"
        return 0
    fi
    return 1
}

# Install gum from package manager
install_gum_package_manager() {
    local pm=$(get_package_manager)

    info_log "Installing gum from package manager..."

    case "$pm" in
        apt)
            # Try to add charm repository
            if ! grep -q "charm.sh" /etc/apt/sources.list.d/* 2>/dev/null; then
                run_privileged mkdir -p /etc/apt/keyrings
                curl -fsSL https://repo.charm.sh/apt/gpg.key | run_privileged gpg --dearmor -o /etc/apt/keyrings/charm.gpg
                echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | \
                    run_privileged tee /etc/apt/sources.list.d/charm.list
                run_privileged apt-get update -qq
            fi
            run_privileged apt-get install -y gum
            ;;
        dnf|yum)
            # Try Charm's rpm repository
            echo '[charm]
name=Charm
baseurl=https://repo.charm.sh/yum/
enabled=1
gpgcheck=1
gpgkey=https://repo.charm.sh/yum/gpg.key' | run_privileged tee /etc/yum.repos.d/charm.repo
            run_privileged $pm install -y gum
            ;;
        *)
            return 1
            ;;
    esac

    check_gum
}

# Ensure gum is installed
ensure_gum() {
    if check_gum; then
        return 0
    fi

    warn "gum is not installed. Installing..."

    # Try GitHub releases first
    if install_gum_github; then
        return 0
    fi

    warn "GitHub installation failed. Trying package manager..."

    # Try package manager
    if install_gum_package_manager; then
        return 0
    fi

    warn "Could not install gum. Falling back to basic menu."
    return 1
}

# UI mode tracking
UI_MODE="gum"  # gum, fallback

set_ui_mode() {
    if check_gum; then
        UI_MODE="gum"
    else
        UI_MODE="fallback"
    fi
}

# Print header box with current PHP version
print_header() {
    local current_version
    current_version=$(get_current_version)

    local header_text="PHP Version Manager v${PHPVM_VERSION}"
    local status_text

    if [[ -n "$current_version" ]]; then
        status_text="Current: PHP ${current_version}"

        # Add framework info if in a framework project
        local framework
        framework=$(detect_framework 2>/dev/null)
        if [[ -n "$framework" ]]; then
            local fw_name fw_version
            fw_name=$(get_framework_display_name "$framework")
            fw_version=$(get_framework_version "$framework" 2>/dev/null)
            if [[ -n "$fw_version" ]]; then
                status_text="${status_text} | ${fw_name} v${fw_version}"
            else
                status_text="${status_text} | ${fw_name}"
            fi
        fi
    else
        status_text="No PHP installed"
    fi

    if [[ "$UI_MODE" == "gum" ]]; then
        gum style \
            --border rounded \
            --border-foreground 212 \
            --padding "0 2" \
            --margin "1 0" \
            "$header_text" \
            "$status_text"
    else
        echo ""
        echo "+-----------------------------------------------------------------+"
        printf "| %-63s |\n" "$header_text"
        printf "| %-63s |\n" "$status_text"
        echo "+-----------------------------------------------------------------+"
        echo ""
    fi
}

# Interactive menu using gum
# Usage: gum_menu "prompt" "option1" "option2" ...
# Returns: selected option (or empty if cancelled)
gum_menu() {
    local prompt="$1"
    shift
    local options=("$@")

    if [[ "$UI_MODE" == "gum" ]]; then
        printf '%s\n' "${options[@]}" | gum choose \
            --header "$prompt" \
            --cursor.foreground 212 \
            --header.foreground 99 \
            --selected.foreground 212
    else
        # Fallback: numbered menu
        echo ""
        echo "${CYAN}${prompt}${RESET}"
        echo ""

        local i=1
        for opt in "${options[@]}"; do
            echo "  ${YELLOW}${i})${RESET} $opt"
            ((i++))
        done
        echo ""

        local choice
        read -rp "Enter number (1-${#options[@]}): " choice

        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#options[@]} )); then
            echo "${options[$((choice-1))]}"
        else
            echo ""
        fi
    fi
}

# Multi-select menu with fuzzy filter
gum_multi_menu() {
    local prompt="$1"
    shift
    local options=("$@")

    if [[ "$UI_MODE" == "gum" ]]; then
        # Get terminal dimensions
        local term_width term_height
        term_width=$(tput cols 2>/dev/null || echo 80)
        term_height=$(tput lines 2>/dev/null || echo 24)

        # Calculate filter height (leave room for header and input)
        local filter_height=$((term_height - 6))
        [[ $filter_height -gt 30 ]] && filter_height=30
        [[ $filter_height -lt 5 ]] && filter_height=5

        # Use full terminal width
        local filter_width=$((term_width - 2))
        [[ $filter_width -lt 40 ]] && filter_width=40

        printf '%s\n' "${options[@]}" | gum filter \
            --no-limit \
            --header "$prompt" \
            --header.foreground 99 \
            --indicator.foreground 212 \
            --match.foreground 212 \
            --height "$filter_height" \
            --width "$filter_width" \
            --placeholder "Type to filter, Tab to select, Enter to confirm"
    else
        # Fallback: multi-column display
        echo ""
        echo "${CYAN}${prompt}${RESET}"
        echo ""

        # Calculate columns based on terminal width
        local term_width
        term_width=$(tput cols 2>/dev/null || echo 80)

        # Find max option length
        local max_len=0
        for opt in "${options[@]}"; do
            [[ ${#opt} -gt $max_len ]] && max_len=${#opt}
        done

        # Column width = number prefix (4) + option + padding (2)
        local col_width=$((max_len + 6))
        local num_cols=$((term_width / col_width))
        [[ $num_cols -lt 1 ]] && num_cols=1
        [[ $num_cols -gt 4 ]] && num_cols=4

        # Print options in columns
        local i=1
        local col=0
        for opt in "${options[@]}"; do
            printf "${YELLOW}%3d)${RESET} %-${max_len}s  " "$i" "$opt"
            ((col++))
            ((i++))
            if [[ $col -ge $num_cols ]]; then
                echo ""
                col=0
            fi
        done
        [[ $col -ne 0 ]] && echo ""
        echo ""

        local choices
        read -rp "Enter numbers separated by comma (e.g., 1,3,5): " choices

        IFS=',' read -ra selected <<< "$choices"
        for num in "${selected[@]}"; do
            num=$(echo "$num" | tr -d ' ')
            if [[ "$num" =~ ^[0-9]+$ ]] && (( num >= 1 && num <= ${#options[@]} )); then
                echo "${options[$((num-1))]}"
            fi
        done
    fi
}

# Confirmation prompt
gum_confirm() {
    local prompt="$1"
    local default="${2:-yes}"  # yes or no

    if [[ "$UI_MODE" == "gum" ]]; then
        if [[ "$default" == "yes" ]]; then
            gum confirm --default=yes "$prompt"
        else
            gum confirm --default=no "$prompt"
        fi
    else
        local yn
        if [[ "$default" == "yes" ]]; then
            read -rp "${prompt} [Y/n]: " yn
            yn="${yn:-y}"
        else
            read -rp "${prompt} [y/N]: " yn
            yn="${yn:-n}"
        fi

        case "$yn" in
            [Yy]*) return 0 ;;
            *) return 1 ;;
        esac
    fi
}

# Text input
gum_input() {
    local prompt="$1"
    local default="${2:-}"
    local placeholder="${3:-}"

    if [[ "$UI_MODE" == "gum" ]]; then
        gum input \
            --prompt "$prompt " \
            --value "$default" \
            --placeholder "$placeholder"
    else
        local input
        if [[ -n "$default" ]]; then
            read -rp "${prompt} [$default]: " input
            echo "${input:-$default}"
        else
            read -rp "${prompt}: " input
            echo "$input"
        fi
    fi
}

# Spinner for long operations
gum_spin() {
    local title="$1"
    shift

    # Check if the first argument is a shell function
    # gum spin runs commands in a subprocess which can't access shell functions
    local cmd="$1"
    local is_function=false
    if [[ "$(type -t "$cmd" 2>/dev/null)" == "function" ]]; then
        is_function=true
    fi

    if [[ "$UI_MODE" == "gum" && "$is_function" == "false" ]]; then
        gum spin --spinner dot --title "$title" -- "$@"
    else
        echo "${CYAN}${title}...${RESET}"
        "$@"
    fi
}

# Display formatted text
gum_format() {
    local text="$1"
    local type="${2:-}"  # markdown, code, template

    if [[ "$UI_MODE" == "gum" ]]; then
        case "$type" in
            markdown) echo "$text" | gum format ;;
            code) echo "$text" | gum format -t code ;;
            *) echo "$text" ;;
        esac
    else
        echo "$text"
    fi
}

# ============================================
# Hotkey Support Functions
# ============================================

# Read single keypress (non-blocking for special keys)
ui_read_key() {
    local key
    IFS= read -rsn1 key 2>/dev/null

    # Handle escape sequences (arrow keys, function keys)
    if [[ "$key" == $'\x1b' ]]; then
        read -rsn2 -t 0.1 key2 2>/dev/null
        key+="$key2"
    fi

    echo "$key"
}

# Menu with numbered hotkeys
# Usage: hotkey_menu "Header" "opt1" "opt2" ...
# Returns: selected option text
hotkey_menu() {
    local header="$1"
    shift
    local options=("$@")
    local count=${#options[@]}

    echo ""
    echo "${BOLD}${CYAN}$header${RESET}"
    echo ""

    local i=1
    for opt in "${options[@]}"; do
        if [[ $i -le 9 ]]; then
            echo "  ${YELLOW}[$i]${RESET} $opt"
        else
            local letter
            letter=$(printf "\\x$(printf '%02x' $((96 + i - 9)))")  # a, b, c...
            echo "  ${YELLOW}[$letter]${RESET} $opt"
        fi
        ((i++))
    done

    echo ""
    echo "  ${YELLOW}[0]${RESET} Cancel"
    echo ""
    echo "${DIM}Press key to select${RESET}"

    local key
    key=$(ui_read_key)

    case "$key" in
        $'\x03'|0|q|Q|\x1b)  # Ctrl-C, 0, q, Escape
            return 1
            ;;
        [1-9])
            local idx=$((key - 1))
            if [[ $idx -lt $count ]]; then
                echo "${options[$idx]}"
                return 0
            fi
            ;;
        [a-z])
            local idx=$(($(printf '%d' "'$key") - 97 + 9))
            if [[ $idx -lt $count ]]; then
                echo "${options[$idx]}"
                return 0
            fi
            ;;
    esac

    return 1
}

# Confirmation with hotkeys
# Usage: hotkey_confirm "Question?"
hotkey_confirm_yesno() {
    local question="$1"
    local default="${2:-yes}"  # yes or no

    echo ""
    echo "$question"

    if [[ "$default" == "yes" ]]; then
        echo "  ${YELLOW}[Y]${RESET} Yes (default)"
        echo "  ${YELLOW}[n]${RESET} No"
    else
        echo "  ${YELLOW}[y]${RESET} Yes"
        echo "  ${YELLOW}[N]${RESET} No (default)"
    fi
    echo ""

    local key
    key=$(ui_read_key)

    case "$key" in
        y|Y) return 0 ;;
        n|N) return 1 ;;
        "")  # Enter key
            [[ "$default" == "yes" ]] && return 0 || return 1
            ;;
        $'\x03'|\x1b)  # Ctrl-C, Escape
            return 1
            ;;
        *)
            [[ "$default" == "yes" ]] && return 0 || return 1
            ;;
    esac
}

# Show key hint
show_key_hint() {
    local hint="$1"
    echo "${DIM}$hint${RESET}"
}

# Wait for any key
wait_any_key() {
    local msg="${1:-Press any key to continue...}"
    echo ""
    echo "${DIM}$msg${RESET}"
    read -rsn1
}

# Pagination helper for long lists
# Usage: paginate_list items_array page_size current_page
paginate_show() {
    local -n items=$1
    local page_size=${2:-10}
    local page=${3:-1}

    local total=${#items[@]}
    local total_pages=$(( (total + page_size - 1) / page_size ))
    local start=$(( (page - 1) * page_size ))
    local end=$(( start + page_size ))
    [[ $end -gt $total ]] && end=$total

    local i=$start
    local num=1
    while [[ $i -lt $end ]]; do
        if [[ $num -le 9 ]]; then
            echo "  ${YELLOW}[$num]${RESET} ${items[$i]}"
        else
            echo "      ${items[$i]}"
        fi
        ((i++))
        ((num++))
    done

    echo ""
    echo "${DIM}Page $page/$total_pages | [n]ext [p]rev [q]uit${RESET}"
}
