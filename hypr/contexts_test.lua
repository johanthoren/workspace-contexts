local THIS = debug.getinfo(1, "S").source:gsub("^@", "")
local M = dofile((THIS:match("^(.*)/") or ".") .. "/contexts.lua")

local function eq(got, want, msg)
  if got ~= want then
    error((msg or "eq") .. ": " .. tostring(got) .. " ~= " .. tostring(want), 2)
  end
end

local function has(list, item)
  for i = 1, #list do
    if list[i] == item then
      return true
    end
  end
  return false
end

local file = {
  slots = 9,
  contexts = {
    { name = "work", base = 0, accent = "blue" },
    { name = "lab", base = 100, accent = "red" },
  },
}

local index, slot = M.location_for_workspace(101, file)
eq(index, 2, "custom base maps workspace to row")
eq(slot, 1, "custom base maps workspace to slot")
eq(M.workspace_id(2, 3, file), 103, "workspace id is base + slot")
eq(M.location_for_workspace(10, file), nil, "gap between banks is unowned")
eq(M.adjacent_context(1, -1, 2), 2, "cycle wraps backward")
eq(M.adjacent_context(2, 1, 2), 1, "cycle wraps forward")

-- Asserts the shape read_dump() must produce, not specific names: this file
-- runs against the caller's real HOME, where contexts.json is whatever the user
-- configured. parse_contexts_test.py pins the shipped defaults under a temp HOME.
M.load_file() -- settle: the first call seeds contexts.json when it is absent
local filled = M.load_file()
if type(filled) ~= "table" or type(filled.contexts) ~= "table" then
  error("load_file did not return a filled table")
end
if #filled.contexts < 1 then
  error("load_file returned no contexts")
end
eq(type(filled.slots), "number", "filled table carries slots")
eq(filled.slots % 1, 0, "slots is a whole number")
if filled.slots < 1 or filled.slots > 10 then
  error("slots outside the number row: " .. tostring(filled.slots))
end
for i, ctx in ipairs(filled.contexts) do
  eq(type(ctx.name), "string", "context " .. i .. " has a name")
  eq(type(ctx.base), "number", "context " .. i .. " has a base")
  eq(type(ctx.accent), "string", "context " .. i .. " has an accent")
  if ctx.base < 0 then
    error("context " .. i .. " has a negative base")
  end
end

-- Once contexts.json exists and is unchanged, the dump must not re-run.
-- read_dump builds a fresh table every call, so the same reference back means
-- the cache was used.
if M.load_file() ~= filled then
  error("load_file re-ran the dump for an unchanged file")
end

local unbinds = {}
local binds = {}
local fake_hl = {
  unbind = function(key)
    unbinds[#unbinds + 1] = key
  end,
  dispatch = function() end,
  get_active_workspace = function()
    return { id = 1 }
  end,
  dsp = {
    focus = function(spec)
      return spec
    end,
    window = {
      move = function(spec)
        return spec
      end,
    },
  },
}
local fake_o = {
  bind = function(key)
    binds[#binds + 1] = key
  end,
}

local bound = M.setup({ hl = fake_hl, o = fake_o })

-- Driven by the filled file, not a hardcoded 9: setup binds exactly the slots
-- the user configured, and leaves the rest of the number row to stock Omarchy.
for slot = 1, filled.slots do
  local key = "SUPER + code:" .. tostring(slot + 9)
  if not has(unbinds, key) then
    error("did not unbind " .. key)
  end
  if not has(binds, key) then
    error("did not bind " .. key)
  end
end

if filled.slots < 10 then
  local past = "SUPER + code:" .. tostring(filled.slots + 10)
  if has(unbinds, past) then
    error("unbound " .. past .. ", which is past the bank")
  end
end

if not has(unbinds, "SUPER + CTRL + LEFT") then
  error("did not unbind Super+Ctrl+Left")
end
if not has(binds, "SUPER + CTRL + RIGHT") then
  error("did not bind Super+Ctrl+Right")
end

-- These mutate the temp HOME or stub dump. The standalone run against a real
-- HOME must not touch the user's contexts.json, so they stay harness-only.
if os.getenv("WORKSPACE_CONTEXTS_TEST") == "1" then
  if filled.slots < 2 then
    error("harness dump must have more than one slot")
  end

  local orig_load = M.load_file
  M.load_file = function()
    return {
      slots = 1,
      contexts = { { name = "a", base = 0, accent = "blue" } },
    }
  end
  local seen = {}
  fake_hl.dispatch = function(spec)
    seen[#seen + 1] = spec
  end
  bound.focus_slot(filled.slots)
  bound.move_window_to_slot(filled.slots, true)
  M.load_file = orig_load
  for i = 1, #seen do
    if seen[i] and seen[i].workspace == "nil" then
      error("leftover slot dispatched workspace nil")
    end
  end
  if #seen ~= 0 then
    error("leftover slot should no-op, got " .. tostring(#seen) .. " dispatches")
  end

  local user = (os.getenv("HOME") or "")
    .. "/.config/omarchy/io.github.johanthoren.workspace-contexts/contexts.json"
  local orig_popen = io.popen
  local popen_count = 0
  io.popen = function()
    popen_count = popen_count + 1
    return nil
  end
  local handle = io.open(user, "w")
  if not handle then
    io.popen = orig_popen
    error("could not rewrite the harness contexts.json")
  end
  handle:write('{"contexts":[{"name":"retry","base":0,"accent":"blue"}]}')
  handle:close()
  popen_count = 0
  M.load_file()
  M.load_file()
  io.popen = orig_popen
  if popen_count < 2 then
    error("failed dump was cached; popen called " .. tostring(popen_count) .. " times")
  end
end
