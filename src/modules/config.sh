# config.sh - Configuration Constants
# PHP Version Manager (PHPVM)

# Tool version
PHPVM_VERSION="1.2.2"
PHPVM_REPO="professor93/phpvm"
PHPVM_GITHUB_API="https://api.github.com/repos/${PHPVM_REPO}/releases/latest"
PHPVM_RAW_URL="https://raw.githubusercontent.com/${PHPVM_REPO}/main"

# Gum configuration
GUM_GITHUB_REPO="charmbracelet/gum"
GUM_MIN_VERSION="0.13.0"

# Installation paths (set during install based on mode)
# System-wide:
PHPVM_BIN_DIR="/usr/local/bin"
PHPVM_ENV_FILE="/etc/profile.d/phpvm.sh"
# User-local:
PHPVM_BIN_DIR_USER="$HOME/.local/bin"
PHPVM_ENV_FILE_USER="$HOME/.config/phpvm/env.sh"

# User data directories (always per-user)
PHPVM_DIR="$HOME/.phpvm"
PHPVM_CONFIG="$PHPVM_DIR/version"
SYSTEM_CONFIG="/etc/phpvm/version"

# Supported PHP versions (newest first)
SUPPORTED_VERSIONS=("8.5" "8.4" "8.3" "8.2" "8.1" "8.0" "7.4" "7.3" "7.2" "7.1" "7.0" "5.6")

# Default extensions to install with new PHP version
# Covers requirements for Laravel, Symfony, Yii2
# Note: cli is installed as base package
# Note: common is a dependency of cli (auto-installed)
# Note: filter, session, ctype, tokenizer, fileinfo are part of php-common
# Note: dom, simplexml are part of php-xml
DEFAULT_EXTENSIONS=(
    "curl" "mbstring" "xml" "zip" "bcmath" "intl" "pdo" "sqlite3" "opcache"
)

# Logging
LOG_TIMESTAMPS=true  # Enable timestamps in verbose/log output
LOG_FILE="$HOME/.phpvm/phpvm.log"
