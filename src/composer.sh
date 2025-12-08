#!/bin/bash
# Composer wrapper for PHP Version Manager

set -o pipefail

# Source modules (will be inlined for distribution)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source all modules
source "$SCRIPT_DIR/modules/config.sh"
source "$SCRIPT_DIR/modules/colors.sh"
source "$SCRIPT_DIR/modules/utils.sh"
source "$SCRIPT_DIR/modules/platform.sh"
source "$SCRIPT_DIR/modules/ui.sh"
source "$SCRIPT_DIR/modules/version.sh"

install_composer() {
    local version="$1"
    local php_bin="$2"
    local composer_dir="$3"

    info_log "Installing Composer for PHP $version..."

    mkdir -p "$composer_dir"

    local tmp_file
    tmp_file=$(mktemp)

    # Download installer
    if ! curl -fsSL https://getcomposer.org/installer -o "$tmp_file"; then
        error "Failed to download Composer installer"
        rm -f "$tmp_file"
        return 1
    fi

    # Verify and install
    if ! "$php_bin" "$tmp_file" --install-dir="$composer_dir" --filename="composer.phar"; then
        error "Composer installation failed"
        rm -f "$tmp_file"
        return 1
    fi

    rm -f "$tmp_file"

    # Create composer.json for global packages
    if [[ ! -f "$composer_dir/composer.json" ]]; then
        cat > "$composer_dir/composer.json" <<EOF
{
    "name": "phpvm/global",
    "description": "Global Composer packages for PHP $version",
    "type": "project",
    "license": "MIT",
    "minimum-stability": "stable",
    "prefer-stable": true
}
EOF
    fi

    success "Composer installed for PHP $version"
    return 0
}

main() {
    setup_colors
    detect_distro
    set_ui_mode
    init_phpvm

    local version
    version=$(get_current_version)

    if [[ -z "$version" ]]; then
        error "No PHP version installed"
        echo "Run 'php install' to install PHP first"
        exit 1
    fi

    local php_bin
    php_bin=$(get_php_binary "$version")

    if [[ -z "$php_bin" || ! -x "$php_bin" ]]; then
        error "PHP $version binary not found"
        exit 1
    fi

    local composer_dir="$PHPVM_DIR/$version/composer"
    local composer_phar="$composer_dir/composer.phar"

    # Install Composer if not present
    if [[ ! -f "$composer_phar" ]]; then
        warn "Composer not installed for PHP $version"

        if ! gum_confirm "Would you like to install Composer now?"; then
            exit 1
        fi

        install_composer "$version" "$php_bin" "$composer_dir" || exit 1
    fi

    # Set Composer environment
    export COMPOSER_HOME="$composer_dir"
    export PATH="$composer_dir/vendor/bin:$PATH"

    # Run Composer
    exec "$php_bin" "$composer_phar" "$@"
}

main "$@"
