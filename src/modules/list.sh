# list.sh - List Command
# PHP Version Manager (PHPVM)

cmd_list() {
    local subcommand="$1"

    if [[ "$subcommand" == "extensions" ]]; then
        list_extensions
    else
        list_versions
    fi
}

list_versions() {
    local installed
    installed=($(get_installed_versions))

    if [[ ${#installed[@]} -eq 0 ]]; then
        warn "No PHP versions installed"
        echo "Run 'php install' to install a PHP version"
        return
    fi

    local current
    current=$(get_current_version)

    echo ""
    echo "${BOLD}Installed PHP Versions:${RESET}"
    echo ""

    for v in "${installed[@]}"; do
        local php_bin
        php_bin=$(get_php_binary "$v")
        local full_version
        full_version=$("$php_bin" -r 'echo PHP_VERSION;' 2>/dev/null)

        if [[ "$v" == "$current" ]]; then
            echo "  ${GREEN}->${RESET} ${BOLD}PHP ${v}${RESET} (${full_version}) ${GREEN}<- active${RESET}"
        else
            echo "    PHP ${v} (${full_version})"
        fi
    done

    echo ""
}

list_extensions() {
    local version
    version=$(get_current_version)

    if [[ -z "$version" ]]; then
        error "No PHP version active"
        return 1
    fi

    local php_bin
    php_bin=$(get_php_binary "$version")

    echo ""
    echo "${BOLD}Extensions for PHP ${version}:${RESET}"
    echo ""

    echo "${CYAN}Loaded extensions (php -m):${RESET}"
    "$php_bin" -m 2>/dev/null | grep -v "^\[" | sort | while read -r ext; do
        echo "  * $ext"
    done

    echo ""
    echo "${CYAN}Installed packages:${RESET}"

    local pm=$(get_package_manager)
    case "$pm" in
        apt)
            dpkg -l "php${version}-*" 2>/dev/null | grep "^ii" | awk '{print "  * " $2}'
            ;;
        dnf|yum)
            local v_nodot="${version//./}"
            $pm list installed "php${v_nodot}*" 2>/dev/null | grep -v "^Installed" | awk '{print "  * " $1}'
            ;;
    esac

    echo ""
}
