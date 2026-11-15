-- ~/.config/oracle/settings (key=value, written by `oracle set` / the Settings screen) as a table. Read at every config reload.
local S = {}
local f = io.open(os.getenv("HOME") .. "/.config/oracle/settings")
if f then
  for l in f:lines() do local k, v = l:match("^([%w_]+)=(.*)$"); if k then S[k] = v end end
  f:close()
end
return S
