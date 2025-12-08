# worker.sh - Queue Worker Management (Supervisor)
# PHP Version Manager (PHPVM)

SUPERVISOR_CONF_DIR="/etc/supervisor/conf.d"
PHPVM_WORKER_PREFIX="phpvm_worker_"

# ============================================
# Supervisor Installation
# ============================================

# Check if supervisor is installed
supervisor_is_installed() {
    command_exists supervisorctl
}

# Get supervisor version
supervisor_get_version() {
    supervisorctl version 2>/dev/null || supervisord --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?'
}

# Install supervisor
supervisor_install() {
    local pm=$(get_package_manager)

    if supervisor_is_installed; then
        local version
        version=$(supervisor_get_version)
        warn "Supervisor is already installed (v${version})"

        if ! gum_confirm "Reinstall/upgrade supervisor?"; then
            return 0
        fi
    fi

    info_log "Installing supervisor..."

    case "$pm" in
        apt)
            run_privileged apt-get update -qq 2>/dev/null
            # Suppress tmpfiles warnings in containers
            run_privileged apt-get install -y supervisor 2>&1 | grep -v "tmpfiles.d" || true
            ;;
        dnf)
            run_privileged dnf install -y supervisor 2>&1 | grep -v "tmpfiles.d" || true
            ;;
        yum)
            run_privileged yum install -y supervisor 2>&1 | grep -v "tmpfiles.d" || true
            ;;
        *)
            error "Unsupported package manager: $pm"
            echo ""
            echo "Please install supervisor manually:"
            echo "  pip install supervisor"
            return 1
            ;;
    esac

    if supervisor_is_installed; then
        local version
        version=$(supervisor_get_version)
        success "Supervisor installed (v${version})"

        # Enable and start supervisor
        if gum_confirm "Start supervisor now?"; then
            run_privileged systemctl enable supervisor 2>/dev/null || \
            run_privileged systemctl enable supervisord 2>/dev/null || true
            run_privileged systemctl start supervisor 2>/dev/null || \
            run_privileged systemctl start supervisord 2>/dev/null || true
            success "Supervisor started"
        fi
        return 0
    else
        error "Supervisor installation failed"
        return 1
    fi
}

# Uninstall supervisor
supervisor_uninstall() {
    if ! supervisor_is_installed; then
        warn "Supervisor is not installed"
        return 0
    fi

    if ! gum_confirm "Uninstall supervisor?" "no"; then
        return 0
    fi

    local pm=$(get_package_manager)

    # Stop service first
    run_privileged systemctl stop supervisor 2>/dev/null || \
    run_privileged systemctl stop supervisord 2>/dev/null || true
    run_privileged systemctl disable supervisor 2>/dev/null || \
    run_privileged systemctl disable supervisord 2>/dev/null || true

    case "$pm" in
        apt)
            if gum_confirm "Remove configuration files too?" "no"; then
                run_privileged apt-get purge -y supervisor
            else
                run_privileged apt-get remove -y supervisor
            fi
            run_privileged apt-get autoremove -y
            ;;
        dnf|yum)
            run_privileged $pm remove -y supervisor
            ;;
    esac

    success "Supervisor uninstalled"
}

# Supervisor service control
supervisor_service() {
    local action="$1"

    if ! supervisor_is_installed; then
        error "Supervisor is not installed"
        return 1
    fi

    # Try both service names (supervisor on Debian, supervisord on RHEL)
    case "$action" in
        start)
            run_privileged systemctl start supervisor 2>/dev/null || \
            run_privileged systemctl start supervisord 2>/dev/null && \
            success "Supervisor started"
            ;;
        stop)
            run_privileged systemctl stop supervisor 2>/dev/null || \
            run_privileged systemctl stop supervisord 2>/dev/null && \
            success "Supervisor stopped"
            ;;
        restart)
            run_privileged systemctl restart supervisor 2>/dev/null || \
            run_privileged systemctl restart supervisord 2>/dev/null && \
            success "Supervisor restarted"
            ;;
        status)
            systemctl status supervisor 2>/dev/null || \
            systemctl status supervisord 2>/dev/null
            ;;
        enable)
            run_privileged systemctl enable supervisor 2>/dev/null || \
            run_privileged systemctl enable supervisord 2>/dev/null && \
            success "Supervisor enabled"
            ;;
        disable)
            run_privileged systemctl disable supervisor 2>/dev/null || \
            run_privileged systemctl disable supervisord 2>/dev/null && \
            success "Supervisor disabled"
            ;;
        *)
            error "Unknown action: $action"
            return 1
            ;;
    esac
}

# Prompt to install supervisor if not installed, returns 1 if user cancels
supervisor_ensure_installed() {
    if ! supervisor_is_installed; then
        warn "Supervisor is not installed"
        if gum_confirm "Install supervisor?"; then
            supervisor_install || return 1
        else
            return 1
        fi
    fi
    return 0
}

# Legacy check function (now prompts for installation)
check_supervisor() {
    supervisor_ensure_installed
}

# Get supervisor config path for project
get_worker_config_path() {
    local project_id="$1"
    local worker_name="$2"
    echo "${SUPERVISOR_CONF_DIR}/${PHPVM_WORKER_PREFIX}${project_id}_${worker_name}.conf"
}

# List all workers for current project
list_project_workers() {
    local project_id
    project_id=$(get_project_id)

    local workers=()
    if [[ -d "$SUPERVISOR_CONF_DIR" ]]; then
        while IFS= read -r -d '' file; do
            local name
            name=$(basename "$file" .conf | sed "s/${PHPVM_WORKER_PREFIX}${project_id}_//")
            workers+=("$name")
        done < <(find "$SUPERVISOR_CONF_DIR" -name "${PHPVM_WORKER_PREFIX}${project_id}_*.conf" -print0 2>/dev/null)
    fi

    printf '%s\n' "${workers[@]}"
}

# Get worker status
get_worker_status() {
    local program_name="$1"
    supervisorctl status "$program_name" 2>/dev/null | awk '{print $2}'
}

# Worker management command
cmd_worker() {
    local framework
    framework=$(detect_framework)

    if [[ -z "$framework" ]]; then
        error "Not in a PHP framework project directory"
        echo "Supported: Laravel, Symfony, Yii2"
        return 1
    fi

    check_supervisor || return 1

    local action
    action=$(gum_menu "Queue Worker Management ($(get_framework_display_name)):" \
        "Add Worker" \
        "List Workers" \
        "Start Worker" \
        "Stop Worker" \
        "Restart Worker" \
        "Remove Worker" \
        "View Logs")

    case "$action" in
        "Add Worker")     worker_add ;;
        "List Workers")   worker_list ;;
        "Start Worker")   worker_control "start" ;;
        "Stop Worker")    worker_control "stop" ;;
        "Restart Worker") worker_control "restart" ;;
        "Remove Worker")  worker_remove ;;
        "View Logs")      worker_logs ;;
        *)                msg "Cancelled" ;;
    esac
}

# Add a new worker
worker_add() {
    local framework
    framework=$(detect_framework)
    local project_id
    project_id=$(get_project_id)
    local project_name
    project_name=$(get_project_name)
    local php_bin
    php_bin=$(get_php_binary)

    echo ""
    echo "${BOLD}Add Queue Worker${RESET}"
    echo ""

    # Worker name
    local worker_name
    worker_name=$(gum_input "Worker name:" "" "default")
    [[ -z "$worker_name" ]] && { msg "Cancelled"; return; }

    # Sanitize worker name
    worker_name=$(echo "$worker_name" | tr -cd 'a-zA-Z0-9_-')

    local command=""
    local num_procs=1

    # Framework-specific options
    case "$framework" in
        laravel)
            if has_horizon; then
                local use_horizon
                use_horizon=$(gum_menu "Laravel Horizon is installed. Use:" \
                    "Horizon (recommended for production)" \
                    "queue:work (standard)")

                if [[ "$use_horizon" == "Horizon"* ]]; then
                    command="$php_bin $PWD/artisan horizon"
                    num_procs=1  # Horizon manages its own workers
                else
                    local queue
                    queue=$(gum_input "Queue name:" "default")
                    local connection
                    connection=$(gum_input "Connection:" "redis")
                    command="$php_bin $PWD/artisan queue:work $connection --queue=$queue --sleep=3 --tries=3"
                fi
            else
                local queue
                queue=$(gum_input "Queue name:" "default")
                local connection
                connection=$(gum_input "Connection:" "database")
                command="$php_bin $PWD/artisan queue:work $connection --queue=$queue --sleep=3 --tries=3"
            fi
            ;;
        symfony)
            local transport
            transport=$(gum_input "Transport name:" "async")
            command="$php_bin $PWD/bin/console messenger:consume $transport --time-limit=3600"
            ;;
        yii)
            command="$php_bin $PWD/yii queue/listen --verbose"
            ;;
    esac

    # Number of processes
    local procs_input
    procs_input=$(gum_input "Number of processes:" "$num_procs")
    num_procs="${procs_input:-$num_procs}"

    # User
    local user
    user=$(gum_input "Run as user:" "$(whoami)")

    # Generate config
    local config_path
    config_path=$(get_worker_config_path "$project_id" "$worker_name")
    local program_name="${PHPVM_WORKER_PREFIX}${project_id}_${worker_name}"

    local config_content="[program:${program_name}]
process_name=%(program_name)s_%(process_num)02d
command=${command}
directory=${PWD}
user=${user}
numprocs=${num_procs}
autostart=true
autorestart=true
startsecs=1
startretries=3
redirect_stderr=true
stdout_logfile=/var/log/supervisor/${program_name}.log
stdout_logfile_maxbytes=10MB
stdout_logfile_backups=5
stopwaitsecs=60
; Project: ${project_name}
; Path: ${PWD}
; Framework: ${framework}
"

    echo ""
    echo "${CYAN}Supervisor configuration:${RESET}"
    echo "$config_content"
    echo ""

    if ! gum_confirm "Create this worker?"; then
        msg "Cancelled"
        return
    fi

    # Write config
    echo "$config_content" | run_privileged tee "$config_path" > /dev/null

    # Reload supervisor
    run_privileged supervisorctl reread
    run_privileged supervisorctl update

    success "Worker '$worker_name' created"
    info_log "Config: $config_path"

    if gum_confirm "Start worker now?"; then
        run_privileged supervisorctl start "${program_name}:*"
        success "Worker started"
    fi
}

# List workers
worker_list() {
    local project_id
    project_id=$(get_project_id)

    echo ""
    echo "${BOLD}Queue Workers for $(get_project_name):${RESET}"
    echo ""

    local workers
    workers=$(list_project_workers)

    if [[ -z "$workers" ]]; then
        warn "No workers configured for this project"
        return
    fi

    while IFS= read -r worker; do
        local program_name="${PHPVM_WORKER_PREFIX}${project_id}_${worker}"
        local status
        status=$(get_worker_status "$program_name:*")

        local status_color
        case "$status" in
            RUNNING) status_color="${GREEN}${status}${RESET}" ;;
            STOPPED) status_color="${YELLOW}${status}${RESET}" ;;
            *)       status_color="${RED}${status}${RESET}" ;;
        esac

        printf "  %-20s %s\n" "$worker" "$status_color"
    done <<< "$workers"

    echo ""
}

# Worker control (start/stop/restart)
worker_control() {
    local action="$1"
    local project_id
    project_id=$(get_project_id)

    local workers
    workers=$(list_project_workers)

    if [[ -z "$workers" ]]; then
        warn "No workers configured for this project"
        return
    fi

    # Build options with status
    local options=()
    while IFS= read -r worker; do
        local program_name="${PHPVM_WORKER_PREFIX}${project_id}_${worker}"
        local status
        status=$(get_worker_status "$program_name:*")
        options+=("$worker [$status]")
    done <<< "$workers"

    options+=("All workers")

    local choice
    choice=$(gum_menu "Select worker to ${action}:" "${options[@]}")

    [[ -z "$choice" ]] && { msg "Cancelled"; return; }

    # Confirm dangerous actions
    local confirm_default="yes"
    [[ "$action" == "stop" ]] && confirm_default="no"

    if [[ "$choice" == "All workers" ]]; then
        if ! gum_confirm "${action^} all workers?" "$confirm_default"; then
            msg "Cancelled"
            return
        fi
        while IFS= read -r worker; do
            local program_name="${PHPVM_WORKER_PREFIX}${project_id}_${worker}"
            run_privileged supervisorctl "$action" "${program_name}:*"
        done <<< "$workers"
        success "All workers ${action}ed"
    else
        local worker_name
        worker_name=$(echo "$choice" | cut -d' ' -f1)
        if ! gum_confirm "${action^} worker '$worker_name'?" "$confirm_default"; then
            msg "Cancelled"
            return
        fi
        local program_name="${PHPVM_WORKER_PREFIX}${project_id}_${worker_name}"
        run_privileged supervisorctl "$action" "${program_name}:*"
        success "Worker '$worker_name' ${action}ed"
    fi
}

# Remove worker
worker_remove() {
    local project_id
    project_id=$(get_project_id)

    local workers
    workers=$(list_project_workers)

    if [[ -z "$workers" ]]; then
        warn "No workers configured for this project"
        return
    fi

    local options=()
    while IFS= read -r worker; do
        options+=("$worker")
    done <<< "$workers"

    local choice
    choice=$(gum_menu "Select worker to remove:" "${options[@]}")

    [[ -z "$choice" ]] && { msg "Cancelled"; return; }

    if ! gum_confirm "Remove worker '$choice'?" "no"; then
        msg "Cancelled"
        return
    fi

    local program_name="${PHPVM_WORKER_PREFIX}${project_id}_${choice}"
    local config_path
    config_path=$(get_worker_config_path "$project_id" "$choice")

    # Stop worker first
    run_privileged supervisorctl stop "${program_name}:*" 2>/dev/null

    # Remove config
    run_privileged rm -f "$config_path"

    # Update supervisor
    run_privileged supervisorctl reread
    run_privileged supervisorctl update

    success "Worker '$choice' removed"
}

# View worker logs
worker_logs() {
    local project_id
    project_id=$(get_project_id)

    local workers
    workers=$(list_project_workers)

    if [[ -z "$workers" ]]; then
        warn "No workers configured for this project"
        return
    fi

    local options=()
    while IFS= read -r worker; do
        options+=("$worker")
    done <<< "$workers"

    local choice
    choice=$(gum_menu "Select worker to view logs:" "${options[@]}")

    [[ -z "$choice" ]] && { msg "Cancelled"; return; }

    local program_name="${PHPVM_WORKER_PREFIX}${project_id}_${choice}"
    local log_file="/var/log/supervisor/${program_name}.log"

    if [[ ! -f "$log_file" ]]; then
        warn "Log file not found: $log_file"
        return
    fi

    local action
    action=$(gum_menu "Log action:" \
        "View last 100 lines" \
        "Follow logs (tail -f)" \
        "View full log")

    case "$action" in
        "View last"*)
            run_privileged tail -n 100 "$log_file" | gum pager
            ;;
        "Follow"*)
            info_log "Press Ctrl+C to stop"
            run_privileged tail -f "$log_file"
            ;;
        "View full"*)
            run_privileged cat "$log_file" | gum pager
            ;;
    esac
}
