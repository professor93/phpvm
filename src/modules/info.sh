# info.sh - PHP Information
# PHP Version Manager (PHPVM)

cmd_info() {
    local version
    version=$(get_current_version)

    if [[ -z "$version" ]]; then
        error "No PHP version active"
        return 1
    fi

    local php_bin
    php_bin=$(get_php_binary "$version")
    local source
    source=$(get_version_source)

    print_header

    # PHPVM Info
    echo "${BOLD}PHPVM:${RESET}"
    echo "  Version: ${PHPVM_VERSION}"
    echo "  GitHub:  https://github.com/${PHPVM_REPO}"
    echo ""

    # PHP Version Info
    echo "${BOLD}PHP Information:${RESET}"
    echo ""

    echo "${CYAN}Version:${RESET}"
    "$php_bin" -v 2>/dev/null | head -1
    echo ""

    echo "${CYAN}Binary:${RESET} $php_bin"
    echo "${CYAN}Source:${RESET} $source"
    echo ""

    # php.ini locations
    echo "${CYAN}Configuration Files:${RESET}"
    local ini_cli
    ini_cli=$("$php_bin" --ini 2>/dev/null | grep "Loaded Configuration File" | cut -d':' -f2 | tr -d ' ')
    echo "  CLI php.ini: ${ini_cli:-Not found}"

    local fpm_ini="/etc/php/${version}/fpm/php.ini"
    if [[ -f "$fpm_ini" ]]; then
        echo "  FPM php.ini: $fpm_ini"
    fi
    echo ""

    # Key settings
    echo "${CYAN}Key Settings:${RESET}"
    echo "  memory_limit:        $("$php_bin" -r 'echo ini_get("memory_limit");' 2>/dev/null)"
    echo "  max_execution_time:  $("$php_bin" -r 'echo ini_get("max_execution_time");' 2>/dev/null)s"
    echo "  upload_max_filesize: $("$php_bin" -r 'echo ini_get("upload_max_filesize");' 2>/dev/null)"
    echo "  post_max_size:       $("$php_bin" -r 'echo ini_get("post_max_size");' 2>/dev/null)"
    echo ""

    # Composer info
    local composer_dir="$PHPVM_DIR/$version/composer"
    echo "${CYAN}Composer:${RESET}"
    if [[ -f "$composer_dir/composer.phar" ]]; then
        local composer_version
        composer_version=$("$php_bin" "$composer_dir/composer.phar" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        echo "  Version: $composer_version"
        echo "  Global packages: $composer_dir/vendor/"
    else
        echo "  Not installed for this PHP version"
        echo "  Run 'composer' to install"
    fi
    echo ""

    # Version Resolution Order
    echo "${CYAN}Version Resolution Order:${RESET}"
    echo ""

    local active_found=false

    # 1. Session
    if [[ -n "${PHPVERSION_USE:-}" ]]; then
        echo "  ${GREEN}[x]${RESET} 1. Session (PHPVERSION_USE=${PHPVERSION_USE})"
        active_found=true
    else
        echo "  ${DIM}[ ] 1. Session (PHPVERSION_USE not set)${RESET}"
    fi

    # 2. Local
    local local_file
    local_file=$(find_phpversion_file 2>/dev/null)
    if [[ -n "$local_file" && "$active_found" == "false" ]]; then
        local local_version
        local_version=$(cat "$local_file" 2>/dev/null | tr -d '[:space:]')
        echo "  ${GREEN}[x]${RESET} 2. Local (${local_file} = ${local_version})"
        active_found=true
    elif [[ -n "$local_file" ]]; then
        local local_version
        local_version=$(cat "$local_file" 2>/dev/null | tr -d '[:space:]')
        echo "  ${DIM}[ ] 2. Local (${local_file} = ${local_version})${RESET}"
    else
        echo "  ${DIM}[ ] 2. Local (no .phpversion found)${RESET}"
    fi

    # 3. User
    if [[ -f "$PHPVM_CONFIG" ]]; then
        local user_version
        user_version=$(cat "$PHPVM_CONFIG" 2>/dev/null | tr -d '[:space:]')
        if [[ "$active_found" == "false" ]]; then
            echo "  ${GREEN}[x]${RESET} 3. User (~/.phpversion/config = ${user_version})"
            active_found=true
        else
            echo "  ${DIM}[ ] 3. User (~/.phpversion/config = ${user_version})${RESET}"
        fi
    else
        echo "  ${DIM}[ ] 3. User (~/.phpversion/config not set)${RESET}"
    fi

    # 4. System
    if [[ -f "$SYSTEM_CONFIG" ]]; then
        local system_version
        system_version=$(cat "$SYSTEM_CONFIG" 2>/dev/null | tr -d '[:space:]')
        if [[ "$active_found" == "false" ]]; then
            echo "  ${GREEN}[x]${RESET} 4. System (/etc/phpversion = ${system_version})"
            active_found=true
        else
            echo "  ${DIM}[ ] 4. System (/etc/phpversion = ${system_version})${RESET}"
        fi
    else
        echo "  ${DIM}[ ] 4. System (/etc/phpversion not set)${RESET}"
    fi

    # 5. Fallback
    if [[ "$active_found" == "false" ]]; then
        echo "  ${GREEN}[x]${RESET} 5. Fallback (first installed)"
    else
        echo "  ${DIM}[ ] 5. Fallback (first installed)${RESET}"
    fi

    echo ""
}
