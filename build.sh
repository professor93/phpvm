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

# Get version from git tag, VERSION file, or use "dev"
get_version() {
    local version
    # Try to get version from git tag (e.g., v1.2.1 -> 1.2.1)
    version=$(git describe --tags --exact-match 2>/dev/null | sed 's/^v//')
    if [[ -z "$version" ]]; then
        # Try to get latest tag + commits (e.g., v1.2.0-5-g1234567 -> 1.2.0-dev)
        version=$(git describe --tags 2>/dev/null | sed 's/^v//' | sed 's/-[0-9]*-g.*$/-dev/')
    fi
    if [[ -z "$version" ]]; then
        # Try to read from VERSION file
        if [[ -f "$SCRIPT_DIR/VERSION" ]]; then
            version=$(cat "$SCRIPT_DIR/VERSION" | tr -d '[:space:]')
        fi
    fi
    if [[ -z "$version" ]]; then
        version="dev"
    fi
    echo "$version"
}

VERSION=$(get_version)
msg "Version: ${BOLD}${VERSION}${RESET}"

# List of modules to include
MODULES=(
    "config.sh"
    "colors.sh"
    "utils.sh"
    "platform.sh"
    "ui.sh"
    "version.sh"
    "framework.sh"
    "install.sh"
    "use.sh"
    "list.sh"
    "info.sh"
    "config_edit.sh"
    "fpm.sh"
    "worker.sh"
    "cron.sh"
    "serve.sh"
    "menu.sh"
    "nginx.sh"
    "logs.sh"
    "completion.sh"
    "self_update.sh"
    "help.sh"
)

# Modules needed for composer wrapper
COMPOSER_MODULES=(
    "config.sh"
    "colors.sh"
    "utils.sh"
    "platform.sh"
    "ui.sh"
    "version.sh"
)

msg "Building PHPVM distribution..."

# Create dist directory
mkdir -p "$DIST_DIR"

# Build php command - combine all modules
msg "Building php command..."
{
    echo '#!/bin/bash'
    echo "# PHP Version Manager (PHPVM) v${VERSION}"
    echo '# https://github.com/professor93/phpvm'
    echo '# This file is auto-generated. Do not edit directly.'
    echo ''
    echo 'set -o pipefail'
    echo ''

    # Include all modules (replace __VERSION__ placeholder)
    for module in "${MODULES[@]}"; do
        echo "# === $module ==="
        cat "$SRC_DIR/modules/$module" | grep -v '^#' | sed "s/__VERSION__/${VERSION}/g"
        echo ''
    done

    # Main function with all commands
    echo '# === Main ==='
    cat <<'MAIN_EOF'
# Quick check if command is PHPVM command (for performance)
is_phpvm_command() {
    case "$1" in
        use|install|list|info|config|fpm|menu|serve|worker|cron|nginx|logs|tail|completion|self-update|selfupdate|update|help|--help|-h)
            return 0
            ;;
        artisan|console|yii|horizon|octane)
            # Framework commands - only if in project directory
            is_framework_project && return 0
            return 1
            ;;
        *)
            return 1
            ;;
    esac
}

main() {
    # Fast path: if no args or not a PHPVM command, minimal initialization
    if [[ $# -eq 0 ]]; then
        setup_colors
        detect_distro
        set_ui_mode
        show_help
        exit 0
    fi

    local command="$1"

    # Fast pass-through for PHP execution (minimal overhead)
    if ! is_phpvm_command "$command"; then
        # Direct pass-through to PHP binary
        local php_binary
        php_binary=$(get_php_binary 2>/dev/null)
        if [[ -z "$php_binary" || ! -x "$php_binary" ]]; then
            setup_colors
            error "No PHP version installed"
            echo "Run 'php install' to install PHP"
            exit 1
        fi
        exec "$php_binary" "$@"
    fi

    # Full initialization for PHPVM commands
    setup_colors
    detect_distro
    set_ui_mode

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

        # Interactive menu
        menu)
            init_phpvm
            cmd_menu
            ;;

        # Framework commands (only available in project directories)
        serve)
            init_phpvm
            cmd_serve
            ;;
        worker)
            init_phpvm
            cmd_worker
            ;;
        cron)
            init_phpvm
            cmd_cron
            ;;

        # Nginx management
        nginx)
            init_phpvm
            cmd_nginx "$@"
            ;;

        # Log management
        logs)
            init_phpvm
            cmd_logs "$@"
            ;;
        tail)
            init_phpvm
            cmd_tail "$@"
            ;;

        # Framework-specific pass-through
        artisan)
            init_phpvm
            run_artisan "$@"
            ;;
        console)
            init_phpvm
            run_console "$@"
            ;;
        yii)
            init_phpvm
            run_yii "$@"
            ;;
        horizon)
            init_phpvm
            run_horizon_cmd
            ;;
        octane)
            init_phpvm
            run_octane_cmd "$@"
            ;;

        # Tab completion
        completion)
            cmd_completion "$@"
            ;;

        # Maintenance
        self-update|selfupdate|update)
            cmd_self_update
            ;;

        # Help
        help|--help|-h)
            show_help
            ;;
    esac
}

# Framework command runners
run_artisan() {
    if [[ ! -f "artisan" ]]; then
        error "Not in a Laravel project directory"
        return 1
    fi
    local php_bin
    php_bin=$(get_php_binary)
    exec "$php_bin" artisan "$@"
}

run_console() {
    if [[ ! -f "bin/console" ]]; then
        error "Not in a Symfony project directory"
        return 1
    fi
    local php_bin
    php_bin=$(get_php_binary)
    exec "$php_bin" bin/console "$@"
}

run_yii() {
    if [[ ! -f "yii" ]]; then
        error "Not in a Yii project directory"
        return 1
    fi
    local php_bin
    php_bin=$(get_php_binary)
    exec "$php_bin" yii "$@"
}

run_horizon_cmd() {
    if [[ ! -f "artisan" ]]; then
        error "Not in a Laravel project directory"
        return 1
    fi
    if ! has_horizon; then
        error "Laravel Horizon is not installed"
        echo "Install with: composer require laravel/horizon"
        return 1
    fi
    local php_bin
    php_bin=$(get_php_binary)
    exec "$php_bin" artisan horizon
}

run_octane_cmd() {
    if [[ ! -f "artisan" ]]; then
        error "Not in a Laravel project directory"
        return 1
    fi
    if ! has_octane; then
        error "Laravel Octane is not installed"
        echo "Install with: composer require laravel/octane"
        return 1
    fi
    local php_bin
    php_bin=$(get_php_binary)
    if [[ $# -eq 0 ]]; then
        exec "$php_bin" artisan octane:start
    else
        exec "$php_bin" artisan "octane:$1" "${@:2}"
    fi
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

    # Include required modules (replace __VERSION__ placeholder)
    for module in "${COMPOSER_MODULES[@]}"; do
        echo "# === $module ==="
        cat "$SRC_DIR/modules/$module" | grep -v '^#' | sed "s/__VERSION__/${VERSION}/g"
        echo ''
    done

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

# Copy install.sh (replace __VERSION__ placeholder)
msg "Building install.sh..."
sed "s/__VERSION__/${VERSION}/g" "$SRC_DIR/install.sh" > "$DIST_DIR/install.sh"
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
