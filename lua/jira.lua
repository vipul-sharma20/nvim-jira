--[[
    TODO:
    - Learn Lua
    - Jira base class
    - get/post request helper methods
    - Get my issues with JQL
    - Convert to vim plugin
--]]

require "os"

Jira = {host = nil, username = nil, accessToken = nil }

function Jira:new (obj, username, accessToken)
    obj = obj or {}
    setmetatable(obj, self)
    self.__index = self
    self.host = host
    self.username = username or os.getenv("JIRA_USERNAME")
    self.accessToken = accessToken or os.getenv("JIRA_TOKEN")
    self.http = require("ssl.https")

    return obj
end

function Jira:httpGet (url)
    mime = require("mime")

    headers = {
        authorization = "Basic " .. mime.b64(string.format('%s:%s', self.username, self.accessToken))
    }

    local ltn12 = require("ltn12")
    local io = require("io")
    responseTable = {}
    response, responseCode, c, h = self.http.request {
        url = url,
        headers = headers,
        sink = ltn12.sink.table(responseTable)
        -- sink = ltn12.sink.file(io.stdout)
    }
    return table.concat(responseTable), responseCode
end

function Jira:getMyIssues (project)
    url = self.host .. "/search?jql=assignee=currentuser()%26project=" .. project
    response, responseCode = self:httpGet(url)

    local json = require('cjson')
    local responseTable = json.decode(response)

    return responseTable.issues
end

local function connect()
    jira = Jira:new{host = 'https://vernacular-ai.atlassian.net/rest/api/3'}
    return jira:getMyIssues("PCK")
end

local api = vim.api
local buf, win
local position = 0

local function center(str)
  local width = api.nvim_win_get_width(0)
  local shift = math.floor(width / 2) - math.floor(string.len(str) / 2)
  return string.rep(' ', shift) .. str
end

local function open_window()
  buf = vim.api.nvim_create_buf(false, true)
  local border_buf = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(buf, 'filetype', 'jira')

  local width = vim.api.nvim_get_option("columns")
  local height = vim.api.nvim_get_option("lines")

  local win_height = math.ceil(height * 0.8 - 4)
  local win_width = math.ceil(width * 0.8)
  local row = math.ceil((height - win_height) / 2 - 1)
  local col = math.ceil((width - win_width) / 2)

  local border_opts = {
    style = "minimal",
    relative = "editor",
    width = win_width + 2,
    height = win_height + 2,
    row = row - 1,
    col = col - 1
  }

  local opts = {
    style = "minimal",
    relative = "editor",
    width = win_width,
    height = win_height,
    row = row,
    col = col
  }

  local border_lines = { '╔' .. string.rep('═', win_width) .. '╗' }
  local middle_line = '║' .. string.rep(' ', win_width) .. '║'
  for i=1, win_height do
    table.insert(border_lines, middle_line)
  end
  table.insert(border_lines, '╚' .. string.rep('═', win_width) .. '╝')
  vim.api.nvim_buf_set_lines(border_buf, 0, -1, false, border_lines)

  local border_win = vim.api.nvim_open_win(border_buf, true, border_opts)
  win = api.nvim_open_win(buf, true, opts)
  api.nvim_command('au BufWipeout <buffer> exe "silent bwipeout! "'..border_buf)

  vim.api.nvim_win_set_option(win, 'cursorline', true)

  api.nvim_buf_set_lines(buf, 0, -1, false, { center('My Jira'), '', ''})
  api.nvim_command('set nofoldenable')
  api.nvim_buf_add_highlight(buf, -1, 'WhidHeader', 0, 0, -1)
end

local function update_view(direction)
  vim.api.nvim_buf_set_option(buf, 'modifiable', true)
  position = position + direction
  if position < 0 then position = 0 end

  jira = Jira:new{host = 'https://vernacular-ai.atlassian.net/rest/api/3'}
  results = jira:getMyIssues("PCK")

  local result = {}
  for idx, issue in ipairs(results) do
    result[idx] = "  " .. issue.key .. ' | ' .. issue.fields.summary
  end

  -- api.nvim_buf_set_lines(buf, 1, 2, false, {center('HEAD~'..position)})
  api.nvim_buf_set_lines(buf, 3, -1, false, result)

  api.nvim_buf_add_highlight(buf, -1, 'whidSubHeader', 1, 0, -1)
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
end

local function close_window()
  api.nvim_win_close(win, true)
end

local function open_file()
  local str = api.nvim_get_current_line()
  close_window()
  api.nvim_command('edit '..str)
end

local function move_cursor()
  local new_pos = math.max(4, api.nvim_win_get_cursor(win)[1] - 1)
  api.nvim_win_set_cursor(win, {new_pos, 0})
end

local function set_mappings()
  local mappings = {
    ['['] = 'update_view(-1)',
    [']'] = 'update_view(1)',
    ['<cr>'] = 'open_file()',
    h = 'update_view(-1)',
    l = 'update_view(1)',
    q = 'close_window()',
    k = 'move_cursor()'
  }

  for k,v in pairs(mappings) do
    api.nvim_buf_set_keymap(buf, 'n', k, ':lua require"jira".'..v..'<cr>', {
        nowait = true, noremap = true, silent = true
      })
  end
  local other_chars = {
    'a', 'b', 'c', 'd', 'e', 'f', 'g', 'i', 'n', 'o', 'p', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z'
  }
  for k,v in ipairs(other_chars) do
    api.nvim_buf_set_keymap(buf, 'n', v, '', { nowait = true, noremap = true, silent = true })
    api.nvim_buf_set_keymap(buf, 'n', v:upper(), '', { nowait = true, noremap = true, silent = true })
    api.nvim_buf_set_keymap(buf, 'n',  '<c-'..v..'>', '', { nowait = true, noremap = true, silent = true })
  end
end

local function jira()
  position = 0
  open_window()
  set_mappings()
  update_view(0)
  api.nvim_win_set_cursor(win, {4, 0})
  -- connect()
end

return {
  jira = jira,
  update_view = update_view,
  open_file = open_file,
  move_cursor = move_cursor,
  close_window = close_window
}
