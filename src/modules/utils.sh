# utils.sh - Utility Functions
# PHP Version Manager (PHPVM)

# Timestamp for logging
timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

# Message functions with optional timestamps
msg() {
    echo "${GREEN}→${RESET} $*"
}

warn() {
    echo "${YELLOW}⚠${RESET} $*"
}

error() {
    echo "${RED}✗${RESET} $*" >&2
}

success() {
    echo "${GREEN}✓${RESET} $*"
}

# Log to file with timestamp
log() {
    local level="$1"
    shift
    if [[ "$LOG_TIMESTAMPS" == "true" ]]; then
        echo "[$(timestamp)] [$level] $*" >> "$LOG_FILE" 2>/dev/null
    fi
}

# Informational message with timestamp (for important operations)
info_log() {
    local msg="$*"
    if [[ "$LOG_TIMESTAMPS" == "true" ]]; then
        echo "${DIM}[$(timestamp)]${RESET} ${CYAN}ℹ${RESET} $msg"
    else
        echo "${CYAN}ℹ${RESET} $msg"
    fi
    log "INFO" "$msg"
}

# Run command with sudo if not root
run_privileged() {
    if [[ $EUID -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

# Check if sudo available (for non-root users)
check_sudo() {
    if [[ $EUID -ne 0 ]]; then
        if ! sudo -v &>/dev/null; then
            error "This operation requires sudo privileges"
            exit 1
        fi
    fi
}

# Initialize user's phpvm directory
init_phpvm() {
    mkdir -p "$PHPVM_DIR"
    touch "$LOG_FILE" 2>/dev/null || true
}

# Check if command exists
command_exists() {
    command -v "$1" &>/dev/null
}

# Compare semantic versions (returns 0 if $1 >= $2)
version_gte() {
    printf '%s\n%s\n' "$2" "$1" | sort -V -C
}

# Validate PHP version format (X.Y)
validate_version_format() {
    local version="$1"
    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+$ ]]; then
        error "Invalid version format: $version"
        echo "Version must be in format X.Y (e.g., 8.4)"
        return 1
    fi
}

# Check if version is in supported list
is_supported_version() {
    local version="$1"
    for v in "${SUPPORTED_VERSIONS[@]}"; do
        [[ "$v" == "$version" ]] && return 0
    done
    return 1
}
