--- Lifecycle management for sampling-dependent features.
--- Registers/deregisters keymaps, completion sources, and commands
--- when a capable MCP client connects or disconnects.
---
--- This is the single coordination point. Other modules (completion, assist)
--- don't manage their own registration — this module handles it all.

local M = {}

local registered = false
local keymap_ids = {} -- track what we've bound so we can unbind

--- Check if sampling is currently available.
function M.sampling_available()
  local ok, sessions = pcall(require, "mcp-nvim.sessions")
  if not ok or #sessions.list() == 0 then
    return false
  end
  local protocol = require("mcp-nvim.mcp.protocol")
  return protocol.client_supports("sampling")
end

--- Register all sampling-dependent keymaps and features.
--- Safe to call multiple times — only registers once.
function M.activate()
  if registered then return end
  registered = true

  -- Autocomplete keymaps
  vim.keymap.set("n", "<leader>ac", function()
    require("mcp-nvim.autocomplete").complete()
  end, { desc = "AI code completion" })
  vim.keymap.set("v", "<leader>ac", function()
    vim.cmd("'<,'>McpAutoComplete")
  end, { desc = "AI code completion (replace selection)" })

  -- Assist keymaps
  vim.keymap.set({ "n", "v" }, "<leader>ae", function()
    require("mcp-nvim.assist").explain()
  end, { desc = "AI explain" })
  vim.keymap.set({ "n", "v" }, "<leader>af", function()
    require("mcp-nvim.assist").fix()
  end, { desc = "AI fix diagnostics" })
  vim.keymap.set({ "n", "v" }, "<leader>ar", function()
    require("mcp-nvim.assist").refactor()
  end, { desc = "AI refactor" })
  vim.keymap.set({ "n", "v" }, "<leader>av", function()
    require("mcp-nvim.assist").review()
  end, { desc = "AI review" })

  -- Completion (blink + native)
  local completion = require("mcp-nvim.completion")
  completion.register()
  completion.on_client_connected()

  vim.notify("[mcp-nvim] AI features activated", vim.log.levels.DEBUG)
end

--- Deregister all sampling-dependent keymaps and features.
function M.deactivate()
  if not registered then return end
  registered = false

  -- Remove keymaps (silently ignore if already gone)
  local maps_to_remove = {
    { mode = "n", lhs = "<leader>ac" },
    { mode = "v", lhs = "<leader>ac" },
    { mode = { "n", "v" }, lhs = "<leader>ae" },
    { mode = { "n", "v" }, lhs = "<leader>af" },
    { mode = { "n", "v" }, lhs = "<leader>ar" },
    { mode = { "n", "v" }, lhs = "<leader>av" },
  }
  for _, map in ipairs(maps_to_remove) do
    pcall(vim.keymap.del, map.mode, map.lhs)
  end

  -- Release completion claims
  local completion = require("mcp-nvim.completion")
  completion.on_client_disconnected()

  vim.notify("[mcp-nvim] AI features deactivated", vim.log.levels.DEBUG)
end

--- Called when a new client session is created and we detect sampling capability.
function M.on_session_ready()
  if M.sampling_available() then
    M.activate()
  end
end

--- Called when a session is removed or the server stops.
function M.on_session_lost()
  if not M.sampling_available() then
    M.deactivate()
  end
end

--- Check current state.
function M.is_active()
  return registered
end

return M

