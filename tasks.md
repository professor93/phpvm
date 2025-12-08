# PHPVM Implementation Tasks

## Directory Structure
- [x] Create src/ directory structure
- [x] Create src/modules/ directory

## Core Modules
- [x] Implement src/modules/config.sh - Configuration constants
- [x] Implement src/modules/colors.sh - Color definitions
- [x] Implement src/modules/utils.sh - Utility functions
- [x] Implement src/modules/platform.sh - Platform detection
- [x] Implement src/modules/ui.sh - UI with gum
- [x] Implement src/modules/version.sh - Version detection
- [x] Implement src/modules/install.sh - PHP installation
- [x] Implement src/modules/use.sh - Version switching
- [x] Implement src/modules/list.sh - List command
- [x] Implement src/modules/info.sh - Info command (includes PHPVM version + resolution order)
- [x] Implement src/modules/config_edit.sh - Config editing
- [x] Implement src/modules/fpm.sh - FPM management
- [x] Implement src/modules/self_update.sh - Self-update
- [x] Implement src/modules/help.sh - Help command

## Main Scripts
- [x] Implement src/php.sh - Main entry point
- [x] Implement src/composer.sh - Composer wrapper
- [x] Implement src/env.sh - Shell environment
- [x] Implement src/install.sh - Installer script

## Build System
- [x] Create build.sh script
- [x] Create dist/ directory with built files

## Refactoring
- [x] Remove php which command (merged into php info)
- [x] Remove php version command (merged into php info)

## Final Steps
- [x] Commit and push changes
