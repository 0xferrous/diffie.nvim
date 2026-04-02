# diffie.nvim

A Neovim plugin template.

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
	"dmnt/diffie.nvim",
	opts = {},
	config = true,
}
```

### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
	"dmnt/diffie.nvim",
	config = function()
		require("diffie").setup({})
	end
}
```

### [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'dmnt/diffie.nvim'
```

Then in your Lua config:
```lua
require("diffie").setup({})
```

## Configuration

```lua
require("diffie").setup({
	enabled = true,
})
```

## License

MIT
