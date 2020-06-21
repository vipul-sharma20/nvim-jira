--[[
    TODO:
    - Learn Lua
    - Jira base class
    - get/post request helper methods
    - Get my issues with JQL
    - Convert to vim plugin
--]]

require "os"
results = nil
cjson = require "cjson"

Jira = {host = nil, username = nil, accessToken = nil }

function Jira:new (obj, username, accessToken)
    obj = obj or {}
    setmetatable(obj, self)
    self.__index = self
    self.host = host or os.getenv("JIRA_HOST")
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

function Jira:httpPost (url, body)
    mime = require("mime")

    headers = {
        authorization = "Basic " .. mime.b64(string.format('%s:%s', self.username, self.accessToken)),
        ["Content-Type"] = "application/json",
        ["Content-Length"] = body:len()
    }

    local ltn12 = require("ltn12")
    local io = require("io")
    responseTable = {}
    response, responseCode, c, h = self.http.request {
        url = url,
        method = "POST",
        headers = headers,
        sink = ltn12.sink.table(responseTable),
        source = ltn12.source.string(body),
    }

    return table.concat(responseTable), responseCode
end

function Jira:postComment (message, issueId)
    local url = self.host .. string.format("/issue/%s/comment", issueId)
    local body = string.format([[ {"body": { "type": "doc", "version": 1, "content": [ { "type": "paragraph", "content": [ { "text": "%s", "type": "text" } ] } ] } } ]], message)

    response, responseCode = self:httpPost(url, body)
    if responseCode == 201 then
        print('Comment posted')
    end
end

function Jira:getMyIssues (project)
    url = self.host .. "/search?maxResults=100&jql=assignee=currentuser()%26resolution=Unresolved%26project=" .. project
    response, responseCode = self:httpGet(url)

    local responseTable = cjson.decode(response)

    return responseTable.issues
end

function Jira:getIssueComments (issueId)
    url = self.host .. string.format("/issue/%s/comment", issueId)
    response, responseCode = self:httpGet(url)

    local json = require('cjson')
    local responseTable = json.decode(response)

    return responseTable.comments
end

local function connect()
    jira = Jira:new{host = 'https://vernacular-ai.atlassian.net/rest/api/3'}
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

    if results == nil then
        connect()
        results = jira:getMyIssues("PCK")
    end

    local result = {}
    for idx, issue in ipairs(results) do
        result[idx] = "  " .. issue.key .. ' | ' .. issue.fields.summary .. ' [' .. issue.fields.status.name .. ']'
    end
    api.nvim_buf_set_lines(buf, 3, -1, false, result)

    api.nvim_buf_add_highlight(buf, -1, 'whidSubHeader', 1, 0, -1)
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
end

local function close_window()
    api.nvim_win_close(win, true)
    buf = nil
    win = nil
end

local function split (inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t
end

local function move_cursor()
   local new_pos = math.max(4, api.nvim_win_get_cursor(win)[1] - 1)
   api.nvim_win_set_cursor(win, {new_pos, 0})
end

local function publish_comment()
    local s = api.nvim_get_current_line()
    jira:postComment(s, current_issue)
end

local function set_mappings()
    local mappings = {
      ['['] = 'update_view(-1)',
      [']'] = 'update_view(1)',
      ['<cr>'] = 'open_file()',
      ['\\com'] = 'insert_comment()',
      [':w'] = 'publish_comment()',
      ['\\web'] = 'open_in_web()',
      q = 'close_window()',
    }

    for k,v in pairs(mappings) do
        api.nvim_buf_set_keymap(buf, 'n', k, ':lua require"jira".'..v..'<cr>', {
            nowait = true, noremap = true, silent = true
          })
    end
    local other_chars = {
      'a', 'c', 'g', 'n', 'o', 'p', 'r', 's', 't', 'v', 'x', 'y', 'z'
    }
    for k,v in ipairs(other_chars) do
        api.nvim_buf_set_keymap(buf, 'n', v, '', { nowait = true, noremap = true, silent = true })
        api.nvim_buf_set_keymap(buf, 'n', v:upper(), '', { nowait = true, noremap = true, silent = true })
        api.nvim_buf_set_keymap(buf, 'n',  '<c-'..v..'>', '', { nowait = true, noremap = true, silent = true })
    end
end

local function init()
    position = 0
    open_window()
    set_mappings()
end

local function filterComments(commentsTable)
    render = {}

    for comment_idx, comment in ipairs(commentsTable) do
        local author = comment.author.displayName .. ' posted at: ' .. comment.created
        local underline = ''
        for i=1,string.len(author) do
            underline = underline .. '='
        end

        table.insert(render, underline)
        table.insert(render, author)
        table.insert(render, underline)
        table.insert(render, '')
        for content_idx, content in ipairs(comment.body.content) do
            for text_idx, text in ipairs(content.content) do
                if text.type == "paragraph" then
                    table.insert(render, cjson.encode(text.paragraph))
                elseif text.type == "text" then
                    if text.text ~= ' ' then
                        table.insert(render, cjson.encode(text.text))
                    end
                elseif text.type == "hardBreak" then
                    table.insert(render, '')
                elseif text.type == "mention" then
                    table.insert(render, text.attrs.text)
                else
                end
                if text.text == nil then
                    table.insert(render, '')
                end
            end
        end
        table.insert(render, '')
    end
    return render
end

local function insert_comment()
    local s = api.nvim_get_current_line()
    close_window()

    splits = split(s, ' ')
    current_issue = current_issue or splits[1]:gsub('%s+', '')
    init()
end

local function open_in_web()
    local s = api.nvim_get_current_line()
    close_window()

    splits = split(s, ' ')
    current_issue = current_issue or splits[1]:gsub('%s+', '')
    local url = string.format("%s/browse/%s", os.getenv("JIRA_HOST"), current_issue)
    api.nvim_command(string.format(':!open %s', url))
end

local function open_file()
    local s = api.nvim_get_current_line()

    splits = split(s, ' ')
    close_window()
    init()

    current_issue = splits[1]:gsub('%s+', '')
    response = jira:getIssueComments(current_issue)
    comments = filterComments(response)

    api.nvim_buf_set_lines(buf, 0, 100, false, comments)
end

local function jira()
   init()
   update_view(0)
   api.nvim_win_set_cursor(win, {4, 0})
end

local function jiraReload()
    results = nil
    jira()
end

return {
  jira = jira,
  jiraReload = jiraReload,
  update_view = update_view,
  open_file = open_file,
  move_cursor = move_cursor,
  close_window = close_window,
  insert_comment = insert_comment,
  publish_comment = publish_comment,
  open_in_web = open_in_web
}
