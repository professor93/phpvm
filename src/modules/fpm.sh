# fpm.sh - FPM Management
# PHP Version Manager (PHPVM)

cmd_fpm() {
    local installed
    installed=($(get_installed_versions))

    if [[ ${#installed[@]} -eq 0 ]]; then
        error "No PHP versions installed"
        return 1
    fi

    # Find installed FPM services
    local fpm_services=()
    for v in "${installed[@]}"; do
        local service="php${v}-fpm"
        if systemctl list-unit-files "$service.service" &>/dev/null; then
            fpm_services+=("$v")
        fi
    done

    if [[ ${#fpm_services[@]} -eq 0 ]]; then
        warn "No PHP-FPM services installed"
        if gum_confirm "Would you like to install PHP-FPM?"; then
            local version
            version=$(get_current_version)
            local pm=$(get_package_manager)
            case "$pm" in
                apt) run_privileged apt-get install -y "php${version}-fpm" ;;
                dnf|yum) run_privileged $pm install -y "php${version//./}-php-fpm" ;;
            esac
            success "PHP-FPM installed"
        fi
        return
    fi

    # Main FPM menu
    local action
    action=$(gum_menu "PHP-FPM Management:" \
        "Service Control (start/stop/restart)" \
        "Enable/Disable Service" \
        "Edit Configuration" \
        "Create New Pool" \
        "Manage Pools" \
        "View Status")

    case "$action" in
        "Service Control"*)
            fpm_service_control "${fpm_services[@]}"
            ;;
        "Enable/Disable"*)
            fpm_enable_disable "${fpm_services[@]}"
            ;;
        "Edit Configuration")
            cmd_config
            ;;
        "Create New Pool")
            fpm_create_pool
            ;;
        "Manage Pools")
            fpm_manage_pools
            ;;
        "View Status")
            fpm_view_status "${fpm_services[@]}"
            ;;
        *)
            msg "Cancelled"
            ;;
    esac
}

fpm_service_control() {
    local services=("$@")
    local current
    current=$(get_current_version)

    # Build service options with status
    local options=()
    for v in "${services[@]}"; do
        local service="php${v}-fpm"
        local status
        if systemctl is-active "$service" &>/dev/null; then
            status="${GREEN}running${RESET}"
        else
            status="${RED}stopped${RESET}"
        fi
        local label="PHP $v FPM ($status)"
        [[ "$v" == "$current" ]] && label="$label <- current"
        options+=("$label")
    done

    local choice
    choice=$(gum_menu "Select FPM service:" "${options[@]}")

    if [[ -z "$choice" ]]; then
        return
    fi

    local version
    version=$(echo "$choice" | grep -oE '[0-9]+\.[0-9]+')
    local service="php${version}-fpm"

    local action
    action=$(gum_menu "Action for $service:" \
        "Start" \
        "Stop" \
        "Restart" \
        "Reload" \
        "Status")

    case "$action" in
        "Start")   run_privileged systemctl start "$service" && success "Started $service" ;;
        "Stop")    run_privileged systemctl stop "$service" && success "Stopped $service" ;;
        "Restart") run_privileged systemctl restart "$service" && success "Restarted $service" ;;
        "Reload")  run_privileged systemctl reload "$service" && success "Reloaded $service" ;;
        "Status")  systemctl status "$service" ;;
    esac
}

fpm_enable_disable() {
    local services=("$@")

    local options=()
    for v in "${services[@]}"; do
        local service="php${v}-fpm"
        local status
        if systemctl is-enabled "$service" &>/dev/null; then
            status="${GREEN}enabled${RESET}"
        else
            status="${YELLOW}disabled${RESET}"
        fi
        options+=("PHP $v FPM ($status)")
    done

    local choice
    choice=$(gum_menu "Select FPM service:" "${options[@]}")

    if [[ -z "$choice" ]]; then
        return
    fi

    local version
    version=$(echo "$choice" | grep -oE '[0-9]+\.[0-9]+')
    local service="php${version}-fpm"

    if systemctl is-enabled "$service" &>/dev/null; then
        if gum_confirm "Disable $service?"; then
            run_privileged systemctl disable "$service"
            success "$service disabled"
        fi
    else
        if gum_confirm "Enable $service?"; then
            run_privileged systemctl enable "$service"
            success "$service enabled"
        fi
    fi
}

fpm_create_pool() {
    local version
    version=$(get_current_version)

    echo ""
    echo "${BOLD}Create New PHP-FPM Pool${RESET}"
    echo ""

    local name
    name=$(gum_input "Pool name:" "" "myapp")

    if [[ -z "$name" ]]; then
        msg "Cancelled"
        return
    fi

    local user
    user=$(gum_input "User:" "$(whoami)")

    local group
    group=$(gum_input "Group:" "$(id -gn)")

    local socket
    socket=$(gum_input "Socket path:" "/run/php/${name}.sock")

    local pool_file="/etc/php/${version}/fpm/pool.d/${name}.conf"

    if [[ -f "$pool_file" ]]; then
        error "Pool configuration already exists: $pool_file"
        return 1
    fi

    run_privileged tee "$pool_file" > /dev/null <<EOF
[$name]
user = $user
group = $group
listen = $socket
listen.owner = www-data
listen.group = www-data
listen.mode = 0660

pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3

; Logging
catch_workers_output = yes
php_admin_flag[log_errors] = on
EOF

    success "Pool created: $pool_file"

    if gum_confirm "Restart PHP-FPM to activate?"; then
        run_privileged systemctl restart "php${version}-fpm"
        success "PHP-FPM restarted"
    fi
}

fpm_manage_pools() {
    local version
    version=$(get_current_version)
    local pool_dir="/etc/php/${version}/fpm/pool.d"

    if [[ ! -d "$pool_dir" ]]; then
        error "Pool directory not found: $pool_dir"
        return 1
    fi

    local pools=()
    while IFS= read -r -d '' file; do
        local name
        name=$(basename "$file")
        if [[ "$name" == *.disabled ]]; then
            pools+=("${name%.conf.disabled} (disabled)")
        else
            pools+=("${name%.conf} (enabled)")
        fi
    done < <(find "$pool_dir" -name "*.conf*" -print0 2>/dev/null)

    if [[ ${#pools[@]} -eq 0 ]]; then
        warn "No pools found"
        return
    fi

    local choice
    choice=$(gum_menu "Select pool:" "${pools[@]}")

    if [[ -z "$choice" ]]; then
        return
    fi

    local pool_name
    pool_name=$(echo "$choice" | cut -d' ' -f1)

    local action
    action=$(gum_menu "Action for $pool_name:" \
        "Edit" \
        "Enable/Disable" \
        "Delete")

    case "$action" in
        "Edit")
            local file="$pool_dir/${pool_name}.conf"
            [[ ! -f "$file" ]] && file="$pool_dir/${pool_name}.conf.disabled"
            run_privileged "${EDITOR:-nano}" "$file"
            ;;
        "Enable/Disable")
            if [[ -f "$pool_dir/${pool_name}.conf" ]]; then
                run_privileged mv "$pool_dir/${pool_name}.conf" "$pool_dir/${pool_name}.conf.disabled"
                success "Pool $pool_name disabled"
            else
                run_privileged mv "$pool_dir/${pool_name}.conf.disabled" "$pool_dir/${pool_name}.conf"
                success "Pool $pool_name enabled"
            fi
            ;;
        "Delete")
            if gum_confirm "Delete pool $pool_name?" "no"; then
                run_privileged rm -f "$pool_dir/${pool_name}.conf" "$pool_dir/${pool_name}.conf.disabled"
                success "Pool $pool_name deleted"
            fi
            ;;
    esac
}

fpm_view_status() {
    local services=("$@")

    echo ""
    echo "${BOLD}PHP-FPM Services Status:${RESET}"
    echo ""

    for v in "${services[@]}"; do
        local service="php${v}-fpm"
        local active_status enabled_status

        if systemctl is-active "$service" &>/dev/null; then
            active_status="${GREEN}running${RESET}"
        else
            active_status="${RED}stopped${RESET}"
        fi

        if systemctl is-enabled "$service" &>/dev/null; then
            enabled_status="${GREEN}enabled${RESET}"
        else
            enabled_status="${YELLOW}disabled${RESET}"
        fi

        printf "  PHP %s FPM: %s / %s\n" "$v" "$active_status" "$enabled_status"
    done

    echo ""
}
