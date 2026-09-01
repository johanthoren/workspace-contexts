local M = dofile("hypr/contexts.lua")

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

local filled = M.load_file()
eq(filled.contexts[1].name, "work", "dump fills shipped defaults")
eq(filled.contexts[2].name, "personal")
eq(filled.contexts[3].name, "other")
eq(filled.contexts[1].base, 0)
eq(filled.slots, 9)

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

M.setup({ hl = fake_hl, o = fake_o })

if not has(unbinds, "SUPER + code:10") then
  error("did not unbind Super+1")
end
if not has(unbinds, "SUPER + code:18") then
  error("did not unbind Super+9")
end
if has(unbinds, "SUPER + code:19") then
  error("unbound Super+10")
end
if not has(unbinds, "SUPER + CTRL + LEFT") then
  error("did not unbind Super+Ctrl+Left")
end
if not has(binds, "SUPER + code:10") then
  error("did not bind Super+1")
end
if not has(binds, "SUPER + CTRL + RIGHT") then
  error("did not bind Super+Ctrl+Right")
end
