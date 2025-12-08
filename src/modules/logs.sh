# logs.sh - Advanced Log Management with Interactive TUI
# PHP Version Manager (PHPVM)

# Default settings
DEFAULT_TAIL_LINES=50
LOG_VIEWER_LEFT_WIDTH=30

# Check if ripgrep is available
has_ripgrep() {
    command -v rg &>/dev/null
}

# Check if grep is available
has_grep() {
    command -v grep &>/dev/null
}

# Ensure search tool is available
ensure_search_tool() {
    if has_ripgrep; then
        return 0
    fi

    if has_grep; then
        warn "ripgrep not found, using grep (slower)"
        return 0
    fi

    # Offer to install ripgrep
    echo "No search tool found (ripgrep or grep)"
    if gum_confirm "Install ripgrep?"; then
        info_log "Installing ripgrep..."
        case "$DISTRO_FAMILY" in
            debian)
                run_privileged apt-get update
                run_privileged apt-get install -y ripgrep
                ;;
            rhel)
                run_privileged dnf install -y ripgrep 2>/dev/null || \
                run_privileged yum install -y ripgrep
                ;;
            *)
                error "Cannot auto-install ripgrep on this platform"
                echo "Please install manually: https://github.com/BurntSushi/ripgrep"
                return 1
                ;;
        esac

        if has_ripgrep; then
            success "ripgrep installed"
            return 0
        else
            error "Failed to install ripgrep"
            return 1
        fi
    fi

    return 1
}

# Get framework log directory
get_framework_log_dir() {
    local framework
    framework=$(detect_framework 2>/dev/null)

    case "$framework" in
        laravel)
            echo "storage/logs"
            ;;
        symfony)
            echo "var/log"
            ;;
        yii)
            echo "runtime/logs"
            ;;
        *)
            return 1
            ;;
    esac
}

# Get all framework log files
get_framework_logs() {
    local log_dir
    log_dir=$(get_framework_log_dir)

    if [[ -z "$log_dir" || ! -d "$log_dir" ]]; then
        return 1
    fi

    find "$log_dir" -type f -name "*.log" 2>/dev/null | sort -r
}

# Get latest framework log
get_latest_framework_log() {
    local log_dir
    log_dir=$(get_framework_log_dir)

    if [[ -z "$log_dir" || ! -d "$log_dir" ]]; then
        return 1
    fi

    local framework
    framework=$(detect_framework 2>/dev/null)

    case "$framework" in
        laravel)
            local today_log="$log_dir/laravel-$(date +%Y-%m-%d).log"
            if [[ -f "$today_log" ]]; then
                echo "$today_log"
            elif [[ -f "$log_dir/laravel.log" ]]; then
                echo "$log_dir/laravel.log"
            else
                find "$log_dir" -type f -name "*.log" -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-
            fi
            ;;
        symfony)
            local env="${APP_ENV:-dev}"
            if [[ -f "$log_dir/$env.log" ]]; then
                echo "$log_dir/$env.log"
            else
                find "$log_dir" -type f -name "*.log" -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-
            fi
            ;;
        yii)
            if [[ -f "$log_dir/app.log" ]]; then
                echo "$log_dir/app.log"
            else
                find "$log_dir" -type f -name "*.log" -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-
            fi
            ;;
    esac
}

# Get supervisor log for project
get_supervisor_log() {
    local project_root="${1:-$PWD}"
    local project_id
    project_id=$(get_project_id "$project_root" 2>/dev/null)

    if [[ -z "$project_id" ]]; then
        return 1
    fi

    local log_file="/var/log/supervisor/${project_id}-worker.log"
    if [[ -f "$log_file" ]]; then
        echo "$log_file"
        return 0
    fi

    find /var/log/supervisor -name "${project_id}*.log" 2>/dev/null | head -1
}

# Get all supervisor logs for project
get_all_supervisor_logs() {
    local project_root="${1:-$PWD}"
    local project_id
    project_id=$(get_project_id "$project_root" 2>/dev/null)

    if [[ -z "$project_id" ]]; then
        return 1
    fi

    find /var/log/supervisor -name "${project_id}*.log" 2>/dev/null | sort
}

# Get nginx access log for project
get_nginx_access_log() {
    local config_file
    config_file=$(find_nginx_config 2>/dev/null)

    if [[ -n "$config_file" ]]; then
        parse_access_log "$config_file"
    else
        echo "/var/log/nginx/access.log"
    fi
}

# Get nginx error log for project
get_nginx_error_log() {
    local config_file
    config_file=$(find_nginx_config 2>/dev/null)

    if [[ -n "$config_file" ]]; then
        parse_error_log "$config_file"
    else
        echo "/var/log/nginx/error.log"
    fi
}

# Get PHP-FPM log
get_fpm_log() {
    local version
    version=$(get_current_version 2>/dev/null)

    local possible_logs=(
        "/var/log/php${version}-fpm.log"
        "/var/log/php-fpm/www-error.log"
        "/var/log/php-fpm.log"
        "/var/log/php/php${version}-fpm.log"
    )

    for log in "${possible_logs[@]}"; do
        if [[ -f "$log" ]]; then
            echo "$log"
            return 0
        fi
    done

    return 1
}

# Build log tree structure
# Returns array of: category|name|path
build_log_tree() {
    local logs=()

    # Nginx logs
    local access_log error_log
    access_log=$(get_nginx_access_log 2>/dev/null)
    error_log=$(get_nginx_error_log 2>/dev/null)

    [[ -f "$access_log" ]] && logs+=("nginx|access|$access_log")
    [[ -f "$error_log" ]] && logs+=("nginx|error|$error_log")

    # Framework logs
    local framework
    framework=$(detect_framework 2>/dev/null)

    if [[ -n "$framework" ]]; then
        local framework_logs
        framework_logs=$(get_framework_logs 2>/dev/null)

        if [[ -n "$framework_logs" ]]; then
            while IFS= read -r log; do
                local name
                name=$(basename "$log")
                logs+=("$framework|$name|$log")
            done <<< "$framework_logs"
        fi
    fi

    # Supervisor logs
    local supervisor_logs
    supervisor_logs=$(get_all_supervisor_logs 2>/dev/null)

    if [[ -n "$supervisor_logs" ]]; then
        while IFS= read -r log; do
            local name
            name=$(basename "$log")
            logs+=("supervisor|$name|$log")
        done <<< "$supervisor_logs"
    fi

    # PHP-FPM log
    local fpm_log
    fpm_log=$(get_fpm_log 2>/dev/null)
    [[ -n "$fpm_log" && -f "$fpm_log" ]] && logs+=("php-fpm|fpm.log|$fpm_log")

    printf '%s\n' "${logs[@]}"
}

# Resolve log type to file path
resolve_log_path() {
    local log_type="$1"

    case "$log_type" in
        app|framework|laravel|symfony|yii)
            get_latest_framework_log
            ;;
        access|nginx-access)
            get_nginx_access_log
            ;;
        error|nginx-error)
            get_nginx_error_log
            ;;
        worker|supervisor)
            get_supervisor_log
            ;;
        fpm|php-fpm)
            get_fpm_log
            ;;
        all)
            echo "all"
            ;;
        *)
            # Assume it's a file path
            if [[ -f "$log_type" ]]; then
                echo "$log_type"
            else
                return 1
            fi
            ;;
    esac
}

# Search logs using ripgrep or grep
search_logs_rg() {
    local pattern="$1"
    local log_path="$2"
    local lines="${3:-50}"
    local case_insensitive="${4:-true}"

    if [[ ! -f "$log_path" ]]; then
        error "Log file not found: $log_path"
        return 1
    fi

    local search_cmd
    local args=()

    if has_ripgrep; then
        search_cmd="rg"
        args+=(--color=always)
        [[ "$case_insensitive" == "true" ]] && args+=(-i)
        args+=("$pattern" "$log_path")
    else
        search_cmd="grep"
        args+=(--color=always)
        [[ "$case_insensitive" == "true" ]] && args+=(-i)
        args+=("$pattern" "$log_path")
    fi

    if [[ ! -r "$log_path" ]]; then
        run_privileged "$search_cmd" "${args[@]}" | tail -n "$lines"
    else
        "$search_cmd" "${args[@]}" | tail -n "$lines"
    fi
}

# Parse multiline Laravel exception
parse_laravel_exception() {
    local log_path="$1"
    local lines="${2:-100}"

    if [[ ! -f "$log_path" ]]; then
        return 1
    fi

    # Laravel log format: [YYYY-MM-DD HH:MM:SS] environment.LEVEL: message
    # Exceptions span multiple lines until next timestamp

    local content
    if [[ ! -r "$log_path" ]]; then
        content=$(run_privileged tail -n "$lines" "$log_path")
    else
        content=$(tail -n "$lines" "$log_path")
    fi

    # Group by timestamp entries
    echo "$content" | awk '
    /^\[20[0-9]{2}-[0-9]{2}-[0-9]{2}/ {
        if (entry != "") print entry
        entry = $0
        next
    }
    { entry = entry "\n" $0 }
    END { if (entry != "") print entry }
    '
}

# Parse multiline Symfony exception
parse_symfony_exception() {
    local log_path="$1"
    local lines="${2:-100}"

    if [[ ! -f "$log_path" ]]; then
        return 1
    fi

    local content
    if [[ ! -r "$log_path" ]]; then
        content=$(run_privileged tail -n "$lines" "$log_path")
    else
        content=$(tail -n "$lines" "$log_path")
    fi

    # Symfony log format: [YYYY-MM-DD HH:MM:SS] channel.LEVEL: message
    echo "$content" | awk '
    /^\[20[0-9]{2}-[0-9]{2}-[0-9]{2}/ {
        if (entry != "") print entry
        entry = $0
        next
    }
    { entry = entry "\n" $0 }
    END { if (entry != "") print entry }
    '
}

# Parse multiline Yii exception
parse_yii_exception() {
    local log_path="$1"
    local lines="${2:-100}"

    if [[ ! -f "$log_path" ]]; then
        return 1
    fi

    local content
    if [[ ! -r "$log_path" ]]; then
        content=$(run_privileged tail -n "$lines" "$log_path")
    else
        content=$(tail -n "$lines" "$log_path")
    fi

    # Yii log format varies, but typically starts with timestamp
    echo "$content" | awk '
    /^20[0-9]{2}[-\/][0-9]{2}[-\/][0-9]{2}/ || /^\[20[0-9]{2}/ {
        if (entry != "") print entry
        entry = $0
        next
    }
    { entry = entry "\n" $0 }
    END { if (entry != "") print entry }
    '
}

# Parse exceptions based on framework
parse_framework_exceptions() {
    local log_path="$1"
    local lines="${2:-100}"

    local framework
    framework=$(detect_framework 2>/dev/null)

    case "$framework" in
        laravel) parse_laravel_exception "$log_path" "$lines" ;;
        symfony) parse_symfony_exception "$log_path" "$lines" ;;
        yii) parse_yii_exception "$log_path" "$lines" ;;
        *)
            # Generic parsing
            if [[ ! -r "$log_path" ]]; then
                run_privileged tail -n "$lines" "$log_path"
            else
                tail -n "$lines" "$log_path"
            fi
            ;;
    esac
}

# Filter logs by level
filter_logs_by_level() {
    local log_path="$1"
    local level="$2"  # ERROR, WARNING, INFO, DEBUG
    local lines="${3:-100}"

    local pattern
    case "${level^^}" in
        ERROR|ERR) pattern="(ERROR|CRITICAL|EMERGENCY|ALERT)" ;;
        WARNING|WARN) pattern="(WARNING|WARN)" ;;
        INFO) pattern="INFO" ;;
        DEBUG) pattern="DEBUG" ;;
        *) pattern="$level" ;;
    esac

    search_logs_rg "$pattern" "$log_path" "$lines" "false"
}

# List available logs in tree format
list_logs_tree() {
    local logs
    logs=$(build_log_tree)

    if [[ -z "$logs" ]]; then
        echo "No logs found"
        return 1
    fi

    echo "${BOLD}Available Logs${RESET}"
    echo ""

    local current_category=""

    while IFS='|' read -r category name path; do
        if [[ "$category" != "$current_category" ]]; then
            current_category="$category"
            echo "${BOLD}${CYAN}$category${RESET}"
        fi

        local size
        size=$(du -h "$path" 2>/dev/null | cut -f1)
        echo "  ├─ ${name} ${DIM}($size)${RESET}"
    done <<< "$logs"
}

# Interactive log viewer with tree navigation
interactive_log_viewer() {
    if [[ "$UI_MODE" != "gum" ]]; then
        error "Interactive viewer requires gum"
        echo "Install gum: https://github.com/charmbracelet/gum"
        return 1
    fi

    local logs
    logs=$(build_log_tree)

    if [[ -z "$logs" ]]; then
        error "No logs found"
        return 1
    fi

    # Build selection menu
    local options=()
    local paths=()

    while IFS='|' read -r category name path; do
        options+=("$category/$name")
        paths+=("$path")
    done <<< "$logs"

    while true; do
        clear
        echo "${BOLD}Interactive Log Viewer${RESET}"
        echo "${DIM}Select a log to view, or press Esc to exit${RESET}"
        echo ""

        local choice
        choice=$(printf '%s\n' "${options[@]}" | gum filter \
            --header "Select log:" \
            --height 15 \
            --placeholder "Type to filter...")

        [[ -z "$choice" ]] && break

        # Find the path for selected choice
        local selected_path=""
        for i in "${!options[@]}"; do
            if [[ "${options[$i]}" == "$choice" ]]; then
                selected_path="${paths[$i]}"
                break
            fi
        done

        if [[ -n "$selected_path" ]]; then
            show_log_with_options "$selected_path"
        fi
    done
}

# Show log with viewing options
show_log_with_options() {
    local log_path="$1"

    while true; do
        clear
        echo "${BOLD}Log: ${CYAN}$log_path${RESET}"
        echo ""

        local action
        action=$(gum choose \
            "View last 50 lines" \
            "View last 100 lines" \
            "View last 500 lines" \
            "Tail (follow)" \
            "Search" \
            "Filter by level" \
            "Parse exceptions" \
            "Clear log" \
            "Back")

        case "$action" in
            "View last 50 lines")
                show_log_content "$log_path" 50
                ;;
            "View last 100 lines")
                show_log_content "$log_path" 100
                ;;
            "View last 500 lines")
                show_log_content "$log_path" 500
                ;;
            "Tail (follow)")
                follow_single_log "$log_path"
                ;;
            "Search")
                interactive_search "$log_path"
                ;;
            "Filter by level")
                interactive_filter_level "$log_path"
                ;;
            "Parse exceptions")
                show_parsed_exceptions "$log_path"
                ;;
            "Clear log")
                clear_single_log "$log_path"
                ;;
            "Back"|"")
                break
                ;;
        esac
    done
}

# Show log content with pager
show_log_content() {
    local log_path="$1"
    local lines="${2:-50}"

    local content
    if [[ ! -r "$log_path" ]]; then
        content=$(run_privileged tail -n "$lines" "$log_path")
    else
        content=$(tail -n "$lines" "$log_path")
    fi

    if [[ "$UI_MODE" == "gum" ]]; then
        echo "$content" | gum pager
    else
        echo "$content" | less
    fi
}

# Follow single log
follow_single_log() {
    local log_path="$1"

    echo ""
    info_log "Following: $log_path"
    echo "${DIM}Press Ctrl+C to stop${RESET}"
    echo ""

    if [[ ! -r "$log_path" ]]; then
        run_privileged tail -f "$log_path"
    else
        tail -f "$log_path"
    fi
}

# Interactive search
interactive_search() {
    local log_path="$1"

    ensure_search_tool || return 1

    local pattern
    pattern=$(gum input --placeholder "Enter search pattern...")

    [[ -z "$pattern" ]] && return

    echo ""
    info_log "Searching for: $pattern"
    echo ""

    local results
    results=$(search_logs_rg "$pattern" "$log_path" 100)

    if [[ -n "$results" ]]; then
        echo "$results" | gum pager
    else
        warn "No matches found"
        read -rp "Press Enter to continue..."
    fi
}

# Interactive filter by level
interactive_filter_level() {
    local log_path="$1"

    local level
    level=$(gum choose "ERROR" "WARNING" "INFO" "DEBUG" "Custom")

    [[ -z "$level" ]] && return

    if [[ "$level" == "Custom" ]]; then
        level=$(gum input --placeholder "Enter custom level/pattern...")
        [[ -z "$level" ]] && return
    fi

    echo ""
    info_log "Filtering by level: $level"
    echo ""

    local results
    results=$(filter_logs_by_level "$log_path" "$level" 100)

    if [[ -n "$results" ]]; then
        echo "$results" | gum pager
    else
        warn "No matches found"
        read -rp "Press Enter to continue..."
    fi
}

# Show parsed exceptions
show_parsed_exceptions() {
    local log_path="$1"

    echo ""
    info_log "Parsing exceptions..."
    echo ""

    local results
    results=$(parse_framework_exceptions "$log_path" 200)

    if [[ -n "$results" ]]; then
        echo "$results" | gum pager
    else
        warn "No exceptions found"
        read -rp "Press Enter to continue..."
    fi
}

# Clear single log
clear_single_log() {
    local log_path="$1"

    if ! gum_confirm "Clear log file: $log_path?"; then
        return 0
    fi

    if [[ ! -w "$log_path" ]]; then
        run_privileged truncate -s 0 "$log_path"
    else
        truncate -s 0 "$log_path"
    fi

    if [[ $? -eq 0 ]]; then
        success "Log cleared"
    else
        error "Failed to clear log"
    fi

    read -rp "Press Enter to continue..."
}

# Split screen log viewer for two logs
split_screen_viewer() {
    if ! command -v tmux &>/dev/null; then
        error "Split screen requires tmux"
        echo "Install tmux: sudo apt install tmux"
        return 1
    fi

    local logs
    logs=$(build_log_tree)

    if [[ -z "$logs" ]]; then
        error "No logs found"
        return 1
    fi

    # Build selection menu
    local options=()
    local paths=()

    while IFS='|' read -r category name path; do
        options+=("$category/$name")
        paths+=("$path")
    done <<< "$logs"

    echo "${BOLD}Split Screen Log Viewer${RESET}"
    echo ""

    # Select first log
    echo "Select log for ${CYAN}LEFT${RESET} pane:"
    local left_choice
    left_choice=$(printf '%s\n' "${options[@]}" | gum filter \
        --header "Select left log:" \
        --height 10)

    [[ -z "$left_choice" ]] && return

    local left_path=""
    for i in "${!options[@]}"; do
        if [[ "${options[$i]}" == "$left_choice" ]]; then
            left_path="${paths[$i]}"
            break
        fi
    done

    # Select second log
    echo ""
    echo "Select log for ${CYAN}RIGHT${RESET} pane:"
    local right_choice
    right_choice=$(printf '%s\n' "${options[@]}" | gum filter \
        --header "Select right log:" \
        --height 10)

    [[ -z "$right_choice" ]] && return

    local right_path=""
    for i in "${!options[@]}"; do
        if [[ "${options[$i]}" == "$right_choice" ]]; then
            right_path="${paths[$i]}"
            break
        fi
    done

    # Start tmux split session
    local session_name="phpvm_logs_$$"

    echo ""
    info_log "Starting split screen viewer..."
    echo "${DIM}Press Ctrl+B then D to detach, or Ctrl+C in both panes to exit${RESET}"
    sleep 1

    # Create tmux session with split panes
    tmux new-session -d -s "$session_name" "tail -f '$left_path'"
    tmux split-window -h -t "$session_name" "tail -f '$right_path'"
    tmux select-layout -t "$session_name" even-horizontal
    tmux attach-session -t "$session_name"

    # Cleanup
    tmux kill-session -t "$session_name" 2>/dev/null
}

# Follow multiple logs simultaneously
follow_all_logs() {
    local logs_to_follow=()

    # Collect all available logs
    local app_log
    app_log=$(get_latest_framework_log 2>/dev/null)
    [[ -n "$app_log" && -f "$app_log" ]] && logs_to_follow+=("$app_log")

    local error_log
    error_log=$(get_nginx_error_log 2>/dev/null)
    [[ -n "$error_log" && -f "$error_log" ]] && logs_to_follow+=("$error_log")

    local supervisor_log
    supervisor_log=$(get_supervisor_log 2>/dev/null)
    [[ -n "$supervisor_log" && -f "$supervisor_log" ]] && logs_to_follow+=("$supervisor_log")

    if [[ ${#logs_to_follow[@]} -eq 0 ]]; then
        error "No log files found to follow"
        return 1
    fi

    info_log "Following ${#logs_to_follow[@]} log files:"
    for log in "${logs_to_follow[@]}"; do
        echo "  - $log"
    done
    echo "${DIM}Press Ctrl+C to stop${RESET}"
    echo ""

    if [[ -r "${logs_to_follow[0]}" ]]; then
        tail -f "${logs_to_follow[@]}"
    else
        run_privileged tail -f "${logs_to_follow[@]}"
    fi
}

# Simple list for non-interactive mode
list_logs() {
    list_logs_tree
}

# Show log content (non-interactive)
show_log() {
    local log_type="${1:-app}"
    local lines="${2:-$DEFAULT_TAIL_LINES}"

    local log_path
    log_path=$(resolve_log_path "$log_type")

    if [[ -z "$log_path" ]]; then
        error "Log type '$log_type' not found"
        echo ""
        echo "Available log types:"
        echo "  app      - Framework log (Laravel/Symfony/Yii)"
        echo "  access   - Nginx access log"
        echo "  error    - Nginx error log"
        echo "  worker   - Supervisor worker log"
        echo "  fpm      - PHP-FPM log"
        return 1
    fi

    if [[ ! -f "$log_path" ]]; then
        error "Log file not found: $log_path"
        return 1
    fi

    if [[ ! -r "$log_path" ]]; then
        run_privileged tail -n "$lines" "$log_path"
    else
        tail -n "$lines" "$log_path"
    fi
}

# Follow log in real-time (non-interactive)
follow_log() {
    local log_type="${1:-app}"

    if [[ "$log_type" == "all" ]]; then
        follow_all_logs
        return
    fi

    local log_path
    log_path=$(resolve_log_path "$log_type")

    if [[ -z "$log_path" ]]; then
        error "Log type '$log_type' not found"
        return 1
    fi

    if [[ ! -f "$log_path" ]]; then
        error "Log file not found: $log_path"
        return 1
    fi

    info_log "Following: $log_path"
    echo "${DIM}Press Ctrl+C to stop${RESET}"
    echo ""

    if [[ ! -r "$log_path" ]]; then
        run_privileged tail -f "$log_path"
    else
        tail -f "$log_path"
    fi
}

# Search logs (non-interactive)
search_logs() {
    local pattern="$1"
    local log_type="${2:-app}"
    local lines="${3:-50}"

    if [[ -z "$pattern" ]]; then
        error "Search pattern required"
        echo "Usage: php logs search <pattern> [log_type] [lines]"
        return 1
    fi

    ensure_search_tool || return 1

    local log_path
    log_path=$(resolve_log_path "$log_type")

    if [[ -z "$log_path" || ! -f "$log_path" ]]; then
        error "Log file not found"
        return 1
    fi

    info_log "Searching in: $log_path"
    echo ""

    search_logs_rg "$pattern" "$log_path" "$lines"
}

# Clear/truncate a log file (non-interactive)
clear_log() {
    local log_type="$1"

    if [[ -z "$log_type" ]]; then
        error "Log type required"
        echo "Usage: php logs clear <log_type>"
        return 1
    fi

    local log_path
    log_path=$(resolve_log_path "$log_type")

    if [[ -z "$log_path" || ! -f "$log_path" ]]; then
        error "Log file not found"
        return 1
    fi

    if ! gum_confirm "Clear log file: $log_path?"; then
        return 0
    fi

    if [[ ! -w "$log_path" ]]; then
        run_privileged truncate -s 0 "$log_path"
    else
        truncate -s 0 "$log_path"
    fi

    if [[ $? -eq 0 ]]; then
        success "Log cleared: $log_path"
    else
        error "Failed to clear log"
        return 1
    fi
}

# Filter logs by level (non-interactive)
filter_logs() {
    local level="$1"
    local log_type="${2:-app}"
    local lines="${3:-100}"

    if [[ -z "$level" ]]; then
        error "Log level required"
        echo "Usage: php logs filter <level> [log_type] [lines]"
        echo "Levels: ERROR, WARNING, INFO, DEBUG"
        return 1
    fi

    local log_path
    log_path=$(resolve_log_path "$log_type")

    if [[ -z "$log_path" || ! -f "$log_path" ]]; then
        error "Log file not found"
        return 1
    fi

    info_log "Filtering $log_path by level: $level"
    echo ""

    filter_logs_by_level "$log_path" "$level" "$lines"
}

# Parse and display exceptions (non-interactive)
parse_exceptions() {
    local log_type="${1:-app}"
    local lines="${2:-200}"

    local log_path
    log_path=$(resolve_log_path "$log_type")

    if [[ -z "$log_path" || ! -f "$log_path" ]]; then
        error "Log file not found"
        return 1
    fi

    info_log "Parsing exceptions from: $log_path"
    echo ""

    parse_framework_exceptions "$log_path" "$lines"
}

# Logs command handler
cmd_logs() {
    local subcommand="${1:-}"
    shift 2>/dev/null || true

    # If no subcommand and gum available, show interactive viewer
    if [[ -z "$subcommand" && "$UI_MODE" == "gum" ]]; then
        interactive_log_viewer
        return
    fi

    case "$subcommand" in
        ""|list|ls)
            list_logs
            ;;
        show|cat)
            show_log "$@"
            ;;
        tail|follow|f)
            follow_log "$@"
            ;;
        search|grep)
            search_logs "$@"
            ;;
        filter)
            filter_logs "$@"
            ;;
        parse|exceptions)
            parse_exceptions "$@"
            ;;
        clear)
            clear_log "$@"
            ;;
        split)
            split_screen_viewer
            ;;
        interactive|viewer|ui)
            interactive_log_viewer
            ;;
        *)
            # If subcommand looks like a log type, show it
            local resolved
            resolved=$(resolve_log_path "$subcommand" 2>/dev/null)
            if [[ -n "$resolved" ]]; then
                show_log "$subcommand" "$@"
            else
                echo "Usage: php logs [command] [options]"
                echo ""
                echo "Commands:"
                echo "  (none)            Interactive log viewer (with gum)"
                echo "  list              List available logs"
                echo "  show <type>       Show last N lines (default: 50)"
                echo "  tail <type>       Follow log in real-time"
                echo "  tail all          Follow all logs simultaneously"
                echo "  search <pattern>  Search logs (ripgrep/grep)"
                echo "  filter <level>    Filter by level (ERROR/WARNING/INFO/DEBUG)"
                echo "  parse             Parse and show exceptions"
                echo "  clear <type>      Clear/truncate log file"
                echo "  split             Split screen view (requires tmux)"
                echo "  interactive       Open interactive viewer"
                echo ""
                echo "Log types:"
                echo "  app      - Framework log (Laravel/Symfony/Yii)"
                echo "  access   - Nginx access log"
                echo "  error    - Nginx error log"
                echo "  worker   - Supervisor worker log"
                echo "  fpm      - PHP-FPM log"
                echo "  all      - All logs (for tail command)"
                echo ""
                echo "Examples:"
                echo "  php logs                      # Interactive viewer"
                echo "  php logs list                 # List all logs"
                echo "  php logs show app             # Show last 50 lines"
                echo "  php logs show app 100         # Show last 100 lines"
                echo "  php logs tail app             # Follow app log"
                echo "  php logs tail all             # Follow all logs"
                echo "  php logs split                # Split screen (tmux)"
                echo "  php logs search \"error\" app   # Search for 'error'"
                echo "  php logs filter ERROR app     # Filter ERROR level"
                echo "  php logs parse app            # Parse exceptions"
                echo "  php logs clear app            # Clear app log"
            fi
            ;;
    esac
}

# Tail command - shortcut for logs tail
cmd_tail() {
    local log_type="${1:-app}"
    follow_log "$log_type"
}
