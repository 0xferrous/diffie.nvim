# diffie.nvim

A Neovim plugin template.

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
	"0xferrous/diffie.nvim",
	opts = {},
	config = true,
}
```

### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
	"0xferrous/diffie.nvim",
	config = function()
		require("diffie").setup({})
	end
}
```

### [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug '0xferrous/diffie.nvim'
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
