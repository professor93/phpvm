# config_edit.sh - Configuration Editing
# PHP Version Manager (PHPVM)

# View file using gum pager
view_config_file() {
    local file="$1"
    local title="$2"

    if [[ "$UI_MODE" == "gum" ]]; then
        gum pager --show-line-numbers < "$file"
    else
        # Fallback to less or cat
        if command_exists less; then
            less -N "$file"
        else
            cat -n "$file"
        fi
    fi
}

cmd_config() {
    local version
    version=$(get_current_version)

    if [[ -z "$version" ]]; then
        error "No PHP version active"
        return 1
    fi

    local choice
    choice=$(gum_menu "Select configuration file:" \
        "CLI php.ini" \
        "FPM php.ini" \
        "FPM Pool (www.conf)")

    local file
    case "$choice" in
        "CLI php.ini")
            file="/etc/php/${version}/cli/php.ini"
            ;;
        "FPM php.ini")
            file="/etc/php/${version}/fpm/php.ini"
            ;;
        "FPM Pool"*)
            file="/etc/php/${version}/fpm/pool.d/www.conf"
            ;;
        *)
            msg "Cancelled"
            return
            ;;
    esac

    if [[ ! -f "$file" ]]; then
        error "Configuration file not found: $file"
        return 1
    fi

    # Ask what to do with the file
    local action
    action=$(gum_menu "What would you like to do with $file?" \
        "View" \
        "Edit")

    case "$action" in
        "View")
            view_config_file "$file" "$choice"
            ;;
        "Edit")
            edit_config_file "$file" "$choice" "$version"
            ;;
        *)
            msg "Cancelled"
            ;;
    esac
}

edit_config_file() {
    local file="$1"
    local choice="$2"
    local version="$3"

    # Select editor
    local editor
    if command_exists micro; then
        editor="micro"
    elif [[ -n "$EDITOR" ]]; then
        editor="$EDITOR"
    elif command_exists nano; then
        editor="nano"
    elif command_exists vim; then
        editor="vim"
    else
        editor="vi"
    fi

    info_log "Opening $file with $editor..."
    run_privileged "$editor" "$file"

    # Offer to restart FPM if editing FPM config
    if [[ "$choice" == "FPM"* ]]; then
        local service="php${version}-fpm"
        if systemctl is-active "$service" &>/dev/null; then
            if gum_confirm "Restart PHP-FPM to apply changes?"; then
                run_privileged systemctl restart "$service"
                success "PHP-FPM restarted"
            fi
        fi
    fi
}
