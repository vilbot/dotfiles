-- Single place for OS checks. Use these instead of calling has("win32") directly.
local M = {}

M.is_win = vim.fn.has("win32") == 1
M.is_mac = vim.fn.has("mac") == 1
M.is_linux = not M.is_win and not M.is_mac

local machine = vim.uv.os_uname().machine:lower()
M.is_arm = machine:find("arm") ~= nil or machine:find("aarch") ~= nil

return M
