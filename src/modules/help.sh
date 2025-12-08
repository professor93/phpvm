# help.sh - Help Command
# PHP Version Manager (PHPVM)

# Quick usage display (when calling `php` without arguments)
show_quick_usage() {
    local current_version
    current_version=$(get_current_version)

    print_header

    cat <<EOF
${BOLD}Usage:${RESET} php [command] [options]

${BOLD}Version Management:${RESET}
  use [version]       Switch PHP version (interactive if no version)
  install [version]   Install PHP version or extension
  list                List installed PHP versions
  list extensions     List extensions for current PHP

${BOLD}Quick Commands:${RESET}
  menu                Interactive dashboard
  info                Show PHP and system info
  help                Show full help

${BOLD}Pass-through:${RESET}
  php [args]          Run PHP with arguments (e.g., php -v, php script.php)
EOF
}

show_help() {
    local framework
    framework=$(detect_framework 2>/dev/null)

    print_header

    cat <<EOF
${BOLD}Usage:${RESET} php [command] [options]

${BOLD}Version Management:${RESET}
  use [version]       Switch PHP version (interactive if no version)
  install [version]   Install PHP version or extension
  list                List installed PHP versions
  list extensions     List extensions for current PHP

${BOLD}Information:${RESET}
  info                Show PHPVM, PHP info, and version resolution
  menu                Interactive dashboard menu

${BOLD}Configuration:${RESET}
  config              Edit PHP configuration files
  fpm                 Manage PHP-FPM services and pools
  nginx               Manage nginx (info/reload/generate/processes)
  nginx generate      Generate nginx config from template

${BOLD}Logs:${RESET}
  logs                Interactive log viewer (with gum)
  logs list           List available logs
  logs show <type>    Show log content
  logs tail <type>    Follow log in real-time
  logs split          Split-screen log viewer (tmux)
  logs search <pat>   Search logs (ripgrep)
  logs filter <lvl>   Filter by level (ERROR/WARNING/INFO)
  logs parse          Parse framework exceptions
  tail [type]         Shortcut for logs tail
EOF

    # Framework-specific commands
    if [[ -n "$framework" ]]; then
        cat <<EOF

${BOLD}Project Commands ($(get_framework_display_name "$framework")):${RESET}
  serve               Start development server
  worker              Manage queue workers (Supervisor)
  cron                Manage scheduled tasks (Crontab)
EOF
        case "$framework" in
            laravel)
                echo "  artisan [cmd]       Run artisan command"
                has_horizon 2>/dev/null && echo "  horizon             Start Laravel Horizon"
                has_octane 2>/dev/null && echo "  octane [cmd]        Run Laravel Octane"
                ;;
            symfony)
                echo "  console [cmd]       Run console command"
                ;;
            yii)
                echo "  yii [cmd]           Run yii command"
                ;;
        esac
    fi

    cat <<EOF

${BOLD}Maintenance:${RESET}
  self-update         Update PHPVM to latest version
  completion [shell]  Generate shell completion (bash/zsh)
  help                Show this help message

${BOLD}Pass-through:${RESET}
  php [args]          Any other arguments pass to PHP binary
  php -v              Show PHP version (pass-through)
  php script.php      Execute PHP script

${BOLD}Composer:${RESET}
  composer [args]     Run Composer with current PHP version

${BOLD}Version Resolution Order:${RESET}
  1. PHPVERSION_USE environment variable (session)
  2. .phpversion file (local, searches up from current directory)
  3. ~/.phpversion/config (user default)
  4. /etc/phpversion (system default)
  5. First installed version (fallback)

${BOLD}Examples:${RESET}
  php use 8.4              # Switch to PHP 8.4
  php install 8.3          # Install PHP 8.3
  php install extension    # Install extension (fuzzy search)
  php menu                 # Open interactive dashboard
  php serve                # Start dev server (in project)
  php worker               # Manage queue workers (in project)
  php nginx                # Interactive nginx menu / config info
  php nginx generate       # Generate nginx config with wizard
  php nginx processes      # Show running backends (Octane, etc.)
  php logs                 # Interactive log viewer
  php logs split           # Split-screen dual log viewer
  php tail app             # Follow application log
  php logs search "error"  # Search logs with ripgrep
  echo "8.4" > .phpversion # Set project PHP version

${BOLD}Tab Completion:${RESET}
  source <(php completion bash)  # Enable bash completion
  source <(php completion zsh)   # Enable zsh completion

${BOLD}More Info:${RESET}
  GitHub: https://github.com/${PHPVM_REPO}
EOF
}
