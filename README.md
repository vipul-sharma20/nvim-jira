# nvim-jira

A Neovim plugin for Jira

🚧 *Note: Work inprogress*

Installation
============

| Plugin Manager | Install with... |
| ------------- | ------------- |
| [Pathogen][1] | `git clone https://github.com/vipul-sharma20/nvim-jira ~/.vim/bundle/nvim-jira`<br/>Remember to run `:Helptags` to generate help tags |
| [NeoBundle][2] | `NeoBundle 'vipul-sharma20/nvim-jira'` |
| [Vundle][3] | `Plugin 'vipul-sharma20/nvim-jira'` |
| [Plug][4] | `Plug 'vipul-sharma20/nvim-jira'` |
| [VAM][5] | `call vam#ActivateAddons([ 'nvim-jira' ])` |
| [Dein][6] | `call dein#add('vipul-sharma20/nvim-jira')` |
| [minpac][7] | `call minpac#add('vipul-sharma20/nvim-jira')` |
| manual | copy all of the files into your `~/.vim` directory |

# Configuration

* Get API access token for JIRA and set it to `JIRA_TOKEN` environment
  variable

  `export JIRA_TOKEN="RANDOM123"`

* Set Jira user name as `JIRA_USERNAME` environment variable

  Eg: `export JIRA_USERNAME="user@domain.com"`

* Set Jira host as `JIRA_HOST` environment variable

  Eg: `export JIRA_HOST="https://example.atlassian.net"`

* Install `lua-cjson` (using luarocks: `luarocks install lua-cjson`)
* Install `luasec` (using luarocks: `luarocks install luasec`)

You might have different Lua versions in your system. We need to install the
modules for Lua shipped with nvim.

Check the Lua version of nvim by:

`:lua print(_VERSION)`

Install modules for this version. Example:

`luarocks --lua-version 5.1 install lua-cjson`

# Documentation

`:h nvim-jira`

or check [here][0]

# Commands

| Command              | List                                                                                                    |
| ---                  | ---                                                                                                     |
| `Jira`               | Fetches tickets assigned to you and tickets you are watching. (Tickets are cached for the nvim session) |
| `JiraReload`         | Reload the tickets. Works same as `:Jira` except it hits the API everytime                              |

Check some keybindings in the documentation `:h nvim-jira`

# LICENSE

MIT

# Credits

Rafał Camlet: https://github.com/rafcamlet/nvim-whid

# Disclaimer

I have created this plugin to learn how to use the Lua runtime embedded with
nvim to build plugins.  Things may look ugly and sub-optimal.


[0]: https://github.com/vipul-sharma20/nvim-jira/tree/master/doc/nvim-jira.txt
[1]: https://github.com/tpope/vim-pathogen
[2]: https://github.com/Shougo/neobundle.vim
[3]: https://github.com/VundleVim/Vundle.vim
[4]: https://github.com/junegunn/vim-plug
[5]: https://github.com/MarcWeber/vim-addon-manager
[6]: https://github.com/Shougo/dein.vim
[7]: https://github.com/k-takata/minpac/

