# serve.sh - Development Server Management
# PHP Version Manager (PHPVM)

# Serve command
cmd_serve() {
    local framework
    framework=$(detect_framework)

    if [[ -z "$framework" ]]; then
        error "Not in a PHP framework project directory"
        echo "Supported: Laravel, Symfony, Yii2"
        return 1
    fi

    local php_bin
    php_bin=$(get_php_binary)

    case "$framework" in
        laravel)  serve_laravel "$php_bin" ;;
        symfony)  serve_symfony "$php_bin" ;;
        yii)      serve_yii "$php_bin" ;;
    esac
}

# Laravel serve options
serve_laravel() {
    local php_bin="$1"

    local options=("artisan serve (built-in)")

    if has_octane; then
        options+=("Octane (Swoole/RoadRunner)")
    fi

    options+=("PHP built-in server")

    local choice
    choice=$(gum_menu "Select server for Laravel:" "${options[@]}")

    case "$choice" in
        "artisan serve"*)
            serve_artisan "$php_bin"
            ;;
        "Octane"*)
            serve_octane "$php_bin"
            ;;
        "PHP built-in"*)
            serve_builtin "$php_bin" "public"
            ;;
        *)
            msg "Cancelled"
            ;;
    esac
}

# Symfony serve options
serve_symfony() {
    local php_bin="$1"

    local choice
    choice=$(gum_menu "Select server for Symfony:" \
        "bin/console server:start" \
        "symfony serve (if installed)" \
        "PHP built-in server")

    case "$choice" in
        "bin/console"*)
            serve_symfony_console "$php_bin"
            ;;
        "symfony serve"*)
            serve_symfony_cli
            ;;
        "PHP built-in"*)
            serve_builtin "$php_bin" "public"
            ;;
        *)
            msg "Cancelled"
            ;;
    esac
}

# Yii serve options
serve_yii() {
    local php_bin="$1"

    local choice
    choice=$(gum_menu "Select server for Yii2:" \
        "yii serve (built-in)" \
        "PHP built-in server")

    case "$choice" in
        "yii serve"*)
            serve_yii_builtin "$php_bin"
            ;;
        "PHP built-in"*)
            serve_builtin "$php_bin" "web"
            ;;
        *)
            msg "Cancelled"
            ;;
    esac
}

# Laravel artisan serve
serve_artisan() {
    local php_bin="$1"

    local host
    host=$(gum_input "Host:" "127.0.0.1")

    local port
    port=$(gum_input "Port:" "8000")

    echo ""
    info_log "Starting Laravel development server..."
    echo "${CYAN}http://${host}:${port}${RESET}"
    echo "${DIM}Press Ctrl+C to stop${RESET}"
    echo ""

    "$php_bin" artisan serve --host="$host" --port="$port"
}

# Laravel Octane serve
serve_octane() {
    local php_bin="$1"

    local server
    server=$(gum_menu "Octane server:" \
        "Swoole" \
        "RoadRunner" \
        "FrankenPHP")

    local host
    host=$(gum_input "Host:" "127.0.0.1")

    local port
    port=$(gum_input "Port:" "8000")

    local workers
    workers=$(gum_input "Workers:" "auto")

    echo ""
    info_log "Starting Laravel Octane (${server})..."
    echo "${CYAN}http://${host}:${port}${RESET}"
    echo "${DIM}Press Ctrl+C to stop${RESET}"
    echo ""

    local server_option
    case "$server" in
        "Swoole")      server_option="--server=swoole" ;;
        "RoadRunner")  server_option="--server=roadrunner" ;;
        "FrankenPHP")  server_option="--server=frankenphp" ;;
    esac

    "$php_bin" artisan octane:start $server_option --host="$host" --port="$port" --workers="$workers"
}

# Symfony console server
serve_symfony_console() {
    local php_bin="$1"

    local host
    host=$(gum_input "Host:" "127.0.0.1")

    local port
    port=$(gum_input "Port:" "8000")

    echo ""
    info_log "Starting Symfony development server..."
    echo "${CYAN}http://${host}:${port}${RESET}"
    echo "${DIM}Press Ctrl+C to stop${RESET}"
    echo ""

    "$php_bin" bin/console server:start "${host}:${port}"
}

# Symfony CLI serve
serve_symfony_cli() {
    if ! command_exists symfony; then
        error "Symfony CLI is not installed"
        echo "Install: https://symfony.com/download"
        return 1
    fi

    local port
    port=$(gum_input "Port:" "8000")

    echo ""
    info_log "Starting Symfony local server..."
    echo "${DIM}Press Ctrl+C to stop${RESET}"
    echo ""

    symfony serve --port="$port"
}

# Yii built-in serve
serve_yii_builtin() {
    local php_bin="$1"

    local host
    host=$(gum_input "Host:" "localhost")

    local port
    port=$(gum_input "Port:" "8080")

    echo ""
    info_log "Starting Yii2 development server..."
    echo "${CYAN}http://${host}:${port}${RESET}"
    echo "${DIM}Press Ctrl+C to stop${RESET}"
    echo ""

    "$php_bin" yii serve "$host:$port"
}

# PHP built-in server
serve_builtin() {
    local php_bin="$1"
    local docroot="${2:-public}"

    local host
    host=$(gum_input "Host:" "127.0.0.1")

    local port
    port=$(gum_input "Port:" "8000")

    # Check if docroot exists
    if [[ ! -d "$docroot" ]]; then
        local available_dirs=()
        [[ -d "public" ]] && available_dirs+=("public")
        [[ -d "web" ]] && available_dirs+=("web")
        [[ -d "www" ]] && available_dirs+=("www")
        available_dirs+=("." "Custom path")

        docroot=$(gum_menu "Document root:" "${available_dirs[@]}")

        if [[ "$docroot" == "Custom path" ]]; then
            docroot=$(gum_input "Document root path:" ".")
        fi
    fi

    echo ""
    info_log "Starting PHP built-in server..."
    echo "${CYAN}http://${host}:${port}${RESET}"
    echo "Document root: $PWD/$docroot"
    echo "${DIM}Press Ctrl+C to stop${RESET}"
    echo ""

    "$php_bin" -S "${host}:${port}" -t "$docroot"
}
