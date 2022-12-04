menuitem(1, "debug", function() debugger.expand(true) end)

-- disable button repeat
poke(0x5f5c, 255)

function _init()
  init_dbg()
end

gravity = 0.2
jerky = 3.5

inputax = 0.1

airdragx = 0.1
platformdragx = 0.4
grounddragx = 0.3
grounddragy = 0

pax = 0
pay = 0

pvx = 0
pvy = 0
maxvx = 5
maxvy = 10

px = 10
py = 63 * 8

sprh = 16
sprw = 8

coll = false

function _update60()
  if (debugger.expand()) then return end

  if (btn(0)) then
    pax = -inputax
  else if (btn(1)) then
    pax = inputax
  else
    if (coll) then
      dragx = platformdragx
    else
      dragx = airdragx
    end
    -- Horizontal velocity always degrades in the opposite direction of motion
    pax = -sgn(pvx) * min(dragx, abs(pvx))
  end end

  -- TODO: Add a jerk (change in acceleration) while jump is held.
  -- The jerk needs to decay while jump is held.
  -- There's a constant gravity acting on the acceleration.
  -- Therefore: The increase in acceleration initially cannot be overcome, but
  -- as the jerk decays, the acceleration reaches zero, so the velocity slows
  -- down, resulting in the the player falling back in the direction of
  -- gravity.
  if (btn(2) and coll) then
    pay = -max(jerky, abs(pvx) * 1.5)
  else
    -- Vertical velocity always degrades in the downward direction
    pay = gravity
  end

  pvx = mid(-maxvx, pvx + pax, maxvx)
  pvy = mid(-maxvy, pvy + pay, maxvy)

  px += pvx
  py += pvy

  coll = false

  -- Use map data to check for collision with platforms
  mapy = flr(py / 8)
  for mapx = flr(px / 8), flr((px + sprw) / 8) do
    mapspr = mget(mapx, mapy)
    isplatform = fget(mapspr, 0)

    if (isplatform and pvy > 0) then
      coll = true
      py = py - (py % 8) + 1
      pvy = 0
    end
  end

  -- Collision with walls
  if (px < 2 or px > 126 - sprw) then
    -- Hitting the wall adds a bit more drag
    pvx -= sgn(pvx) * min(airdragx, abs(pvx))
    pvx = pvx * -1
    px = mid(0, px, 15 * 8)
  end
end

-- Dump to the terminal
--printTable({ pay, pvy }, true)

function _draw()
  cls(0)
  camera(0, (64 - 16) * 8)
  map(0, 0, 0, 0, 128, 64)
  spr(16, px, py - sprh, 1, 2)
  debugger.draw()
  sdbg()
end
