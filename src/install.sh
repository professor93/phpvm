#!/bin/bash
# PHPVM Installer
# Usage:
#   curl -fsSL https://github.com/professor93/phpvm/releases/latest/download/install.sh | bash
#   Or run as root for system-wide installation

set -o pipefail

PHPVM_VERSION="__VERSION__"
PHPVM_REPO="professor93/phpvm"
PHPVM_RAW_URL="https://raw.githubusercontent.com/${PHPVM_REPO}/main"

# Sudo helper - use sudo only if not already root
SUDO=""
[[ $EUID -ne 0 ]] && SUDO="sudo"

# Colors
setup_colors() {
    if [[ -t 1 ]]; then
        RED=$(tput setaf 1 2>/dev/null || echo '')
        GREEN=$(tput setaf 2 2>/dev/null || echo '')
        YELLOW=$(tput setaf 3 2>/dev/null || echo '')
        CYAN=$(tput setaf 6 2>/dev/null || echo '')
        BOLD=$(tput bold 2>/dev/null || echo '')
        DIM=$(tput dim 2>/dev/null || echo '')
        RESET=$(tput sgr0 2>/dev/null || echo '')
    fi
}

msg()     { echo "${GREEN}->${RESET} $*"; }
warn()    { echo "${YELLOW}!${RESET} $*"; }
error()   { echo "${RED}x${RESET} $*" >&2; }
success() { echo "${GREEN}[x]${RESET} $*"; }

# Check if gum is available
has_gum() {
    command -v gum &>/dev/null
}

# UI: Choose from options (returns selected option)
ui_choose() {
    local header="$1"
    shift
    local options=("$@")

    if has_gum; then
        printf '%s\n' "${options[@]}" | gum choose --header "$header"
    else
        echo ""
        echo "${BOLD}${header}${RESET}"
        echo ""
        local i=1
        for opt in "${options[@]}"; do
            echo "  ${i}) ${opt}"
            ((i++))
        done
        echo ""
        read -rp "Select [1]: " choice
        choice="${choice:-1}"
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#options[@]} )); then
            echo "${options[$((choice-1))]}"
        else
            echo "${options[0]}"
        fi
    fi
}

# UI: Confirm yes/no (returns 0 for yes, 1 for no)
ui_confirm() {
    local prompt="$1"
    local default="${2:-no}"

    if has_gum; then
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

# Parse arguments
INSTALL_MODE=""
UPGRADE_MODE=false
UNINSTALL=false
FORCE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --system)  INSTALL_MODE="system" ;;
        --user)    INSTALL_MODE="user" ;;
        --upgrade) UPGRADE_MODE=true ;;
        --uninstall) UNINSTALL=true ;;
        --force|-f) FORCE=true ;;
        *) ;;
    esac
    shift
done

# Detect platform
detect_platform() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        DISTRO_ID="${ID:-unknown}"
        DISTRO_NAME="${PRETTY_NAME:-$ID}"
    else
        DISTRO_ID="unknown"
        DISTRO_NAME="Unknown Linux"
    fi

    IS_WSL=false
    grep -qi microsoft /proc/version 2>/dev/null && IS_WSL=true
}

# Check if a file is PHPVM or real PHP
is_phpvm_binary() {
    local file="$1"
    [[ -f "$file" ]] && grep -q "PHP Version Manager\|PHPVM" "$file" 2>/dev/null
}

# Get PHP version from binary
get_php_version() {
    local php_bin="$1"
    "$php_bin" -v 2>/dev/null | head -1 | grep -oE 'PHP [0-9]+\.[0-9]+\.[0-9]+' | cut -d' ' -f2
}

# Install gum
install_gum() {
    if has_gum; then
        return 0
    fi

    msg "Installing gum..."

    local arch
    case "$(uname -m)" in
        x86_64)  arch="amd64" ;;
        aarch64) arch="arm64" ;;
        armv7l)  arch="armv7" ;;
        *)       return 1 ;;
    esac

    local tmp_dir=$(mktemp -d)
    local latest_url="https://api.github.com/repos/charmbracelet/gum/releases/latest"

    local release_json
    release_json=$(curl -fsSL "$latest_url" 2>/dev/null)

    if [[ -z "$release_json" ]]; then
        rm -rf "$tmp_dir"
        return 1
    fi

    # Try to find download URL - different naming patterns:
    # .deb: gum_VERSION_ARCH.deb (e.g., gum_0.17.0_amd64.deb)
    # .rpm: gum_VERSION_ARCH.rpm
    # .tar.gz: gum_VERSION_Linux_ARCH.tar.gz
    local download_url

    # Detect package manager and prefer native package
    if command -v apt &>/dev/null; then
        download_url=$(echo "$release_json" | grep -oE "https://[^\"]+_${arch}\.deb" | head -1)
    elif command -v dnf &>/dev/null || command -v yum &>/dev/null; then
        download_url=$(echo "$release_json" | grep -oE "https://[^\"]+_${arch}\.rpm" | head -1)
    fi

    # Fallback to tar.gz
    if [[ -z "$download_url" ]]; then
        local tar_arch="$arch"
        [[ "$arch" == "amd64" ]] && tar_arch="x86_64"
        download_url=$(echo "$release_json" | grep -oE "https://[^\"]+Linux_${tar_arch}\.tar\.gz" | head -1)
    fi

    if [[ -z "$download_url" ]]; then
        warn "Could not find gum release for $arch"
        rm -rf "$tmp_dir"
        return 1
    fi

    local filename="${download_url##*/}"

    if ! curl -fsSL -o "${tmp_dir}/${filename}" "$download_url"; then
        rm -rf "$tmp_dir"
        return 1
    fi

    case "$filename" in
        *.deb)
            $SUDO dpkg -i "${tmp_dir}/${filename}" &>/dev/null
            ;;
        *.rpm)
            $SUDO rpm -i "${tmp_dir}/${filename}" &>/dev/null
            ;;
        *.tar.gz)
            tar -xzf "${tmp_dir}/${filename}" -C "$tmp_dir"
            local gum_bin=$(find "$tmp_dir" -name "gum" -type f -executable | head -1)
            if [[ -n "$gum_bin" ]]; then
                if [[ "$INSTALL_MODE" == "system" || $EUID -eq 0 ]]; then
                    $SUDO install -m 755 "$gum_bin" /usr/local/bin/gum
                else
                    mkdir -p "$HOME/.local/bin"
                    install -m 755 "$gum_bin" "$HOME/.local/bin/gum"
                    export PATH="$HOME/.local/bin:$PATH"
                fi
            fi
            ;;
    esac

    rm -rf "$tmp_dir"
    has_gum
}

# Check for existing PHP installation
check_existing_php() {
    local bin_dir="$1"
    local target_php="$bin_dir/php"

    # Check if target already has PHPVM
    if is_phpvm_binary "$target_php"; then
        if [[ "$UPGRADE_MODE" == "true" ]]; then
            msg "Upgrading existing PHPVM installation..."
            return 0
        fi
        warn "PHPVM is already installed at $target_php"
        echo ""
        if ui_confirm "Reinstall/upgrade?"; then
            return 0
        else
            msg "Installation cancelled"
            exit 0
        fi
    fi

    # Check if target has real PHP binary
    if [[ -x "$target_php" ]]; then
        local php_version
        php_version=$(get_php_version "$target_php")

        echo ""
        warn "Found existing PHP at $target_php"
        [[ -n "$php_version" ]] && echo "     Version: PHP $php_version"
        echo ""

        if [[ "$FORCE" == "true" ]]; then
            msg "Force mode: will backup and replace existing PHP"
        else
            local choice
            choice=$(ui_choose "What would you like to do?" \
                "Backup existing PHP and install PHPVM" \
                "Cancel installation")

            if [[ "$choice" == "Cancel"* ]]; then
                msg "Installation cancelled"
                exit 0
            fi
        fi

        # Backup existing PHP
        msg "Backing up $target_php to ${target_php}.backup..."

        if [[ "$INSTALL_MODE" == "system" ]]; then
            $SUDO mv "$target_php" "${target_php}.backup"
        else
            mv "$target_php" "${target_php}.backup"
        fi
        success "Backup created: ${target_php}.backup"
    fi

    # Check /usr/bin/php for system-wide install (informational)
    if [[ "$INSTALL_MODE" == "system" && -x "/usr/bin/php" ]]; then
        local sys_php_version
        sys_php_version=$(get_php_version "/usr/bin/php")
        echo ""
        msg "Note: System PHP found at /usr/bin/php (v${sys_php_version})"
        echo "     PHPVM will be installed to /usr/local/bin/php which takes precedence."
        echo "     The system PHP will remain available as /usr/bin/php"
        echo ""
    fi

    return 0
}

# Prompt for install mode
select_install_mode() {
    if [[ -n "$INSTALL_MODE" ]]; then
        return
    fi

    if [[ $EUID -eq 0 ]]; then
        local choice
        choice=$(ui_choose "Installation Mode" \
            "System-wide (/usr/local/bin) - All users" \
            "User-local (~/.local/bin) - Current user only")

        if [[ "$choice" == "User"* ]]; then
            INSTALL_MODE="user"
        else
            INSTALL_MODE="system"
        fi
    else
        INSTALL_MODE="user"
        msg "Installing for current user (run as root for system-wide)"
    fi
}

# Uninstall
do_uninstall() {
    msg "Uninstalling PHPVM..."

    # System-wide
    if is_phpvm_binary "/usr/local/bin/php"; then
        $SUDO rm -f /usr/local/bin/php /usr/local/bin/composer
        $SUDO rm -f /etc/profile.d/phpvm.sh
        $SUDO rm -rf /etc/phpvm

        if [[ -f "/usr/local/bin/php.backup" ]]; then
            if ui_confirm "Restore backed up PHP?"; then
                $SUDO mv /usr/local/bin/php.backup /usr/local/bin/php
                success "Restored backup PHP"
            fi
        fi
        success "Removed system-wide installation"
    fi

    # User-local
    if is_phpvm_binary "$HOME/.local/bin/php"; then
        rm -f "$HOME/.local/bin/php" "$HOME/.local/bin/composer"
        rm -rf "$HOME/.config/phpvm"

        if [[ -f "$HOME/.local/bin/php.backup" ]]; then
            if ui_confirm "Restore backed up PHP?"; then
                mv "$HOME/.local/bin/php.backup" "$HOME/.local/bin/php"
                success "Restored backup PHP"
            fi
        fi
        success "Removed user-local installation"
    fi

    warn "User data in ~/.phpvm was NOT removed"
    echo "To remove completely: rm -rf ~/.phpvm"

    success "PHPVM uninstalled"
    echo "Please restart your shell or run: source ~/.bashrc"
}

# Main installation
do_install() {
    echo ""
    echo "${BOLD}+----------------------------------------+${RESET}"
    echo "${BOLD}|     PHP Version Manager Installer      |${RESET}"
    echo "${BOLD}|              v${PHPVM_VERSION}                     |${RESET}"
    echo "${BOLD}+----------------------------------------+${RESET}"
    echo ""

    detect_platform
    msg "Detected: $DISTRO_NAME"
    $IS_WSL && msg "Running in WSL"

    # Check requirements
    if ! command -v curl &>/dev/null; then
        error "curl is required but not installed"
        exit 1
    fi

    # Install gum first for nice UI
    install_gum || warn "gum installation failed, using fallback prompts"

    select_install_mode

    # Set paths based on mode
    local bin_dir env_file
    if [[ "$INSTALL_MODE" == "system" ]]; then
        bin_dir="/usr/local/bin"
        env_file="/etc/profile.d/phpvm.sh"
    else
        bin_dir="$HOME/.local/bin"
        env_file="$HOME/.config/phpvm/env.sh"
        mkdir -p "$bin_dir" "$HOME/.config/phpvm"
    fi

    # Check for existing PHP
    check_existing_php "$bin_dir"

    # Download scripts
    msg "Downloading PHPVM scripts..."

    local tmp_dir=$(mktemp -d)

    for script in php composer; do
        if ! curl -fsSL -o "${tmp_dir}/${script}" "${PHPVM_RAW_URL}/dist/${script}"; then
            error "Failed to download ${script}"
            rm -rf "$tmp_dir"
            exit 1
        fi
        chmod +x "${tmp_dir}/${script}"
    done

    if ! curl -fsSL -o "${tmp_dir}/env.sh" "${PHPVM_RAW_URL}/dist/env.sh"; then
        error "Failed to download env.sh"
        rm -rf "$tmp_dir"
        exit 1
    fi

    # Install scripts
    msg "Installing to $bin_dir..."

    if [[ "$INSTALL_MODE" == "system" ]]; then
        $SUDO install -m 755 "${tmp_dir}/php" "$bin_dir/php"
        $SUDO install -m 755 "${tmp_dir}/composer" "$bin_dir/composer"
        $SUDO install -m 644 "${tmp_dir}/env.sh" "$env_file"
    else
        install -m 755 "${tmp_dir}/php" "$bin_dir/php"
        install -m 755 "${tmp_dir}/composer" "$bin_dir/composer"
        install -m 644 "${tmp_dir}/env.sh" "$env_file"

        # Add to shell rc
        for rc_file in "$HOME/.bashrc" "$HOME/.zshrc"; do
            if [[ -f "$rc_file" ]]; then
                if ! grep -q "phpvm/env.sh" "$rc_file"; then
                    echo "" >> "$rc_file"
                    echo "# PHP Version Manager" >> "$rc_file"
                    echo "[[ -f \"$env_file\" ]] && source \"$env_file\"" >> "$rc_file"
                    msg "Added PHPVM to $rc_file"
                fi
            fi
        done

        # Ensure ~/.local/bin in PATH
        if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
            for rc_file in "$HOME/.bashrc" "$HOME/.zshrc"; do
                if [[ -f "$rc_file" ]]; then
                    if ! grep -q '\.local/bin' "$rc_file"; then
                        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$rc_file"
                    fi
                fi
            done
        fi
    fi

    rm -rf "$tmp_dir"

    # Create user directory
    mkdir -p "$HOME/.phpvm"

    # Source the environment file to make phpvm available immediately
    source "$env_file" 2>/dev/null || true

    success "PHPVM installed successfully!"
    echo ""
    echo "${BOLD}Next steps:${RESET}"
    echo ""
    echo "  1. Install PHP:"
    echo "     ${CYAN}php install${RESET}"
    echo ""
    echo "  2. Show help:"
    echo "     ${CYAN}php help${RESET}"
    echo ""

    echo "${DIM}Note: PHPVM is installed to $bin_dir which takes precedence over /usr/bin."
    echo "      Running 'apt install php' will not overwrite PHPVM."
    echo "      Open a new terminal if 'php' command is not found.${RESET}"
    echo ""
}

# Main
setup_colors

if [[ "${UNINSTALL:-}" == "true" ]]; then
    do_uninstall
else
    do_install
fi
