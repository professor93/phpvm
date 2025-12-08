# PHPVM - PHP Version Manager

A shell-based PHP version manager for Linux with interactive TUI.

## Installation

```bash
# User-local install
curl -fsSL https://raw.githubusercontent.com/professor93/phpvm/main/dist/install.sh | bash

# System-wide install
curl -fsSL https://raw.githubusercontent.com/professor93/phpvm/main/dist/install.sh | sudo bash
```

## Commands

| Command | Description |
|---------|-------------|
| `php use [version]` | Switch PHP version |
| `php install [version]` | Install PHP version or extension |
| `php list` | List installed PHP versions |
| `php list extensions` | List extensions for current PHP |
| `php info` | Show PHP and PHPVM information |
| `php config` | View/edit PHP configuration |
| `php fpm` | Manage PHP-FPM services |
| `php self-update` | Update PHPVM |
| `php help` | Show help |

## Version Resolution

PHPVM resolves PHP version in this order:

1. `PHPVERSION_USE` environment variable
2. `.phpversion` file (searches up from current directory)
3. `~/.phpversion/config` (user default)
4. `/etc/phpversion` (system default)
5. First installed version

## Per-Project PHP Version

```bash
echo "8.4" > .phpversion
```

## Supported Platforms

- Ubuntu/Debian (Ondřej Surý's PPA)
- RHEL/Fedora/CentOS (Remi repository)
- WSL

## License

MIT
