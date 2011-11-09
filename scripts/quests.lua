----------------------------------------------------------------
--  QUEST ASSIGNMENT
----------------------------------------------------------------
--
--  Oblige Level Maker
--
--  Copyright (C) 2006-2011 Andrew Apted
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

--[[ *** CLASS INFORMATION ***

class QUEST
{
  -- a quest is a group of rooms with a particular goal, usually
  -- a key or switch which allows progression to the next quest.
  -- The final quest always leads to a room with an exit switch.

  id : number

  start : ROOM   -- room which player enters this quest.
                 -- for first quest, this is the map's starting room.
                 -- Never nil.
                 --
                 -- start.entry_conn is the entry connection

  target : ROOM  -- room containing the goal of this quest (key or switch).
                 -- the room object will contain more information.
                 -- Never nil.

  rooms : list(ROOM / HALL)  -- all the rooms in the quest

  storage_rooms : list(ROOM)

  zone : ZONE

  parent : QUEST  -- the quest which this one branched off (if any)

  parent_room : ROOM / HALL  -- the room or hall branched off

  volume : number  -- size of quest (sum of tvols)
}


class ZONE
{
  -- a zone is a group of quests    FIXME: MORE INFO

  id : number

  rooms : list(ROOM)

  volume : number  -- total of all rooms

---##  parent : ZONE
}


class LOCK
{
  kind : keyword  -- "KEY" or "SWITCH"

  key    : string   -- name of key (game specific)
  switch : string   -- name of switch (to match door with)

  tag : number    -- tag number to use for a switched door
                  -- (also an identifying number)

  target : ROOM   -- the room containing the key or switch
  conn   : CONN   -- the connection which is locked
}


--------------------------------------------------------------]]

require 'defs'
require 'util'


QUEST_CLASS = {}

function QUEST_CLASS.new(start)
  local id = 1 + #LEVEL.quests
  local Q = { id=id, start=start, rooms={}, storage_rooms={} }
  table.set_class(Q, QUEST_CLASS)
  table.insert(LEVEL.quests, Q)
  return Q
end


function QUEST_CLASS.tostr(quest)
  return string.format("QUEST_%d", quest.id)
end


function QUEST_CLASS.calc_volume(quest)
  quest.volume = 0

  each L in quest.rooms do
    quest.volume = quest.volume + L.base_tvol
  end
end


function QUEST_CLASS.add_room_or_hall(quest, L)
  L.quest = quest

  table.insert(quest.rooms, L)
end


function QUEST_CLASS.add_storage_room(quest, R)
  -- a "storage room" is a dead-end room which does not contain a
  -- specific purpose (key, switch or exit).  We place some of the
  -- ammo and health needed by the player elsewhere into these rooms
  -- to encourage exploration.
  R.is_storage = true

  table.insert(quest.storage_rooms, R)
end


function QUEST_CLASS.remove_storage_room(quest, R)
  R.is_storage = nil

  table.kill_elem(quest.storage_rooms, R)
end


----------------------------------------------------------------


ZONE_CLASS = {}

function ZONE_CLASS.new()
  local id = 1 + #LEVEL.zones
  local Z = { id=id, rooms={} }
  table.set_class(Z, ZONE_CLASS)
  table.insert(LEVEL.zones, Z)
  return Z
end


function ZONE_CLASS.tostr(Z)
  return string.format("ZONE_%d", Z.id)
end


function ZONE_CLASS.remove(Z)
  assert(Z.id)

  table.kill_elem(LEVEL.zones, Z)

  Z.id = nil
  Z.rooms = nil
end


function ZONE_CLASS.add_room(Z, R)
  R.zone = Z

  table.insert(Z.rooms, R)
end


function ZONE_CLASS.calc_volume(Z)
  Z.volume = 0

  each L in Z.rooms do
    Z.volume = Z.volume + L.base_tvol
  end
end


function ZONE_CLASS.merge(Z1, Z2)
  --- assert(Z2.parent == Z1)

  -- transfer the rooms and halls
  each L in Z2.rooms do
    Z1:add_room(L)
  end

  Z1:calc_volume()

---##  -- fix any parent fields which refer to Z2
---##  each Z in LEVEL.zones do
---##    if Z.parent == Z2 then
---##       Z.parent = Z1
---##    end
---##  end

  ZONE_CLASS.remove(Z2)
end


----------------------------------------------------------------

function Quest_find_path_to_room(src, dest)  -- NOT USED ATM
  local seen_rooms = {}

  local function recurse(R)
    if R == dest then
      return {}
    end

    if seen_rooms[R] then
      return nil
    end

    seen_rooms[R] = true

    for _,C in ipairs(R.conns) do
      local p = recurse(C:neighbor(R))
      if p then
        table.insert(p, 1, C)
        return p
      end
    end

    return nil -- no way
  end

  local path = recurse(src)

  if not path then
    gui.debugf("No path %s --> %s\n", src:tostr(), dest:tostr())
    error("Failed to find path between two rooms!")
  end

  return path
end



function Quest_distribute_unused_keys()
  local next_L = GAME.levels[LEVEL.index + 1]

  if not next_L then return end
  if next_L.episode != LEVEL.episode then return end

  each name,prob in LEVEL.usable_keys do
    next_L.usable_keys[name] = prob
    LEVEL .usable_keys[name] = nil
  end
end



function Quest_add_weapons()
 
  local function prob_for_weapon(name, info, R)
    local prob  = info.add_prob
    local level = info.level or 1

    -- ignore weapons which lack a pick-up item
    if not prob or prob <= 0 then return 0 end

    if R.purpose == "START" then
      if info.start_prob then
        prob = info.start_prob
      else
        prob = prob / level
      end
    end

    -- make powerful weapons only appear in later levels
    if level > LEVEL.max_level then return 0 end

    -- theme adjustment
    if LEVEL.weap_prefs then
      prob = prob * (LEVEL.weap_prefs[name] or 1)
    end

    if THEME.weap_prefs then
      prob = prob * (THEME.weap_prefs[name] or 1)
    end

    return prob
  end


  local function decide_weapon(R)
    -- determine probabilities 
    local name_tab = {}

    each name,info in GAME.WEAPONS do
      -- ignore weapons already given
      if LEVEL.added_weapons[name] then continue end

      local prob = prob_for_weapon(name, info, R)

      if prob > 0 then
        name_tab[name] = prob
      end
    end

    gui.debugf("decide_weapon list:\n%s\n", table.tostr(name_tab))

    -- nothing is possible? ok
    if table.empty(name_tab) then return nil end

    local weapon = rand.key_by_probs(name_tab)

    return weapon
  end


  local function should_swap(early, later)
    assert(early and later)

    local info1 = assert(GAME.WEAPONS[early])
    local info2 = assert(GAME.WEAPONS[later])

    -- only swap when the ammo is the same
    if info1.ammo != info2.ammo then return false end

    -- determine firepower
    local fp1 = info1.rate * info1.damage
    local fp2 = info2.rate * info2.damage

    return (fp1 > fp2)
  end


  local function reorder_weapons(list)
    for pass = 1,2 do
      for i = 1, (#list - 1) do
        for k = (i + 1), #list do
          if should_swap(list[i].weapon, list[k].weapon) then
            local A = list[i].weapon
            local B = list[k].weapon

            list[i].weapon = B
            list[k].weapon = A
          end
        end
      end
    end
  end


  local function add_weapon(R, name)
    if not R.weapons then R.weapons = { } end

    table.insert(R.weapons, name)
  end


  local function hexen_add_weapons()
    local idx = 2

    if #LEVEL.rooms <= 2 or rand.odds(30) then idx = 1 end

    if LEVEL.hub_weapon then
      local R = LEVEL.rooms[idx]
      add_weapon(R, LEVEL.hub_weapon)
    end

    idx = idx + 1

    if LEVEL.hub_piece then
      local R = LEVEL.rooms[idx]
      add_weapon(R, LEVEL.hub_piece)
    end
  end


  ---| Quest_add_weapons |---

  -- special handling for HEXEN and HEXEN II
  if PARAM.hexen_weapons then
    hexen_add_weapons()
    return
  end

  LEVEL.added_weapons = {}

  local list = {}
  local next_weap_at = 0  -- start room guaranteed to have one

  each R in LEVEL.rooms do
    -- putting weapons in the exit room is a tad silly
    if R.purpose == "EXIT" then continue end

    for loop = 1,3 do
      if R.weap_along < next_weap_at then break end

      -- allow a second weapon only if room is large
      if loop == 2 and R.svolume < 15 then break end
      if loop == 3 and R.svolume < 60 then break end

      weapon = decide_weapon(R)

      if not weapon then break end

      table.insert(list, { weapon=weapon, room=R })

      -- mark it as used
      LEVEL.added_weapons[weapon] = true

      -- melee weapons are not worth as much as other ones
      local worth = 1
      local info = GAME.WEAPONS[weapon]

      if info.attack == "melee" then worth = 0.5 end

      next_weap_at = next_weap_at + worth
    end
  end

  gui.printf("Weapon list:\n")

  if table.empty(list) then
    gui.printf("  NONE!\n")
  end

  -- make sure weapon order is reasonable, e.g. the shotgun should
  -- appear before the super shotgun, plasma rifle before BFG, etc...
  reorder_weapons(list)

  each loc in list do
    gui.printf("  %s: %s\n", loc.room:tostr(), loc.weapon)

    add_weapon(loc.room, loc.weapon)
  end

  gui.printf("\n")
end



function Quest_assign_themes()
 
  local function handle_zones()
    local zone_tab
    
    if THEME.zones then
      zone_tab = table.copy(THEME.zones)
    else
      -- FIXME: create some (?)
    end
    
    each Z in LEVEL.zones do
      if zone_tab then
        local name = rand.key_by_probs(zone_tab)

        -- greatly prefer to pick a different one
        zone_tab[name] = zone_tab[name] / 20
      
        Z.theme = GAME.ZONE_THEMES[name]

        if not Z.theme then
          error("No such zone theme: " .. tostring(name))
        end

      else
        Z.theme = { dummy=true }
      end
    end
  end


  local function assign_theme(L)
    -- one hallway theme per zone
    if L.is_hall and L.zone.hallway_theme then
      L.theme = L.zone.hallway_theme
      return
    -- one cave theme per level
    elseif L.cave and LEVEL.cave_theme then
      L.theme = L.cave_theme
      return
    end

    -- figure out which table to use
    local tab
    local tab_name

    if L.is_hall then
      tab_name = "hallways"
    elseif L.cave then
      tab_name = "caves"
    elseif L.outdoor then
      tab_name = "outdoors"
    else
      tab_name = "buildings"
    end

    -- the Zone Theme takes precedence over the Level Theme
    tab = L.zone.theme[tab_name] or THEME[tab_name]

    if not tab and L.is_hall then
      tab = L.zone.theme["buildings"] or THEME["buildings"]
    end

    if not tab then
      error("Theme is missing choices table: " .. tab_name)
    end

    -- now pick one
    -- FIXME: this is too simplistic

    local theme_name = rand.key_by_probs(tab)

    L.theme = GAME.ROOM_THEMES[theme_name]

    if not L.theme then
      error("No such room theme: " .. tostring(name))
    end

    if L.is_hall then
      L.zone.hallway_theme = L.theme
    elseif L.cave then
      LEVEL.cave_theme = L.theme
    end
  end


  ---| Quest_assign_themes |---

  handle_zones()

  each R in LEVEL.rooms do
    assign_theme(R)
  end

  each H in LEVEL.hallways do
    assign_theme(R)
  end
end



function Quest_select_textures()

  local function assign_to_zones(WHAT, orig_source)
    
    -- TODO: number of passes depends on zone size
    --       __OR__ : do a pass for each real room

    local source

    for pass = 1,1 do
      each Z in LEVEL.zones do

        if not Z[WHAT] then
          Z[WHAT] = {}
        end

        if not source or table.empty(source) then
          source = table.copy(orig_source)
        end

        local mat = rand.key_by_probs(source)

        source[mat] = nil  -- don't use again

        local mat_tab = Z[WHAT]

        mat_tab[mat] = 60 - (pass - 1) * 20
      end
    end
  end


  ---| Quest_select_textures |---

  assign_to_zones("building_walls",    THEME.building_walls)
  assign_to_zones("building_facades",  THEME.building_facades or THEME.building_walls)
  assign_to_zones("building_floors",   THEME.building_floors)
  assign_to_zones("building_ceilings", THEME.building_ceilings)

  assign_to_zones("hallway_walls",    THEME.hallway_walls    or THEME.building_walls)
  assign_to_zones("hallway_floors",   THEME.hallway_floors   or THEME.building_floors)
  assign_to_zones("hallway_ceilings", THEME.hallway_ceilings or THEME.building_ceilings)

  assign_to_zones("courtyard_floors", THEME.courtyard_floors or THEME.building_floors)

  -- ETC ETC...


---##  local base_num = 3
---##
---##  -- more variety in large levels
---##  if SECTION_W * SECTION_H >= 30 then
---##    base_num = 4
---##  end
---##
---##  if not LEVEL.building_facades then
---##    LEVEL.building_facades = {}
---##
---##    for num = 1,base_num - rand.sel(75,1,0) do
---##      local name = rand.key_by_probs(THEME.building_facades or THEME.building_walls)
---##      LEVEL.building_facades[num] = name
---##    end
---##  end
---##
---##  if not LEVEL.building_walls then
---##    LEVEL.building_walls = {}
---##
---##    for num = 1,base_num do
---##      local name = rand.key_by_probs(THEME.building_walls)
---##      LEVEL.building_walls[num] = name
---##    end
---##  end
---##
---##  if not LEVEL.building_floors then
---##    LEVEL.building_floors = {}
---##
---##    for num = 1,base_num do
---##      local name = rand.key_by_probs(THEME.building_floors)
---##      LEVEL.building_floors[num] = name
---##    end
---##  end
---##
---##  if not LEVEL.courtyard_floors then
---##    LEVEL.courtyard_floors = {}
---##
---##    if not THEME.courtyard_floors then
---##      LEVEL.courtyard_floors[1] = rand.key_by_probs(THEME.building_floors)
---##    else
---##      for num = 1,base_num do
---##        local name = rand.key_by_probs(THEME.courtyard_floors)
---##        LEVEL.courtyard_floors[num] = name
---##      end
---##    end
---##  end

  if not LEVEL.outer_fence_tex then
    if THEME.outer_fences then
      LEVEL.outer_fence_tex = rand.key_by_probs(THEME.outer_fences)
    end
  end

  if not LEVEL.step_skin then
    if not THEME.steps then
      gui.printf("WARNING: Theme is missing step skins\n") 
      LEVEL.step_skin = {}
    else
      local name = rand.key_by_probs(THEME.steps)
      LEVEL.step_skin = assert(GAME.STEPS[name])
    end
  end

  if not LEVEL.lift_skin then
    if not THEME.lifts then
      -- OK
    else
      local name = rand.key_by_probs(THEME.lifts)
      LEVEL.lift_skin = assert(GAME.LIFTS[name])
    end
  end


  -- TODO: caves and landscapes

  gui.printf("\nSelected textures:\n")

  gui.printf("facades =\n%s\n", table.tostr(LEVEL.building_facades))
  gui.printf("walls =\n%s\n", table.tostr(LEVEL.building_walls))
  gui.printf("floors =\n%s\n", table.tostr(LEVEL.building_floors))
  gui.printf("courtyards =\n%s\n", table.tostr(LEVEL.courtyard_floors))

  gui.printf("\n")
end



function Quest_get_exits(L, no_teleporters)
  local exits = {}

  each D in L.conns do
    if D.L1 == L and D.kind != "double_R" and
       (not no_teleporters or D.kind != "teleporter")
    then
      table.insert(exits, D)
    end
  end

  return exits
end



function calc_travel_volumes(L, zoney)
  -- returns volume for given room + all descendants.
  -- if zoney is true => treat a child room with a zone as locked

  local vol

  -- larger rooms have bigger volume 
  if L.is_hall then
    vol = 0.2
  else
    vol = 1 + L.svolume / 50
  end

  L.base_tvol = vol

  local exits = Quest_get_exits(L)

  each D in exits do
    calc_travel_volumes(D.L2, zoney)

    -- exclude locked exits
    if not (D.lock or (zoney and D.L2.zone)) then
      vol = vol + D.L2.travel_vol
    end

    D.L2.PARENT = L
  end

  L.travel_vol = vol
end



function dump_room_flow(L, indents, is_locked)
  if not indents then
    indents = {}
  else
    indents = table.copy(indents)
  end

  local line = ""

  for i = 1, #indents do
    if i == #indents then
      if is_locked == "tele" then
        line = line .. "|== "
      elseif is_locked then
        line = line .. "|## "
      else
        line = line .. "|-- "
      end
    elseif indents[i] then
      line = line .. "|   "
    else
      line = line .. "    "
    end
  end

  gui.debugf("%s%s (%1.1f)\n", line, L:tostr(), L.travel_vol)

  local exits = Quest_get_exits(L)

  --[[
    while #exits == 1 do
      L = exits[1].L2 ; exits = Quest_get_exits(L)
    end
  --]]

  table.insert(indents, true)

  each D in exits do
    if _index == #exits then
      indents[#indents] = false
    end

    dump_room_flow(D.L2, indents, (D.kind == "teleporter" ? "tele" ; D.lock))
  end
end


function Quest_create_zones()

  local all_rooms_and_halls = {}


  local function collect_rooms_and_halls()
    each R in LEVEL.rooms do
      table.insert(all_rooms_and_halls, R)
    end

    each H in LEVEL.halls do
      table.insert(all_rooms_and_halls, H)
    end
  end


  local function update_zone_volumes()
    each Z in LEVEL.zones do
      Z:calc_volume()
    end
  end


  local function score_for_merge(Z1, Z2)
    -- prefer smallest
    local score = 400 - (Z1.volume + Z2.volume)

    return score + gui.random()  -- tie breaker
  end


  local function merge_a_zone()
    -- merge two zones together

    -- A zone can only merge with its parent or one of its children.

    local best_Z1
    local best_Z2
    local best_score

    each L in all_rooms_and_halls do
      local Z1 = L.zone

      if not L.PARENT then continue end

      local Z2 = L.PARENT.zone

      if Z2 == Z1 then continue end

      local score = score_for_merge(Z1, Z2)

      if not best_score or score > best_score then
        best_Z1 = Z1
        best_Z2 = Z2
        best_score = score
      end
    end

    assert(best_Z1 and best_Z2)
    assert(best_Z1 !=  best_Z2)

    gui.debugf("Merging %s --> %s\n", best_Z2:tostr(), best_Z1:tostr())

    best_Z1:merge(best_Z2)

    best_Z1:calc_volume()
  end


  local function dump_zones()
    gui.printf("Zone list:\n")

    each Z in LEVEL.zones do
      gui.printf("  %d: vol:%3.1f rooms:%d head:%s\n", Z.id,
                 Z.volume or 0, #Z.rooms,
                 (Z.rooms[1] ? Z.rooms[1]:tostr() ; "NIL"))
    end
  end


  local function has_lockable_exit(L, child)

    local count = 0

    each exit in Quest_get_exits(L) do
      local L2 = exit.L2

      if L2.zone then continue end

      if L2 == child and exit.kind == "teleporter" then return false end

      count = count + 1
    end

    return (count >= 2)
  end


  local function find_branch_for_zone(min_tvol)
    local best

    each L in all_rooms_and_halls do
      if L.zone then continue end

      if L.travel_vol < min_tvol then continue end

      if L.PARENT and not has_lockable_exit(L.PARENT, L) then continue end

      if not best or L.travel_vol < best.travel_vol then
        best = L
      end
    end

if not best then gui.debugf("find_branch_for_zone: NONE\n")
else gui.debugf("find_branch_for_zone: %s tvol:%1.1f\n", best:tostr(), best.travel_vol)
end

    return best
  end


  local function create_zone_at_room(L, Z)
    assert(not L.zone)

    if not Z then
      Z = ZONE_CLASS.new()
gui.debugf("Created %s\n", Z:tostr())
    end

    Z:add_room(L)
gui.debugf("Added %s --> %s\n", L:tostr(), Z:tostr())

    each exit in Quest_get_exits(L) do
      local L2 = exit.L2

      if L2.zone then continue end

      create_zone_at_room(L2, Z)
    end

    return Z
  end


  local function assign_zone_to_root(min_tvol)
    if #LEVEL.zones == 0 then
      return create_zone_at_room(LEVEL.start_room)
    end

    local best_Z

    each Z in LEVEL.zones do
      local L1 = Z.rooms[1] ; assert(L1)

      assert(L1.PARENT)

      if L1.PARENT.zone then continue end

      if not best_Z -- or L1.zone.volume < best_Z.volume
      then
        best_Z = Z
      end
    end

    assert(best_Z)

    gui.debugf("assign_zone_to_root: using %s\n", best_Z:tostr())

    create_zone_at_room(LEVEL.start_room, best_Z)

    update_zone_volumes()
  end


  ---| Quest_create_zones |---

  LEVEL.zones = {}

  local base = (MAP_W + MAP_H) / 6
  local zone_quota = base * rand.pick({ 1.3, 1.7, 2.1, 2.5 })

  local keys = LEVEL.usable_keys or THEME.keys or {}
  local num_keys = table.size(keys)

  if zone_quota > 1 + num_keys then
     zone_quota = 1 + num_keys
  end

  -- TODO: this will need tweaking
  -- [IDEA: adjust this instead of having a zone quota]
  local min_tvol = 4.5

  zone_quota = int(zone_quota)

  gui.printf("Zone quota: %d (tvol >= %1.1f)\n\n", zone_quota, min_tvol)


  collect_rooms_and_halls()


  while true do
    local L = find_branch_for_zone(min_tvol)

    -- finished?
    if not L then
      if not LEVEL.start_room.zone then
        assign_zone_to_root()
      end

      break
    end

    create_zone_at_room(L)

    calc_travel_volumes(LEVEL.start_room, "zoney")

    update_zone_volumes()

gui.debugf("AFTER CREATING ZONE:\n")
dump_room_flow(LEVEL.start_room)
  end

  -- verify everything got a zone
  each L in all_rooms_and_halls do
    assert(L.zone)
  end


  -- if too many zones, merge some

  while #LEVEL.zones > zone_quota do
    merge_a_zone()
  end

---##  initial_zones()
---##
---##      dump_zones()
---##
---##  while #LEVEL.zones > 1 do
---##    local vol, Z = min_zone_tvol()
---##
---##    -- stop merging when all zones are large enough
---##    if vol >= min_tvol and #LEVEL.zones <= zone_quota then break end
---##
---##    merge_a_zone(Z)
---##
---##        gui.printf("AFTER MERGE\n")
---##        dump_zones()
---##  end

  dump_zones()

end



function Quest_make_quests()

  -- ALGORITHM NOTES:
  --
  -- A fundamental requirement of a locked door is that the player
  -- needs to reach the door _before_ he/she reaches the key.  Then
  -- the player knows what they are looking for.  Without this, the
  -- player can just stumble on the key before finding the door and
  -- says to themselves "what the hell is this key for ???".
  --
  -- The main idea in this algorithm is that you LOCK all but one exits
  -- in each room, and continue down the free exit.  Each lock is added
  -- to an active list.  When you hit a leaf room, pick a lock from the
  -- active list (removing it) and mark the room as having its key.
  -- Then the algorithm continues on the other side of the locked door
  -- (creating a new quest for those rooms).
  -- 

  local active_locks = {}


local function Quest_choose_keys()

  local function dump_locks()
    gui.printf("Lock list:\n")

    each LOCK in LEVEL.locks do
      gui.printf("  %d = %s %s\n", _index, LOCK.kind, LOCK.key or LOCK.switch or "")
    end

    gui.printf("\n")
  end


  ---| Quest_choose_keys |---

  local num_locks = #LEVEL.locks

  if num_locks <= 0 then
    gui.printf("Lock list: NONE\n\n")
    return
  end


  local key_probs = table.copy(LEVEL.usable_keys or THEME.keys or {}) 
  local num_keys  = table.size(key_probs)

--!!!!!!
--num_keys = math.min(num_keys, #LEVEL.zones - 1)

  assert(THEME.switches)

  local switches = table.copy(THEME.switches)

  gui.printf("Lock count:%d  want_keys:%d (of %d)  switches:%d\n",
              num_locks, #LEVEL.zones - 1, num_keys, table.size(switches));


  --- Step 1: assign keys to places where a new ZONE is entered ---

  local function add_key(LOCK)
    if num_keys < 1 then error("Quests: Run out of keys!") end

    LOCK.kind = "KEY"
    LOCK.key  = rand.key_by_probs(key_probs)

    -- cannot use this key again
    key_probs[LOCK.key] = nil

    if LEVEL.usable_keys then
      LEVEL.usable_keys[LOCK.key] = nil
    end

    num_keys = num_keys - 1
  end

  each LOCK in LEVEL.locks do
    ---### if LOCK.conn.L1.zone != LOCK.conn.L2.zone then
    if LOCK.kind == "KEY" then
      add_key(LOCK)
    end
  end


  -- Step 2. assign keys or switches everywhere else

  -- TODO: use left-over keys

  local function add_switch(LOCK)
    LOCK.kind = "SWITCH"
    LOCK.switch = rand.key_by_probs(switches)

    -- make it less likely to choose the same switch again
    switches[LOCK.switch] = switches[LOCK.switch] / 5
  end

  each LOCK in LEVEL.locks do
    if LOCK.kind == "SWITCH" then
      add_switch(LOCK)
    end
  end

  dump_locks()
end


  local function add_lock(L, D)

    local LOCK =
    {
      conn = D
      tag = Plan_alloc_id("tag")
    }

    if D.L1.zone == D.L2.zone then
      LOCK.kind = "SWITCH"
    else
      LOCK.kind = "KEY"
    end

    D.lock = LOCK

-- gui.debugf("add_lock: LOCK_%d to %s\n", LOCK.tag, D.L2:tostr())

    -- for double hallways, put the lock in both connections
    if D.kind == "double_L" then
      assert(D.peer)
      D.peer.lock = LOCK
    end

    -- keep newest locks at the front of the active list
    table.insert(active_locks, 1, LOCK)

    table.insert(LEVEL.locks, LOCK)
  end


  local function get_matching_locks(req_kind, req_zone)
    -- req_kind is the required kind, or NIL for any
    -- req_zone is the required zone (front side of doo), or NIL for any

    local indexes = {}

    each LOCK in active_locks do
      if req_kind and LOCK.kind != req_kind then continue end

      if req_zone and LOCK.conn.L1.zone != req_zone then continue end

      table.insert(indexes, _index)
    end

    return indexes
  end


  local function pick_lock_to_solve(cur_zone)
    
    -- for switched doors we require that the solution room lies in the
    -- same zone as the room with the locked door.  So the only reason
    -- the player needs to back-track out of a zone is because they
    -- found a key which will provide access into a new zone.

    assert(#active_locks > 0)

    local poss_locks = get_matching_locks("SWITCH", cur_zone)

    if table.empty(poss_locks) then
      poss_locks = get_matching_locks("KEY", nil)
    end

    -- the above SHOULD work -- but this is emergency fallback
    if table.empty(poss_locks) then
      gui.printf("WARNING: could not pick an appropriate lock.\n")
      poss_locks = get_matching_locks(nil, nil)
    end

    -- choosing the newest lock (at index 1) produces the most linear
    -- progression, which is easiest on the player.  Choosing older
    -- locks produces more back-tracking and memory strain, which on
    -- large levels could make it very confusing to navigate.
    --
    -- [Note: the zone system alleviates this problem a lot]

    assert(#poss_locks > 0)

    local p = 1

    while (p + 1) <= #poss_locks and rand.odds(50) do
       p = p + 1
    end

    return table.remove(active_locks, poss_locks[p])
  end


  local function add_solution(R)
    assert(R.is_room)

    if table.empty(active_locks) then
-- gui.debugf("add_solution: EXIT\n")
      R.purpose = "EXIT"
      LEVEL.exit_room = R
      return false
    end

    local lock = pick_lock_to_solve(R.zone)

-- gui.debugf("add_solution: LOCK_%d @ %s\n", lock.tag, R:tostr())

    R.purpose = "SOLUTION"
    R.purpose_lock = lock

    lock.target = R

    return lock
  end


  local function crossover_volume(L)
    local count = 0
    if L.is_room then count = L:num_crossovers() end

    each D in L.conns do
      if D.L1 == L and D.kind != "double_R" then
        count = count + crossover_volume(D.L2)
      end
    end

    return count
  end


  local function evaluate_exit(L, D)
    -- generally want to visit the SMALLEST section first, since that
    -- means the player's hard work to find the switch is rewarded
    -- with a larger new area to explore.  In theory anyway :-)
    local vol = math.clamp(2.5, D.L2.travel_vol, 50)

    local score = 50 - vol

    -- prefer to visit rooms which have crossovers first
    score = score + crossover_volume(D.L2) * 2.3

    -- prefer exit to be away from entrance
    if D.dir1 and L.entry_conn and L.entry_conn.dir2 then
      local x1, y1 = L.entry_conn.K2:approx_side_coord(L.entry_conn.dir2)
      local x2, y2 =            D.K1:approx_side_coord(D.dir1)

      local dist = geom.dist(x1, y1, x2, y2)
      if dist > 4 then dist = 4 end

      -- preference to avoid 180 degree turns
      if D.dir1 != L.entry_conn.dir2 then
        dist = dist + 2
      end

      score = score + dist / 2.0
    end

    -- tie breaker
    return score + gui.random() / 10
  end


  local function pick_free_exit(L, exits)
    if #exits == 1 then
      return exits[1]
    end

    local best
    local best_score = -9e9

    each D in exits do
      assert(D.kind != "teleporter")

      local score = evaluate_exit(L, D)

-- gui.debugf("exit score for %s = %1.1f", D:tostr(), score)

      if score > best_score then
        best = D
        best_score = score
      end
    end

    return assert(best)
  end


  local function storage_flow(L, quest)
    -- used when a branch of the level is dudded
    
    gui.debugf("storage_flow @ %s : %s\n", L:tostr(), quest:tostr())

    L.dudded = true

    quest:add_room_or_hall(L)

    if L.is_room then
      table.insert(LEVEL.rooms, L)
    end

    local exits = Quest_get_exits(L)

    -- hit a leaf?
    if #exits == 0 then
      assert(L.is_room)

      quest:add_storage_room(L)

      return L
    end


    local best_leaf

    each D in exits do
      local leaf = storage_flow(D.L2, quest)

      -- choose largest leaf [only needed in NO-QUEST mode]
      if leaf and (not best_leaf or leaf.svolume > best_leaf.svolume) then
        best_leaf = leaf
      end

      -- normally this should be impossible, since zones are large
      -- (over a minimum size) but we only dud up small branches.
      -- It commonly occurs in NO-QUEST mode though.
      if D.L1.zone != D.L2.zone then
        gui.printf("WARNING: dudded %s\n", D.L2.zone:tostr())
      end
    end

    return best_leaf  -- NIL is ok
  end


  local function quest_flow(L, quest)
-- gui.debugf("quest_flow @ %s : %s\n", L:tostr(), quest:tostr())

    quest:add_room_or_hall(L)

    if L.is_room then
      table.insert(LEVEL.rooms, L)
    end

    local exits = Quest_get_exits(L)

    if #exits > 0 then

      --- branching room ---

      local free_exit

      -- handle exits which MUST be either free or locked
      for index = #exits, 1, -1 do
        local D = exits[index]

        if D.L1.zone != D.L2.zone then
          add_lock(L, D)

          table.remove(exits, index)

        -- teleporters cannot be locked
        -- [they could become storage, but we don't do it]
        elseif D.kind == "teleporter" then
          assert(not free_exit)
          free_exit = D

          table.remove(exits, index)
        end
      end

      -- pick the free exit now
      if not free_exit then
        free_exit = pick_free_exit(L, exits)

        table.kill_elem(exits, free_exit)
      end

      L.exit_conn = free_exit

      -- turn some branches into storage
      each D in exits do
        if D.L2.travel_vol < 1.9 and rand.odds(50) then
          table.kill_elem(exits, D)

          storage_flow(D.L2, quest)
        end
      end

      -- lock up all other branches
      each D in exits do
        add_lock(L, D)
      end

      -- continue down the free exit
      quest_flow(free_exit.L2, quest)

      return "ok"
    end


    --- leaf room ---

-- gui.debugf("hit leaf\n")

    quest.target = L

    local lock = add_solution(L)

    -- finished?
    if not lock then return end

    -- create new quest
    local old_room = lock.conn.L1
    local new_room = lock.conn.L2

    local old_Q = assert(old_room.quest)

    local new_Q = QUEST_CLASS.new(lock.conn.L2)

    new_Q.parent = old_Q
    new_Q.parent_room = old_room

-- gui.debugf("new %s branches off %s\n", new_Q:tostr(), old_Q:tostr())

    -- continue on with new room and quest
    quest_flow(new_Q.start, new_Q)

    return "ok"
  end


  local function no_quest_mode(start, quest)
    -- this is used when there are no quests (except to find the exit)

    local leaf = storage_flow(start, quest)

    assert(leaf)
    assert(leaf != start)

    quest:remove_storage_room(leaf)

    leaf.purpose = "EXIT"

    LEVEL.exit_room = leaf
  end


  local function setup_lev_alongs()
    local w_along = LEVEL.mon_along

    each R in LEVEL.rooms do
      R.lev_along  = _index / #LEVEL.rooms

      local w_step = R.kvolume / SECTION_W
 
      R.weap_along = w_along + w_step / 3
      R.weap_along = R.weap_along * (PARAM.weapon_factor or 1)

--stderrf("WEAPON ALONG : %1.2f\n", R.weap_along)

      w_along = w_along + w_step * rand.range(0.5, 0.8)
    end
  end


  local function dump_visit_order()
    gui.printf("Room Visit Order:\n")

    each R in LEVEL.rooms do
      gui.printf("Room %2d : %1.2f : quest %d : zone %d : purpose %s\n",
                 R.id, R.lev_along, R.quest.id, R.zone.id, R.purpose or "-")
    end

    gui.printf("\n")
  end


  local function create_quests()
    local Q = QUEST_CLASS.new(LEVEL.start_room)

    -- room list will be rebuilt in visit order
    LEVEL.rooms = {}

    if THEME.switches and THEME.keys then
      quest_flow(Q.start, Q)
    else
      no_quest_mode(Q.start, Q)
    end

    setup_lev_alongs()

    assert(LEVEL.exit_room)

    gui.printf("Exit room: %s\n", LEVEL.exit_room:tostr())

    dump_visit_order()
  end


  local function update_crossovers()
    each H in LEVEL.halls do
      if H.crossover then H:set_cross_mode() end
    end
  end


  --==| Quest_make_quests |==--

  gui.printf("\n--==| Make Quests |==--\n\n")

  Monsters_max_level()

  -- need at least a START room and an EXIT room
  if #LEVEL.rooms < 2 then
    error("Level only has one room! (2 or more are needed)")
  end

  LEVEL.quests = {}
  LEVEL.locks  = {}


  calc_travel_volumes(LEVEL.start_room, "zoney")

  gui.debugf("Level Flow:\n\n")
  dump_room_flow(LEVEL.start_room)

  Quest_create_zones()

  calc_travel_volumes(LEVEL.start_room)

  create_quests()

  update_crossovers()


  Quest_assign_themes()

  Quest_select_textures()

  Quest_add_weapons()

  Quest_choose_keys()

  -- left over keys can be used in the next level of a hub
  if LEVEL.usable_keys and LEVEL.hub_links then
    Quest_distribute_unused_keys()
  end
end


----------------------------------------------------------------


function Hub_connect_levels(epi, keys)

  local function connect(src, dest, kind)
    assert(src!= dest)

    local LINK =
    {
      kind = kind
      src  = src
      dest = dest
    }

    table.insert( src.hub_links, LINK)
    table.insert(dest.hub_links, LINK)
    table.insert( epi.hub_links, LINK)
  end


  local function dump()
    gui.debugf("\nHub links:\n")

    each link in epi.hub_links do
      gui.debugf("  %s --> %s\n", link.src.name, link.dest.name)
    end

    gui.debugf("\n")
  end


  ---| Hub_connect_levels |---

  local levels = table.copy(epi.levels)

  assert(#levels >= 4)

  keys = table.copy(keys)

  rand.shuffle(keys)

  -- setup
  epi.hub_links = { }
  epi.used_keys = { }

  each L in levels do
    L.hub_links = { }
  end

  -- create the initial chain, which consists of the start level, end
  -- level and possibly a level or two in between.

  local start_L = table.remove(levels, 1)
  local end_L   = table.remove(levels, #levels)

  assert(end_L.kind == "BOSS")

  local chain = { start_L }

  for loop = 1, rand.sel(75, 2, 1) do
    assert(#levels >= 1)

    table.insert(chain, table.remove(levels, 1))
  end

  table.insert(chain, end_L)

  for i = 1, #chain - 1 do
    connect(chain[i], chain[i+1], "chain")
  end

  -- the remaining levels just branch off the current chain

  each L in levels do
    -- pick existing level to branch from (NEVER the end level)
    local src = chain[rand.irange(1, #chain - 1)]

    -- prefer an level with no branches so far
    if #src.hub_links > 0 then
      src = chain[rand.irange(1, #chain - 1)]
    end

    connect(src, L, "branch")

    -- assign keys to these branch levels

    if L.kind != "SECRET" and not table.empty(keys) then
      L.hub_key = rand.key_by_probs(keys)

      keys[L.hub_key] = nil

      table.insert(epi.used_keys, L.hub_key)

      gui.debugf("Hub: assigning key '%s' --> %s\n", L.hub_key, L.name)
    end
  end

  dump()
end



function Hub_assign_keys(epi, keys)
  -- determines which keys can be used on which levels

  keys = table.copy(keys)

  local function level_for_key()
    for loop = 1,999 do
      local idx = rand.irange(1, #epi.levels)
      local L = epi.levels[idx]

      if L.kind == "SECRET" then continue end

      if L.hub_key and rand.odds(95) then continue end

      local already = #L.usable_keys

      if already == 0 then return L end
      if already == 1 and rand.odds(20) then return L end
      if already >= 2 and rand.odds(4)  then return L end
    end

    error("level_for_key failed.")
  end

  each L in epi.levels do
    L.usable_keys = { }
  end

  -- take away keys already used in the branch levels
  each name in epi.used_keys do
    keys[name] = nil
  end

  while not table.empty(keys) do
    local name = rand.key_by_probs(keys)
    local prob = keys[name]

    keys[name] = nil

    local L = level_for_key()

    L.usable_keys[name] = prob

    gui.debugf("Hub: may use key '%s' --> %s\n", name, L.name)
  end
end



function Hub_assign_weapons(epi)

  -- Hexen and Hexen II only have two pick-up-able weapons per class.
  -- The normal weapon placement logic does not work well for that,
  -- instead we pick which levels to place them on.

  local a = rand.sel(75, 2, 1)
  local b = rand.sel(75, 3, 4)

  epi.levels[a].hub_weapon = "weapon2"
  epi.levels[b].hub_weapon = "weapon3"

  gui.debugf("Hub: assigning 'weapon2' --> %s\n", epi.levels[a].name)
  gui.debugf("Hub: assigning 'weapon3' --> %s\n", epi.levels[b].name)

  local function mark_assumes(start, weapon)
    for i = start, #epi.levels do
      local L = epi.levels[i]
      if not L.assume_weapons then L.assume_weapons = { } end
      L.assume_weapons[weapon] = true
    end
  end

  mark_assumes(a, "weapon2")
  mark_assumes(b, "weapon3")

  mark_assumes(#epi.levels, "weapon4")
end



function Hub_assign_pieces(epi, pieces)

  -- assign weapon pieces (for HEXEN's super weapon) to levels

  assert(#pieces < #epi.levels)

  local levels = { }

  each L in epi.levels do
    if L.kind != "BOSS" and L.kind != "SECRET" then
      table.insert(levels, L)
    end
  end

  assert(#levels >= #pieces)

  rand.shuffle(levels)

  each piece in pieces do
    local L = levels[_index]

    L.hub_piece = piece

    gui.debugf("Hub: assigning piece '%s' --> %s\n", piece, L.name)
  end 
end

