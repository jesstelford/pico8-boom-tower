menuitem(1, "debug", function() debugger.expand(true) end)

-- There are 5 coordinate systems, denoted by variable prefixes:
-- w_*: World. Scaled so 1 world coordinate maps onto 1 screen pixel.
-- wc_*: World cell. World coordinates divided into 8x8 "cells".
-- c_*: Camera. PICO8's built-in camera.
-- mc_*: Map cell. PICO8's built-in map.
-- s_*: Screen pixels. PICO8's built-in display.

-- Map notes:
-- We're using the map as a convenient storage space to store the locations of
-- levels and walls and their associated sprites.
-- We use 41 y-cells (0-40):
--  40-9 (16 + 16 = 2 screens)
--   8-3 (6 = 2 levels for over-jump)
--   2-0 (3 = 1 level for scroll buffer)
-- By 48 x-cells (0-47):
--   0-15 (background)
--  16-31 (levels)
--  32-47 (walls/foreground)
--
-- Why 2 screens? So we can incrementally add new cells as old cells scroll off
-- the camera view, then simply render the map at (w_camy / 8) % 41, instead of
-- having to do huge copy operations each time a cell moves off the screen to
-- shift the map down.

-- disable button repeat
poke(0x5f5c, 255)

w_gravity = -0.2
w_jerky = 3.5

w_inputax = 0.1

w_airdragx = 0.1
w_platformdragx = 0.4
-- TODO
w_grounddragx = 0.3

w_pax = 0
w_pay = 0

w_pvx = 0
w_pvy = 0
w_maxvx = 5
w_maxvy = 10

w_px = 10
w_py = 17

w_ph = 16
w_pw = 8
wc_pw = w_pw / 8

w_camy = 0 -- Bottom of the map
w_camh = 128

w_scrollthreshold = w_camh * 0.75
w_scrollsize = w_camh - w_scrollthreshold

w_scrollspeed = 0
w_scrollpushforce = 3
w_maxscrollspeed = 40

coll = false
gameover = false

highestlevel = 0

-- NOTE: World coordinates are x-positive right, and y-positive up
-- So we have to convert back to Screen coordinates when rendering
mc_height = 41
c_maph = 8 * mc_height

wc_screenwidth = 16

wc_wallwidth = 1

wc_towerwidth = wc_screenwidth - (2 * wc_wallwidth)

-- Must be 2 or more
wc_minlevelwidth = 4
wc_maxlevelwidth = ceil(wc_towerwidth / 2)

-- rndup(0,3) == 0
-- rndup(1,3) == 3
-- rndup(2,3) == 3
-- rndup(3,3) == 3
-- rndup(4,3) == 6
-- from: https://stackoverflow.com/questions/3407012/rounding-up-to-the-nearest-multiple-of-a-number#comment76735655_4073700
function rndup(num, factor)
  local a = num + factor - 1;
  return a - a % factor;
end

function generate_levels(wc_y1, wc_y2)
  -- Levels are every 3rd cell, so skip forward to the next cell that is a
  -- multiple of 3
  local wc_nextlevely = rndup(wc_y1, 3)

  if (wc_nextlevely > wc_y2) then
    -- Nothing to do
    return
  end

  for wc_y=wc_nextlevely, wc_y2, 3 do
    local level = wc_y / 3

    if (level % 100 == 0) then
       -- change the type of level
    end

    local wc_levelwidth
    local wc_levelx

    -- Every 50th level is full width
    if (level % 50 == 0) then
      wc_levelwidth = wc_screenwidth
      wc_levelx = 0
    else
      -- otherwise it's a random width & position
      wc_levelwidth = wc_minlevelwidth + flr(rnd(wc_maxlevelwidth - wc_minlevelwidth  + 1))
      wc_levelx = wc_wallwidth + flr(rnd(wc_towerwidth - wc_levelwidth + 1))
    end

    -- convert from world coords to map coords
    local mc_y = mc_height - (wc_y % mc_height) - 1

    -- draw the ends
    mset(wc_levelx, mc_y, 1)
    mset(wc_levelx + wc_levelwidth - 1, mc_y, 3)

    -- draw the rest of the level
    for mc_x = wc_levelx + 1, wc_levelx + wc_levelwidth - 2 do
      mset(mc_x, mc_y, 2)
    end
  end
end

function _init()
  init_dbg()
  -- Generate the first 2 screens worth of levels
  generate_levels(0, 32)
end

function _update60()
  if (debugger.expand()) then return end

  if (not gameover) then
    if (btn(0)) then
      w_pax = -w_inputax
    else if (btn(1)) then
      w_pax = w_inputax
    else
      local w_dragx
      if (coll) then
        w_dragx = w_platformdragx
      else
        w_dragx = w_airdragx
      end
      -- Horizontal velocity always degrades in the opposite direction of motion
      w_pax = -sgn(w_pvx) * min(w_dragx, abs(w_pvx))
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
    w_pay = max(w_jerky, abs(w_pvx) * 1.5)
  else
    -- Vertical velocity always degrades in the downward direction
    w_pay = w_gravity
  end

  w_pvx = mid(-w_maxvx, w_pvx + w_pax, w_maxvx)
  w_pvy = mid(-w_maxvy, w_pvy + w_pay, w_maxvy)

  w_px += w_pvx
  w_py += w_pvy

  if (not gameover) then
    local w_rely = w_py - w_camy

    -- Fallen through bottom of the screen
    if (w_rely < 0) then
      gameover = true
      coll = false
    end

    -- How fast the screen needs to scroll up
    local w_scrollforcey = mid(
      w_scrollspeed,
      -- The closer to the top of the screen, the faster the screen has to
      -- scroll up
      ((w_rely - w_scrollthreshold) / w_scrollsize) * w_scrollpushforce,
      -- But only to a maximum
      w_maxscrollspeed
    )

    w_camy += w_scrollforcey

    -- Once past a certain point, the screen starts scrolling automatically
    if (w_scrollspeed == 0 and w_camy > w_scrollsize) then
      w_scrollspeed = 0.2
    end

    coll = false

    -- Use map data to check for collision with platforms
    -- Only when player is moving downward
    if (w_pvy < 0) then
      local wc_y = flr(w_py / 8)
      local wc_x1 = flr(w_px / 8)
      local wc_x2 = wc_x1 + wc_pw
      local mc_y = mc_height - 1 - (wc_y % mc_height)
      for mc_x = wc_x1, wc_x2 do
        mapspr = mget(mc_x, mc_y)
        isplatform = fget(mapspr, 0)

        if (isplatform) then
          -- This is a hacky calculation. Can the levels themsleves hold this
          -- information?
          coll =true
          -- Move back to the top of the platform
          w_py += (8 - (w_py % 8)) - 1
          w_pvy = 0
          -- Floors are rendered every 3rd map tile, hence the division by 3
          highestlevel = flr(w_py / 8) / 3
        end
      end
    end

    -- Collision with walls
    if (w_px < 2 or w_px > 126 - w_pw) then
      -- Hitting the wall adds a bit more drag
      w_pvx -= sgn(w_pvx) * min(w_airdragx, abs(w_pvx))
      w_pvx = w_pvx * -1
      w_px = mid(0, w_px, 15 * 8)
    end
  end
end

-- Dump to the terminal
--printTable({ w_pay, w_pvy }, true)

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
  camera(0, c_maph - w_camy - w_camh)
  text("icy 8", 64, 115, 14, 2, 0, 'center')
  map(0, 0, 0, 0, 128, mc_height)
  spr(16, w_px, c_maph - w_py - w_ph, 1, 2)
  camera(0, 0)
  if (gameover) then
    score = highestlevel * 10
    s_colwidth = max(textwidth("level "), textwidth(" "..tostr(score)))
    s_leftcol = 64 - s_colwidth
    s_rightcol = 64 + s_colwidth

    s_texty = 50

    rectfill(0, s_texty + 1, 128, s_texty + 25, 13)
    rectfill(0, s_texty + 2, 128, s_texty + 24, 1)

    text("game over", 64, s_texty, 8, 2, 0, 'center')

    text("level", s_leftcol, s_texty + 12, 12, 1, 0, 'left')
    text(tostr(highestlevel), s_rightcol, s_texty + 12, 12, 1, 0, 'right')

    text("score", s_leftcol, s_texty + 21, 10, 4, 0, 'left')
    text(tostr(score), s_rightcol, s_texty + 21, 10, 4, 0, 'right')
  end
  --debugger.draw()
  --sdbg()
end
