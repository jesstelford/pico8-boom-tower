menuitem(1, "debug", function() debugger.expand(true) end)

-- disable button repeat
poke(0x5f5c, 255)

gravity = -0.2
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
py = 17

ph = 16
pw = 8

camystart = 0
camy = camystart -- Bottom of the map
camh = 128

scrollthreshold = camh * 0.75
scrollsize = camh - scrollthreshold

scrollspeed = 0
scrollpushforce = 3
maxscrollspeed = 40

coll = false
gameover = false

highestlevel = 0

-- NOTE: World coordinates are x-positive right, and y-positive up
-- So we have to convert back to Screen coordinates when rendering
mapcellsy = 64
maph = 8 * 64

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
    pay = max(jerky, abs(pvx) * 1.5)
  else
    -- Vertical velocity always degrades in the downward direction
    pay = gravity
  end

  pvx = mid(-maxvx, pvx + pax, maxvx)
  pvy = mid(-maxvy, pvy + pay, maxvy)

  px += pvx
  py += pvy

  if (not gameover) then
    rely = py - camy

    -- Fallen through bottom of the screen
    if (rely < 0) then
      gameover = true
      coll = false
    end

    -- How fast the screen needs to scroll up
    scrollforce = mid(
      scrollspeed,
      -- The closer to the top of the screen, the faster the screen has to
      -- scroll up
      ((rely - scrollthreshold) / scrollsize) * scrollpushforce,
      -- But only to a maximum
      maxscrollspeed
    )

    camy += scrollforce

    -- Once past a certain point, the screen starts scrolling automatically
    if (scrollspeed == 0 and camy > scrollsize) then
      scrollspeed = 0.2
    end

    coll = false

    -- Use map data to check for collision with platforms
    -- Only when player is moving downward
    if (pvy < 0) then
      mapy = mapcellsy - 1 - flr(py / 8)
      for mapx = flr(px / 8), flr((px + pw) / 8) do
        mapspr = mget(mapx, mapy)
        isplatform = fget(mapspr, 0)

        if (isplatform) then
          -- This is a hacky calculation. Can the levels themsleves hold this
          -- information?
          coll =true
          -- Move back to the top of the platform
          py += (8 - (py % 8)) - 1
          pvy = 0
          -- Floors are rendered every 3rd map tile, hence the division by 3
          highestlevel = flr(py / 8) / 3
        end
      end
    end

    -- Collision with walls
    if (px < 2 or px > 126 - pw) then
      -- Hitting the wall adds a bit more drag
      pvx -= sgn(pvx) * min(airdragx, abs(pvx))
      pvx = pvx * -1
      px = mid(0, px, 15 * 8)
    end
  end
end

-- Dump to the terminal
--printTable({ pay, pvy }, true)

function textwidth(str)
  return print(str, 200, 0) - 200
end

function text(str, x, y, col, shadow, outline, align)
  width = textwidth(str)
  if (align == 'right') then
    x -= width
  else if (align == 'center') then
    x -= flr(width / 2)
  end end

  for yout = y - 1, y + 2 do
    for xout = x - 1, x + 1 do
      print(str, xout, yout, outline)
    end
  end
  print(str, x, y + 1, shadow)
  print(str, x, y, col)
end

function _draw()
  cls(0)
  camera(0, maph - camy - camh)
  text("icy 8", 64, 115, 14, 2, 0, 'center')
  map(0, 0, 0, 0, 128, mapcellsy)
  spr(16, px, maph - py - ph, 1, 2)
  camera(0, 0)
  if (gameover) then
    score = highestlevel * 10
    colwidth = max(textwidth("level "), textwidth(" "..tostr(score)))
    leftcol = 64 - colwidth
    rightcol = 64 + colwidth

    texty = 50

    rectfill(0, texty + 1, 128, texty + 25, 13)
    rectfill(0, texty + 2, 128, texty + 24, 1)

    text("game over", 64, texty, 8, 2, 0, 'center')

    text("level", leftcol, texty + 12, 12, 1, 0, 'left')
    text(tostr(highestlevel), rightcol, texty + 12, 12, 1, 0, 'right')

    text("score", leftcol, texty + 21, 10, 4, 0, 'left')
    text(tostr(score), rightcol, texty + 21, 10, 4, 0, 'right')
  end
  --debugger.draw()
  --sdbg()
end
