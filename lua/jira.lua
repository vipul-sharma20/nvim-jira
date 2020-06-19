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
    response, responseCode = self.http.request {
        url = url,
        headers = headers,
        sink = ltn12.sink.table(responseTable)
    }
    return table.concat(responseTable), responseCode
end

function Jira:getMyIssues (project)
    url = self.host .. "/search?jql=assignee=currentuser()%26project=" .. project
    response, responseCode = self:httpGet(url)

    local json = require('cjson')
    local responseTable = json.decode(response)

    for idx, issue in ipairs(responseTable.issues) do
        print("https://vernacular-ai.atlassian.net/browse/" .. issue.key)
    end

    return self
end

jira = Jira:new{host = 'https://vernacular-ai.atlassian.net/rest/api/3'}
jira:getMyIssues("PCK")

