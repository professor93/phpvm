# platform.sh - Platform Detection
# PHP Version Manager (PHPVM)

# Detect Linux distribution
detect_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        DISTRO_ID="${ID:-unknown}"
        DISTRO_ID_LIKE="${ID_LIKE:-}"
        DISTRO_VERSION="${VERSION_ID:-}"
        DISTRO_NAME="${PRETTY_NAME:-$ID}"
    elif [[ -f /etc/redhat-release ]]; then
        DISTRO_ID="rhel"
        DISTRO_NAME=$(cat /etc/redhat-release)
    elif [[ -f /etc/debian_version ]]; then
        DISTRO_ID="debian"
        DISTRO_NAME="Debian $(cat /etc/debian_version)"
    else
        DISTRO_ID="unknown"
        DISTRO_NAME="Unknown Linux"
    fi

    # Detect WSL
    IS_WSL=false
    if grep -qi microsoft /proc/version 2>/dev/null; then
        IS_WSL=true
    fi
}

# Get package manager type
get_package_manager() {
    case "$DISTRO_ID" in
        ubuntu|debian|linuxmint|pop)
            echo "apt"
            ;;
        fedora|rhel|centos|rocky|alma|ol)
            if command_exists dnf; then
                echo "dnf"
            else
                echo "yum"
            fi
            ;;
        opensuse*|sles)
            echo "zypper"
            ;;
        arch|manjaro)
            echo "pacman"
            ;;
        *)
            # Check by ID_LIKE
            if [[ "$DISTRO_ID_LIKE" == *"debian"* ]] || [[ "$DISTRO_ID_LIKE" == *"ubuntu"* ]]; then
                echo "apt"
            elif [[ "$DISTRO_ID_LIKE" == *"rhel"* ]] || [[ "$DISTRO_ID_LIKE" == *"fedora"* ]]; then
                command_exists dnf && echo "dnf" || echo "yum"
            else
                echo "unknown"
            fi
            ;;
    esac
}

# Get PHP package prefix for distro
get_php_package_prefix() {
    local pm=$(get_package_manager)
    case "$pm" in
        apt)
            echo "php"  # php8.4, php8.4-cli, etc.
            ;;
        dnf|yum)
            echo "php"  # php84, php84-cli, etc. (Remi format)
            ;;
        *)
            echo "php"
            ;;
    esac
}

# Get PHP binary path pattern
get_php_binary_path() {
    local version="$1"
    local pm=$(get_package_manager)

    case "$pm" in
        apt)
            echo "/usr/bin/php${version}"
            ;;
        dnf|yum)
            # Remi installs as php (managed by alternatives) or /usr/bin/phpXY
            local v_nodot="${version//./}"
            if [[ -x "/usr/bin/php${v_nodot}" ]]; then
                echo "/usr/bin/php${v_nodot}"
            elif [[ -x "/opt/remi/php${v_nodot}/root/usr/bin/php" ]]; then
                echo "/opt/remi/php${v_nodot}/root/usr/bin/php"
            else
                echo "/usr/bin/php${version}"
            fi
            ;;
        *)
            echo "/usr/bin/php${version}"
            ;;
    esac
}

# Check if repository is configured
check_php_repository() {
    local pm=$(get_package_manager)

    case "$pm" in
        apt)
            # Check for Ondrej's PPA
            if ls /etc/apt/sources.list.d/*ondrej* &>/dev/null || \
               grep -r "ondrej/php" /etc/apt/sources.list.d/ &>/dev/null; then
                return 0
            fi
            return 1
            ;;
        dnf|yum)
            # Check for Remi repository
            if [[ -f /etc/yum.repos.d/remi.repo ]] || \
               [[ -f /etc/yum.repos.d/remi-php*.repo ]] || \
               dnf repolist 2>/dev/null | grep -qi remi; then
                return 0
            fi
            return 1
            ;;
        *)
            return 1
            ;;
    esac
}

# Setup PHP repository
setup_php_repository() {
    local pm=$(get_package_manager)

    info_log "Setting up PHP repository for $DISTRO_NAME..."

    case "$pm" in
        apt)
            run_privileged apt-get update -qq
            run_privileged apt-get install -y software-properties-common
            run_privileged add-apt-repository -y ppa:ondrej/php
            run_privileged apt-get update -qq
            success "Ondrej's PHP PPA configured"
            ;;
        dnf)
            # Fedora
            if [[ "$DISTRO_ID" == "fedora" ]]; then
                run_privileged dnf install -y "https://rpms.remirepo.net/fedora/remi-release-${DISTRO_VERSION}.rpm"
            # RHEL/CentOS/Rocky/Alma
            else
                run_privileged dnf install -y epel-release
                run_privileged dnf install -y "https://rpms.remirepo.net/enterprise/remi-release-${DISTRO_VERSION%%.*}.rpm"
            fi
            success "Remi repository configured"
            ;;
        yum)
            run_privileged yum install -y epel-release
            run_privileged yum install -y "https://rpms.remirepo.net/enterprise/remi-release-${DISTRO_VERSION%%.*}.rpm"
            success "Remi repository configured"
            ;;
        *)
            error "Unsupported package manager: $pm"
            echo ""
            echo "Please manually configure a PHP repository for your distribution."
            echo ""
            echo "Supported repositories:"
            echo "  - Ubuntu/Debian: ppa:ondrej/php"
            echo "  - RHEL/CentOS/Fedora: https://rpms.remirepo.net/"
            return 1
            ;;
    esac
}

# Check if PHP version package is available
check_php_available() {
    local version="$1"
    local pm=$(get_package_manager)

    case "$pm" in
        apt)
            apt-cache show "php${version}" &>/dev/null
            ;;
        dnf)
            local v_nodot="${version//./}"
            dnf info "php${v_nodot}" &>/dev/null 2>&1 || \
            dnf info "php${v_nodot}-php-cli" &>/dev/null 2>&1
            ;;
        yum)
            local v_nodot="${version//./}"
            yum info "php${v_nodot}" &>/dev/null 2>&1
            ;;
        *)
            return 1
            ;;
    esac
}

# Install PHP base package (CLI only, no Apache)
install_php_base() {
    local version="$1"
    local pm=$(get_package_manager)

    case "$pm" in
        apt)
            # Install php-cli directly to avoid pulling in Apache
            run_privileged apt-get install -y "php${version}-cli"
            ;;
        dnf|yum)
            local v_nodot="${version//./}"
            # Enable Remi module for this PHP version
            if [[ "$pm" == "dnf" ]]; then
                run_privileged dnf module reset php -y 2>/dev/null || true
                run_privileged dnf module enable "php:remi-${version}" -y 2>/dev/null || true
            fi
            run_privileged $pm install -y "php${v_nodot}-php-cli"
            ;;
    esac
}

# Install single PHP extension
install_php_extension() {
    local version="$1"
    local ext="$2"
    local pm=$(get_package_manager)

    case "$pm" in
        apt)
            run_privileged apt-get install -y "php${version}-${ext}"
            ;;
        dnf|yum)
            local v_nodot="${version//./}"
            run_privileged $pm install -y "php${v_nodot}-php-${ext}"
            ;;
    esac
}

# Get available extensions for PHP version
get_available_extensions() {
    local version="$1"
    local pm=$(get_package_manager)

    case "$pm" in
        apt)
            apt-cache search "^php${version}-" 2>/dev/null | sed "s/php${version}-//" | cut -d' ' -f1 | sort
            ;;
        dnf|yum)
            local v_nodot="${version//./}"
            $pm list available "php${v_nodot}-php-*" 2>/dev/null | grep -v "^Last" | awk '{print $1}' | sed "s/php${v_nodot}-php-//" | cut -d'.' -f1 | sort -u
            ;;
    esac
}

# Get installed extensions for PHP version
get_installed_extensions() {
    local version="$1"
    local pm=$(get_package_manager)

    case "$pm" in
        apt)
            dpkg -l "php${version}-*" 2>/dev/null | grep "^ii" | awk '{print $2}' | sed "s/:.*//; s/php${version}-//"
            ;;
        dnf|yum)
            local v_nodot="${version//./}"
            $pm list installed "php${v_nodot}-php-*" 2>/dev/null | grep -v "^Installed" | awk '{print $1}' | sed "s/php${v_nodot}-php-//" | cut -d'.' -f1
            ;;
    esac
}

# Uninstall PHP package
uninstall_php_package() {
    local version="$1"
    local pm=$(get_package_manager)

    case "$pm" in
        apt)
            run_privileged apt-get remove -y "php${version}*"
            run_privileged apt-get autoremove -y
            ;;
        dnf|yum)
            local v_nodot="${version//./}"
            run_privileged $pm remove -y "php${v_nodot}*"
            ;;
    esac
}

# Get installed PHP versions
get_installed_versions_platform() {
    local pm=$(get_package_manager)
    local versions=()

    case "$pm" in
        apt)
            # Check for /usr/bin/phpX.Y binaries
            for v in "${SUPPORTED_VERSIONS[@]}"; do
                [[ -x "/usr/bin/php${v}" ]] && versions+=("$v")
            done
            ;;
        dnf|yum)
            # Check for Remi PHP installations
            for v in "${SUPPORTED_VERSIONS[@]}"; do
                local v_nodot="${v//./}"
                if [[ -x "/usr/bin/php${v_nodot}" ]] || \
                   [[ -x "/opt/remi/php${v_nodot}/root/usr/bin/php" ]]; then
                    versions+=("$v")
                fi
            done
            ;;
    esac

    echo "${versions[@]}"
}
