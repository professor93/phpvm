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

# Multi-select menu
gum_multi_menu() {
    local prompt="$1"
    shift
    local options=("$@")

    if [[ "$UI_MODE" == "gum" ]]; then
        printf '%s\n' "${options[@]}" | gum choose \
            --no-limit \
            --header "$prompt" \
            --cursor.foreground 212 \
            --header.foreground 99 \
            --selected.foreground 212
    else
        # Fallback: comma-separated input
        echo ""
        echo "${CYAN}${prompt}${RESET}"
        echo ""

        local i=1
        for opt in "${options[@]}"; do
            echo "  ${YELLOW}${i})${RESET} $opt"
            ((i++))
        done
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

    if [[ "$UI_MODE" == "gum" ]]; then
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
