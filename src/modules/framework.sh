# framework.sh - Framework Detection
# PHP Version Manager (PHPVM)

# Detect framework type in current directory
# Returns: laravel, symfony, yii, or empty
detect_framework() {
    local dir="${1:-$PWD}"

    # Laravel: has artisan file
    if [[ -f "$dir/artisan" ]]; then
        echo "laravel"
        return 0
    fi

    # Symfony: has bin/console or symfony.lock
    if [[ -f "$dir/bin/console" ]] || [[ -f "$dir/symfony.lock" ]]; then
        echo "symfony"
        return 0
    fi

    # Yii2: has yii file
    if [[ -f "$dir/yii" ]]; then
        echo "yii"
        return 0
    fi

    return 1
}

# Check if current directory is a PHP framework project
is_framework_project() {
    [[ -n "$(detect_framework)" ]]
}

# Get project name from composer.json or directory name
get_project_name() {
    local dir="${1:-$PWD}"

    if [[ -f "$dir/composer.json" ]]; then
        local name
        name=$(grep -oE '"name"\s*:\s*"[^"]+"' "$dir/composer.json" 2>/dev/null | head -1 | cut -d'"' -f4)
        if [[ -n "$name" ]]; then
            echo "$name"
            return
        fi
    fi

    # Fallback to directory name
    basename "$dir"
}

# Get framework console command
get_console_command() {
    local framework="${1:-$(detect_framework)}"
    local dir="${2:-$PWD}"

    case "$framework" in
        laravel)  echo "$dir/artisan" ;;
        symfony)  echo "$dir/bin/console" ;;
        yii)      echo "$dir/yii" ;;
    esac
}

# Get serve command for framework
get_serve_command() {
    local framework="${1:-$(detect_framework)}"

    case "$framework" in
        laravel)  echo "artisan serve" ;;
        symfony)  echo "bin/console server:start" ;;
        yii)      echo "yii serve" ;;
    esac
}

# Get queue worker command for framework
get_queue_command() {
    local framework="${1:-$(detect_framework)}"

    case "$framework" in
        laravel)  echo "artisan queue:work" ;;
        symfony)  echo "bin/console messenger:consume" ;;
        yii)      echo "yii queue/listen" ;;
    esac
}

# Get scheduler command for framework
get_scheduler_command() {
    local framework="${1:-$(detect_framework)}"

    case "$framework" in
        laravel)  echo "artisan schedule:run" ;;
        symfony)  echo "bin/console scheduler:run" ;;
        yii)      echo "yii schedule/run" ;;
    esac
}

# Check if Laravel Horizon is installed
has_horizon() {
    local dir="${1:-$PWD}"
    [[ -f "$dir/composer.json" ]] && grep -q '"laravel/horizon"' "$dir/composer.json" 2>/dev/null
}

# Check if Laravel Octane is installed
has_octane() {
    local dir="${1:-$PWD}"
    [[ -f "$dir/composer.json" ]] && grep -q '"laravel/octane"' "$dir/composer.json" 2>/dev/null
}

# Get available artisan/console commands (for completion)
get_framework_commands() {
    local framework="${1:-$(detect_framework)}"
    local php_bin="${2:-php}"

    case "$framework" in
        laravel)
            "$php_bin" artisan list --format=txt 2>/dev/null | grep -E '^\s+\w+' | awk '{print $1}'
            ;;
        symfony)
            "$php_bin" bin/console list --format=txt 2>/dev/null | grep -E '^\s+\w+' | awk '{print $1}'
            ;;
        yii)
            "$php_bin" yii help 2>/dev/null | grep -E '^\s+-\s+' | awk '{print $2}'
            ;;
    esac
}

# Get unique project identifier (for supervisor/cron naming)
get_project_id() {
    local dir="${1:-$PWD}"
    # Use hash of absolute path for uniqueness
    echo "phpvm_$(echo "$dir" | md5sum | cut -c1-8)"
}

# Get framework display name
get_framework_display_name() {
    local framework="${1:-$(detect_framework)}"

    case "$framework" in
        laravel)  echo "Laravel" ;;
        symfony)  echo "Symfony" ;;
        yii)      echo "Yii2" ;;
        *)        echo "PHP" ;;
    esac
}
