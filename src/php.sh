#!/bin/bash
# PHP Version Manager (PHPVM)
# https://github.com/professor93/phpvm

set -o pipefail

# Version (overridden by config.sh)
PHPVM_VERSION="1.2.2"

# Source modules (will be inlined for distribution)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source all modules
source "$SCRIPT_DIR/modules/config.sh"
source "$SCRIPT_DIR/modules/colors.sh"
source "$SCRIPT_DIR/modules/utils.sh"
source "$SCRIPT_DIR/modules/platform.sh"
source "$SCRIPT_DIR/modules/ui.sh"
source "$SCRIPT_DIR/modules/version.sh"
source "$SCRIPT_DIR/modules/framework.sh"
source "$SCRIPT_DIR/modules/install.sh"
source "$SCRIPT_DIR/modules/use.sh"
source "$SCRIPT_DIR/modules/list.sh"
source "$SCRIPT_DIR/modules/info.sh"
source "$SCRIPT_DIR/modules/config_edit.sh"
source "$SCRIPT_DIR/modules/fpm.sh"
source "$SCRIPT_DIR/modules/worker.sh"
source "$SCRIPT_DIR/modules/cron.sh"
source "$SCRIPT_DIR/modules/serve.sh"
source "$SCRIPT_DIR/modules/menu.sh"
source "$SCRIPT_DIR/modules/nginx.sh"
source "$SCRIPT_DIR/modules/logs.sh"
source "$SCRIPT_DIR/modules/completion.sh"
source "$SCRIPT_DIR/modules/self_update.sh"
source "$SCRIPT_DIR/modules/help.sh"

# Quick check if command is PHPVM command (for performance)
is_phpvm_command() {
    case "$1" in
        use|install|list|info|config|fpm|menu|serve|worker|cron|nginx|logs|tail|completion|self-update|selfupdate|update|help|--help|-h)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

main() {
    # Fast path: if no args, show quick usage
    if [[ $# -eq 0 ]]; then
        setup_colors
        detect_distro
        set_ui_mode
        show_quick_usage
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

        # Development server
        serve)
            init_phpvm
            cmd_serve "$@"
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

main "$@"
