# PHPVM - PHP Version Manager

Shell-based PHP version manager for Linux with interactive TUI using gum.

## Project Structure

```
phpvm/
├── src/
│   ├── modules/
│   │   ├── config.sh        # Configuration constants
│   │   ├── colors.sh        # Terminal colors
│   │   ├── utils.sh         # Utility functions
│   │   ├── platform.sh      # Distro detection, package manager
│   │   ├── ui.sh            # Gum TUI with fallbacks
│   │   ├── version.sh       # Version detection/resolution
│   │   ├── framework.sh     # Framework detection (Laravel/Symfony/Yii)
│   │   ├── install.sh       # PHP installation
│   │   ├── use.sh           # Version switching
│   │   ├── list.sh          # List command
│   │   ├── info.sh          # Info command
│   │   ├── config_edit.sh   # Config viewing/editing
│   │   ├── fpm.sh           # FPM management
│   │   ├── worker.sh        # Queue worker management (Supervisor)
│   │   ├── cron.sh          # Crontab management
│   │   ├── serve.sh         # Development server
│   │   ├── menu.sh          # Interactive dashboard menu
│   │   ├── completion.sh    # Tab completion (bash/zsh)
│   │   ├── self_update.sh   # Self-update
│   │   └── help.sh          # Help command
│   ├── php.sh               # Main entry point
│   ├── composer.sh          # Composer wrapper
│   ├── env.sh               # Shell environment
│   └── install.sh           # Installer
├── dist/                    # Built distribution files
├── build.sh                 # Build script
└── scripts/
    └── install-hooks.sh     # Git hooks installer
```

## Commands

- `php use [version]` - Switch PHP version
- `php install [version]` - Install PHP or extension
- `php list` - List installed versions
- `php list extensions` - List extensions
- `php info` - Show info and version resolution
- `php menu` - Interactive dashboard
- `php config` - View/edit configuration
- `php fpm` - Manage PHP-FPM
- `php serve` - Start dev server (in project)
- `php worker` - Manage queue workers (in project)
- `php cron` - Manage cron jobs (in project)
- `php completion [shell]` - Generate tab completion
- `php self-update` - Update PHPVM
- `php help` - Show help

## Development Commands

- `php serve` - Start development server (auto-detect framework)
- `php serve --port 3000` - Custom port
- `php serve --host 127.0.0.1` - Custom host
- `php serve --dir public` - Custom document root

## Version Resolution Order

1. `PHPVERSION_USE` env var (session)
2. `.phpversion` file (local)
3. `~/.phpvm/version` (user)
4. `/etc/phpvm/version` (system)
5. First installed (fallback)

## Supported Platforms

- Ubuntu/Debian (Ondřej PPA)
- RHEL/Fedora/CentOS (Remi)
- WSL

## Development

```bash
# Install git hooks
bash scripts/install-hooks.sh

# Build dist files
bash build.sh
```
