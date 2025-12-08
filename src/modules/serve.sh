# serve.sh - Development Server Management
# PHP Version Manager (PHPVM)

# Serve command - smart argument parsing
# Usage: php serve [host:port | :port | port | args...]
#
# Smart parsing:
#   php serve 8080           -> --port=8080 --host=127.0.0.1
#   php serve :8080          -> --port=8080 --host=0.0.0.0
#   php serve 10.0.0.1:8080  -> --port=8080 --host=10.0.0.1
#   php serve --port 8080    -> passed directly to framework
#
# Laravel Octane:
#   php serve --octane       -> php artisan octane:start
#   php serve --octane 8080  -> php artisan octane:start --port=8080
#
# Framework detection:
#   Laravel:  php artisan serve [args...]
#   Symfony:  php bin/console server:start [args...]
#   Yii:      php yii serve [args...]
#   Other:    php -S host:port -t docroot
cmd_serve() {
    local php_bin
    php_bin=$(get_php_binary)

    local framework
    framework=$(detect_framework)

    # Check for --octane flag (Laravel only)
    local use_octane=false
    local remaining_args=()

    for arg in "$@"; do
        if [[ "$arg" == "--octane" ]]; then
            use_octane=true
        else
            remaining_args+=("$arg")
        fi
    done

    set -- "${remaining_args[@]}"

    # Parse shorthand arguments
    local args=()
    local host=""
    local port=""

    if [[ $# -gt 0 ]]; then
        local first_arg="$1"

        # Check if first arg is shorthand format
        if [[ "$first_arg" =~ ^:([0-9]+)$ ]]; then
            # :8080 format -> host=0.0.0.0, port=8080
            host="0.0.0.0"
            port="${BASH_REMATCH[1]}"
            shift
        elif [[ "$first_arg" =~ ^([0-9]+)$ ]]; then
            # 8080 format -> host=127.0.0.1, port=8080
            host="127.0.0.1"
            port="${BASH_REMATCH[1]}"
            shift
        elif [[ "$first_arg" =~ ^([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+):([0-9]+)$ ]]; then
            # 10.0.0.1:8080 format
            host="${BASH_REMATCH[1]}"
            port="${BASH_REMATCH[2]}"
            shift
        elif [[ "$first_arg" =~ ^([a-zA-Z0-9.-]+):([0-9]+)$ ]]; then
            # hostname:8080 format (e.g., localhost:8080)
            host="${BASH_REMATCH[1]}"
            port="${BASH_REMATCH[2]}"
            shift
        fi
    fi

    # Handle Laravel Octane
    if [[ "$use_octane" == "true" ]]; then
        if [[ "$framework" != "laravel" ]]; then
            error "Octane is only available for Laravel projects"
            return 1
        fi
        serve_octane "$php_bin" "$host" "$port" "$@"
        return
    fi

    # Build framework-specific arguments
    if [[ -n "$host" && -n "$port" ]]; then
        case "$framework" in
            laravel)
                args=("--host=$host" "--port=$port")
                ;;
            symfony)
                args=("$host:$port")
                ;;
            yii)
                args=("$host:$port")
                ;;
            *)
                # Non-framework: handled in serve_builtin
                args=("--host" "$host" "--port" "$port")
                ;;
        esac
    fi

    # Add remaining arguments
    args+=("$@")

    case "$framework" in
        laravel)
            serve_laravel "$php_bin" "${args[@]}"
            ;;
        symfony)
            serve_symfony "$php_bin" "${args[@]}"
            ;;
        yii)
            serve_yii "$php_bin" "${args[@]}"
            ;;
        *)
            serve_builtin "$php_bin" "${args[@]}"
            ;;
    esac
}

# Laravel artisan serve
serve_laravel() {
    local php_bin="$1"
    shift

    echo ""
    info_log "Starting Laravel development server..."
    echo "${DIM}Press Ctrl+C to stop${RESET}"
    echo ""

    "$php_bin" artisan serve "$@"
}

# Laravel Octane serve
serve_octane() {
    local php_bin="$1"
    local host="$2"
    local port="$3"
    shift 3

    # Check if Octane is installed
    if ! grep -q '"laravel/octane"' composer.json 2>/dev/null; then
        error "Laravel Octane is not installed"
        echo "Install with: composer require laravel/octane"
        return 1
    fi

    # Build octane arguments
    local octane_args=()
    [[ -n "$host" ]] && octane_args+=("--host=$host")
    [[ -n "$port" ]] && octane_args+=("--port=$port")
    octane_args+=("$@")

    echo ""
    info_log "Starting Laravel Octane..."
    echo "${DIM}Press Ctrl+C to stop${RESET}"
    echo ""

    "$php_bin" artisan octane:start "${octane_args[@]}"
}

# Symfony console server
serve_symfony() {
    local php_bin="$1"
    shift

    echo ""
    info_log "Starting Symfony development server..."
    echo "${DIM}Press Ctrl+C to stop${RESET}"
    echo ""

    "$php_bin" bin/console server:start "$@"
}

# Yii serve
serve_yii() {
    local php_bin="$1"
    shift

    echo ""
    info_log "Starting Yii2 development server..."
    echo "${DIM}Press Ctrl+C to stop${RESET}"
    echo ""

    "$php_bin" yii serve "$@"
}

# PHP built-in server (non-framework)
serve_builtin() {
    local php_bin="$1"
    shift

    local host="0.0.0.0"
    local port="8000"
    local docroot="."

    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --host|-h)
                host="$2"
                shift 2
                ;;
            --port|-p)
                port="$2"
                shift 2
                ;;
            --dir|-d|-t)
                docroot="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    # Auto-detect document root
    if [[ "$docroot" == "." ]]; then
        if [[ -d "public" ]]; then
            docroot="public"
        elif [[ -d "web" ]]; then
            docroot="web"
        elif [[ -d "www" ]]; then
            docroot="www"
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
