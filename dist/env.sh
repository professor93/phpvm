#!/bin/bash
# PHP Version Manager - Shell Environment
# Sourced automatically for bash/zsh

# Prevent double-sourcing
[[ -n "$__PHPVM_LOADED" ]] && return
export __PHPVM_LOADED=1

# Configuration
PHPVM_DIR="$HOME/.phpvm"
PHPVM_CONFIG="$PHPVM_DIR/version"
SYSTEM_CONFIG="/etc/phpvm/version"

# Get current PHP version (mirrors version.sh logic)
__phpvm_get_version() {
    local version=""

    # 1. PHPVERSION_USE env var
    if [[ -n "${PHPVERSION_USE:-}" ]]; then
        echo "$PHPVERSION_USE"
        return
    fi

    # 2. .phpversion file (search up)
    local dir="$PWD"
    while [[ "$dir" != "/" && "$dir" != "$HOME" ]]; do
        if [[ -f "${dir}/.phpversion" ]]; then
            cat "${dir}/.phpversion" 2>/dev/null | tr -d '[:space:]'
            return
        fi
        dir=$(dirname "$dir")
    done

    # Check home
    if [[ -f "${HOME}/.phpversion" ]]; then
        cat "${HOME}/.phpversion" 2>/dev/null | tr -d '[:space:]'
        return
    fi

    # 3. User config
    if [[ -f "$PHPVM_CONFIG" ]]; then
        cat "$PHPVM_CONFIG" 2>/dev/null | tr -d '[:space:]'
        return
    fi

    # 4. System config
    if [[ -f "$SYSTEM_CONFIG" ]]; then
        cat "$SYSTEM_CONFIG" 2>/dev/null | tr -d '[:space:]'
        return
    fi
}

# Update PATH with current version's composer vendor/bin
__phpvm_update_path() {
    local version
    version=$(__phpvm_get_version)

    # Remove old phpvm paths from PATH
    PATH=$(echo "$PATH" | tr ':' '\n' | grep -v "\.phpvm/.*/composer/vendor/bin" | tr '\n' ':' | sed 's/:$//')

    # Add new path if version set
    if [[ -n "$version" && -d "$PHPVM_DIR/$version/composer/vendor/bin" ]]; then
        export PATH="$PHPVM_DIR/$version/composer/vendor/bin:$PATH"
    fi
}

# Notify on version change (for auto-switch)
__phpvm_notify_switch() {
    local old_version="$1"
    local new_version="$2"
    local source="$3"

    if [[ -n "$new_version" && "$old_version" != "$new_version" ]]; then
        echo -e "\033[0;36m->\033[0m Switched to PHP $new_version ($source)"
    fi
}

# PHP wrapper function
php() {
    local php_cmd="${PHPVM_BIN:-/usr/local/bin/php}"

    # Check for user-local install
    if [[ -x "$HOME/.local/bin/php" ]]; then
        php_cmd="$HOME/.local/bin/php"
    fi

    # Handle "php use" specially for session switching
    if [[ "$1" == "use" ]]; then
        local old_version
        old_version=$(__phpvm_get_version)

        # Create temp file for session communication
        export PHPVM_SESSION_FILE=$(mktemp)

        # Run the command
        "$php_cmd" "$@"
        local exit_code=$?

        # Check if session version was set
        if [[ -f "$PHPVM_SESSION_FILE" && -s "$PHPVM_SESSION_FILE" ]]; then
            export PHPVERSION_USE=$(cat "$PHPVM_SESSION_FILE")
            __phpvm_update_path
            echo -e "\033[0;32m[x]\033[0m PHP $PHPVERSION_USE set for this session"
        fi

        rm -f "$PHPVM_SESSION_FILE"
        unset PHPVM_SESSION_FILE

        return $exit_code
    fi

    # Pass through to php command
    "$php_cmd" "$@"
}

# Helper functions
phpvm_use_session() {
    if [[ -n "$1" ]]; then
        export PHPVERSION_USE="$1"
        __phpvm_update_path
        echo "PHP $1 set for this session"
    fi
}

phpvm_clear_session() {
    unset PHPVERSION_USE
    __phpvm_update_path
    echo "Session PHP version cleared"
}

# cd wrapper for auto-switch notification
if [[ -n "$BASH_VERSION" ]]; then
    __phpvm_original_cd=$(type -t cd)
    cd() {
        local old_version
        old_version=$(__phpvm_get_version)

        builtin cd "$@"
        local exit_code=$?

        if [[ $exit_code -eq 0 ]]; then
            local new_version
            new_version=$(__phpvm_get_version)

            # Determine source for notification
            local source=""
            if [[ -f "$PWD/.phpversion" ]]; then
                source=".phpversion"
            elif [[ -f "$(dirname "$PWD")/.phpversion" ]]; then
                source="parent .phpversion"
            fi

            __phpvm_notify_switch "$old_version" "$new_version" "$source"
            __phpvm_update_path
        fi

        return $exit_code
    }
elif [[ -n "$ZSH_VERSION" ]]; then
    autoload -U add-zsh-hook

    __phpvm_chpwd() {
        local old_version="${__PHPVM_LAST_VERSION:-}"
        local new_version
        new_version=$(__phpvm_get_version)

        local source=""
        if [[ -f "$PWD/.phpversion" ]]; then
            source=".phpversion"
        fi

        __phpvm_notify_switch "$old_version" "$new_version" "$source"
        __phpvm_update_path

        export __PHPVM_LAST_VERSION="$new_version"
    }

    add-zsh-hook chpwd __phpvm_chpwd
fi

# Initial setup
__phpvm_update_path
export __PHPVM_LAST_VERSION=$(__phpvm_get_version)
