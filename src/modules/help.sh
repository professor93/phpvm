# help.sh - Help Command
# PHP Version Manager (PHPVM)

show_help() {
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

${BOLD}Configuration:${RESET}
  config              Edit PHP configuration files
  fpm                 Manage PHP-FPM services and pools

${BOLD}Maintenance:${RESET}
  self-update         Update PHPVM to latest version
  help                Show this help message

${BOLD}Pass-through:${RESET}
  php [args]          Any other arguments pass to PHP binary
  php -v              Show PHP version (pass-through)
  php --version       Show PHP version (pass-through)
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
  php use 8.4              # Switch to PHP 8.4 (select scope)
  php install 8.3          # Install PHP 8.3
  php install              # Interactive install menu
  php list                 # Show installed versions
  php info                 # Show detailed info
  echo "8.4" > .phpversion # Set project PHP version
  composer require foo     # Run composer with current PHP

${BOLD}More Info:${RESET}
  GitHub: https://github.com/${PHPVM_REPO}
EOF
}
