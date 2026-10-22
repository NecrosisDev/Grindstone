-- Combat wear, rust and oil. The game never wears gear in a fight; this adds a
-- little wear to the striking weapon, to the armour piece that takes a blow and
-- (for the player) to a blocking shield. Blood left on steel rusts it. A piece
-- worked at a station wears faster until it is oiled with an Oil Flask.
local config = require("options")
local common = require("common")
local say = common.say
local M = {}

local OIL_MODEL = "Jar05"   -- the Oil Flask's model; assets.py builds the item
local SAVE_LIMIT = 4000     -- save_data holds 4096 bytes per addon
local CORRODE_POLL_SECONDS = 60
local CORRODE_SEARCH_LIMIT = 32
local SHIELD_BROKEN = 255
local SHIELD_WARNINGS = {
    {128, "Your shield is battered."},
    {192, "Your shield is cracking."},
    {230, "Your shield won't take much more."},
}
local DROP_OFFSET_CM = 40
local DROP_DELAY_SECONDS = 0.5

-- Settings can change in game (Mod Settings), so derived values are rebuilt.
local edge_per_hit, blunt_per_hit, armour_per_blow, edge_on_armour, unoiled_factor
local blood_dirt, shield_per_block, quality_effect, corrode_dirt, corrode_per_hour
local function refresh()
    local clamp = common.clamp
    edge_per_hit = clamp(config.edge_wear_per_hit, 0.6, 0, 16)
    blunt_per_hit = clamp(config.blunt_wear_per_hit, 0.3, 0, 16)
    armour_per_blow = clamp(config.armour_wear_per_blow, 0.8, 0, 16)
    edge_on_armour = clamp(config.edge_on_armour_factor, 2, 1, 10)
    unoiled_factor = clamp(config.unoiled_factor, 3, 1, 10)
    blood_dirt = math.floor(clamp(config.blood_dirt_per_hit, 1, 0, 16))
    shield_per_block = clamp(config.shield_wear_per_block, 0.8, 0, 16)
    quality_effect = clamp(config.quality_wear_effect, 0.5, 0, 1.9)
    corrode_dirt = clamp(config.corrode_dirt, 96, 1, 256)
    corrode_per_hour = clamp(config.corrode_wear_per_hour, 1, 0, 16)
end
refresh()
config.on_change(refresh)

-- Kept in the save as "id,id,...|shield=wear,...": pieces worked but not yet
-- oiled, and the player's shield wear. Shields have no condition of their own and
-- are not instanced (every shield of a type shares one record ID), so shield wear
-- is per type the player owns. Fractional wear owed lives only in memory.
local unoiled, order, owed, shields = {}, {}, {}, {}

local function save()
    if not (save_data and save_data.set) then return end
    local parts = {}
    for id, value in pairs(shields) do parts[#parts + 1] = id .. "=" .. value end
    local shield_text = table.concat(parts, ",")
    local ids = {}
    for _, id in ipairs(order) do if unoiled[id] then ids[#ids + 1] = tostring(id) end end
    while #ids > 0 and #table.concat(ids, ",") + #shield_text > SAVE_LIMIT do
        unoiled[tonumber(table.remove(ids, 1))] = nil   -- the oldest work drops off first
    end
    order = {}
    for _, id in ipairs(ids) do order[#order + 1] = tonumber(id) end
    local text = table.concat(ids, ",") .. "|" .. shield_text
    save_data.set(text ~= "|" and text or nil)
end

local function load()
    unoiled, order, owed, shields = {}, {}, {}, {}
    local text = save_data and save_data.get and save_data.get() or ""
    local ids, rest = string.match(text, "^([^|]*)|?(.*)$")
    for id in string.gmatch(ids or "", "%d+") do
        id = math.tointeger(tonumber(id))
        if id and not unoiled[id] then unoiled[id] = true order[#order + 1] = id end
    end
    for id, value in string.gmatch(rest or "", "(%d+)=(%d+)") do
        shields[math.tointeger(tonumber(id))] = math.min(SHIELD_BROKEN, math.tointeger(tonumber(value)) or 0)
    end
end

-- Unknown IDs count as oiled: an item that changed ID (it left a level) is never
-- punished by mistake.
function M.repaired(id)
    if not unoiled[id] then unoiled[id] = true order[#order + 1] = id end
    save()
end

-- Better-made pieces hold up longer: quality 255 wears at (1 - effect/2) of the
-- base rate, quality 0 at (1 + effect/2).
local function quality_factor(id)
    local stats = items.stats(id)
    local quality = stats and stats.condition and stats.condition.quality
    if not quality then return 1 end
    return 1 + quality_effect * (0.5 - quality / 255)
end

local function owe(id, amount)
    amount = amount * quality_factor(id)
    if unoiled[id] then amount = amount * unoiled_factor end
    owed[id] = (owed[id] or 0) + amount
    local whole = math.floor(owed[id])
    owed[id] = owed[id] - whole
    return whole
end

local function add(id, wear, dirt)
    if (wear > 0 or dirt > 0) and common.instanced(id) and items.add_wear and api.has_capability("items.wear") then
        items.add_wear(id, {wear = wear, dirt = dirt})
    end
end

-- At full wear the player's shield splits: taken off, then dropped at their feet
-- (two staged steps). Picked up again, it splits on the next block.
local function break_shield(id)
    timers.after(0, function()
        local pack = inventory and inventory.snapshot and inventory.snapshot()
        if not pack then return end
        for _, name in ipairs({"weapons", "alternate_weapons"}) do
            for _, row in ipairs(pack[name] or {}) do
                if row.item_id == id and row.unequip then row:unequip() break end
            end
        end
        timers.after(DROP_DELAY_SECONDS, function()
            local again = inventory.snapshot()
            if not again then return end
            for _, row in ipairs(again.carried or {}) do
                if row.item_id == id and row.drop then
                    local p = again.position
                    row:drop({p[1] + DROP_OFFSET_CM, p[2], p[3]})
                    return
                end
            end
        end)
    end)
end

local function block(id)
    local before = shields[id] or 0
    if before >= SHIELD_BROKEN then break_shield(id) return end
    local after = math.min(SHIELD_BROKEN, before + owe(id, shield_per_block))
    if after == before then return end
    shields[id] = after
    save()
    if after >= SHIELD_BROKEN then
        say("Your shield splits apart.")
        break_shield(id)
        return
    end
    for _, warning in ipairs(SHIELD_WARNINGS) do
        if before < warning[1] and after >= warning[1] then say(warning[2]) end
    end
end

function M.shield_wear(id) return shields[id] or 0 end

function M.mend_shield(id, goal)
    if (shields[id] or 0) <= goal then return false end
    shields[id] = goal > 0 and goal or nil
    save()
    return true
end

local function weapon_hit(hit, struck_armour)
    local stats = items.stats(hit.weapon_id)
    if not (stats and stats.weapon) then return end
    local edge = common.sharp(stats.weapon)
    local amount = edge and edge_per_hit or blunt_per_hit
    if edge and (struck_armour or hit.blocked or hit.parried) then amount = amount * edge_on_armour end
    local bloody = (hit.health_damage or 0) > 0 and not struck_armour
    add(hit.weapon_id, owe(hit.weapon_id, amount), bloody and blood_dirt or 0)
end

local function parry(id)
    local stats = items.stats(id)
    if not (stats and stats.weapon) then return end
    local amount = common.sharp(stats.weapon) and edge_per_hit * edge_on_armour or blunt_per_hit
    add(id, owe(id, amount), 0)
end

-- character.hit. armour_id, blocked/shield_id and parried/parry_weapon_id are
-- read when the runtime reports them and ignored while they are nil.
local function on_hit(hit)
    if config.combat_wear == false or hit.source ~= "weapon" then return end
    local struck_armour = (hit.armour_id or 0) ~= 0
    if (hit.weapon_id or 0) ~= 0 then weapon_hit(hit, struck_armour) end
    if struck_armour then add(hit.armour_id, owe(hit.armour_id, armour_per_blow), 0) end
    if hit.blocked and hit.is_player and (hit.shield_id or 0) ~= 0 then block(hit.shield_id) end
    if hit.parried and (hit.parry_weapon_id or 0) ~= 0 then parry(hit.parry_weapon_id) end
end

-- Oil Flask used on a piece in the pack: worked-but-unoiled steel is oiled and the
-- flask used up; anything else is left alone and the flask kept.
local function on_oil(event)
    if event.storage_open or event.target.kind ~= "inventory" then return false end
    local id = event.target.item_id
    if id == event.item.id then return true end
    if not event.target.gear or not unoiled[id] then
        say("Oil is for freshly worked steel; this doesn't need it.")
        return true
    end
    unoiled[id] = nil
    save()
    say("You oil the fresh work. It will hold up now.")
    if common.can(event, "consume", "inventory.transfer") then event:consume() end
    return true
end

-- Every in-game hour, the player's metal with dirt at or above corrode_dirt gains
-- wear. A brush (dirt down to 32) stops it.
local last_clock
local function corrode()
    if config.combat_wear == false or corrode_per_hour <= 0 or corrode_dirt > 255 then return end
    local now = world and world.time and world.time()
    if not now then return end
    if not last_clock or now < last_clock then last_clock = now return end
    local hours = (now - last_clock) / 3600
    if hours < 1 then return end
    last_clock = now
    local pack = inventory and inventory.snapshot and inventory.snapshot()
    if not pack then return end
    local lists = {"weapons", "alternate_weapons", "worn", "carried"}
    for _, id in ipairs(common.pack_ids(pack, lists, CORRODE_SEARCH_LIMIT)) do
        local stats = items.stats(id)
        local cond = stats and stats.condition
        local steel = stats and (stats.weapon or (stats.armour and common.metal(stats.armour)))
        if cond and steel and cond.dirt >= corrode_dirt then add(id, owe(id, corrode_per_hour * hours), 0) end
    end
end

-- Oil Flasks beside the forges, added by the runtime as the game reads each level
-- (fresh levels only). assets.py writes placements.lua with the built item ID.
local function place_oil()
    if not (levels and levels.add_placement and api.has_capability("levels.serve")) then return end
    local placements = require("placements")
    for _, spot in ipairs(placements.oil) do
        levels.add_placement(spot.level, placements.oil_item_id, {spot.x, spot.y, spot.z})
    end
end

-- A level-local copy gets a new world ID when it leaves its level; carry its
-- unoiled mark and owed wear over. Shield wear is keyed by template IDs, which
-- never change.
local function on_id_changed(event)
    local old, new = event.old_id, event.new_id
    if owed[old] then owed[new], owed[old] = owed[old], nil end
    if not unoiled[old] then return end
    unoiled[old] = nil
    unoiled[new] = true
    for i, id in ipairs(order) do
        if id == old then order[i] = new end
    end
    save()
end

function M.install()
    place_oil()
    if api.has_capability("items.read") then events.on("item.id_changed", on_id_changed) end
    if api.has_capability("events.combat") then events.on("character.hit", on_hit) end
    if api.has_capability("events.item_use") then events.on("item.use", OIL_MODEL, on_oil) end
    local poll
    events.on("runtime.phase", function(event)
        if poll then timers.cancel(poll) poll = nil end
        last_clock = nil
        if event.phase == "session" then
            timers.after(0, load)
            poll = timers.every(CORRODE_POLL_SECONDS, corrode)
        end
    end)
    if not (items.add_wear and api.has_capability("items.wear")) then
        common.warn_once("Combat wear is idle: this runtime cannot add wear yet")
    end
end

return M
