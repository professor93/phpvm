#!/bin/bash
# Install git hooks for PHPVM development

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
HOOKS_DIR="$REPO_ROOT/.git/hooks"

echo "Installing git hooks..."

# Create pre-commit hook
cat > "$HOOKS_DIR/pre-commit" << 'EOF'
#!/bin/bash
# Pre-commit hook: Auto-build dist files when src changes

# Check if any src/ files are staged
if git diff --cached --name-only | grep -q "^src/"; then
    echo "Source files changed, rebuilding dist..."

    # Run build script
    bash build.sh

    # Check if build was successful
    if [ $? -ne 0 ]; then
        echo "Build failed! Commit aborted."
        exit 1
    fi

    # Add rebuilt dist files to the commit
    git add dist/

    echo "Dist files rebuilt and staged."
fi

exit 0
EOF

chmod +x "$HOOKS_DIR/pre-commit"

echo "Pre-commit hook installed successfully!"
echo ""
echo "The hook will automatically rebuild dist/ when src/ files are changed."
