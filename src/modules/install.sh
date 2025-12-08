# install.sh - Installation Module
# PHP Version Manager (PHPVM)

# Ensure PHP repository is configured
ensure_repository() {
    if ! check_php_repository; then
        warn "PHP repository not configured"

        if gum_confirm "Would you like to set up the PHP repository?"; then
            setup_php_repository || return 1
        else
            error "Cannot install PHP without repository"
            echo ""
            echo "Manual setup instructions:"
            local pm=$(get_package_manager)
            case "$pm" in
                apt)
                    echo "  sudo add-apt-repository ppa:ondrej/php"
                    echo "  sudo apt-get update"
                    ;;
                dnf|yum)
                    echo "  sudo dnf install https://rpms.remirepo.net/enterprise/remi-release-\$(rpm -E %rhel).rpm"
                    echo "  # Or for Fedora:"
                    echo "  sudo dnf install https://rpms.remirepo.net/fedora/remi-release-\$(rpm -E %fedora).rpm"
                    ;;
            esac
            return 1
        fi
    fi
    return 0
}

# Main install command
cmd_install() {
    local requested_version="$1"

    ensure_repository || return 1

    if [[ -n "$requested_version" ]]; then
        # Direct version install: php install 8.4
        validate_version_format "$requested_version" || return 1

        if ! is_supported_version "$requested_version"; then
            error "PHP $requested_version is not in the supported versions list"
            echo "Supported versions: ${SUPPORTED_VERSIONS[*]}"
            return 1
        fi

        # Check if already installed
        local php_bin
        php_bin=$(get_php_binary "$requested_version" 2>/dev/null)

        if [[ -n "$php_bin" && -x "$php_bin" ]]; then
            # Already installed - show options
            local action
            action=$(gum_menu "PHP $requested_version is already installed. What would you like to do?" \
                "Update" \
                "Install extensions" \
                "Uninstall" \
                "Cancel")

            case "$action" in
                "Update")
                    update_php_version "$requested_version"
                    ;;
                "Install extensions")
                    install_extension "$requested_version"
                    ;;
                "Uninstall")
                    uninstall_php_version "$requested_version"
                    ;;
                *)
                    msg "Cancelled"
                    ;;
            esac
        else
            # Not installed - install it
            install_new_php_version "$requested_version"
        fi
    else
        # Interactive install
        local choice
        choice=$(gum_menu "What would you like to install?" \
            "PHP Version" \
            "Extension (for current PHP)")

        case "$choice" in
            "PHP Version")
                install_php_version_interactive
                ;;
            "Extension"*)
                local current
                current=$(get_current_version)
                if [[ -z "$current" ]]; then
                    error "No PHP version installed"
                    echo "Run 'php install' to install a PHP version first"
                    return 1
                fi
                install_extension "$current"
                ;;
            *)
                msg "Cancelled"
                ;;
        esac
    fi
}

# Display failed extensions list
show_failed_extensions() {
    local version="$1"
    shift
    local failed=("$@")

    if [[ ${#failed[@]} -eq 0 ]]; then
        return 0
    fi

    echo ""
    warn "The following extensions failed to install:"
    echo ""

    if [[ "$UI_MODE" == "gum" ]]; then
        printf '%s\n' "${failed[@]}" | gum format
    else
        for ext in "${failed[@]}"; do
            echo "  - php${version}-${ext}"
        done
    fi

    echo ""
    return 1
}

# Install new PHP version
install_new_php_version() {
    local version="$1"

    info_log "Checking package availability for PHP $version..."

    if ! check_php_available "$version"; then
        error "PHP $version is not available in the repository"
        echo ""
        echo "This could mean:"
        echo "  - The version is not yet released"
        echo "  - The version is no longer supported"
        echo "  - The repository needs to be updated"
        echo ""
        echo "Try running: sudo apt-get update (or sudo dnf check-update)"
        return 1
    fi

    info_log "Installing PHP $version..."
    echo ""

    # Install base PHP first
    msg "Installing PHP $version base package..."
    if ! install_php_base "$version"; then
        error "Failed to install PHP $version base package"
        return 1
    fi
    success "PHP $version base installed"

    # Install default extensions one by one, collect failures
    local failed_extensions=()

    for ext in "${DEFAULT_EXTENSIONS[@]}"; do
        msg "Installing php${version}-${ext}..."
        if ! install_php_extension "$version" "$ext"; then
            failed_extensions+=("$ext")
        else
            success "php${version}-${ext} installed"
        fi
    done

    echo ""
    success "PHP $version installation completed"

    # Show failed extensions if any
    show_failed_extensions "$version" "${failed_extensions[@]}"

    # Validate installation
    local php_bin
    php_bin=$(get_php_binary "$version")

    if [[ -z "$php_bin" || ! -x "$php_bin" ]]; then
        warn "PHP $version was installed but binary not found at expected location"
        warn "You may need to configure your PATH or check the installation"
    else
        local full_version
        full_version=$("$php_bin" -r 'echo PHP_VERSION;' 2>/dev/null)
        success "Verified: PHP $full_version is working"
    fi

    # Set as default if first installation
    local installed
    installed=($(get_installed_versions))

    if [[ ${#installed[@]} -eq 1 ]]; then
        info_log "Setting PHP $version as default (first installation)"
        mkdir -p "$PHPVM_DIR"
        echo "$version" > "$PHPVM_CONFIG"
    fi

    return 0
}

# Interactive PHP version selection for installation
install_php_version_interactive() {
    local options=()
    local installed
    installed=($(get_installed_versions))

    for v in "${SUPPORTED_VERSIONS[@]}"; do
        local label="PHP $v"
        for inst in "${installed[@]}"; do
            if [[ "$inst" == "$v" ]]; then
                label="[INSTALLED] PHP $v"
                break
            fi
        done
        options+=("$label")
    done

    local choice
    choice=$(gum_menu "Select PHP version to install:" "${options[@]}")

    if [[ -z "$choice" ]]; then
        msg "Cancelled"
        return
    fi

    # Extract version from choice
    local version
    version=$(echo "$choice" | grep -oE '[0-9]+\.[0-9]+')

    if [[ "$choice" == "[INSTALLED]"* ]]; then
        local action
        action=$(gum_menu "PHP $version is already installed. What would you like to do?" \
            "Update" \
            "Install extensions" \
            "Uninstall" \
            "Cancel")

        case "$action" in
            "Update") update_php_version "$version" ;;
            "Install extensions") install_extension "$version" ;;
            "Uninstall") uninstall_php_version "$version" ;;
            *) msg "Cancelled" ;;
        esac
    else
        install_new_php_version "$version"
    fi
}

# Update PHP version
update_php_version() {
    local version="$1"
    local pm=$(get_package_manager)

    info_log "Updating PHP $version..."

    case "$pm" in
        apt)
            gum_spin "Updating PHP $version" run_privileged apt-get upgrade -y "php${version}*"
            ;;
        dnf|yum)
            local v_nodot="${version//./}"
            gum_spin "Updating PHP $version" run_privileged $pm update -y "php${v_nodot}*"
            ;;
    esac

    success "PHP $version updated"
}

# Uninstall PHP version
uninstall_php_version() {
    local version="$1"

    if ! gum_confirm "Are you sure you want to uninstall PHP $version?" "no"; then
        msg "Cancelled"
        return
    fi

    info_log "Uninstalling PHP $version..."

    gum_spin "Removing PHP $version" uninstall_php_package "$version"

    success "PHP $version uninstalled"

    # Clean up config if this was the default
    if [[ -f "$PHPVM_CONFIG" ]]; then
        local configured
        configured=$(cat "$PHPVM_CONFIG" 2>/dev/null | tr -d '[:space:]')
        if [[ "$configured" == "$version" ]]; then
            rm -f "$PHPVM_CONFIG"
            info_log "Removed user default configuration"
        fi
    fi
}

# Install extension for PHP version
install_extension() {
    local version="$1"

    info_log "Fetching available extensions for PHP $version..."

    # Get available and installed extensions using platform functions
    local available=()
    local installed_ext=()

    while IFS= read -r ext; do
        [[ -n "$ext" ]] && available+=("$ext")
    done < <(get_available_extensions "$version")

    while IFS= read -r ext; do
        [[ -n "$ext" ]] && installed_ext+=("$ext")
    done < <(get_installed_extensions "$version")

    if [[ ${#available[@]} -eq 0 ]]; then
        error "No extensions found for PHP $version"
        return 1
    fi

    # Build display options (only show not installed extensions)
    local options=()
    for ext in "${available[@]}"; do
        local is_installed=false
        for inst in "${installed_ext[@]}"; do
            if [[ "$inst" == "$ext" ]]; then
                is_installed=true
                break
            fi
        done
        if [[ "$is_installed" == "false" ]]; then
            options+=("$ext")
        fi
    done

    if [[ ${#options[@]} -eq 0 ]]; then
        info_log "All available extensions are already installed"
        return 0
    fi

    # Use multiselect menu
    local selected
    selected=$(gum_multi_menu "Select extensions to install for PHP $version:" "${options[@]}")

    if [[ -z "$selected" ]]; then
        msg "Cancelled"
        return
    fi

    echo ""

    # Install selected extensions one by one, collect failures
    local failed_extensions=()
    local success_count=0

    while IFS= read -r ext_name; do
        [[ -z "$ext_name" ]] && continue
        msg "Installing php${version}-${ext_name}..."
        if install_php_extension "$version" "$ext_name"; then
            success "php${version}-${ext_name} installed"
            ((success_count++))
        else
            failed_extensions+=("$ext_name")
        fi
    done <<< "$selected"

    echo ""

    # Show summary
    if [[ $success_count -gt 0 ]]; then
        success "$success_count extension(s) installed successfully"
    fi

    # Show failed extensions if any
    show_failed_extensions "$version" "${failed_extensions[@]}"
}

# Check if PHP is installed, prompt to install if not
check_no_php_installed() {
    local installed
    installed=($(get_installed_versions))

    if [[ ${#installed[@]} -eq 0 ]]; then
        warn "No PHP versions installed"
        echo ""

        if gum_confirm "Would you like to install PHP now?"; then
            cmd_install
            return $?
        else
            echo "Run 'php install' when ready to install PHP"
            exit 1
        fi
    fi
}
