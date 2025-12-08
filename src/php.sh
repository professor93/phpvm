#!/bin/bash
# PHP Version Manager (PHPVM)
# https://github.com/professor93/phpvm

set -o pipefail

# Version
PHPVM_VERSION="1.0.0"

# Source modules (will be inlined for distribution)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source all modules
source "$SCRIPT_DIR/modules/config.sh"
source "$SCRIPT_DIR/modules/colors.sh"
source "$SCRIPT_DIR/modules/utils.sh"
source "$SCRIPT_DIR/modules/platform.sh"
source "$SCRIPT_DIR/modules/ui.sh"
source "$SCRIPT_DIR/modules/version.sh"
source "$SCRIPT_DIR/modules/install.sh"
source "$SCRIPT_DIR/modules/use.sh"
source "$SCRIPT_DIR/modules/list.sh"
source "$SCRIPT_DIR/modules/info.sh"
source "$SCRIPT_DIR/modules/config_edit.sh"
source "$SCRIPT_DIR/modules/fpm.sh"
source "$SCRIPT_DIR/modules/self_update.sh"
source "$SCRIPT_DIR/modules/help.sh"

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
