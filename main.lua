-- vim: set filetype=pico8:
menuitem(1, "debug", function() debugger.expand(true) end)

-- There are 5 coordinate systems, denoted by variable prefixes:
-- w_*: World. Scaled so 1 world coordinate maps onto 1 screen pixel.
-- wc_*: World cell. World coordinates divided into 8x8 "cells".
-- c_*: Camera. PICO8's built-in camera.
-- mc_*: Map cell. PICO8's built-in map.
-- s_*: Screen pixels. PICO8's built-in display.
--
-- there's also time variables:
-- t_*: an absolute time since the game started in seconds
-- dt_*: a relative time in seconds

-- disable button repeat
poke(0x5f5c, 255)

local w_gravity = -0.2
local w_jerky = 3.5

local w_inputax = 0.1

local w_airdragx = 0.1
local w_platformdragx = 0.4
-- TODO
local w_grounddragx = 0.3

local w_pay = 0

local w_pvx = 0
local w_pvy = 0
local w_maxvx = 2
local w_maxvy = 10

local w_px = 10
local w_py = 17

local w_ph = 8
local w_pw = 8
local wc_pw = w_pw / 8
local wc_ph = w_ph / 8

local w_camy = 0 -- Bottom of the map
local w_camh = 128

local wc_lastcamy = 0

local w_scrollthreshold = w_camh * 0.75
local w_scrollsize = w_camh - w_scrollthreshold

local w_scrollspeed = 0
local w_scrollpushforce = 3
local w_maxscrollspeed = 40

local coll = false
local gameover = false

local highestlevel = 0

-- Map notes:
--
-- We're using the map as a convenient storage space to store the locations of
-- levels and walls and their associated sprites.
-- At all times we're maintaining 1 screens worth of levels + a buffer for high
-- jumps and fast scroll speeds.
--
--                    ┌───────────────┐0
--       ▲            │               │
--       │            ├───────────────┤
--       │            │               │
--       │            │               │             ▲
--       │            │               │             │
--       │            │               │             │
--       │            │               │     ┌───────┴───────┐
--       │            │               │     │               │
--    scratch         │               │     ├───────────────┤
--     height         ├───────────────┤     │               │
-- (2x generated  ▲   │    buffer     │     │               │
--     height)    │   ├───────────────┤     │    render     │
--       │        │   │           ▲   │     │    window     │
--       │  generated │           │   │     │               │
--       │    height  │  rendered │   │     │               │
--       │        │   │  (screen) │   │     │               │
--       │        │   │   height  │   │     └───────────────┘
--       │        │   │           │   │
--       │        │   │           │   │
--       ┴        ┴   └───────────┴───┘41
--
-- We use 50 y-cells (0-49):
--   0- 2 (3 = 1 level for scroll buffer)
--   3- 8 (6 = 2 levels for over-jump)
--   9-24 (16 = 1 screen)
--  25-27 (3 = 1 level for scroll buffer)
--  28-33 (6 = 2 levels for over-jump)
--  34-49 (16 = 1 screen)
--
-- By 48 x-cells (0-47):
--   0-15 (background)
--  16-31 (levels)
--  32-47 (walls/foreground)
--
-- Why 2 screens? So we can incrementally add new cells as old cells scroll off
-- the camera view, then simply render the map at (w_camy / 8) % 41, instead of
-- having to do huge copy operations each time a cell moves off the screen to
-- shift the map down.
local mc_screenwidth = 16
local mc_screenheight = 16

-- 6 for over-jump + 3 for scroll / safety
local mc_windowbuffer = 9
local mc_windowheight = mc_screenheight + mc_windowbuffer
local mc_scratchheight = 2 * mc_windowheight

local c_scratchheight = 8 * mc_scratchheight

local wc_wallwidth = 1

local wc_towerwidth = mc_screenwidth - (2 * wc_wallwidth)

-- Must be 2 or more
local wc_minlevelwidth = 4
local wc_maxlevelwidth = ceil(wc_towerwidth / 2)

local easevx = nil

local last={
 t_t=t(),
 dir=0
}

-- rndup(0,3) == 0
-- rndup(1,3) == 3
-- rndup(2,3) == 3
-- rndup(3,3) == 3
-- rndup(4,3) == 6
-- from: https://stackoverflow.com/questions/3407012/rounding-up-to-the-nearest-multiple-of-a-number#comment76735655_4073700
local function rndup(num, factor)
  local a = num + factor - 1;
  return a - a % factor;
end

local function world_cell_to_map_celly(wc_y)
  return mc_scratchheight - 1 - (wc_y % mc_windowheight)
end

local function generate_levels(wc_y1, wc_y2)
  -- zero-out the data
  -- TODO: Use memcpy or something faster
  for wc_y=wc_y1, wc_y2 do
    -- convert from world coords to map coords
    local mc_y = world_cell_to_map_celly(wc_y)

    -- The first screens-worth of levels render in the bottom half of the
    -- scratch area. But every screens-worth there-after needs to render in the
    -- top half of the scratch area, so we adjust it here.
    if (wc_y >= mc_windowheight) then
      mc_y -= mc_windowheight
    end

    for mc_x=0,mc_screenwidth do
      mset(mc_x, mc_y, 0)
    end
  end

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
      wc_levelwidth = mc_screenwidth
      wc_levelx = 0
    else
      -- otherwise it's a random width & position
      wc_levelwidth = wc_minlevelwidth + flr(rnd(wc_maxlevelwidth - wc_minlevelwidth  + 1))
      wc_levelx = wc_wallwidth + flr(rnd(wc_towerwidth - wc_levelwidth + 1))
    end

    -- convert from world coords to map coords
    local mc_y = world_cell_to_map_celly(wc_y)

    -- The first screens-worth of levels render in the bottom half of the
    -- scratch area. But every screens-worth there-after needs to render in the
    -- top half of the scratch area, so we adjust it here.
    if (wc_y >= mc_windowheight) then
      mc_y -= mc_windowheight
    end

    -- draw the ends
    mset(wc_levelx, mc_y, 1)
    mset(wc_levelx + wc_levelwidth - 1, mc_y, 3)

    -- draw the rest of the level
    for mc_x = wc_levelx + 1, wc_levelx + wc_levelwidth - 2 do
      mset(mc_x, mc_y, 2)
    end
  end
end

-- v0 = current value
-- v1 = target value
-- t = interpolation % (0-1)
local function lerp(v0,v1,t)
 return v0*(1-t)+v1*t
end

local function easelinear(x)
 return x
end

local function easeincubic(x)
 return x^3
end

local function easeoutcubic(x)
 return 1 - (1-x)^3
end

local function sgn2(v)
 return v < 0 and -1 or v > 0 and 1 or 0
end

local msperframe=1000/60

local function framestosec(f)
 return msperframe*(f/1000)
end

local function easer(
 -- see easings.net for fns
 easefn,
 -- the current value to ease
 v,
 -- desired starting value
 v0,
 -- target value
 v1,
 -- secs to go from v0 to v1
 dur
)
 -- work backwards from the
 -- target, using the actual
 -- current value of vx (not
 -- the "start" value).
 local tfrac=(v-v0)/(v1-v0)
 local step=1/dur

 -- when starting overshot
 if (tfrac < 0) then
 -- scale the step when t is
 -- negative (turning around)
  step*=(1-tfrac)
  -- start at the overshot
  v0=v
  tfrac=0
 end
 
 return function(dt)
  tfrac=min(1,tfrac+dt*step)
  easedt=easefn(tfrac)
  return lerp(v0,v1,easedt)
 end
end

function _init()
  init_dbg()
  -- Generate the first 2 screens worth of levels
  generate_levels(0, 32)
end

function _update60()
  if (debugger.expand()) then return end

  local dt_t=t()-last.t_t

  local dir = 0

  -- Vertical velocity always degrades in the downward direction
  w_pay = w_gravity

  if (not gameover) then
    dir = btn(⬅️) and -1 or btn(➡️) and 1 or 0

    -- TODO: Add a jerk (change in acceleration) while jump is held.
    -- The jerk needs to decay while jump is held.
    -- There's a constant gravity acting on the acceleration.
    -- Therefore: The increase in acceleration initially cannot be overcome, but
    -- as the jerk decays, the acceleration reaches zero, so the velocity slows
    -- down, resulting in the the player falling back in the direction of
    -- gravity.
    if (btnp(❎) and coll) then
      w_pay = max(w_jerky, abs(w_pvx) * 1.5)
    end
  end

  if (dir==0) then
    if (dir~=last.dir) then
      -- start decelerating
      easevx = easer(
        easelinear,
        w_pvx,
        w_maxvx*last.dir,
        0,
        framestosec(4)
      )
    end
  else
    if (dir~=last.dir) then
      -- start accelerating, or
      -- changed direction ⬅️/➡️
      easevx = easer(
        easelinear,
        w_pvx,
        0,
        w_maxvx*dir,
        framestosec(4)
      )
    end
  end

  if (easevx) then
    w_pvx=easevx(dt_t)
  end

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
      local mc_y = world_cell_to_map_celly(wc_y)

      for mc_x = wc_x1, wc_x2 do
        local mapspr = mget(mc_x, mc_y)
        local isplatform = fget(mapspr, 0)

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
    -- todo: project forward to see if we'd collide with the wall at the given
    -- velocity / acceleration, then check if that's within some threshold. if
    -- so, set t_wall_impact_at to the projected time, and also flag which way
    -- the wall is facing; we'll use that info later to figure out how the boom
    -- jump will work
    if (w_px < 2 or w_px > 126 - w_pw) then
      w_px = mid(2, w_px, 126 - w_pw)
    end

    -- Checking to see if rendering has moved into the top half of our generated
    -- levels within the map
    local wc_camy = flr(w_camy / 8)
    local wc_cellsmoved = wc_camy - wc_lastcamy

    -- The camera has moved up at least one cell
    if (wc_cellsmoved > 0) then
      -- First, generate new levels
      local wc_newlevely1 = wc_lastcamy + mc_windowheight
      local wc_newlevely2 = wc_camy + mc_windowheight - 1
      generate_levels(wc_newlevely1, wc_newlevely2)

      -- Next, copy any levels that we've moved past into the correct spots

      for wc_y=wc_newlevely1, wc_newlevely2 do
        -- convert from world coords to map coords
        local mc_toy = world_cell_to_map_celly(wc_y)
        local mc_fromy = mc_toy - mc_windowheight

        -- todo: use memcpy
        for mc_x=0,mc_screenwidth do
         mset(mc_x, mc_toy, mget(mc_x, mc_fromy))
        end
      end

      wc_lastcamy = wc_camy
    end
  end

  last.t_t=t()
  last.dir=dir
end

-- Dump to the terminal
--printTable({ w_pay, w_pvy }, true)

local function textwidth(str)
  return print(str, 200, 0) - 200
end

local function text(str, x, y, col, shadow, outline, align)
  local width = textwidth(str)
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
  text("boom tower", 64, 128 - 115 + w_camy, 14, 2, 0, 'center')
  camera(0, c_scratchheight - (w_camy % (mc_windowheight * 8)) - w_camh)
  map(0, 0, 0, 0, mc_screenwidth, mc_scratchheight)

  camera(0, 0)

  -- there's only ever 6 levels on a screen at a time, so we know that there can
  -- only be on numbered level at a time (they're every 10th level)
  local firstvisiblelevel = ceil(w_camy / (8 * 3)) - 1
  local lastvisiblelevel = flr((w_camy + w_camh - 1) / (8 * 3))
  local numberedlevel = firstvisiblelevel + 10 - firstvisiblelevel % 10
  if (firstvisiblelevel > 0 and numberedlevel >= firstvisiblelevel and numberedlevel <= lastvisiblelevel) then
    local mc_numberedypos = world_cell_to_map_celly(numberedlevel * 3)
    local c_numberedx1 = 0
    local c_numberedx2 = 127
    -- todo: wont work when there's not a numbered level generated in the map yet
    for mc_x=0,15 do
      if mget(mc_x, mc_numberedypos) ~= 0 then
        c_numberedx1 = mc_x * 8
        for mc_x=mc_x,15 do

          if mget(mc_x, mc_numberedypos) == 0 then
            c_numberedx2 = (mc_x + 1) * 8 - 1
            break
          end
        end
        break
      end
    end

    text(
      numberedlevel,
      c_numberedx1 + flr((c_numberedx2 - c_numberedx1) / 2),
      128 - 2 - (numberedlevel * 8 * 3) + w_camy,
      14,
      2,
      0,
      'center'
    )
  end

  -- the player sprite
  spr(16, w_px, 128 - w_py - w_ph + w_camy, wc_pw, wc_ph)

  if (gameover) then
    local score = highestlevel * 10
    local s_colwidth = max(textwidth("level "), textwidth(" "..tostr(score)))
    local s_leftcol = 64 - s_colwidth
    local s_rightcol = 64 + s_colwidth

    local s_texty = 50

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
