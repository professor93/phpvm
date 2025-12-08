# cron.sh - Crontab Management
# PHP Version Manager (PHPVM)

PHPVM_CRON_MARKER="# PHPVM:"

# Get cron marker for project
get_cron_marker() {
    local project_id
    project_id=$(get_project_id)
    echo "${PHPVM_CRON_MARKER}${project_id}"
}

# List crons for current project
list_project_crons() {
    local marker
    marker=$(get_cron_marker)

    crontab -l 2>/dev/null | grep -A1 "$marker" | grep -v "^--$" | grep -v "^${PHPVM_CRON_MARKER}"
}

# Count crons for current project
count_project_crons() {
    local marker
    marker=$(get_cron_marker)

    crontab -l 2>/dev/null | grep "$marker" | wc -l
}

# Cron management command
cmd_cron() {
    local framework
    framework=$(detect_framework)

    if [[ -z "$framework" ]]; then
        error "Not in a PHP framework project directory"
        echo "Supported: Laravel, Symfony, Yii2"
        return 1
    fi

    local action
    action=$(gum_menu "Scheduler/Cron Management ($(get_framework_display_name)):" \
        "Add Scheduler" \
        "Add Custom Cron" \
        "List Crons" \
        "Remove Cron" \
        "Remove All Project Crons")

    case "$action" in
        "Add Scheduler")       cron_add_scheduler ;;
        "Add Custom Cron")     cron_add_custom ;;
        "List Crons")          cron_list ;;
        "Remove Cron")         cron_remove ;;
        "Remove All"*)         cron_remove_all ;;
        *)                     msg "Cancelled" ;;
    esac
}

# Add framework scheduler cron
cron_add_scheduler() {
    local framework
    framework=$(detect_framework)
    local project_name
    project_name=$(get_project_name)
    local marker
    marker=$(get_cron_marker)
    local php_bin
    php_bin=$(get_php_binary)

    echo ""
    echo "${BOLD}Add Scheduler Cron${RESET}"
    echo ""

    local schedule="* * * * *"
    local command=""
    local description=""

    case "$framework" in
        laravel)
            command="cd $PWD && $php_bin artisan schedule:run >> /dev/null 2>&1"
            description="Laravel scheduler"
            ;;
        symfony)
            # Symfony doesn't have built-in scheduler like Laravel
            local schedule_cmd
            schedule_cmd=$(gum_input "Symfony command to schedule:" "app:my-command")
            command="cd $PWD && $php_bin bin/console $schedule_cmd >> /dev/null 2>&1"
            description="Symfony: $schedule_cmd"

            # Ask for custom schedule
            local custom_schedule
            custom_schedule=$(gum_input "Cron schedule:" "$schedule")
            schedule="${custom_schedule:-$schedule}"
            ;;
        yii)
            command="cd $PWD && $php_bin yii schedule/run >> /dev/null 2>&1"
            description="Yii2 scheduler"
            ;;
    esac

    echo ""
    echo "${CYAN}Cron entry:${RESET}"
    echo "$schedule $command"
    echo ""

    if ! gum_confirm "Add this cron job?"; then
        msg "Cancelled"
        return
    fi

    # Add to crontab
    local new_cron="${marker} ${project_name} - ${description}
${schedule} ${command}"

    (crontab -l 2>/dev/null; echo "$new_cron") | crontab -

    success "Scheduler cron added"
    info_log "Project: $project_name"
}

# Add custom cron
cron_add_custom() {
    local framework
    framework=$(detect_framework)
    local project_name
    project_name=$(get_project_name)
    local marker
    marker=$(get_cron_marker)
    local php_bin
    php_bin=$(get_php_binary)

    echo ""
    echo "${BOLD}Add Custom Cron${RESET}"
    echo ""

    # Schedule selection
    local schedule
    local schedule_choice
    schedule_choice=$(gum_menu "Select schedule:" \
        "Every minute (* * * * *)" \
        "Every 5 minutes (*/5 * * * *)" \
        "Every hour (0 * * * *)" \
        "Every day at midnight (0 0 * * *)" \
        "Every Monday at 9am (0 9 * * 1)" \
        "Custom schedule")

    case "$schedule_choice" in
        "Every minute"*)     schedule="* * * * *" ;;
        "Every 5"*)          schedule="*/5 * * * *" ;;
        "Every hour"*)       schedule="0 * * * *" ;;
        "Every day"*)        schedule="0 0 * * *" ;;
        "Every Monday"*)     schedule="0 9 * * 1" ;;
        "Custom"*)
            schedule=$(gum_input "Cron schedule (min hour day month weekday):" "* * * * *")
            ;;
        *)
            msg "Cancelled"
            return
            ;;
    esac

    # Command selection
    local command=""
    local description=""

    case "$framework" in
        laravel)
            local artisan_cmd
            artisan_cmd=$(gum_input "Artisan command:" "inspire")
            command="cd $PWD && $php_bin artisan $artisan_cmd >> /dev/null 2>&1"
            description="artisan $artisan_cmd"
            ;;
        symfony)
            local console_cmd
            console_cmd=$(gum_input "Console command:" "app:my-command")
            command="cd $PWD && $php_bin bin/console $console_cmd >> /dev/null 2>&1"
            description="console $console_cmd"
            ;;
        yii)
            local yii_cmd
            yii_cmd=$(gum_input "Yii command:" "my/command")
            command="cd $PWD && $php_bin yii $yii_cmd >> /dev/null 2>&1"
            description="yii $yii_cmd"
            ;;
    esac

    echo ""
    echo "${CYAN}Cron entry:${RESET}"
    echo "$schedule $command"
    echo ""

    if ! gum_confirm "Add this cron job?"; then
        msg "Cancelled"
        return
    fi

    # Add to crontab
    local new_cron="${marker} ${project_name} - ${description}
${schedule} ${command}"

    (crontab -l 2>/dev/null; echo "$new_cron") | crontab -

    success "Custom cron added"
}

# List crons
cron_list() {
    local marker
    marker=$(get_cron_marker)
    local project_name
    project_name=$(get_project_name)

    echo ""
    echo "${BOLD}Cron Jobs for ${project_name}:${RESET}"
    echo ""

    local crons
    crons=$(crontab -l 2>/dev/null | grep -A1 "$marker")

    if [[ -z "$crons" ]]; then
        warn "No cron jobs configured for this project"
        return
    fi

    local count=1
    while IFS= read -r line; do
        if [[ "$line" == "${PHPVM_CRON_MARKER}"* ]]; then
            local desc
            desc=$(echo "$line" | sed "s/${PHPVM_CRON_MARKER}[^ ]* //")
            echo "${CYAN}[$count] $desc${RESET}"
        elif [[ -n "$line" && "$line" != "--" ]]; then
            echo "    $line"
            echo ""
            ((count++))
        fi
    done <<< "$crons"
}

# Remove cron
cron_remove() {
    local marker
    marker=$(get_cron_marker)

    local crons
    crons=$(crontab -l 2>/dev/null | grep "$marker")

    if [[ -z "$crons" ]]; then
        warn "No cron jobs configured for this project"
        return
    fi

    # Build options
    local options=()
    while IFS= read -r line; do
        local desc
        desc=$(echo "$line" | sed "s/${PHPVM_CRON_MARKER}[^ ]* //")
        options+=("$desc")
    done <<< "$crons"

    local choice
    choice=$(gum_menu "Select cron to remove:" "${options[@]}")

    [[ -z "$choice" ]] && { msg "Cancelled"; return; }

    if ! gum_confirm "Remove this cron job?" "no"; then
        msg "Cancelled"
        return
    fi

    # Remove from crontab (remove marker line and following command line)
    local escaped_choice
    escaped_choice=$(echo "$choice" | sed 's/[[\.*^$()+?{|]/\\&/g')

    crontab -l 2>/dev/null | grep -v "${marker}.*${escaped_choice}" | \
        awk -v marker="$marker" -v choice="$choice" '
            BEGIN { skip_next = 0 }
            {
                if (skip_next) { skip_next = 0; next }
                if ($0 ~ marker && $0 ~ choice) { skip_next = 1; next }
                print
            }
        ' | crontab -

    success "Cron job removed"
}

# Remove all project crons
cron_remove_all() {
    local marker
    marker=$(get_cron_marker)
    local project_name
    project_name=$(get_project_name)

    local count
    count=$(count_project_crons)

    if [[ "$count" -eq 0 ]]; then
        warn "No cron jobs configured for this project"
        return
    fi

    echo ""
    warn "This will remove $count cron job(s) for '$project_name'"
    echo ""

    if ! gum_confirm "Remove all project crons?" "no"; then
        msg "Cancelled"
        return
    fi

    # Remove all project crons from crontab
    crontab -l 2>/dev/null | awk -v marker="$marker" '
        BEGIN { skip_next = 0 }
        {
            if (skip_next) { skip_next = 0; next }
            if ($0 ~ marker) { skip_next = 1; next }
            print
        }
    ' | crontab -

    success "All project crons removed"
}
