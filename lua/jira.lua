require("os")

JSON = require("JSON")
mime = require("mime")
ltn12 = require("ltn12")
io = require("io")

local api = vim.api
local buf, win
local position = 0

Jira = {host = nil, username = nil, accessToken = nil }

-- Jira interface
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

-- GET request handler
function Jira:http_get(url)
    headers = {
        authorization = "Basic " .. mime.b64(string.format('%s:%s', self.username, self.accessToken))
    }
    response_table = {}
    response, response_code, c, h = self.http.request {
        url = url,
        headers = headers,
        sink = ltn12.sink.table(response_table)
        -- sink = ltn12.sink.file(io.stdout)
    }
    return table.concat(response_table), response_code
end

-- POST request handler
function Jira:http_post(url, body)
    headers = {
        authorization = "Basic " .. mime.b64(string.format('%s:%s', self.username, self.accessToken)),
        ["Content-Type"] = "application/json",
        ["Content-Length"] = body:len()
    }
    response_table = {}
    response, response_code, c, h = self.http.request {
        url = url,
        method = "POST",
        headers = headers,
        sink = ltn12.sink.table(response_table),
        source = ltn12.source.string(body),
    }

    return table.concat(response_table), response_code
end

-- Fetch my issues (assigned + watching)
function Jira:get_my_issues(project)
    url = self.host .. "/search?maxResults=100&jql=watcher+=+currentuser()%26resolution=Unresolved%26project=" .. project
    response, response_code = self:http_get(url)

    local response_table = JSON:decode(response)

    return response_table.issues
end

-- Fetch comments on an issue
function Jira:get_issue_comments(issueId)
    url = self.host .. string.format("/issue/%s/comment", issueId)
    response, response_code = self:http_get(url)

    local response_table = JSON:decode(response)

    return response_table.comments
end

-- Publish comment for the issue
function Jira:publish_comment(issueId)
    local message = api.nvim_get_current_line()

    local url = self.host .. string.format("/issue/%s/comment", issueId)
    local body = string.format([[ {"body": { "type": "doc", "version": 1, "content": [ { "type": "paragraph", "content": [ { "text": "%s", "type": "text" } ] } ] } } ]], message)

    response, response_code = self:http_post(url, body)

    if response_code == 201 then
        print(string.format('Comment posted: %s', message))
    end
end

-- Event handler of publish comment keymap
function publish_comment_handler()
    jira:publish_comment(current_issue)
end

-- Event handler for add comment key map
function comment_event_handler()
    local s = api.nvim_get_current_line()
    close_window()

    splits = split(s, ' ')
    current_issue = current_issue or splits[1]:gsub('%s+', '')
    init()
end

-- Format the comment lines fetched
function get_formatted_comments(commentsTable)
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
            local comment_line = ''
            for text_idx, text in ipairs(content.content) do
                if text.type == "paragraph" then
                    table.insert(render, comment_line .. text.paragraph)
                    comment_line = ''
                elseif text.type == "text" then
                    if text.text ~= ' ' then
                        table.insert(render, comment_line .. text.text)
                        comment_line = ''
                    end
                elseif text.type == "hardBreak" then
                    table.insert(render, '')
                elseif text.type == "mention" then
                    comment_line = comment_line .. string.format("[%s]", text.attrs.text)
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

-- Open the selected issue
function open_issue()
    local s = api.nvim_get_current_line()

    splits = split(s, ' ')
    close_window()
    init()

    current_issue = splits[1]:gsub('%s+', '')
    response = jira:get_issue_comments(current_issue)
    comments = get_formatted_comments(response)

    api.nvim_buf_set_lines(buf, 0, 100, false, comments)
end

-- Open floating window
function open_window()
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

-- Close window event handler
function close_window()
    api.nvim_win_close(win, true)
    buf = nil
    win = nil
end

-- Update and populate floating window with Jira issues
function update_view(direction)
    vim.api.nvim_buf_set_option(buf, 'modifiable', true)
    position = position + direction
    if position < 0 then position = 0 end

    if results == nil then
        connect()
        results = jira:get_my_issues("PCK")
    end

    local result = {}
    for idx, issue in ipairs(results) do
        issue_line = string.format('  %s <%s> | %s [%s]', issue.key, issue.fields.assignee.displayName, issue.fields.summary, issue.fields.status.name)
        result[idx] = issue_line
    end
    api.nvim_buf_set_lines(buf, 3, -1, false, result)

    api.nvim_buf_add_highlight(buf, -1, 'whidSubHeader', 1, 0, -1)
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
end

function move_cursor()
   local new_pos = math.max(4, api.nvim_win_get_cursor(win)[1] - 1)
   api.nvim_win_set_cursor(win, {new_pos, 0})
end

-- Define keymappings
function set_mappings()
    local mappings = {
      ['['] = 'update_view(-1)',
      [']'] = 'update_view(1)',
      ['<cr>'] = 'open_issue()',
      ['\\com'] = 'comment_event_handler()',
      [':w'] = 'publish_comment_handler()',
      ['\\web'] = 'open_in_web()',
      q = 'close_window()',
    }

    for k,v in pairs(mappings) do
        api.nvim_buf_set_keymap(buf, 'n', k, ':lua require"jira".'..v..'<cr>', {
            nowait = true, noremap = true, silent = true
          })
    end
    local other_chars = {
      'a', 'c', 'n', 'o', 'p', 'r', 's', 't', 'v', 'x', 'y', 'z'
    }
    for k,v in ipairs(other_chars) do
        api.nvim_buf_set_keymap(buf, 'n', v, '', { nowait = true, noremap = true, silent = true })
        api.nvim_buf_set_keymap(buf, 'n', v:upper(), '', { nowait = true, noremap = true, silent = true })
        api.nvim_buf_set_keymap(buf, 'n',  '<c-'..v..'>', '', { nowait = true, noremap = true, silent = true })
    end
end

-- Open issue in browser
local function open_in_web()
    local s = api.nvim_get_current_line()
    close_window()

    splits = split(s, ' ')
    current_issue = current_issue or splits[1]:gsub('%s+', '')
    local url = string.format("%s/browse/%s", os.getenv("JIRA_HOST"), current_issue)
    api.nvim_command(string.format(':!open %s', url))
end

-- function call for :Jira
function jira_load()
   init()
   update_view(0)
   api.nvim_win_set_cursor(win, {4, 0})
end

-- function call for :JiraReload
function jira_reload()
    results = nil
    jira_load()
end

-- Create Jira instance
function connect()
    jira = Jira:new{host = string.format("%s/rest/api/3", os.getenv("JIRA_HOST"))}
end

-- Initialize
function init()
    position = 0
    open_window()
    set_mappings()
end

-- Text align center
function center(str)
   local width = api.nvim_win_get_width(0)
   local shift = math.floor(width / 2) - math.floor(string.len(str) / 2)
   return string.rep(' ', shift) .. str
end

-- Split string by a delimiter
function split (inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t
end

return {
  jira_load = jira_load,
  jira_reload = jira_reload,
  update_view = update_view,
  open_issue = open_issue,
  move_cursor = move_cursor,
  close_window = close_window,
  comment_event_handler = comment_event_handler,
  publish_comment_handler = publish_comment_handler,
  open_in_web = open_in_web
}
