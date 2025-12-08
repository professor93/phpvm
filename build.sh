#!/bin/bash
# build.sh - Combine modules into distributable files

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/src"
DIST_DIR="$SCRIPT_DIR/dist"

# Colors
RED=$(tput setaf 1 2>/dev/null || echo '')
GREEN=$(tput setaf 2 2>/dev/null || echo '')
CYAN=$(tput setaf 6 2>/dev/null || echo '')
BOLD=$(tput bold 2>/dev/null || echo '')
RESET=$(tput sgr0 2>/dev/null || echo '')

msg()     { echo "${GREEN}->${RESET} $*"; }
success() { echo "${GREEN}[x]${RESET} $*"; }
error()   { echo "${RED}x${RESET} $*" >&2; }

msg "Building PHPVM distribution..."

# Create dist directory
mkdir -p "$DIST_DIR"

# Build php command - combine all modules
msg "Building php command..."
{
    echo '#!/bin/bash'
    echo '# PHP Version Manager (PHPVM) v1.0.0'
    echo '# https://github.com/professor93/phpvm'
    echo '# This file is auto-generated. Do not edit directly.'
    echo ''
    echo 'set -o pipefail'
    echo ''

    # config.sh
    echo '# === config.sh ==='
    cat "$SRC_DIR/modules/config.sh" | grep -v '^#'
    echo ''

    # colors.sh
    echo '# === colors.sh ==='
    cat "$SRC_DIR/modules/colors.sh" | grep -v '^#'
    echo ''

    # utils.sh
    echo '# === utils.sh ==='
    cat "$SRC_DIR/modules/utils.sh" | grep -v '^#'
    echo ''

    # platform.sh
    echo '# === platform.sh ==='
    cat "$SRC_DIR/modules/platform.sh" | grep -v '^#'
    echo ''

    # ui.sh
    echo '# === ui.sh ==='
    cat "$SRC_DIR/modules/ui.sh" | grep -v '^#'
    echo ''

    # version.sh
    echo '# === version.sh ==='
    cat "$SRC_DIR/modules/version.sh" | grep -v '^#'
    echo ''

    # install.sh module
    echo '# === install.sh (module) ==='
    cat "$SRC_DIR/modules/install.sh" | grep -v '^#'
    echo ''

    # use.sh
    echo '# === use.sh ==='
    cat "$SRC_DIR/modules/use.sh" | grep -v '^#'
    echo ''

    # list.sh
    echo '# === list.sh ==='
    cat "$SRC_DIR/modules/list.sh" | grep -v '^#'
    echo ''

    # info.sh
    echo '# === info.sh ==='
    cat "$SRC_DIR/modules/info.sh" | grep -v '^#'
    echo ''

    # config_edit.sh
    echo '# === config_edit.sh ==='
    cat "$SRC_DIR/modules/config_edit.sh" | grep -v '^#'
    echo ''

    # fpm.sh
    echo '# === fpm.sh ==='
    cat "$SRC_DIR/modules/fpm.sh" | grep -v '^#'
    echo ''

    # self_update.sh
    echo '# === self_update.sh ==='
    cat "$SRC_DIR/modules/self_update.sh" | grep -v '^#'
    echo ''

    # help.sh
    echo '# === help.sh ==='
    cat "$SRC_DIR/modules/help.sh" | grep -v '^#'
    echo ''

    # Main function
    echo '# === Main ==='
    cat <<'MAIN_EOF'
main() {
    setup_colors
    detect_distro
    set_ui_mode

    # No arguments - show help
    if [[ $# -eq 0 ]]; then
        show_help
        exit 0
    fi

    local command="$1"
    shift

    case "$command" in
        # Version management
        use)
            init_phpvm
            cmd_use "$@"
            ;;
        install)
            init_phpvm
            cmd_install "$@"
            ;;
        list)
            init_phpvm
            cmd_list "$@"
            ;;

        # Information
        info)
            init_phpvm
            cmd_info
            ;;

        # Configuration
        config)
            init_phpvm
            cmd_config
            ;;
        fpm)
            init_phpvm
            cmd_fpm
            ;;

        # Maintenance
        self-update|selfupdate|update)
            cmd_self_update
            ;;

        # Help
        help|--help|-h)
            show_help
            ;;

        # Pass-through to PHP
        -v|--version)
            # These go directly to PHP binary
            local php_binary
            php_binary=$(get_php_binary 2>/dev/null)
            if [[ -n "$php_binary" && -x "$php_binary" ]]; then
                exec "$php_binary" "$command" "$@"
            else
                error "No PHP version installed"
                echo "Run 'php install' to install PHP"
                exit 1
            fi
            ;;

        *)
            # Any other command passes through to PHP binary
            local php_binary
            php_binary=$(get_php_binary 2>/dev/null)
            if [[ -z "$php_binary" || ! -x "$php_binary" ]]; then
                error "No PHP version installed"
                echo "Run 'php install' to install PHP"
                exit 1
            fi
            exec "$php_binary" "$command" "$@"
            ;;
    esac
}

main "$@"
MAIN_EOF
} > "$DIST_DIR/php"

chmod +x "$DIST_DIR/php"
success "Built: dist/php"

# Build composer wrapper
msg "Building composer wrapper..."
{
    echo '#!/bin/bash'
    echo '# Composer wrapper for PHP Version Manager'
    echo '# https://github.com/professor93/phpvm'
    echo '# This file is auto-generated. Do not edit directly.'
    echo ''
    echo 'set -o pipefail'
    echo ''

    # config.sh
    echo '# === config.sh ==='
    cat "$SRC_DIR/modules/config.sh" | grep -v '^#'
    echo ''

    # colors.sh
    echo '# === colors.sh ==='
    cat "$SRC_DIR/modules/colors.sh" | grep -v '^#'
    echo ''

    # utils.sh
    echo '# === utils.sh ==='
    cat "$SRC_DIR/modules/utils.sh" | grep -v '^#'
    echo ''

    # platform.sh
    echo '# === platform.sh ==='
    cat "$SRC_DIR/modules/platform.sh" | grep -v '^#'
    echo ''

    # ui.sh
    echo '# === ui.sh ==='
    cat "$SRC_DIR/modules/ui.sh" | grep -v '^#'
    echo ''

    # version.sh
    echo '# === version.sh ==='
    cat "$SRC_DIR/modules/version.sh" | grep -v '^#'
    echo ''

    # Composer specific functions
    cat <<'COMPOSER_EOF'
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
COMPOSER_EOF
} > "$DIST_DIR/composer"

chmod +x "$DIST_DIR/composer"
success "Built: dist/composer"

# Copy env.sh
msg "Copying env.sh..."
cp "$SRC_DIR/env.sh" "$DIST_DIR/env.sh"
success "Built: dist/env.sh"

# Copy install.sh
msg "Copying install.sh..."
cp "$SRC_DIR/install.sh" "$DIST_DIR/install.sh"
chmod +x "$DIST_DIR/install.sh"
success "Built: dist/install.sh"

echo ""
success "Build complete!"
echo ""
echo "${BOLD}Distribution files:${RESET}"
ls -la "$DIST_DIR/"
echo ""
echo "${BOLD}To install locally for testing:${RESET}"
echo "  ${CYAN}bash dist/install.sh --user${RESET}"
echo ""
