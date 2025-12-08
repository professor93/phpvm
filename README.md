# PHPVM - PHP Version Manager

A shell-based PHP version manager for Linux with interactive TUI using [gum](https://github.com/charmbracelet/gum).

## Features

- **Multiple PHP versions** (5.6 - 8.5)
- **Interactive TUI** with fuzzy search and hotkey navigation
- **Per-project PHP versions** via `.phpversion`
- **Per-version Composer** installations
- **PHP-FPM management** with pool creation
- **Nginx management** with config generator and templates
- **Log viewer** with search, filtering, and split-screen mode
- **Process monitoring** for Octane, Swoole, RoadRunner, FrankenPHP
- **Framework support** (Laravel, Symfony, Yii2)
- **Queue worker management** (Supervisor)
- **Scheduler/cron management**
- **Tab completion** (bash/zsh)
- Auto-switch when changing directories

## Installation

```bash
# User-local install
curl -fsSL https://raw.githubusercontent.com/professor93/phpvm/main/dist/install.sh | bash

# System-wide install
curl -fsSL https://raw.githubusercontent.com/professor93/phpvm/main/dist/install.sh | sudo bash

# Uninstall
curl -fsSL https://raw.githubusercontent.com/professor93/phpvm/main/dist/install.sh | bash -s -- --uninstall
```

## Commands

### Core Commands

| Command | Description |
|---------|-------------|
| `php use [version]` | Switch PHP version |
| `php install [version]` | Install PHP version or extension |
| `php list` | List installed PHP versions |
| `php list extensions` | List extensions for current PHP |
| `php info` | Show PHP and PHPVM information |
| `php menu` | Interactive dashboard with hotkeys |
| `php config` | View/edit PHP configuration |
| `php fpm` | Manage PHP-FPM services and pools |
| `php self-update` | Update PHPVM |
| `php completion [shell]` | Generate shell completion |
| `php help` | Show help |

### Nginx Commands

| Command | Description |
|---------|-------------|
| `php nginx` | Interactive nginx menu |
| `php nginx info` | Show nginx configuration info |
| `php nginx reload` | Reload nginx configuration |
| `php nginx restart` | Restart nginx service |
| `php nginx generate` | Generate nginx config with wizard |
| `php nginx processes` | Show running backend processes |
| `php nginx templates` | Manage custom templates |

### Log Commands

| Command | Description |
|---------|-------------|
| `php logs` | Interactive log viewer |
| `php logs list` | List available logs |
| `php logs show <type>` | Show log content |
| `php logs tail <type>` | Follow log in real-time |
| `php logs split` | Split-screen dual log viewer (tmux) |
| `php logs search <pattern>` | Search logs with ripgrep |
| `php logs filter <level>` | Filter by level (ERROR/WARNING/INFO) |
| `php logs parse` | Parse framework exceptions |
| `php tail [type]` | Shortcut for logs tail |

Log types: `app`, `access`, `error`, `worker`, `fpm`, `all`

### Development Commands

| Command | Description |
|---------|-------------|
| `php serve` | Start development server (auto-detect framework) |
| `php serve --port 3000` | Start server on custom port |
| `php serve --host 127.0.0.1` | Start server on custom host |
| `php serve --dir public` | Start server with custom document root |
| `php worker` | Manage queue workers (Supervisor) |
| `php cron` | Manage scheduled tasks (Crontab) |

## Interactive Dashboard

Launch with `php menu` for a full-featured dashboard with arrow key navigation:

```
╔═════════════════════════════════════╗
║      PHPVM Dashboard v1.2.2         ║
║      PHP 8.4.1 | Laravel v11.0      ║
║      nginx ●  fpm ●                 ║
╚═════════════════════════════════════╝

─── Version Management ───
  [u] Switch PHP version
  [i] Install PHP/extension
  [l] List installed versions

─── Configuration ───
  [c] Edit PHP configuration
  [f] Manage PHP-FPM
  [n] Nginx management

─── Development ───
  [s] Start dev server
  [g] Log viewer

─── Other ───
  [o] Show PHP info
  [?] Help
  [q] Quit
```

## Version Resolution

PHPVM resolves PHP version in this order:

1. `PHPVERSION_USE` environment variable
2. `.phpversion` file (searches up from current directory)
3. `~/.phpvm/version` (user default)
4. `/etc/phpvm/version` (system default)
5. First installed version

## Per-Project PHP Version

```bash
echo "8.4" > .phpversion
```

## Nginx Config Generator

Generate framework-optimized nginx configurations:

```bash
php nginx generate
```

Features:
- Framework detection (Laravel, Symfony, Yii2)
- Backend selection (PHP-FPM, Octane, Swoole, RoadRunner, FrankenPHP)
- Auto-detect FPM pools and supervisor services
- Custom template support

### Custom Templates

```bash
php nginx templates add     # Create custom template
php nginx templates list    # List templates
php nginx templates edit    # Edit template
php nginx templates delete  # Delete template
```

Templates support variables: `{{SERVER_NAME}}`, `{{PORT}}`, `{{ROOT_PATH}}`, `{{BACKEND}}`

## Log Viewer

Interactive log viewer with advanced features:

```bash
php logs              # Interactive menu
php logs split        # Split-screen (requires tmux)
php logs search "error" --context 5  # Search with ripgrep
php logs filter ERROR # Filter by level
```

Requires `ripgrep` for search (falls back to grep).

## Backend Process Monitoring

Monitor running PHP backends:

```bash
php nginx processes
```

Detects: Swoole, RoadRunner, FrankenPHP, Laravel Octane

## Default Extensions

When installing PHP, the following extensions are included:
- curl, mbstring, xml, zip, bcmath, intl, pdo, sqlite3, opcache

Additional extensions can be installed with fuzzy search:
```bash
php install extension
```

## Tab Completion

```bash
# Bash
source <(php completion bash)

# Zsh
source <(php completion zsh)

# Persist in shell config
echo 'source <(php completion bash)' >> ~/.bashrc
```

## Supported Platforms

- Ubuntu/Debian (Ondřej Surý's PPA)
- RHEL/Fedora/CentOS (Remi repository)
- WSL

## Dependencies

Required:
- bash 4.0+
- curl
- PHP installation support (apt/dnf/yum)

Optional:
- [gum](https://github.com/charmbracelet/gum) - Interactive TUI (auto-installed)
- [ripgrep](https://github.com/BurntSushi/ripgrep) - Fast log search
- tmux - Split-screen log viewer
- supervisor - Queue worker management

## License

MIT
