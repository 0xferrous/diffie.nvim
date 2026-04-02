# Justfile for diffie.nvim

# Default recipe to display help
[private]
default:
    @just --list

# Run all tests with plenary.nvim
test:
    nvim --headless \
        -u tests/minimal_init.lua \
        -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}" \
        -c "qa!"

# Run tests interactively (opens nvim with test output)
test-interactive:
    nvim \
        -u tests/minimal_init.lua \
        -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"

# Run a specific test file
test-file file:
    nvim --headless \
        -u tests/minimal_init.lua \
        -c "PlenaryBustedFile {{file}}" \
        -c "qa!"

# Load plugin in nvim with test_init.lua for manual testing
dev:
    nvim -u tests/test_init.lua

# Check Lua syntax
lint:
    @echo "Checking Lua syntax..."
    @for f in lua/**/*.lua tests/**/*.lua; do \
        nvim --headless -c "luafile $$f" -c "qa!" 2>/dev/null || echo "Syntax error in $$f"; \
    done
    @echo "Done"

# Clean up generated files
clean:
    @echo "Nothing to clean"

# Format Lua files with stylua
format:
    stylua lua/ tests/

# Check formatting (CI)
check-format:
    stylua --check lua/ tests/
