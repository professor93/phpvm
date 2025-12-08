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

    info_log "Installing PHP $version with default extensions..."

    if gum_spin "Installing PHP $version" install_php_package "$version" "${DEFAULT_EXTENSIONS[@]}"; then
        success "PHP $version installed successfully"

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
    else
        error "Failed to install PHP $version"
        return 1
    fi
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
    local pm=$(get_package_manager)

    info_log "Fetching available extensions for PHP $version..."

    local available=()
    local installed_ext=()

    case "$pm" in
        apt)
            # Get available packages
            while IFS= read -r line; do
                local ext_name
                ext_name=$(echo "$line" | sed "s/php${version}-//" | cut -d' ' -f1)
                available+=("$ext_name")
            done < <(apt-cache search "^php${version}-" 2>/dev/null | sort)

            # Get installed packages
            while IFS= read -r line; do
                local ext_name
                ext_name=$(echo "$line" | sed "s/php${version}-//")
                installed_ext+=("$ext_name")
            done < <(dpkg -l "php${version}-*" 2>/dev/null | grep "^ii" | awk '{print $2}' | sed "s/:.*//")
            ;;
        dnf|yum)
            local v_nodot="${version//./}"
            while IFS= read -r line; do
                local ext_name
                ext_name=$(echo "$line" | sed "s/php${v_nodot}-php-//" | sed "s/php${v_nodot}-//" | cut -d'.' -f1)
                available+=("$ext_name")
            done < <($pm list available "php${v_nodot}*" 2>/dev/null | grep -v "^Last" | awk '{print $1}' | sort -u)

            while IFS= read -r line; do
                local ext_name
                ext_name=$(echo "$line" | sed "s/php${v_nodot}-php-//" | sed "s/php${v_nodot}-//" | cut -d'.' -f1)
                installed_ext+=("$ext_name")
            done < <($pm list installed "php${v_nodot}*" 2>/dev/null | grep -v "^Installed" | awk '{print $1}')
            ;;
    esac

    if [[ ${#available[@]} -eq 0 ]]; then
        error "No extensions found for PHP $version"
        return 1
    fi

    # Build display options
    local options=()
    for ext in "${available[@]}"; do
        local label="$ext"
        for inst in "${installed_ext[@]}"; do
            if [[ "$inst" == "$ext" ]]; then
                label="[INSTALLED] $ext"
                break
            fi
        done
        options+=("$label")
    done

    local choice
    choice=$(gum_menu "Select extension for PHP $version:" "${options[@]}")

    if [[ -z "$choice" ]]; then
        msg "Cancelled"
        return
    fi

    local ext_name
    ext_name=$(echo "$choice" | sed 's/\[INSTALLED\] //')

    if [[ "$choice" == "[INSTALLED]"* ]]; then
        local action
        action=$(gum_menu "Extension $ext_name is installed. What would you like to do?" \
            "Update" \
            "Uninstall" \
            "Cancel")

        case "$action" in
            "Update")
                case "$pm" in
                    apt) gum_spin "Updating $ext_name" run_privileged apt-get upgrade -y "php${version}-${ext_name}" ;;
                    dnf|yum) gum_spin "Updating $ext_name" run_privileged $pm update -y "php${version//./}-php-${ext_name}" ;;
                esac
                success "Extension $ext_name updated"
                ;;
            "Uninstall")
                case "$pm" in
                    apt) gum_spin "Removing $ext_name" run_privileged apt-get remove -y "php${version}-${ext_name}" ;;
                    dnf|yum) gum_spin "Removing $ext_name" run_privileged $pm remove -y "php${version//./}-php-${ext_name}" ;;
                esac
                success "Extension $ext_name removed"
                ;;
            *)
                msg "Cancelled"
                ;;
        esac
    else
        info_log "Installing extension $ext_name for PHP $version..."
        case "$pm" in
            apt) gum_spin "Installing $ext_name" run_privileged apt-get install -y "php${version}-${ext_name}" ;;
            dnf|yum) gum_spin "Installing $ext_name" run_privileged $pm install -y "php${version//./}-php-${ext_name}" ;;
        esac
        success "Extension $ext_name installed"
    fi
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
