menuitem(1, "debug", function() debugger.expand(true) end)

function _init()
  init_dbg()
end

gravity = 0.4
jerky = 3

inputax = 0.2
inputay = 0.8

airdragx = 0.1
airdragy = 0.4
grounddragx = 0.3
grounddragy = 0

pax = 0
pay = 0

pvx = 0
pvy = 0
maxvx = 5
maxvy = 5

px = 10
py = 62 * 8

jumping = false
coll = false

function _update60()
  if (debugger.expand()) then return end

  if (btn(0)) then
    pax = -inputax
  else if (btn(1)) then
    pax = inputax
  else
    -- Horizontal velocity always degrades in the opposite direction of motion
    pax = -sgn(pvx) * min(airdragx, abs(pvx))
  end end

  -- TODO: Add a jerk (change in acceleration) while jump is held.
  -- The jerk needs to decay while jump is held.
  -- There's a constant gravity acting on the acceleration.
  -- Therefore: The increase in acceleration initially cannot be overcome, but
  -- as the jerk decays, the acceleration reaches zero, so the velocity slows
  -- down, resulting in the the player falling back in the direction of
  -- gravity.
  if (btn(2)) then
    if (coll) then
      jumping = true
    end

    if (jumping) then
      pay = -inputay
    else
      pay = 0
    end
  else
    jumping = false
    -- Vertical velocity always degrades downwards
    pay = 0
  end

  pvx = mid(-maxvx, pvx + pax, maxvx)
  pvy = mid(-maxvy, pvy + pay + airdragy, maxvy)

  if (abs(pvy) == maxvy) then
    -- Can't jump past max velocity
    jumping = false
  end

  px += pvx
  py += pvy

  if (px < 0 or px > 15 * 8) then
    -- Hitting the wall adds a bit more drag
    pvx -= sgn(pvx) * min(airdragx, abs(pvx))
    pvx = pvx * -1
    px = mid(0, px, 15 * 8)
  end

  if (py >= 62 * 8) then
    py = 62 * 8
    pvy = 0
    coll = true
  else
    coll = false
  end
end

-- Dump to the terminal
printTable({ pay, pvy }, true)

function _draw()
  cls(0)
  camera(0, (64 - 16) * 8)
  map(0, 0, 0, 0, 128, 64)
  spr(16, px, py, 1, 2)
  print("pico-8 starter project", 10, 10, 7)
  print("by jess telford", 10, 20, 7)
  debugger.draw()
  sdbg()
end
