-- Turns binds.lua data into hl.bind calls.
local function dispatcher(action)
  local verb, arg = action:match("^(%S+)%s*(.*)$")
  if verb == "exec" then return hl.dsp.exec_cmd(arg) end
  if verb == "close" then return hl.dsp.window.close() end
  if verb == "float" then return hl.dsp.window.float({ action = "toggle" }) end
  if verb == "exit" then return hl.dsp.exit() end
  if verb == "dpms" then return hl.dsp.dpms("off") end -- toggles
  if verb == "drag" then return hl.dsp.window.drag(), { mouse = true } end
  if verb == "resize" then return hl.dsp.window.resize(), { mouse = true } end
  if verb == "focus" then return hl.dsp.focus({ direction = arg }) end
  if verb == "workspace" then return hl.dsp.focus({ workspace = tonumber(arg) or arg }) end
  error("oracle: unknown bind action '" .. action .. "'")
end

return function(binds)
  for key, action in pairs(binds) do
    if action then
      local d, opts = dispatcher(action)
      if key:match("^XF86") then opts = { locked = true, repeating = true } end
      hl.bind(key, d, opts)
    end
  end
end
