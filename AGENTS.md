# Agent Notes for diffie.nvim

## nvim plugin extmark/virtual text patterns

When building nvim plugins that use extmarks/virtual text:

1. **Separate state from rendering**: Keep pure data in a `M.state` table, all vim API calls in a dedicated Renderer module
2. **Track render state**: Maintain extmark/sign IDs to enable clean cleanup before re-rendering
3. **Use `clear() → render()` pattern**: Always wipe old extmarks before creating new ones to prevent duplicates
4. **Normalize buffer numbers**: Handle `bufnr=0` (current buffer) edge case early, especially at startup when buffer 0 may not be valid
5. **Expose internal modules for testing**: Use `M._renderer` pattern to allow unit tests to verify rendering behavior without relying on full UI
6. **Make state inspectable**: Provide getter functions like `M.get_comment(buf, lnum)` for testing and debugging

Example architecture:
```lua
-- STATE: pure Lua tables
M.state = {} -- bufnr -> { lnum -> Comment }

-- RENDERER: all vim.api calls isolated here
local Renderer = {}
function Renderer.clear(bufnr) ... end
function Renderer.render_buffer(bufnr) ... end

-- API: triggers render after state changes
function M.add_comment(...) ... Renderer.render_buffer(bufnr) end
```

## Running tests locally

```bash
just test           # Run all tests
just test-interactive  # Interactive test mode
just dev            # Manual testing with test_init.lua
```

## Test structure

- `tests/minimal_init.lua` - Bootstraps plenary.nvim and test helpers
- `tests/comments_spec.lua` - State management and renderer tests
- Use `create_test_buffer()` helper to create buffers with content for extmark tests

## Documentation maintenance

**Always keep README.md in sync with code changes.** When modifying:

- **API changes** → Update Usage section and Configuration examples
- **New features** → Add to Features list with description
- **Removed features** → Remove from all sections
- **Keymap changes** → Update keymaps table and Configuration section
- **New config options** → Add to Configuration section with defaults

**Before completing a task:**
1. Review README for outdated information
2. Update any sections affected by your changes
3. Ensure examples in README still work with current API
