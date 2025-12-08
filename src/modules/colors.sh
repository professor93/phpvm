# colors.sh - Color Setup
# PHP Version Manager (PHPVM)

setup_colors() {
    if [[ -t 1 ]]; then
        RED=$(tput setaf 1 2>/dev/null || echo '')
        GREEN=$(tput setaf 2 2>/dev/null || echo '')
        YELLOW=$(tput setaf 3 2>/dev/null || echo '')
        BLUE=$(tput setaf 4 2>/dev/null || echo '')
        CYAN=$(tput setaf 6 2>/dev/null || echo '')
        MAGENTA=$(tput setaf 5 2>/dev/null || echo '')
        BOLD=$(tput bold 2>/dev/null || echo '')
        DIM=$(tput dim 2>/dev/null || echo '')
        RESET=$(tput sgr0 2>/dev/null || echo '')
    else
        RED="" GREEN="" YELLOW="" BLUE="" CYAN="" MAGENTA="" BOLD="" DIM="" RESET=""
    fi
}
