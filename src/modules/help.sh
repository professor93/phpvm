# help.sh - Help Command
# PHP Version Manager (PHPVM)

# Quick usage display (when calling `php` without arguments)
show_quick_usage() {
    print_header

    cat <<EOF
${BOLD}Usage:${RESET} php [command] [options]

${BOLD}Commands:${RESET}
  use [version]       Switch PHP version
  install [version]   Install PHP version or extension
  list                List installed versions
  menu                Interactive dashboard
  help                Show full help

${DIM}Run 'php help' for all commands${RESET}
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
  nginx               Manage nginx (interactive menu)

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

    cat <<EOF

${BOLD}Development:${RESET}
  serve [options]     Start development server (auto-detect framework)
                      --host HOST   Bind to host (default: 0.0.0.0)
                      --port PORT   Listen on port (default: 8000)
                      --dir DIR     Document root (default: auto-detect)
                      --octane      Use Laravel Octane (Laravel only)
                      Shorthand: 8080, :8080, 10.0.0.1:8080
  worker              Manage queue workers (Supervisor)
  cron                Manage scheduled tasks (Crontab)
EOF

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
  3. ~/.phpvm/version (user default)
  4. /etc/phpvm/version (system default)
  5. First installed version (fallback)

${BOLD}Examples:${RESET}
  php use 8.4              # Switch to PHP 8.4
  php install 8.3          # Install PHP 8.3
  php install extension    # Install extension (fuzzy search)
  php menu                 # Open interactive dashboard
  php serve                # Start dev server (auto-detect framework)
  php serve 8080           # Start on port 8080 (localhost)
  php serve :3000          # Start on port 3000 (all interfaces)
  php serve --octane       # Start with Laravel Octane
  php logs                 # Interactive log viewer
  php tail app             # Follow application log
  echo "8.4" > .phpversion # Set project PHP version

${BOLD}Tab Completion:${RESET}
  source <(php completion bash)  # Enable bash completion
  source <(php completion zsh)   # Enable zsh completion

${BOLD}More Info:${RESET}
  GitHub: https://github.com/${PHPVM_REPO}
EOF
}
