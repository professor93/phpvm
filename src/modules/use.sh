# use.sh - Version Switching
# PHP Version Manager (PHPVM)

# Session file for shell communication
PHPVM_SESSION_FILE="${PHPVM_SESSION_FILE:-}"

cmd_use() {
    local requested_version="$1"

    # Check if any PHP installed
    local installed
    installed=($(get_installed_versions))

    if [[ ${#installed[@]} -eq 0 ]]; then
        warn "No PHP versions installed"
        if gum_confirm "Would you like to install PHP now?"; then
            cmd_install
        fi
        return
    fi

    local version

    if [[ -n "$requested_version" ]]; then
        # Version specified
        validate_version_format "$requested_version" || return 1

        # Check if installed
        local found=false
        for v in "${installed[@]}"; do
            [[ "$v" == "$requested_version" ]] && found=true && break
        done

        if [[ "$found" == "false" ]]; then
            warn "PHP $requested_version is not installed"
            if gum_confirm "Would you like to install PHP $requested_version?"; then
                install_new_php_version "$requested_version" || return 1
            else
                return 1
            fi
        fi

        version="$requested_version"
    else
        # Interactive selection
        local options=()
        local current
        current=$(get_current_version)

        for v in "${installed[@]}"; do
            local label="PHP $v"
            [[ "$v" == "$current" ]] && label="PHP $v <- current"
            options+=("$label")
        done

        local choice
        choice=$(gum_menu "Select PHP version:" "${options[@]}")

        if [[ -z "$choice" ]]; then
            msg "Cancelled"
            return
        fi

        version=$(echo "$choice" | grep -oE '[0-9]+\.[0-9]+')
    fi

    # Select scope
    local scope
    scope=$(gum_menu "Set PHP $version for:" \
        "This session only" \
        "This directory (local .phpversion)" \
        "This user (global default)" \
        "System-wide (all users)")

    case "$scope" in
        "This session only")
            set_session_version "$version"
            ;;
        "This directory"*)
            set_local_version "$version"
            ;;
        "This user"*)
            set_user_version "$version"
            ;;
        "System-wide"*)
            set_system_version "$version"
            ;;
        *)
            msg "Cancelled"
            ;;
    esac
}

set_session_version() {
    local version="$1"

    # If running interactively with session file, write to it
    if [[ -n "$PHPVM_SESSION_FILE" ]]; then
        echo "$version" > "$PHPVM_SESSION_FILE"
        success "PHP $version set for this session"
    else
        # Output marker for shell wrapper to detect
        echo "PHPVERSION_USE=$version"
        success "PHP $version set for this session"
        echo ""
        echo "${DIM}Note: Run 'source ~/.bashrc' or start a new terminal for changes to take effect${RESET}"
    fi
}

set_local_version() {
    local version="$1"
    local target_dir="$PWD"

    # Check if .phpversion exists in parent directories
    local existing_file
    existing_file=$(find_phpversion_file 2>/dev/null)

    if [[ -n "$existing_file" && "$(dirname "$existing_file")" != "$PWD" ]]; then
        local choice
        choice=$(gum_menu "Found existing .phpversion in parent directory. Create in:" \
            "Current directory ($PWD)" \
            "Existing location ($(dirname "$existing_file"))" \
            "Cancel")

        case "$choice" in
            "Current directory"*)
                target_dir="$PWD"
                ;;
            "Existing location"*)
                target_dir=$(dirname "$existing_file")
                ;;
            *)
                msg "Cancelled"
                return
                ;;
        esac
    fi

    # Don't allow in root or home directly (unless explicit)
    if [[ "$target_dir" == "/" ]]; then
        error "Cannot create .phpversion in root directory"
        return 1
    fi

    echo "$version" > "${target_dir}/.phpversion"
    success "PHP $version set for ${target_dir}"
    info_log "Created ${target_dir}/.phpversion"
}

set_user_version() {
    local version="$1"

    mkdir -p "$PHPVM_DIR"
    echo "$version" > "$PHPVM_CONFIG"
    success "PHP $version set as user default"
    info_log "Updated ~/.phpversion/config"
}

set_system_version() {
    local version="$1"

    check_sudo

    run_privileged tee "$SYSTEM_CONFIG" > /dev/null <<< "$version"
    success "PHP $version set as system-wide default"
    info_log "Updated /etc/phpversion"
}
