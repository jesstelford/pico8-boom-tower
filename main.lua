menuitem(1,"debug",function()debugger.expand(true)end)

function _init()
  init_dbg()
end

function _update60()
  if (debugger.expand()) then return end
end

-- Dump to the terminal
printTable({{x=1,y=2},{z=4,h="hello"}, 18}, true)

function _draw()
  cls(0)
  print("pico-8 starter project",10,10,7)
  print("by jess telford",10,20,7)
  debugger.draw()
  sdbg()
end
