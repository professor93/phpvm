# completion.sh - Tab Completion Support
# PHP Version Manager (PHPVM)

# Generate bash completion script
generate_bash_completion() {
    cat <<'COMPLETION'
# PHPVM Bash Completion
# Add to ~/.bashrc: source <(php completion bash)

_phpvm_completions() {
    local cur prev words cword
    _get_comp_words_by_ref -n : cur prev words cword

    # Base PHPVM commands
    local base_commands="use install list info config fpm nginx logs tail menu serve worker cron self-update help"

    # Framework detection (cached for performance)
    local framework=""
    if [[ -f "$PWD/artisan" ]]; then
        framework="laravel"
    elif [[ -f "$PWD/bin/console" ]] || [[ -f "$PWD/symfony.lock" ]]; then
        framework="symfony"
    elif [[ -f "$PWD/yii" ]]; then
        framework="yii"
    fi

    case "$cword" in
        1)
            # First argument - main commands
            local commands="$base_commands"

            # Add framework commands if in project
            case "$framework" in
                laravel)
                    commands="$commands artisan"
                    [[ -f "$PWD/composer.json" ]] && grep -q '"laravel/horizon"' "$PWD/composer.json" 2>/dev/null && commands="$commands horizon"
                    ;;
                symfony)
                    commands="$commands console"
                    ;;
                yii)
                    commands="$commands yii"
                    ;;
            esac

            COMPREPLY=($(compgen -W "$commands" -- "$cur"))
            ;;
        2)
            case "${words[1]}" in
                use|install)
                    # PHP versions
                    local versions="8.5 8.4 8.3 8.2 8.1 8.0 7.4 7.3 7.2 7.1 7.0 5.6"
                    if [[ "${words[1]}" == "install" ]]; then
                        versions="$versions extension"
                    fi
                    COMPREPLY=($(compgen -W "$versions" -- "$cur"))
                    ;;
                list)
                    COMPREPLY=($(compgen -W "extensions" -- "$cur"))
                    ;;
                nginx)
                    COMPREPLY=($(compgen -W "info status reload restart config edit test generate processes templates" -- "$cur"))
                    ;;
                logs)
                    COMPREPLY=($(compgen -W "list show tail search filter parse clear split interactive app access error worker fpm" -- "$cur"))
                    ;;
                tail)
                    COMPREPLY=($(compgen -W "app access error worker fpm all" -- "$cur"))
                    ;;
                artisan)
                    # Laravel artisan commands
                    if [[ "$framework" == "laravel" ]]; then
                        local artisan_commands
                        artisan_commands=$(php artisan list --format=txt 2>/dev/null | grep -E '^\s+\S+' | awk '{print $1}' | head -100)
                        COMPREPLY=($(compgen -W "$artisan_commands" -- "$cur"))
                    fi
                    ;;
                console)
                    # Symfony console commands
                    if [[ "$framework" == "symfony" ]]; then
                        local console_commands
                        console_commands=$(php bin/console list --format=txt 2>/dev/null | grep -E '^\s+\S+' | awk '{print $1}' | head -100)
                        COMPREPLY=($(compgen -W "$console_commands" -- "$cur"))
                    fi
                    ;;
                yii)
                    # Yii commands
                    if [[ "$framework" == "yii" ]]; then
                        local yii_commands
                        yii_commands=$(php yii help 2>/dev/null | grep -E '^\s+-' | awk '{print $2}' | head -100)
                        COMPREPLY=($(compgen -W "$yii_commands" -- "$cur"))
                    fi
                    ;;
            esac
            ;;
    esac

    return 0
}

complete -F _phpvm_completions php
COMPLETION
}

# Generate zsh completion script
generate_zsh_completion() {
    cat <<'COMPLETION'
# PHPVM Zsh Completion
# Add to ~/.zshrc: source <(php completion zsh)

_phpvm() {
    local curcontext="$curcontext" state line
    typeset -A opt_args

    # Framework detection
    local framework=""
    if [[ -f "$PWD/artisan" ]]; then
        framework="laravel"
    elif [[ -f "$PWD/bin/console" ]] || [[ -f "$PWD/symfony.lock" ]]; then
        framework="symfony"
    elif [[ -f "$PWD/yii" ]]; then
        framework="yii"
    fi

    local base_commands=(
        'use:Switch PHP version'
        'install:Install PHP version or extension'
        'list:List installed PHP versions'
        'info:Show PHP information'
        'config:Edit PHP configuration'
        'fpm:Manage PHP-FPM'
        'nginx:Manage nginx configuration'
        'logs:View and manage logs'
        'tail:Follow logs in real-time'
        'menu:Interactive menu'
        'serve:Start development server'
        'worker:Manage queue workers'
        'cron:Manage scheduled tasks'
        'self-update:Update PHPVM'
        'help:Show help'
    )

    # Add framework commands
    case "$framework" in
        laravel)
            base_commands+=('artisan:Run artisan command')
            [[ -f "$PWD/composer.json" ]] && grep -q '"laravel/horizon"' "$PWD/composer.json" 2>/dev/null && base_commands+=('horizon:Start Horizon')
            ;;
        symfony)
            base_commands+=('console:Run console command')
            ;;
        yii)
            base_commands+=('yii:Run yii command')
            ;;
    esac

    _arguments -C \
        '1: :->command' \
        '*: :->args'

    case $state in
        command)
            _describe -t commands 'php command' base_commands
            ;;
        args)
            case $words[2] in
                use|install)
                    local versions=(8.5 8.4 8.3 8.2 8.1 8.0 7.4 7.3 7.2 7.1 7.0 5.6)
                    [[ $words[2] == "install" ]] && versions+=(extension)
                    _describe -t versions 'PHP version' versions
                    ;;
                list)
                    _describe -t args 'list option' '(extensions)'
                    ;;
                nginx)
                    local nginx_cmds=(info status reload restart config edit test generate processes templates)
                    _describe -t commands 'nginx command' nginx_cmds
                    ;;
                logs)
                    local logs_cmds=(list show tail search filter parse clear split interactive app access error worker fpm)
                    _describe -t commands 'logs command' logs_cmds
                    ;;
                tail)
                    local log_types=(app access error worker fpm all)
                    _describe -t types 'log type' log_types
                    ;;
                artisan)
                    if [[ "$framework" == "laravel" ]]; then
                        local -a artisan_commands
                        artisan_commands=(${(f)"$(php artisan list --format=txt 2>/dev/null | grep -E '^\s+\S+' | awk '{print $1}' | head -100)"})
                        _describe -t commands 'artisan command' artisan_commands
                    fi
                    ;;
                console)
                    if [[ "$framework" == "symfony" ]]; then
                        local -a console_commands
                        console_commands=(${(f)"$(php bin/console list --format=txt 2>/dev/null | grep -E '^\s+\S+' | awk '{print $1}' | head -100)"})
                        _describe -t commands 'console command' console_commands
                    fi
                    ;;
                yii)
                    if [[ "$framework" == "yii" ]]; then
                        local -a yii_commands
                        yii_commands=(${(f)"$(php yii help 2>/dev/null | grep -E '^\s+-' | awk '{print $2}' | head -100)"})
                        _describe -t commands 'yii command' yii_commands
                    fi
                    ;;
            esac
            ;;
    esac
}

compdef _phpvm php
COMPLETION
}

# Completion command
cmd_completion() {
    local shell="$1"

    case "$shell" in
        bash)
            generate_bash_completion
            ;;
        zsh)
            generate_zsh_completion
            ;;
        *)
            echo "Usage: php completion [bash|zsh]"
            echo ""
            echo "Enable completions:"
            echo "  Bash: source <(php completion bash)"
            echo "  Zsh:  source <(php completion zsh)"
            echo ""
            echo "To persist, add to your shell rc file:"
            echo "  echo 'source <(php completion bash)' >> ~/.bashrc"
            echo "  echo 'source <(php completion zsh)' >> ~/.zshrc"
            ;;
    esac
}
