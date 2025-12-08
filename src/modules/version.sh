# version.sh - Version Detection
# PHP Version Manager (PHPVM)

# Get list of installed PHP versions
get_installed_versions() {
    get_installed_versions_platform
}

# Find .phpversion file searching upward from current directory
find_phpversion_file() {
    local dir="$PWD"
    local home_dir="$HOME"

    while [[ "$dir" != "/" && "$dir" != "$home_dir" ]]; do
        if [[ -f "${dir}/.phpversion" ]]; then
            echo "${dir}/.phpversion"
            return 0
        fi
        dir=$(dirname "$dir")
    done

    # Check home directory itself (but not root /)
    if [[ -f "${home_dir}/.phpversion" && "$home_dir" != "/" ]]; then
        echo "${home_dir}/.phpversion"
        return 0
    fi

    return 1
}

# Get directory containing .phpversion
find_phpversion_dir() {
    local file
    file=$(find_phpversion_file) || return 1
    dirname "$file"
}

# Get current PHP version based on resolution order
get_current_version() {
    local version=""

    # 1. PHPVERSION_USE env var (session)
    if [[ -n "${PHPVERSION_USE:-}" ]]; then
        version="$PHPVERSION_USE"
    # 2. .phpversion file (local - searches up from $PWD)
    elif local file; file=$(find_phpversion_file) 2>/dev/null; then
        version=$(cat "$file" 2>/dev/null | tr -d '[:space:]')
    # 3. ~/.phpvm/version (user default)
    elif [[ -f "$PHPVM_CONFIG" ]]; then
        version=$(cat "$PHPVM_CONFIG" 2>/dev/null | tr -d '[:space:]')
    # 4. /etc/phpvm/version (system default)
    elif [[ -f "$SYSTEM_CONFIG" ]]; then
        version=$(cat "$SYSTEM_CONFIG" 2>/dev/null | tr -d '[:space:]')
    # 5. First installed version (fallback)
    else
        local installed
        installed=($(get_installed_versions))
        if [[ ${#installed[@]} -gt 0 ]]; then
            version="${installed[0]}"
        fi
    fi

    # Validate the version is actually installed
    if [[ -n "$version" ]]; then
        local php_bin
        php_bin=$(get_php_binary_path "$version")
        if [[ -x "$php_bin" ]]; then
            echo "$version"
            return 0
        fi
    fi

    # If configured version not installed, fall back to first installed
    local installed
    installed=($(get_installed_versions))
    if [[ ${#installed[@]} -gt 0 ]]; then
        echo "${installed[0]}"
    fi
}

# Get source description of current version
get_version_source() {
    # 1. PHPVERSION_USE env var (session)
    if [[ -n "${PHPVERSION_USE:-}" ]]; then
        echo "session (PHPVERSION_USE=${PHPVERSION_USE})"
        return
    fi

    # 2. .phpversion file (local)
    local file
    if file=$(find_phpversion_file) 2>/dev/null; then
        echo "local (${file})"
        return
    fi

    # 3. ~/.phpvm/version (user default)
    if [[ -f "$PHPVM_CONFIG" ]]; then
        echo "user (~/.phpvm/version)"
        return
    fi

    # 4. /etc/phpvm/version (system default)
    if [[ -f "$SYSTEM_CONFIG" ]]; then
        echo "system (/etc/phpvm/version)"
        return
    fi

    # 5. First installed version (fallback)
    echo "fallback (first installed)"
}

# Get PHP binary path for a version
get_php_binary() {
    local version="${1:-$(get_current_version)}"

    if [[ -z "$version" ]]; then
        return 1
    fi

    local php_bin
    php_bin=$(get_php_binary_path "$version")

    if [[ -x "$php_bin" ]]; then
        echo "$php_bin"
        return 0
    fi

    return 1
}

# Get full PHP version string (e.g., "8.4.2")
get_full_php_version() {
    local version="${1:-$(get_current_version)}"
    local php_bin
    php_bin=$(get_php_binary "$version") || return 1

    "$php_bin" -r 'echo PHP_VERSION;' 2>/dev/null
}
