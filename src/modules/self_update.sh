# self_update.sh - Self-Update
# PHP Version Manager (PHPVM)

cmd_self_update() {
    info_log "Checking for updates..."

    local current_version="$PHPVM_VERSION"
    local latest_info

    # Fetch latest release info from GitHub
    latest_info=$(curl -fsSL "$PHPVM_GITHUB_API" 2>/dev/null)

    if [[ -z "$latest_info" ]]; then
        error "Failed to check for updates"
        echo "Could not connect to GitHub API"
        return 1
    fi

    local latest_version
    latest_version=$(echo "$latest_info" | grep -oE '"tag_name":\s*"v?[0-9]+\.[0-9]+\.[0-9]+"' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)

    if [[ -z "$latest_version" ]]; then
        error "Could not determine latest version"
        return 1
    fi

    echo ""
    echo "${BOLD}Current version:${RESET} $current_version"
    echo "${BOLD}Latest version:${RESET}  $latest_version"
    echo ""

    if version_gte "$current_version" "$latest_version"; then
        success "You are already running the latest version!"
        return 0
    fi

    # Show changelog if available
    local changelog
    changelog=$(echo "$latest_info" | grep -oE '"body":\s*"[^"]*"' | sed 's/"body":\s*"//' | sed 's/"$//' | head -20)

    if [[ -n "$changelog" ]]; then
        echo "${BOLD}Changelog:${RESET}"
        echo "$changelog" | sed 's/\\n/\n/g' | head -10
        echo ""
    fi

    if ! gum_confirm "Update to v${latest_version}?"; then
        msg "Update cancelled"
        return
    fi

    info_log "Downloading update..."

    local tmp_dir
    tmp_dir=$(mktemp -d)

    # Download the installer script
    local installer_url="${PHPVM_RAW_URL}/src/install.sh"

    if ! curl -fsSL -o "${tmp_dir}/install.sh" "$installer_url"; then
        error "Failed to download installer"
        rm -rf "$tmp_dir"
        return 1
    fi

    info_log "Running installer..."

    # Determine current installation mode
    local install_mode="user"
    if [[ -f "/usr/local/bin/php" ]]; then
        install_mode="system"
    fi

    # Run installer with appropriate mode
    if [[ "$install_mode" == "system" ]]; then
        run_privileged bash "${tmp_dir}/install.sh" --upgrade
    else
        bash "${tmp_dir}/install.sh" --upgrade --user
    fi

    rm -rf "$tmp_dir"

    success "Updated to v${latest_version}!"
    echo ""
    echo "Please restart your shell or run: source ~/.bashrc"
}
