-- Repair stations. Double-click a piece in the pack, then click a sharpening wheel
-- (sharp weapons: wear and dirt), an anvil (blunt weapons, metal armour, shields:
-- wear) or a cold forge with a torch, the way keys and Repair Spheres are used.
-- The game's Whetstone becomes a field tool for edges. Each click is one pass
-- toward a floor; nothing ever raises wear or dirt.
local config = require("options")
local common = require("common")
local wear = require("wear")
local say, percent, sharp, blunt, metal = common.say, common.percent, common.sharp, common.blunt, common.metal

-- Placed scenery models in the story levels (Objlib).
local WHEELS = {"sharpeningwheel", "sharpenwheel a01"}
local ANVILS = {"anvil", "anvil02", "anvilball", "anvillong", "anvil mtod a01", "anvil log a01",
    "anvil log a02", "anvil log b01", "anvil log c01", "anvil log d01", "anvil log d02", "anvil log d03"}
-- Anvils in levels 1 and 3 stand 2-3 m from one of these.
local FORGES = {}
for _, name in ipairs({"uw1_furnace a", "uw1_furnace b", "furnace", "furnace mtob a1", "furnace mtob a2",
    "furnace uaa a1", "forgearch ub5 ", "ubma forgenichea", "hm_furnace_top", "hm_furnace_uwb01"}) do
    FORGES[name] = true
end
local TORCH_MODEL = "TorchA02"
local WHETSTONE_MODEL = "WhetStone01"
local HAMMER_SEARCH_LIMIT = 24
local MIN_REACH, MAX_REACH = 50, 400

-- Settings can change in game (Mod Settings), so derived values are rebuilt.
local reach, wear_floor, dirt_floor, anvil_wear_floor, pass_wear, pass_dirt, ruined_wear
local whet_floor, whet_pass
local station = {}

local function refresh()
    reach = common.clamp(config.reach_cm, 200, MIN_REACH, MAX_REACH)
    wear_floor = common.byte(config.wear_floor, 64)
    dirt_floor = common.byte(config.dirt_floor, 32)
    anvil_wear_floor = common.byte(config.anvil_wear_floor, wear_floor)
    pass_wear = common.byte(config.pass_wear, 48)
    pass_dirt = common.byte(config.pass_dirt, 64)
    -- At or past this wear a weapon or armour piece is ruined: only a Repair
    -- Sphere can bring it back. 256 turns this off.
    ruined_wear = math.max(1, math.min(256, math.tointeger(config.ruined_wear) or 192))
    whet_floor = common.byte(config.whetstone_wear_floor, 128)
    whet_pass = common.byte(config.whetstone_pass_wear, 24)
    for name in pairs(station) do station[name] = nil end
    for _, name in ipairs(WHEELS) do station[name] = "wheel" end
    if config.anvil_enabled ~= false then
        for _, name in ipairs(ANVILS) do station[name] = "anvil" end
    end
end
refresh()
config.on_change(refresh)

-- One pass: at most pass_wear / pass_dirt off, never below the floor. Poorly made
-- steel won't take as fine an edge: the wear floor rises by a quarter of what the
-- quality lacks (quality 128 stops about 32 above it). A field left nil is not
-- touched; the runtime refuses any request that would raise a value.
local function pass(cond, floor_wear, floor_dirt)
    local goal = {}
    if floor_wear then
        if config.quality_matters ~= false then
            floor_wear = math.min(255, floor_wear + (255 - (cond.quality or 255)) // 4)
        end
        local value = math.max(floor_wear, cond.wear - pass_wear)
        if cond.wear > value then goal.wear = value end
    end
    if floor_dirt then
        local value = math.max(floor_dirt, cond.dirt - pass_dirt)
        if cond.dirt > value then goal.dirt = value end
    end
    if goal.wear or goal.dirt then return goal end
end

-- The pass a station would do, or nil and the reason it has nothing to do.
local function plan(kind, stats, cond, at)
    if at == "wheel" then
        if kind ~= "weapon" then return nil, "The grindstone is for blades, not armour." end
        if not sharp(stats.weapon) then return nil, "There is no edge here to grind. Try an anvil." end
        return pass(cond, wear_floor, dirt_floor), "This blade is as keen as this wheel can make it."
    end
    if kind == "weapon" then
        if sharp(stats.weapon) then return nil, "Edges are ground, not hammered. Try a grindstone." end
        if not blunt(stats.weapon) then return nil, "There is nothing here an anvil can mend." end
        return pass(cond, anvil_wear_floor), "This head is as true as hammering can make it."
    end
    if config.anvil_armour == false or not (stats.armour and metal(stats.armour)) then
        return nil, "Cloth and leather can't be mended on an anvil."
    end
    return pass(cond, anvil_wear_floor), "This piece is as sound as hammering can make it."
end

-- Any blunt weapon carried or held, other than the piece being worked, serves as
-- the hammer. When the pack can't be read, nothing is blocked.
local function has_hammer(except_id)
    if config.anvil_needs_hammer == false or not (inventory and inventory.snapshot) then return true end
    local pack = inventory.snapshot()
    if not pack then return true end
    for _, id in ipairs(common.pack_ids(pack, {"weapons", "alternate_weapons", "carried"}, HAMMER_SEARCH_LIMIT)) do
        if id ~= except_id then
            local stats = items.stats(id)
            if stats and stats.weapon and blunt(stats.weapon) then return true end
        end
    end
    return false
end

-- Heat is only asked for where a forge stands by the anvils and can be lit:
-- levels 1 and 3 have a furnace 2-3 m from them; levels 7 and 67 have none in
-- reach, so their anvils work cold.
local FORGE_LEVELS = {exanima01 = true, exanima03 = true}

local function heat_required(event, place)
    if config.anvil_needs_heat == false or place.heat ~= false then return false end
    if not common.can(event, "ignite_target", "world.devices") then return false end   -- nothing could light it
    local level = world and world.level and world.level()
    return level ~= nil and FORGE_LEVELS[level.name] == true
end

-- Why the anvil can't be worked right now, or nil.
local function anvil_blocked(event, item_id, place)
    if not has_hammer(item_id) then return "You need a hammer or mace in your pack to work the anvil." end
    if heat_required(event, place) then return "The forge is cold. Light it with a torch first." end
end

-- Moves the world clock on after a pass (0 minutes by default: nothing in the
-- game is known to follow the clock). set_time only answers in timer callbacks.
local function spend(minutes)
    minutes = tonumber(minutes) or 0
    if minutes <= 0 or not (world and world.time and world.set_time) then return end
    timers.after(0, function()
        local now = world.time()
        if now then world.set_time(now + math.floor(minutes * 60)) end
    end)
end

local function light_forge(event, place)
    if place.heat then say("The forge is already burning.") return true end
    if not common.can(event, "ignite_target", "world.devices") then
        say("The forge won't catch.")
        common.warn_once("This runtime cannot light forges yet")
        return true
    end
    say(event:ignite_target() and "You light the forge." or "The forge won't catch.")
    return true
end

-- Shields have no condition of their own; the wear module keeps theirs.
local function mend_shield(event, item, place, at)
    if at ~= "anvil" then say("The grindstone is for blades, not shields.") return true end
    local now = wear.shield_wear(item.id)
    local goal = math.max(anvil_wear_floor, now - pass_wear)
    if now <= goal then say("This shield is as sound as hammering can make it.") return true end
    local blocked = anvil_blocked(event, item.id, place)
    if blocked then say(blocked) return true end
    if wear.mend_shield(item.id, goal) then
        common.play(common.REPAIR_SOUND)
        say(string.format("Mending the shield: %d%% worn to %d%%.", percent(now), percent(goal)))
        spend(config.anvil_minutes_per_pass)
    end
    return true
end

local function work(event, item, place, at)
    local cond = item.condition
    if not cond or not item.carried or not common.instanced(item.id) then return false end
    if cond.wear >= ruined_wear then
        say(string.format("Too far gone (%d%% worn). Only a Repair Sphere can save it.", percent(cond.wear)))
        return true
    end
    local stats = items.stats(item.id)
    if not stats then return false end
    local goal, reason = plan(item.kind, stats, cond, at)
    if not goal then say(reason) return true end
    local blocked = at == "anvil" and anvil_blocked(event, item.id, place)
    if blocked then say(blocked) return true end
    if not common.can(event, "restore_condition", "items.condition") then
        common.warn_once("This runtime cannot change item condition yet")
        return true
    end
    if event:restore_condition(goal) then
        common.play(goal.wear and common.REPAIR_SOUND or common.CLEAN_SOUND)
        local verb = at == "wheel" and "Sharpening" or (item.kind == "weapon" and "Hammering out" or "Mending")
        say(string.format("%s: %d%% worn to %d%%. Oil it to make it last.", verb, percent(cond.wear),
            percent(goal.wear or cond.wear)))
        wear.repaired(item.id)
        spend(at == "anvil" and config.anvil_minutes_per_pass or config.wheel_minutes_per_pass)
    end
    return true
end

-- gear.use: true takes the click; false passes it to the next addon (the runtime
-- never hands a gear click to the game).
local function on_use(event)
    if not config.enabled then return false end
    local item, place = event.item, event.target
    local name = place and place.name or ""
    local near = place and (place.distance or math.huge) <= reach
    if FORGES[name] and item.model == TORCH_MODEL then
        if not near then return false end
        return light_forge(event, place)
    end
    local at = station[name]
    if not at then return false end
    if not near then say("You need to stand at it.") return true end
    if item.kind == "shield" then return mend_shield(event, item, place, at) end
    return work(event, item, place, at)
end

-- Whetstone used on a sharp weapon in the pack: a small pass, never finer than
-- whet_floor. Wheels still do the real work.
local function on_whetstone(event)
    if config.whetstone == false or event.storage_open or event.target.kind ~= "inventory" then return false end
    local target = event.target
    local id = target.item_id
    if id == event.item.id then return true end
    -- restore_condition only takes a carried, generated weapon or apparel piece.
    if target.gear ~= "weapon" or not target.carried or not common.instanced(id) then
        say("A whetstone is for edges.")
        return true
    end
    local stats = items.stats(id)
    local cond = target.condition or (stats and stats.condition)
    if not (cond and stats and stats.weapon and sharp(stats.weapon)) then say("A whetstone is for edges.") return true end
    if cond.wear >= ruined_wear then say("Too far gone for a whetstone. Only a Repair Sphere can save it.") return true end
    local goal = math.max(whet_floor, cond.wear - whet_pass)
    if cond.wear <= goal then say("A whetstone can't do more. Find a grindstone.") return true end
    if not common.can(event, "restore_condition", "items.condition") then
        common.warn_once("This runtime cannot change item condition from a whetstone yet")
        return true
    end
    if event:restore_condition{wear = goal} then
        common.play(common.REPAIR_SOUND)
        say(string.format("You hone the edge: %d%% worn to %d%%.", percent(cond.wear), percent(goal)))
        wear.repaired(id)
        spend(config.whetstone_minutes_per_pass)
    end
    return true
end

if api.has_capability("events.item_use") then
    events.on("item.use", WHETSTONE_MODEL, on_whetstone)
end
wear.install()
if api.has_capability("events.gear_use") then
    events.on("gear.use", on_use)
else
    events.on("runtime.phase", function(event)
        if event.phase == "session" and config.enabled then
            common.warn_once("Grindstone is idle: this runtime cannot use weapons or armour on objects yet")
        end
    end)
end
