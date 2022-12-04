menuitem(1, "debug", function() debugger.expand(true) end)

-- disable button repeat
poke(0x5f5c, 255)

gravity = 0.2
jerky = 3.5

inputax = 0.1

airdragx = 0.1
platformdragx = 0.4
grounddragx = 0.3

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

camystart = 512
camy = camystart -- Bottom of the map
camh = 128

scrollthreshold = camh * 0.75
scrollsize = camh - scrollthreshold

scrollspeed = 0
scrollpushforce = 3
maxscrollspeed = 40

coll = false
gameover = false

function _init()
  init_dbg()
end

function _update60()
  if (debugger.expand()) then return end

  if (not gameover) then
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
  end

  -- TODO: Add a jerk (change in acceleration) while jump is held.
  -- The jerk needs to decay while jump is held.
  -- There's a constant gravity acting on the acceleration.
  -- Therefore: The increase in acceleration initially cannot be overcome, but
  -- as the jerk decays, the acceleration reaches zero, so the velocity slows
  -- down, resulting in the the player falling back in the direction of
  -- gravity.
  if (not gameover and btn(2) and coll) then
    pay = -max(jerky, abs(pvx) * 1.5)
  else
    -- Vertical velocity always degrades in the downward direction
    pay = gravity
  end

  pvx = mid(-maxvx, pvx + pax, maxvx)
  pvy = mid(-maxvy, pvy + pay, maxvy)

  px += pvx
  py += pvy

  if (not gameover) then
    rely = camy - py

    -- Fallen through bottom of the screen
    if (rely < 0) then
      gameover = true
      coll = false
    end

    scrollforce = mid(
      scrollspeed,
      ((rely - scrollthreshold) / scrollsize) * scrollpushforce,
      maxscrollspeed
    )

    camy -= scrollforce

    if (scrollspeed == 0 and camy < camystart - scrollsize) then
      scrollspeed = 0.2
    end

    coll = false

    -- Use map data to check for collision with platforms
    if (pvy > 0) then
      mapy = flr(py / 8)
      for mapx = flr(px / 8), flr((px + sprw) / 8) do
        mapspr = mget(mapx, mapy)
        isplatform = fget(mapspr, 0)

        if (isplatform) then
          coll = true
          py = py - (py % 8) + 1
          pvy = 0
        end
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
end

-- Dump to the terminal
--printTable({ pay, pvy }, true)

function text(str, x, y, col, shadow, align)
  width = print(str, 1000, 0) - 1000
  if (align == 'right') then
    x -= width
  else if (align == 'center') then
    x -= flr(width / 2)
  end end

  for yout = y - 1, y + 2 do
    for xout = x - 1, x + 1 do
      print(str, xout, yout, 0)
    end
  end
  print(str, x, y + 1, shadow)
  print(str, x, y, col)
end

function _draw()
  cls(0)
  camera(0, camy - camh)
  map(0, 0, 0, 0, 128, 64)
  spr(16, px, py - sprh, 1, 2)
  camera(0, 0)
  if (gameover) then
    text("game over", 64, 60, 7, 13, 'center')
  end
  --debugger.draw()
  --sdbg()
end
