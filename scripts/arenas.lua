----------------------------------------------------------------
--  BOSS ARENAS
----------------------------------------------------------------
--
--  Oblige Level Maker (C) 2009 Andrew Apted
--
--  This program is free software; you can redistribute it and/or
--  modify it under the terms of the GNU General Public License
--  as published by the Free Software Foundation; either version 2
--  of the License, or (at your option) any later version.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
----------------------------------------------------------------

require 'defs'
require 'util'


function Arena_add_players(x, y, z, angle)
  local dist = 40

  gui.add_entity(tostring(GAME.things["player1"].id),
                 x, y, z, { angle=angle })

  if GAME.things["player2"] then
    gui.add_entity(tostring(GAME.things["player2"].id),
                   x - dist, y, z, { angle=angle })

    gui.add_entity(tostring(GAME.things["player3"].id),
                   x + dist, y, z, { angle=angle })

    gui.add_entity(tostring(GAME.things["player4"].id),
                   x, y - dist, z, { angle=angle })
  end
end


function Arena_Doom_MAP30()

  local face_x = 1024 + 128
  local face_y = 4096

  local room_y  = face_y - 1600
  local room_x1 = face_x - 768
  local room_x2 = face_x + 768

  local function make_face()

    local FACE_TEX =
    {
      { "ZZZFACE9", "ZZZFACE5", "ZZZFACE7" },
      { "ZZZFACE8", "ZZZFACE4", "ZZZFACE6" },
      { "ZZZFACE1", "ZZZFACE3", "ZZZFACE2" },
      { "ZZZFACE9", "ZZZFACE9", "ZZZFACE9" },
    }

    for fx = 1,3 do for fy = 1,4 do

      local x1 = face_x - 384 + (fx-1) * 256
      local x2 = x1 + 256

      local y1 = face_y - sel(fy==4, 12, (3-fy)*4)
      local y2 = y1 + 32

      local z1 = sel(fy <= 3, -EXTREME_H, 3*128)
      local z2 = fy * 128

      local info =
      {
        t_face = { texture="CEIL5_1" },
        b_face = { texture="CEIL5_1", light=0.75 },
        w_face = { texture=FACE_TEX[fy][fx] },  --!! x_offset=0, y_offset=0, peg=true }
      }

      if (fx == 2 and fy == 3) then
        transformed_brush(nil, info, rect_coords(x1,y1, face_x-32,y2), z1,z2)
        
        -- info.w_face.x_offset=(face_x+32-x1)
        transformed_brush(nil, info, rect_coords(face_x+32,y1, x2,y2), z1,z2)

        -- info.w_face.x_offset=(face_x-32-x1)
        -- info.w_face.y_offset=32
        transformed_brush(nil, info, rect_coords(face_x-32,y1, face_x+32,y2), 256+32,z2)
      else
        transformed_brush(nil, info, rect_coords(x1,y1, x2,y2), z1, z2)
      end
    end end -- for fx, fy
  end

  local function make_hole()
    local x1 = face_x - 30
    local x2 = face_x + 30

    local y1 = face_y + 2
    local y2 = y1 + 128

    local z1 = 256 + 1
    local z2 = 256 + 31

    local info =
    {
      t_face = { texture="BLOOD1" },
      b_face = { texture="BLOOD1", light=0.99 },
      w_face = { texture="BFALL1", x_offset=0, y_offset=0, peg=true },
    }

    transformed_brush(nil, info, rect_coords(x1-32,y1, x1,y2), z1-32, z2+32)
    transformed_brush(nil, info, rect_coords(x2,y1, x2+32,y2), z1-32, z2+32)

    transformed_brush(nil, info, rect_coords(x1,y1, x2,y2), z1-32, z1)
    transformed_brush(nil, info, rect_coords(x1,y1, x2,y2), z2, z2+32)

    gui.add_entity(tostring(GAME.things["brain_shooter"].id),
                   face_x, y1+24, z1, { angle=270 })

    z1 = z1 - 96

    y1 = y2
    y2 = y1 + 128

    transformed_brush(nil, info, rect_coords(x1-32,y1, x1,y2), z1-32, z2+32)
    transformed_brush(nil, info, rect_coords(x2,y1, x2+32,y2), z1-32, z2+32)

    transformed_brush(nil, info, rect_coords(x1,y2, x2,y2+32), z1-32, z2+32)

    transformed_brush(nil, info, rect_coords(x1,y1, x2,y2), z1-32, z1)
    transformed_brush(nil, info, rect_coords(x1,y1, x2,y2), z2, z2+32)

    gui.add_entity(tostring(GAME.things["brain_boss"].id),
                   face_x, y2-48, z1, { angle=270 })

  end

  local function make_room()
    local x1 = room_x1
    local x2 = room_x2

    local y1 = room_y
    local y2 = face_y

    local z1 = 0
    local z2 = 512-32

    local info =
    {
      t_face = { texture="RROCK08" },
      b_face = { texture="RROCK08" },
      w_face = { texture="SP_HOT1" },
    }

    transformed_brush(nil, info, rect_coords(x1-32,y1, x1,y2),
                      -EXTREME_H, EXTREME_H)

    transformed_brush(nil, info, rect_coords(x2,y1, x2+32,y2),
                      -EXTREME_H, EXTREME_H)

    transformed_brush(nil, info, rect_coords(x1,y1-32, x2,y1),
                      -EXTREME_H, EXTREME_H)

    transformed_brush(nil, info, rect_coords(x1,y2-24, face_x-384,y2+32),
                      -EXTREME_H, EXTREME_H)

    transformed_brush(nil, info, rect_coords(face_x+384,y2-24, x2,y2+32),
                      -EXTREME_H, EXTREME_H)

    transformed_brush(nil, info, rect_coords(x1,y1, x2,y2), -EXTREME_H, z1)
    transformed_brush(nil, info, rect_coords(x1,y1, x2,y2), z2, EXTREME_H)

    transformed_brush(nil, info, rect_coords(x1,y1, x2,y1+600), -EXTREME_H, 128)

    for i=-1,1 do
      local hx = face_x + i * 256
      local hy = face_y - 96
      local item = sel(i == 0, "blue_armor", "mega")

      gui.add_entity(tostring(GAME.things[item].id), hx, hy, 0)
    end
  end

  local function make_cybers()
    for i = 1,4 do
      local x1 = sel((i % 2) == 1, room_x1, room_x2-352)
      local x2 = sel((i % 2) == 1, room_x1+352, room_x2)

      local y1 = sel(i <= 2, face_y-200, room_y)
      local y2 = sel(i <= 2, face_y, room_y+200)
      local y3 = sel(i <= 2, y1 - 64, y2 + 64)

      local z = sel(i <= 2, 0, 128)

      local mx = sel((i % 2) == 1, x1+96, x2-96)
      local my = (y1 + y2) / 2

      local angle = sel((i % 2) == 1, 180, 0)

      local info =
      {
        t_face = { texture="FLOOR4_8" },
        b_face = { texture="FLOOR4_8" },
        w_face = { texture="METAL1" },
      }

      local step =
      {
        t_face = { texture="FLOOR5_2" },
        b_face = { texture="FLOOR5_2" },
        w_face = { texture="BROWN1", y_offset=0, peg=true },
      }
      
      transformed_brush(nil, info, rect_coords(x1,y1, x2,y2), -EXTREME_H, z + 32)

      transformed_brush(nil, step, rect_coords(x1,y3-32, x2,y3+32), -EXTREME_H, z + 16)

      gui.add_entity(tostring(GAME.things["Cyberdemon"].id),
                     mx, my, z, { angle=angle })

      gui.add_entity(tostring(GAME.things["launch"].id),
                     mx, my, z, { angle=angle })

      for side = 2,8,2 do
        local rx, ry = nudge_coord(mx, my, side, 40)
        gui.add_entity(tostring(GAME.things["rockets"].id),
                       rx, ry, z, { angle=angle })
      end
    end
  end

  local function make_platform()
  end


  ---| Arena_Doom_MAP30 |---

  make_face()
  make_hole()
  make_room()
  make_cybers()

  Arena_add_players(face_x, face_y - 512, 0, 90)
end

