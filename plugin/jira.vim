if exists('g:loaded_jira') | finish | endif " prevent loading file twice

let s:save_cpo = &cpo
set cpo&vim

hi def link JiraHeader      Number
hi def link JiraSubHeader   Identifier
hi jiraCursorLine ctermbg=238 cterm=none

command! Jira lua require'jira'.jira()
command! JiraReload lua require'jira'.jiraReload()

let &cpo = s:save_cpo
unlet s:save_cpo

let g:loaded_jira = 1

