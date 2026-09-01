local M = {}

local THIS_SOURCE = debug.getinfo(1, "S").source
if THIS_SOURCE:sub(1, 1) == "@" then
  THIS_SOURCE = THIS_SOURCE:sub(2)
end
local THIS_DIR = THIS_SOURCE:match("^(.*)/") or "."
local PARSE_PY = THIS_DIR .. "/../parse_contexts.py"
local PLUGIN_ID = "io.github.johanthoren.workspace-contexts"
local USER_FILE = (os.getenv("HOME") or "")
  .. "/.config/omarchy/"
  .. PLUGIN_ID
  .. "/contexts.json"

-- Used only when python3 --dump fails. The filled table comes from parse_contexts.py.
local DEFAULT_FILE = {
  stride = 10,
  slots = 9,
  maxContexts = 10,
  contexts = {
    { name = "work", base = 0, accent = "blue" },
    { name = "personal", base = 10, accent = "green" },
    { name = "other", base = 20, accent = "magenta" },
  },
}

-- Omarchy exports the same helper as o.shell_quote, but this module is also
-- loaded standalone by the test, before that global exists.
local function shell_quote(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function decode_json(text)
  local s = tostring(text or "")
  local n = #s
  local i = 1

  local function fail(msg)
    error("json " .. msg .. " at " .. i)
  end

  local function peek()
    return s:sub(i, i)
  end

  local function skip()
    local _, last = s:find("^[ \t\n\r]+", i)
    if last then
      i = last + 1
    end
  end

  local parse_value

  local function parse_string()
    if peek() ~= '"' then
      fail("string")
    end
    i = i + 1
    local out = {}
    while i <= n do
      local c = s:sub(i, i)
      if c == '"' then
        i = i + 1
        return table.concat(out)
      end
      if c == "\\" then
        local e = s:sub(i + 1, i + 1)
        local map = {
          ['"'] = '"',
          ["\\"] = "\\",
          ["/"] = "/",
          b = "\b",
          f = "\f",
          n = "\n",
          r = "\r",
          t = "\t",
        }
        if e == "u" then
          local hex = s:sub(i + 2, i + 5)
          if not hex:find("^[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]$") then
            fail("unicode")
          end
          local code = tonumber(hex, 16)
          if code < 128 then
            out[#out + 1] = string.char(code)
          elseif code < 2048 then
            out[#out + 1] = string.char(192 + math.floor(code / 64), 128 + (code % 64))
          else
            out[#out + 1] = string.char(
              224 + math.floor(code / 4096),
              128 + (math.floor(code / 64) % 64),
              128 + (code % 64)
            )
          end
          i = i + 6
        elseif map[e] then
          out[#out + 1] = map[e]
          i = i + 2
        else
          fail("escape")
        end
      else
        out[#out + 1] = c
        i = i + 1
      end
    end
    fail("unterminated")
  end

  local function parse_number()
    local token = s:match("^-?%d+%.%d+[eE][%+%-]?%d+", i)
      or s:match("^-?%d+[eE][%+%-]?%d+", i)
      or s:match("^-?%d+%.%d+", i)
      or s:match("^-?%d+", i)
    if not token then
      fail("number")
    end
    i = i + #token
    return tonumber(token)
  end

  local function parse_array()
    i = i + 1
    local arr = {}
    skip()
    if peek() == "]" then
      i = i + 1
      return arr
    end
    while true do
      arr[#arr + 1] = parse_value()
      skip()
      local c = peek()
      if c == "]" then
        i = i + 1
        return arr
      end
      if c ~= "," then
        fail("comma")
      end
      i = i + 1
    end
  end

  local function parse_object()
    i = i + 1
    local obj = {}
    skip()
    if peek() == "}" then
      i = i + 1
      return obj
    end
    while true do
      skip()
      local key = parse_string()
      skip()
      if peek() ~= ":" then
        fail("colon")
      end
      i = i + 1
      obj[key] = parse_value()
      skip()
      local c = peek()
      if c == "}" then
        i = i + 1
        return obj
      end
      if c ~= "," then
        fail("comma")
      end
      i = i + 1
    end
  end

  parse_value = function()
    skip()
    local c = peek()
    if c == '"' then
      return parse_string()
    end
    if c == "{" then
      return parse_object()
    end
    if c == "[" then
      return parse_array()
    end
    if c == "-" or c:find("%d") then
      return parse_number()
    end
    if s:sub(i, i + 3) == "true" then
      i = i + 4
      return true
    end
    if s:sub(i, i + 4) == "false" then
      i = i + 5
      return false
    end
    if s:sub(i, i + 3) == "null" then
      i = i + 4
      return nil
    end
    fail("value")
  end

  local value = parse_value()
  skip()
  if i <= n then
    fail("trailing")
  end
  return value
end

local function slots_of(file)
  local slots = file and file.slots
  if type(slots) == "number" and slots >= 1 and slots % 1 == 0 then
    return slots
  end
  return 9
end

local function read_dump()
  local cmd = "/usr/bin/python3 " .. shell_quote(PARSE_PY) .. " --dump"
  local pipe = io.popen(cmd)
  if not pipe then
    return nil
  end
  local raw = pipe:read("*a") or ""
  pipe:close()
  if raw == "" then
    return nil
  end
  local ok, data = pcall(decode_json, raw)
  if not ok or type(data) ~= "table" or type(data.contexts) ~= "table" or #data.contexts < 1 then
    return nil
  end
  return data
end

function M.location_for_workspace(workspace_id, file)
  if type(workspace_id) ~= "number" or workspace_id % 1 ~= 0 or workspace_id < 1 then
    return nil, nil
  end
  if type(file) ~= "table" or type(file.contexts) ~= "table" then
    return nil, nil
  end
  local slots = slots_of(file)
  for index, ctx in ipairs(file.contexts) do
    if type(ctx) == "table" and type(ctx.base) == "number" then
      local slot = workspace_id - ctx.base
      if slot >= 1 and slot <= slots then
        return index, slot
      end
    end
  end
  return nil, nil
end

function M.workspace_id(context_index, slot, file)
  if type(file) ~= "table" or type(file.contexts) ~= "table" then
    return nil
  end
  local ctx = file.contexts[context_index]
  if type(ctx) ~= "table" or type(ctx.base) ~= "number" then
    return nil
  end
  local slots = slots_of(file)
  if type(slot) ~= "number" or slot % 1 ~= 0 or slot < 1 or slot > slots then
    return nil
  end
  return ctx.base + slot
end

function M.adjacent_context(context_index, direction, count)
  if type(count) ~= "number" or count < 1 or count % 1 ~= 0 then
    return nil
  end
  if type(context_index) ~= "number" or context_index % 1 ~= 0 then
    return nil
  end
  if context_index < 1 or context_index > count then
    return nil
  end
  if direction ~= -1 and direction ~= 1 then
    return nil
  end
  return ((context_index - 1 + direction) % count) + 1
end

-- Every keybind resolves the current file, and read_dump() forks a Python
-- interpreter inside the compositor's Lua VM (~40 ms). Reading contexts.json
-- costs nothing by comparison, so its raw text is the cache key: the dump only
-- re-runs when the user actually edits the file. A failed dump is not cached,
-- so the next keypress retries. Absent reads as false, which differs from any
-- string, so the first read after a seed re-runs once.
local cached_source = nil
local cached_file = nil

local function read_user_source()
  local handle = io.open(USER_FILE, "r")
  if not handle then
    return false
  end
  local text = handle:read("*a")
  handle:close()
  return text or false
end

function M.load_file()
  local source = read_user_source()
  if cached_file and source == cached_source then
    return cached_file
  end
  local dumped = read_dump()
  if not dumped then
    return DEFAULT_FILE
  end
  cached_file = dumped
  cached_source = source
  return dumped
end

function M.setup(dependencies)
  local api = dependencies and dependencies.hl or hl
  local helpers = dependencies and dependencies.o or o
  local last_slots = {}
  local active_name = nil

  local function current_file()
    return M.load_file()
  end

  local function resolve_index(file)
    local workspace = api.get_active_workspace()
    local index, slot = M.location_for_workspace(workspace and workspace.id, file)
    if index then
      active_name = file.contexts[index].name
      last_slots[active_name] = slot
      return index
    end
    if active_name then
      for i, ctx in ipairs(file.contexts) do
        if ctx.name == active_name then
          return i
        end
      end
    end
    return 1
  end

  local function focus_workspace(file, context_index, slot)
    local id = M.workspace_id(context_index, slot, file)
    if not id then
      return
    end
    api.dispatch(api.dsp.focus({ workspace = tostring(id) }))
  end

  local function slot_of(file, name)
    local slot = last_slots[name] or 1
    local slots = slots_of(file)
    if slot < 1 or slot > slots then
      return 1
    end
    return slot
  end

  local function focus_slot(slot)
    local file = current_file()
    local index = resolve_index(file)
    local name = file.contexts[index].name
    last_slots[name] = slot
    focus_workspace(file, index, slot)
  end

  local function move_window_to_slot(slot, follow)
    local file = current_file()
    local index = resolve_index(file)
    local id = M.workspace_id(index, slot, file)
    if not id then
      return
    end
    local spec = { workspace = tostring(id) }
    if follow == false then
      spec.follow = false
    else
      last_slots[file.contexts[index].name] = slot
    end
    api.dispatch(api.dsp.window.move(spec))
  end

  local function switch_context(direction)
    local file = current_file()
    local index = resolve_index(file)
    local target = M.adjacent_context(index, direction, #file.contexts)
    if not target or target == index then
      return
    end
    local ctx = file.contexts[target]
    active_name = ctx.name
    focus_workspace(file, target, slot_of(file, ctx.name))
  end

  local function move_window_to_context(direction)
    local file = current_file()
    local index = resolve_index(file)
    local slot = slot_of(file, file.contexts[index].name)
    local target = M.adjacent_context(index, direction, #file.contexts)
    if not target or target == index then
      return
    end
    local ctx = file.contexts[target]
    active_name = ctx.name
    last_slots[ctx.name] = slot
    api.dispatch(api.dsp.window.move({
      workspace = tostring(M.workspace_id(target, slot, file)),
    }))
  end

  local file = current_file()
  local slots = slots_of(file)
  for slot = 1, slots do
    local key = "code:" .. tostring(slot + 9)

    -- Stock Super+N focuses global workspace N. Keep Super+10 if slots is 9.
    api.unbind("SUPER + " .. key)
    api.unbind("SUPER + SHIFT + " .. key)
    api.unbind("SUPER + SHIFT + ALT + " .. key)

    helpers.bind(
      "SUPER + " .. key,
      "Switch to workspace " .. slot .. " in current context",
      function()
        focus_slot(slot)
      end
    )
    helpers.bind(
      "SUPER + SHIFT + " .. key,
      "Move window to workspace " .. slot .. " in current context",
      function()
        move_window_to_slot(slot, true)
      end
    )
    helpers.bind(
      "SUPER + SHIFT + ALT + " .. key,
      "Move window silently to workspace " .. slot .. " in current context",
      function()
        move_window_to_slot(slot, false)
      end
    )
  end

  -- Stock Super+Ctrl+Left/Right move grouped-window focus.
  api.unbind("SUPER + CTRL + LEFT")
  api.unbind("SUPER + CTRL + RIGHT")
  helpers.bind("SUPER + CTRL + LEFT", "Previous workspace context", function()
    switch_context(-1)
  end)
  helpers.bind("SUPER + CTRL + RIGHT", "Next workspace context", function()
    switch_context(1)
  end)
  helpers.bind("SUPER + CTRL + SHIFT + LEFT", "Move window to previous workspace context", function()
    move_window_to_context(-1)
  end)
  helpers.bind("SUPER + CTRL + SHIFT + RIGHT", "Move window to next workspace context", function()
    move_window_to_context(1)
  end)

  return {
    focus_slot = focus_slot,
    move_window_to_slot = move_window_to_slot,
    move_window_to_context = move_window_to_context,
    switch_context = switch_context,
  }
end

if hl then
  M.setup()
end

return M
