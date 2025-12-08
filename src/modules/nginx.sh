# nginx.sh - Advanced Nginx Configuration Management
# PHP Version Manager (PHPVM)

# Common nginx config locations
NGINX_CONF_DIRS=(
    "/etc/nginx/sites-enabled"
    "/etc/nginx/conf.d"
    "/etc/nginx/sites-available"
)

# Template directory
NGINX_TEMPLATE_DIR="${HOME}/.phpvm/nginx-templates"

# Backend types
BACKEND_FPM="php-fpm"
BACKEND_OCTANE_SWOOLE="octane-swoole"
BACKEND_OCTANE_ROADRUNNER="octane-roadrunner"
BACKEND_OCTANE_FRANKENPHP="octane-frankenphp"
BACKEND_SWOOLE="swoole"
BACKEND_ROADRUNNER="roadrunner"
BACKEND_FRANKENPHP="frankenphp"
BACKEND_CUSTOM="custom"
BACKEND_UNKNOWN="unknown"

# Initialize template directory
init_nginx_templates() {
    mkdir -p "$NGINX_TEMPLATE_DIR"
}

# Find all nginx config files for current project
find_all_nginx_configs() {
    local project_root="${1:-$PWD}"
    project_root=$(cd "$project_root" 2>/dev/null && pwd)

    local found_configs=()

    for conf_dir in "${NGINX_CONF_DIRS[@]}"; do
        [[ ! -d "$conf_dir" ]] && continue

        while IFS= read -r -d '' conf_file; do
            if grep -q "$project_root" "$conf_file" 2>/dev/null; then
                found_configs+=("$conf_file")
            fi
        done < <(find "$conf_dir" -type f \( -name "*.conf" -o ! -name "*.*" \) -print0 2>/dev/null)
    done

    printf '%s\n' "${found_configs[@]}"
}

# Find nginx config file for current project (first match or interactive selection)
find_nginx_config() {
    local project_root="${1:-$PWD}"
    local all_configs
    all_configs=$(find_all_nginx_configs "$project_root")

    if [[ -z "$all_configs" ]]; then
        return 1
    fi

    local config_count
    config_count=$(echo "$all_configs" | wc -l)

    if [[ "$config_count" -eq 1 ]]; then
        echo "$all_configs"
        return 0
    fi

    # Multiple configs - return first one (use select_nginx_config for interactive)
    echo "$all_configs" | head -1
}

# Interactive nginx config selection
select_nginx_config() {
    local project_root="${1:-$PWD}"
    local all_configs
    all_configs=$(find_all_nginx_configs "$project_root")

    if [[ -z "$all_configs" ]]; then
        error "No nginx configurations found for this project"
        return 1
    fi

    local config_count
    config_count=$(echo "$all_configs" | wc -l)

    if [[ "$config_count" -eq 1 ]]; then
        echo "$all_configs"
        return 0
    fi

    # Multiple configs - let user select
    if [[ "$UI_MODE" == "gum" ]]; then
        local choice
        choice=$(echo "$all_configs" | gum filter \
            --header "Multiple configs found. Select one:" \
            --height 10)
        echo "$choice"
    else
        echo "Multiple nginx configurations found:"
        local i=1
        while IFS= read -r config; do
            echo "  $i) $config"
            ((i++))
        done <<< "$all_configs"

        local choice
        read -rp "Select config (1-$config_count): " choice

        echo "$all_configs" | sed -n "${choice}p"
    fi
}

# Parse server_name from nginx config
parse_server_name() {
    local config_file="$1"
    [[ ! -f "$config_file" ]] && return 1

    grep -oP 'server_name\s+\K[^;]+' "$config_file" 2>/dev/null | head -1 | tr -d ' '
}

# Parse listen port from nginx config
parse_listen_port() {
    local config_file="$1"
    [[ ! -f "$config_file" ]] && return 1

    local port
    port=$(grep -oP 'listen\s+\K\d+' "$config_file" 2>/dev/null | head -1)
    echo "${port:-80}"
}

# Parse access log path from nginx config
parse_access_log() {
    local config_file="$1"
    [[ ! -f "$config_file" ]] && return 1

    local log_path
    log_path=$(grep -oP 'access_log\s+\K[^\s;]+' "$config_file" 2>/dev/null | head -1)

    if [[ -n "$log_path" && "$log_path" != "off" ]]; then
        echo "$log_path"
    else
        echo "/var/log/nginx/access.log"
    fi
}

# Parse error log path from nginx config
parse_error_log() {
    local config_file="$1"
    [[ ! -f "$config_file" ]] && return 1

    local log_path
    log_path=$(grep -oP 'error_log\s+\K[^\s;]+' "$config_file" 2>/dev/null | head -1)

    if [[ -n "$log_path" && "$log_path" != "off" ]]; then
        echo "$log_path"
    else
        echo "/var/log/nginx/error.log"
    fi
}

# Detect backend type from nginx config
detect_backend_type() {
    local config_file="$1"
    [[ ! -f "$config_file" ]] && echo "$BACKEND_UNKNOWN" && return 1

    local config_content
    config_content=$(cat "$config_file")

    # Check for FrankenPHP
    if echo "$config_content" | grep -qE 'proxy_pass.*:8443|proxy_pass.*frankenphp'; then
        echo "$BACKEND_FRANKENPHP"
        return 0
    fi

    # Check for RoadRunner
    if echo "$config_content" | grep -qE 'proxy_pass.*:8080|proxy_pass.*roadrunner'; then
        echo "$BACKEND_ROADRUNNER"
        return 0
    fi

    # Check for Swoole/Octane
    if echo "$config_content" | grep -qE 'proxy_pass.*:(8000|9501)|proxy_pass.*swoole|proxy_pass.*octane'; then
        if is_framework_project && [[ "$(detect_framework)" == "laravel" ]] && has_octane 2>/dev/null; then
            local octane_driver
            octane_driver=$(get_octane_driver)
            case "$octane_driver" in
                swoole) echo "$BACKEND_OCTANE_SWOOLE" ;;
                roadrunner) echo "$BACKEND_OCTANE_ROADRUNNER" ;;
                frankenphp) echo "$BACKEND_OCTANE_FRANKENPHP" ;;
                *) echo "$BACKEND_SWOOLE" ;;
            esac
            return 0
        fi
        echo "$BACKEND_SWOOLE"
        return 0
    fi

    # Check for PHP-FPM
    if echo "$config_content" | grep -qE 'fastcgi_pass'; then
        echo "$BACKEND_FPM"
        return 0
    fi

    echo "$BACKEND_UNKNOWN"
    return 1
}

# Get Octane driver from Laravel config
get_octane_driver() {
    if [[ -f ".env" ]]; then
        local driver
        driver=$(grep -oP 'OCTANE_SERVER=\K\w+' .env 2>/dev/null)
        [[ -n "$driver" ]] && echo "$driver" && return 0
    fi

    if [[ -f "config/octane.php" ]]; then
        local driver
        driver=$(grep -oP "'server'\s*=>\s*\K\w+" "config/octane.php" 2>/dev/null | head -1)
        [[ -n "$driver" ]] && echo "$driver" && return 0
    fi

    echo "swoole"
}

# Parse PHP-FPM socket/port from nginx config
parse_fpm_backend() {
    local config_file="$1"
    [[ ! -f "$config_file" ]] && return 1

    grep -oP 'fastcgi_pass\s+\K[^;]+' "$config_file" 2>/dev/null | head -1 | tr -d ' '
}

# Parse proxy backend from nginx config
parse_proxy_backend() {
    local config_file="$1"
    [[ ! -f "$config_file" ]] && return 1

    grep -oP 'proxy_pass\s+\K[^;]+' "$config_file" 2>/dev/null | head -1 | tr -d ' '
}

# Get human-readable backend name
get_backend_display_name() {
    local backend_type="$1"

    case "$backend_type" in
        "$BACKEND_FPM") echo "PHP-FPM" ;;
        "$BACKEND_OCTANE_SWOOLE") echo "Laravel Octane (Swoole)" ;;
        "$BACKEND_OCTANE_ROADRUNNER") echo "Laravel Octane (RoadRunner)" ;;
        "$BACKEND_OCTANE_FRANKENPHP") echo "Laravel Octane (FrankenPHP)" ;;
        "$BACKEND_SWOOLE") echo "Swoole" ;;
        "$BACKEND_ROADRUNNER") echo "RoadRunner" ;;
        "$BACKEND_FRANKENPHP") echo "FrankenPHP" ;;
        "$BACKEND_CUSTOM") echo "Custom" ;;
        *) echo "Unknown" ;;
    esac
}

# ============================================
# PHP-FPM Pool Detection
# ============================================

# Get all available PHP-FPM pools
get_fpm_pools() {
    local pools=()

    # Check for FPM sockets
    for socket in /var/run/php/php*-fpm*.sock /run/php/php*-fpm*.sock; do
        [[ -S "$socket" ]] && pools+=("unix:$socket")
    done

    # Check for FPM TCP ports (common: 9000, 9001, etc.)
    for port in 9000 9001 9002 9003; do
        if netstat -tuln 2>/dev/null | grep -q ":$port " || \
           ss -tuln 2>/dev/null | grep -q ":$port "; then
            pools+=("127.0.0.1:$port")
        fi
    done

    printf '%s\n' "${pools[@]}" | sort -u
}

# Get FPM pools for specific PHP version
get_fpm_pools_for_version() {
    local version="$1"
    local pools=()

    # Socket pattern for version
    for socket in /var/run/php/php${version}-fpm*.sock /run/php/php${version}-fpm*.sock; do
        [[ -S "$socket" ]] && pools+=("unix:$socket")
    done

    printf '%s\n' "${pools[@]}"
}

# Interactive FPM pool selection
select_fpm_pool() {
    local pools
    pools=$(get_fpm_pools)

    if [[ -z "$pools" ]]; then
        warn "No PHP-FPM pools found"
        local custom
        custom=$(gum_input "Enter custom FPM socket/address:" "unix:/var/run/php/php-fpm.sock")
        echo "$custom"
        return
    fi

    if [[ "$UI_MODE" == "gum" ]]; then
        local options=()
        while IFS= read -r pool; do
            options+=("$pool")
        done <<< "$pools"
        options+=("Custom...")

        local choice
        choice=$(printf '%s\n' "${options[@]}" | gum filter \
            --header "Select PHP-FPM pool:" \
            --height 10)

        if [[ "$choice" == "Custom..." ]]; then
            gum_input "Enter custom FPM socket/address:" "unix:/var/run/php/php-fpm.sock"
        else
            echo "$choice"
        fi
    else
        echo "Available PHP-FPM pools:"
        local i=1
        while IFS= read -r pool; do
            echo "  $i) $pool"
            ((i++))
        done <<< "$pools"
        echo "  $i) Custom..."

        local choice
        read -rp "Select pool: " choice

        local pool_count
        pool_count=$(echo "$pools" | wc -l)

        if [[ "$choice" -gt "$pool_count" ]]; then
            read -rp "Enter custom FPM socket/address: " custom
            echo "$custom"
        else
            echo "$pools" | sed -n "${choice}p"
        fi
    fi
}

# ============================================
# Supervisor Service Detection
# ============================================

# Get supervisor services for current project
get_project_supervisor_services() {
    local project_root="${1:-$PWD}"
    local project_id
    project_id=$(get_project_id "$project_root" 2>/dev/null)

    if [[ -z "$project_id" ]]; then
        return 1
    fi

    # Find supervisor configs for this project
    local configs=()
    for conf in /etc/supervisor/conf.d/${project_id}*.conf; do
        [[ -f "$conf" ]] && configs+=("$conf")
    done

    if [[ ${#configs[@]} -eq 0 ]]; then
        return 1
    fi

    # Extract program names and ports
    for conf in "${configs[@]}"; do
        local program
        program=$(grep -oP '\[program:\K[^\]]+' "$conf" 2>/dev/null)

        # Try to detect port from command
        local port
        port=$(grep -oP 'port[=:]\s*\K\d+|--port[=\s]+\K\d+|-p\s+\K\d+' "$conf" 2>/dev/null | head -1)

        if [[ -n "$program" ]]; then
            if [[ -n "$port" ]]; then
                echo "$program|$port"
            else
                echo "$program|8000"  # Default port
            fi
        fi
    done
}

# Interactive supervisor service selection
select_supervisor_service() {
    local services
    services=$(get_project_supervisor_services)

    if [[ -z "$services" ]]; then
        return 1
    fi

    local options=()
    local ports=()

    while IFS='|' read -r name port; do
        options+=("$name (port $port)")
        ports+=("$port")
    done <<< "$services"

    if [[ "$UI_MODE" == "gum" ]]; then
        local choice
        choice=$(printf '%s\n' "${options[@]}" | gum filter \
            --header "Select supervisor service:" \
            --height 10)

        # Extract port from choice
        echo "$choice" | grep -oP 'port \K\d+'
    else
        echo "Available supervisor services:"
        local i=1
        for opt in "${options[@]}"; do
            echo "  $i) $opt"
            ((i++))
        done

        local choice
        read -rp "Select service: " choice
        echo "${ports[$((choice-1))]}"
    fi
}

# ============================================
# Process Monitoring
# ============================================

# Check if Octane is running
is_octane_running() {
    pgrep -f "artisan octane" &>/dev/null || \
    pgrep -f "swoole" &>/dev/null || \
    pgrep -f "roadrunner" &>/dev/null || \
    pgrep -f "frankenphp" &>/dev/null
}

# Get running backend processes
get_running_backends() {
    local backends=()

    # Check Swoole
    if pgrep -f "swoole" &>/dev/null; then
        local pid port
        pid=$(pgrep -f "swoole" | head -1)
        port=$(ss -tlnp 2>/dev/null | grep "pid=$pid" | grep -oP ':\K\d+' | head -1)
        backends+=("Swoole|$pid|${port:-N/A}")
    fi

    # Check RoadRunner
    if pgrep -f "roadrunner\|rr " &>/dev/null; then
        local pid port
        pid=$(pgrep -f "roadrunner\|rr " | head -1)
        port=$(ss -tlnp 2>/dev/null | grep "pid=$pid" | grep -oP ':\K\d+' | head -1)
        backends+=("RoadRunner|$pid|${port:-N/A}")
    fi

    # Check FrankenPHP
    if pgrep -f "frankenphp" &>/dev/null; then
        local pid port
        pid=$(pgrep -f "frankenphp" | head -1)
        port=$(ss -tlnp 2>/dev/null | grep "pid=$pid" | grep -oP ':\K\d+' | head -1)
        backends+=("FrankenPHP|$pid|${port:-N/A}")
    fi

    # Check Octane
    if pgrep -f "artisan octane" &>/dev/null; then
        local pid port
        pid=$(pgrep -f "artisan octane" | head -1)
        port=$(ss -tlnp 2>/dev/null | grep "pid=$pid" | grep -oP ':\K\d+' | head -1)
        backends+=("Octane|$pid|${port:-N/A}")
    fi

    printf '%s\n' "${backends[@]}"
}

# Show running backend processes
show_backend_processes() {
    local backends
    backends=$(get_running_backends)

    if [[ -z "$backends" ]]; then
        echo "No backend processes running"
        return 1
    fi

    echo "${BOLD}Running Backend Processes${RESET}"
    echo ""
    printf "  %-15s %-10s %-10s\n" "BACKEND" "PID" "PORT"
    echo "  ----------------------------------------"

    while IFS='|' read -r name pid port; do
        printf "  %-15s %-10s %-10s\n" "$name" "$pid" "$port"
    done <<< "$backends"
}

# ============================================
# Nginx Service Control
# ============================================

# Check nginx service status
nginx_status() {
    if command -v systemctl &>/dev/null; then
        systemctl is-active nginx 2>/dev/null
    elif command -v service &>/dev/null; then
        service nginx status &>/dev/null && echo "active" || echo "inactive"
    else
        pgrep -x nginx &>/dev/null && echo "active" || echo "inactive"
    fi
}

# Reload nginx
nginx_reload() {
    info_log "Reloading nginx..."

    if ! run_privileged nginx -t 2>/dev/null; then
        error "Nginx configuration test failed"
        return 1
    fi

    if command -v systemctl &>/dev/null; then
        run_privileged systemctl reload nginx
    elif command -v service &>/dev/null; then
        run_privileged service nginx reload
    else
        run_privileged nginx -s reload
    fi

    [[ $? -eq 0 ]] && success "Nginx reloaded" || { error "Failed to reload nginx"; return 1; }
}

# Restart nginx
nginx_restart() {
    info_log "Restarting nginx..."

    if command -v systemctl &>/dev/null; then
        run_privileged systemctl restart nginx
    elif command -v service &>/dev/null; then
        run_privileged service nginx restart
    else
        run_privileged nginx -s stop
        sleep 1
        run_privileged nginx
    fi

    [[ $? -eq 0 ]] && success "Nginx restarted" || { error "Failed to restart nginx"; return 1; }
}

# ============================================
# Nginx Config Templates
# ============================================

# Laravel nginx template
generate_laravel_template() {
    local server_name="$1"
    local port="$2"
    local root_path="$3"
    local backend="$4"
    local backend_type="$5"

    local fastcgi_or_proxy=""

    if [[ "$backend_type" == "$BACKEND_FPM" ]]; then
        fastcgi_or_proxy="
        location ~ \\.php\$ {
            fastcgi_pass $backend;
            fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
            include fastcgi_params;
            fastcgi_hide_header X-Powered-By;
        }"
    else
        local proxy_port="${backend##*:}"
        fastcgi_or_proxy="
        location / {
            proxy_pass http://127.0.0.1:$proxy_port;
            proxy_http_version 1.1;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection \"upgrade\";
            proxy_read_timeout 60s;
            proxy_buffering off;
        }"
    fi

    cat << EOF
server {
    listen $port;
    listen [::]:$port;
    server_name $server_name;
    root $root_path/public;

    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";

    index index.php;

    charset utf-8;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    error_page 404 /index.php;
$fastcgi_or_proxy

    location ~ /\\.(?!well-known).* {
        deny all;
    }

    access_log /var/log/nginx/${server_name}-access.log;
    error_log /var/log/nginx/${server_name}-error.log;
}
EOF
}

# Symfony nginx template
generate_symfony_template() {
    local server_name="$1"
    local port="$2"
    local root_path="$3"
    local backend="$4"
    local backend_type="$5"

    local fastcgi_or_proxy=""

    if [[ "$backend_type" == "$BACKEND_FPM" ]]; then
        fastcgi_or_proxy="
        location ~ ^/index\\.php(/|\$) {
            fastcgi_pass $backend;
            fastcgi_split_path_info ^(.+\\.php)(/.*)$;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
            fastcgi_param DOCUMENT_ROOT \$realpath_root;
            internal;
        }

        location ~ \\.php\$ {
            return 404;
        }"
    else
        local proxy_port="${backend##*:}"
        fastcgi_or_proxy="
        location / {
            proxy_pass http://127.0.0.1:$proxy_port;
            proxy_http_version 1.1;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }"
    fi

    cat << EOF
server {
    listen $port;
    listen [::]:$port;
    server_name $server_name;
    root $root_path/public;

    location / {
        try_files \$uri /index.php\$is_args\$args;
    }
$fastcgi_or_proxy

    access_log /var/log/nginx/${server_name}-access.log;
    error_log /var/log/nginx/${server_name}-error.log;
}
EOF
}

# Yii nginx template
generate_yii_template() {
    local server_name="$1"
    local port="$2"
    local root_path="$3"
    local backend="$4"
    local backend_type="$5"

    local fastcgi_or_proxy=""

    if [[ "$backend_type" == "$BACKEND_FPM" ]]; then
        fastcgi_or_proxy="
        location ~ \\.php\$ {
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
            fastcgi_pass $backend;
            try_files \$uri =404;
        }"
    else
        local proxy_port="${backend##*:}"
        fastcgi_or_proxy="
        location / {
            proxy_pass http://127.0.0.1:$proxy_port;
            proxy_http_version 1.1;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }"
    fi

    cat << EOF
server {
    listen $port;
    listen [::]:$port;
    server_name $server_name;
    root $root_path/web;
    index index.php;

    charset utf-8;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ ^/assets/.*\\.php\$ {
        deny all;
    }
$fastcgi_or_proxy

    location ~ /\\.(ht|svn|git) {
        deny all;
    }

    access_log /var/log/nginx/${server_name}-access.log;
    error_log /var/log/nginx/${server_name}-error.log;
}
EOF
}

# Generic PHP nginx template
generate_generic_template() {
    local server_name="$1"
    local port="$2"
    local root_path="$3"
    local backend="$4"
    local backend_type="$5"

    local fastcgi_or_proxy=""

    if [[ "$backend_type" == "$BACKEND_FPM" ]]; then
        fastcgi_or_proxy="
        location ~ \\.php\$ {
            fastcgi_pass $backend;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
            include fastcgi_params;
        }"
    else
        local proxy_port="${backend##*:}"
        fastcgi_or_proxy="
        location / {
            proxy_pass http://127.0.0.1:$proxy_port;
            proxy_http_version 1.1;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }"
    fi

    cat << EOF
server {
    listen $port;
    listen [::]:$port;
    server_name $server_name;
    root $root_path;
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
$fastcgi_or_proxy

    location ~ /\\. {
        deny all;
    }

    access_log /var/log/nginx/${server_name}-access.log;
    error_log /var/log/nginx/${server_name}-error.log;
}
EOF
}

# ============================================
# Custom Template Management
# ============================================

# List custom templates
list_custom_templates() {
    init_nginx_templates

    local templates
    templates=$(find "$NGINX_TEMPLATE_DIR" -maxdepth 1 -name "*.conf" -type f 2>/dev/null)

    if [[ -z "$templates" ]]; then
        echo "No custom templates found"
        echo "Templates directory: $NGINX_TEMPLATE_DIR"
        return 1
    fi

    echo "${BOLD}Custom Nginx Templates${RESET}"
    echo ""

    while IFS= read -r template; do
        local name
        name=$(basename "$template" .conf)
        echo "  - $name"
    done <<< "$templates"
}

# Add custom template
add_custom_template() {
    init_nginx_templates

    local name
    name=$(gum_input "Template name:" "my-template")

    [[ -z "$name" ]] && return

    local template_file="$NGINX_TEMPLATE_DIR/${name}.conf"

    if [[ -f "$template_file" ]]; then
        if ! gum_confirm "Template '$name' exists. Overwrite?"; then
            return
        fi
    fi

    local editor="${EDITOR:-nano}"

    # Create template with placeholder
    cat > "$template_file" << 'EOF'
# Custom Nginx Template
# Available variables (will be replaced):
#   {{SERVER_NAME}} - Server name/domain
#   {{PORT}} - Listen port
#   {{ROOT_PATH}} - Project root path
#   {{BACKEND}} - Backend address (FPM socket or proxy URL)

server {
    listen {{PORT}};
    listen [::]:{{PORT}};
    server_name {{SERVER_NAME}};
    root {{ROOT_PATH}}/public;

    # Add your configuration here

    access_log /var/log/nginx/{{SERVER_NAME}}-access.log;
    error_log /var/log/nginx/{{SERVER_NAME}}-error.log;
}
EOF

    "$editor" "$template_file"

    if [[ -f "$template_file" ]]; then
        success "Template saved: $name"
    fi
}

# Edit custom template
edit_custom_template() {
    init_nginx_templates

    local templates
    templates=$(find "$NGINX_TEMPLATE_DIR" -maxdepth 1 -name "*.conf" -type f 2>/dev/null)

    if [[ -z "$templates" ]]; then
        error "No custom templates found"
        return 1
    fi

    local options=()
    while IFS= read -r template; do
        options+=("$(basename "$template" .conf)")
    done <<< "$templates"

    local choice
    choice=$(printf '%s\n' "${options[@]}" | gum filter \
        --header "Select template to edit:" \
        --height 10)

    [[ -z "$choice" ]] && return

    local editor="${EDITOR:-nano}"
    "$editor" "$NGINX_TEMPLATE_DIR/${choice}.conf"
}

# Delete custom template
delete_custom_template() {
    init_nginx_templates

    local templates
    templates=$(find "$NGINX_TEMPLATE_DIR" -maxdepth 1 -name "*.conf" -type f 2>/dev/null)

    if [[ -z "$templates" ]]; then
        error "No custom templates found"
        return 1
    fi

    local options=()
    while IFS= read -r template; do
        options+=("$(basename "$template" .conf)")
    done <<< "$templates"

    local choice
    choice=$(printf '%s\n' "${options[@]}" | gum filter \
        --header "Select template to delete:" \
        --height 10)

    [[ -z "$choice" ]] && return

    if gum_confirm "Delete template '$choice'?"; then
        rm -f "$NGINX_TEMPLATE_DIR/${choice}.conf"
        success "Template deleted"
    fi
}

# Use custom template
use_custom_template() {
    local template_name="$1"
    local server_name="$2"
    local port="$3"
    local root_path="$4"
    local backend="$5"

    local template_file="$NGINX_TEMPLATE_DIR/${template_name}.conf"

    if [[ ! -f "$template_file" ]]; then
        error "Template not found: $template_name"
        return 1
    fi

    cat "$template_file" | \
        sed "s|{{SERVER_NAME}}|$server_name|g" | \
        sed "s|{{PORT}}|$port|g" | \
        sed "s|{{ROOT_PATH}}|$root_path|g" | \
        sed "s|{{BACKEND}}|$backend|g"
}

# ============================================
# Nginx Config Generator (Interactive)
# ============================================

generate_nginx_config() {
    local project_root="${1:-$PWD}"
    project_root=$(cd "$project_root" && pwd)

    local project_name
    project_name=$(basename "$project_root")

    echo "${BOLD}Nginx Configuration Generator${RESET}"
    echo ""

    # Server name
    local server_name
    server_name=$(gum_input "Server name (domain):" "${project_name}.local")

    [[ -z "$server_name" ]] && return

    # Listen port
    local port
    if [[ "$UI_MODE" == "gum" ]]; then
        port=$(gum choose --header "Listen port:" "80" "8080" "443" "Custom...")
        if [[ "$port" == "Custom..." ]]; then
            port=$(gum_input "Enter port:" "80")
        fi
    else
        read -rp "Listen port [80]: " port
        port="${port:-80}"
    fi

    # Listen IP
    local listen_ip
    if [[ "$UI_MODE" == "gum" ]]; then
        listen_ip=$(gum choose --header "Listen IP:" "*" "127.0.0.1" "0.0.0.0")
    else
        read -rp "Listen IP [*]: " listen_ip
        listen_ip="${listen_ip:-*}"
    fi

    # Backend type selection
    local backend_choice
    if [[ "$UI_MODE" == "gum" ]]; then
        local backend_options=("PHP-FPM" "Supervisor Service" "Custom Proxy")

        # Check for available options
        local supervisor_services
        supervisor_services=$(get_project_supervisor_services 2>/dev/null)
        [[ -z "$supervisor_services" ]] && backend_options=("PHP-FPM" "Custom Proxy")

        backend_choice=$(printf '%s\n' "${backend_options[@]}" | gum filter \
            --header "Select backend type:" \
            --height 8)
    else
        echo "Backend type:"
        echo "  1) PHP-FPM"
        echo "  2) Supervisor Service"
        echo "  3) Custom Proxy"
        read -rp "Select [1]: " bc
        case "$bc" in
            2) backend_choice="Supervisor Service" ;;
            3) backend_choice="Custom Proxy" ;;
            *) backend_choice="PHP-FPM" ;;
        esac
    fi

    local backend=""
    local backend_type=""

    case "$backend_choice" in
        "PHP-FPM")
            backend=$(select_fpm_pool)
            backend_type="$BACKEND_FPM"
            ;;
        "Supervisor Service")
            local service_port
            service_port=$(select_supervisor_service)
            if [[ -n "$service_port" ]]; then
                backend="127.0.0.1:$service_port"
                backend_type="$BACKEND_CUSTOM"
            else
                backend=$(gum_input "Enter proxy address:" "127.0.0.1:8000")
                backend_type="$BACKEND_CUSTOM"
            fi
            ;;
        "Custom Proxy")
            backend=$(gum_input "Enter proxy address:" "127.0.0.1:8000")
            backend_type="$BACKEND_CUSTOM"
            ;;
    esac

    [[ -z "$backend" ]] && return

    # Template selection
    local template_choice
    local framework
    framework=$(detect_framework 2>/dev/null)

    # Build template options
    local template_options=()
    case "$framework" in
        laravel) template_options+=("Laravel (recommended)") ;;
        symfony) template_options+=("Symfony (recommended)") ;;
        yii) template_options+=("Yii (recommended)") ;;
    esac
    template_options+=("Generic PHP")

    # Add custom templates
    local custom_templates
    custom_templates=$(find "$NGINX_TEMPLATE_DIR" -maxdepth 1 -name "*.conf" -type f 2>/dev/null | while read -r t; do basename "$t" .conf; done)
    if [[ -n "$custom_templates" ]]; then
        while IFS= read -r ct; do
            template_options+=("Custom: $ct")
        done <<< "$custom_templates"
    fi

    if [[ "$UI_MODE" == "gum" ]]; then
        template_choice=$(printf '%s\n' "${template_options[@]}" | gum filter \
            --header "Select template:" \
            --height 10)
    else
        echo "Template:"
        local i=1
        for opt in "${template_options[@]}"; do
            echo "  $i) $opt"
            ((i++))
        done
        read -rp "Select [1]: " tc
        template_choice="${template_options[$((tc-1))]}"
    fi

    # Generate config
    local config=""
    case "$template_choice" in
        "Laravel"*) config=$(generate_laravel_template "$server_name" "$port" "$project_root" "$backend" "$backend_type") ;;
        "Symfony"*) config=$(generate_symfony_template "$server_name" "$port" "$project_root" "$backend" "$backend_type") ;;
        "Yii"*) config=$(generate_yii_template "$server_name" "$port" "$project_root" "$backend" "$backend_type") ;;
        "Custom: "*)
            local custom_name="${template_choice#Custom: }"
            config=$(use_custom_template "$custom_name" "$server_name" "$port" "$project_root" "$backend")
            ;;
        *) config=$(generate_generic_template "$server_name" "$port" "$project_root" "$backend" "$backend_type") ;;
    esac

    # Adjust listen directive for IP
    if [[ "$listen_ip" != "*" ]]; then
        config=$(echo "$config" | sed "s/listen $port;/listen ${listen_ip}:${port};/g")
        config=$(echo "$config" | sed "s/listen \[::\]:$port;/listen [::1]:${port};/g")
    fi

    # Preview config
    echo ""
    echo "${BOLD}Generated Configuration:${RESET}"
    echo "----------------------------------------"
    echo "$config"
    echo "----------------------------------------"
    echo ""

    # Save location
    local save_location
    if [[ "$UI_MODE" == "gum" ]]; then
        save_location=$(gum choose \
            --header "Save to:" \
            "/etc/nginx/sites-available/${server_name}.conf" \
            "/etc/nginx/conf.d/${server_name}.conf" \
            "Print to stdout only" \
            "Cancel")
    else
        echo "Save to:"
        echo "  1) /etc/nginx/sites-available/${server_name}.conf"
        echo "  2) /etc/nginx/conf.d/${server_name}.conf"
        echo "  3) Print to stdout only"
        echo "  4) Cancel"
        read -rp "Select [1]: " sl
        case "$sl" in
            2) save_location="/etc/nginx/conf.d/${server_name}.conf" ;;
            3) save_location="Print to stdout only" ;;
            4) save_location="Cancel" ;;
            *) save_location="/etc/nginx/sites-available/${server_name}.conf" ;;
        esac
    fi

    case "$save_location" in
        "Cancel"|"")
            return
            ;;
        "Print to stdout only")
            echo "$config"
            return
            ;;
        *)
            echo "$config" | run_privileged tee "$save_location" > /dev/null

            if [[ $? -eq 0 ]]; then
                success "Configuration saved: $save_location"

                # Enable site if in sites-available
                if [[ "$save_location" == "/etc/nginx/sites-available/"* ]]; then
                    local site_name
                    site_name=$(basename "$save_location")
                    local enabled_link="/etc/nginx/sites-enabled/$site_name"

                    if [[ ! -e "$enabled_link" ]]; then
                        if gum_confirm "Enable site?"; then
                            run_privileged ln -sf "$save_location" "$enabled_link"
                            success "Site enabled"
                        fi
                    fi
                fi

                # Test and reload nginx
                if gum_confirm "Test and reload nginx?"; then
                    if run_privileged nginx -t; then
                        nginx_reload
                    else
                        error "Configuration test failed. Please fix errors before reloading."
                    fi
                fi

                # Add to /etc/hosts
                if gum_confirm "Add '$server_name' to /etc/hosts?"; then
                    if ! grep -q "$server_name" /etc/hosts 2>/dev/null; then
                        echo "127.0.0.1 $server_name" | run_privileged tee -a /etc/hosts > /dev/null
                        success "Added to /etc/hosts"
                    else
                        warn "$server_name already in /etc/hosts"
                    fi
                fi
            else
                error "Failed to save configuration"
            fi
            ;;
    esac
}

# ============================================
# Show nginx config info for project
# ============================================

show_nginx_info() {
    local project_root="${1:-$PWD}"

    local all_configs
    all_configs=$(find_all_nginx_configs "$project_root")

    if [[ -z "$all_configs" ]]; then
        warn "No nginx configuration found for this project"
        echo ""
        echo "Searched directories:"
        for dir in "${NGINX_CONF_DIRS[@]}"; do
            echo "  - $dir"
        done
        echo ""
        echo "Run 'php nginx generate' to create a configuration"
        return 1
    fi

    local config_count
    config_count=$(echo "$all_configs" | wc -l)

    echo ""
    echo "${BOLD}Nginx Configuration${RESET}"

    if [[ "$config_count" -gt 1 ]]; then
        echo "  ${YELLOW}Multiple configs found ($config_count)${RESET}"
    fi

    while IFS= read -r config_file; do
        local server_name port backend_type
        server_name=$(parse_server_name "$config_file")
        port=$(parse_listen_port "$config_file")
        backend_type=$(detect_backend_type "$config_file")

        echo ""
        echo "  ${CYAN}Config:${RESET} $config_file"
        echo "  Server name: ${server_name:-N/A}"
        echo "  Listen port: $port"
        echo "  Backend:     $(get_backend_display_name "$backend_type")"

        case "$backend_type" in
            "$BACKEND_FPM")
                local fpm_backend
                fpm_backend=$(parse_fpm_backend "$config_file")
                echo "  FPM Socket:  ${fpm_backend:-N/A}"
                ;;
            *)
                local proxy_backend
                proxy_backend=$(parse_proxy_backend "$config_file")
                [[ -n "$proxy_backend" ]] && echo "  Proxy:       $proxy_backend"
                ;;
        esac
    done <<< "$all_configs"

    echo ""
    echo "${BOLD}Nginx Status${RESET}"
    local status
    status=$(nginx_status)
    if [[ "$status" == "active" ]]; then
        echo "  Service: ${GREEN}running${RESET}"
    else
        echo "  Service: ${RED}stopped${RESET}"
    fi

    # Show running backends
    echo ""
    show_backend_processes

    echo ""
    echo "${BOLD}Log Files${RESET}"
    local first_config
    first_config=$(echo "$all_configs" | head -1)
    echo "  Access: $(parse_access_log "$first_config")"
    echo "  Error:  $(parse_error_log "$first_config")"
}

# View config in pager
view_nginx_config() {
    local config_file
    config_file=$(select_nginx_config)

    [[ -z "$config_file" ]] && return

    if [[ "$UI_MODE" == "gum" ]]; then
        cat "$config_file" | gum pager
    else
        less "$config_file"
    fi
}

# ============================================
# Nginx command handler
# ============================================

cmd_nginx() {
    local subcommand="${1:-}"
    shift 2>/dev/null || true

    # If no subcommand and gum available, show interactive menu
    if [[ -z "$subcommand" && "$UI_MODE" == "gum" ]]; then
        interactive_nginx_menu
        return
    fi

    case "$subcommand" in
        ""|info|status)
            show_nginx_info
            ;;
        reload)
            if gum_confirm "Reload nginx configuration?"; then
                nginx_reload
            fi
            ;;
        restart)
            if gum_confirm "Restart nginx service?"; then
                nginx_restart
            fi
            ;;
        config|view)
            view_nginx_config
            ;;
        edit)
            local config_file
            config_file=$(select_nginx_config)
            [[ -n "$config_file" ]] && run_privileged "${EDITOR:-nano}" "$config_file"
            ;;
        test)
            info_log "Testing nginx configuration..."
            run_privileged nginx -t
            ;;
        generate|create|new)
            generate_nginx_config
            ;;
        processes|ps)
            show_backend_processes
            ;;
        templates)
            local template_cmd="${1:-list}"
            case "$template_cmd" in
                list) list_custom_templates ;;
                add|new|create) add_custom_template ;;
                edit) edit_custom_template ;;
                delete|remove) delete_custom_template ;;
                *)
                    echo "Usage: php nginx templates [command]"
                    echo "Commands: list, add, edit, delete"
                    ;;
            esac
            ;;
        *)
            echo "Usage: php nginx [command]"
            echo ""
            echo "Commands:"
            echo "  info        Show nginx configuration info (default)"
            echo "  status      Same as info"
            echo "  reload      Reload nginx configuration"
            echo "  restart     Restart nginx service"
            echo "  config      View nginx configuration (with selection)"
            echo "  edit        Edit nginx configuration"
            echo "  test        Test nginx configuration"
            echo "  generate    Generate new nginx configuration"
            echo "  processes   Show running backend processes"
            echo "  templates   Manage custom templates"
            echo ""
            echo "Template commands:"
            echo "  php nginx templates list    List custom templates"
            echo "  php nginx templates add     Add custom template"
            echo "  php nginx templates edit    Edit custom template"
            echo "  php nginx templates delete  Delete custom template"
            ;;
    esac
}

# Interactive nginx menu
interactive_nginx_menu() {
    while true; do
        clear
        echo "${BOLD}Nginx Management${RESET}"
        echo ""

        local choice
        choice=$(gum choose \
            "Show Configuration Info" \
            "View Configuration" \
            "Edit Configuration" \
            "Generate New Config" \
            "Reload Nginx" \
            "Restart Nginx" \
            "Test Configuration" \
            "Show Backend Processes" \
            "Manage Templates" \
            "Back")

        case "$choice" in
            "Show Configuration Info")
                show_nginx_info
                read -rp "Press Enter to continue..."
                ;;
            "View Configuration")
                view_nginx_config
                ;;
            "Edit Configuration")
                local config_file
                config_file=$(select_nginx_config)
                [[ -n "$config_file" ]] && run_privileged "${EDITOR:-nano}" "$config_file"
                ;;
            "Generate New Config")
                generate_nginx_config
                read -rp "Press Enter to continue..."
                ;;
            "Reload Nginx")
                if gum_confirm "Reload nginx configuration?"; then
                    nginx_reload
                fi
                read -rp "Press Enter to continue..."
                ;;
            "Restart Nginx")
                if gum_confirm "Restart nginx service?"; then
                    nginx_restart
                fi
                read -rp "Press Enter to continue..."
                ;;
            "Test Configuration")
                run_privileged nginx -t
                read -rp "Press Enter to continue..."
                ;;
            "Show Backend Processes")
                show_backend_processes
                read -rp "Press Enter to continue..."
                ;;
            "Manage Templates")
                manage_templates_menu
                ;;
            "Back"|"")
                break
                ;;
        esac
    done
}

# Templates management menu
manage_templates_menu() {
    while true; do
        clear
        echo "${BOLD}Nginx Template Management${RESET}"
        echo ""

        local choice
        choice=$(gum choose \
            "List Templates" \
            "Add Template" \
            "Edit Template" \
            "Delete Template" \
            "Back")

        case "$choice" in
            "List Templates")
                list_custom_templates
                read -rp "Press Enter to continue..."
                ;;
            "Add Template")
                add_custom_template
                ;;
            "Edit Template")
                edit_custom_template
                ;;
            "Delete Template")
                delete_custom_template
                ;;
            "Back"|"")
                break
                ;;
        esac
    done
}
