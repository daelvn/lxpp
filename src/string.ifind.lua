-- Iterative string.find
local function ifind (s, pattern, _spos)
  local positions = {}
  local i = 0
  while true do
    i,e = s:find(pattern, i+1)    -- find 'next' newline
    if i == nil then break end
    table.insert(positions, {i,e})
  end
  return positions
end

for i,v in pairs(ifind("a b c a b c", "a", 1)) do
  print "====="
  for ii, vv in ipairs(v) do
    print(vv)
  end
  print "====="
end
