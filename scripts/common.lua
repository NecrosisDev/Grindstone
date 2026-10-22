-- Helpers shared by the station (main) and wear modules.
local M = {}

-- Generated copies carry one of these high ID bits; templates have none, and
-- writing a template would change every ungenerated copy of that item.
M.INSTANCED_BITS = 0xF0000000

function M.instanced(id)
    return id ~= nil and id & M.INSTANCED_BITS ~= 0
end

-- A condition byte (0..255) from a setting, or the default when unset.
function M.byte(value, default)
    return math.max(0, math.min(255, math.tointeger(value) or default))
end

function M.clamp(value, default, low, high)
    return math.max(low, math.min(high, tonumber(value) or default))
end

function M.percent(value)
    return math.floor(value * 100 / 255 + 0.5)
end

-- What the player sees: a short line at the bottom of the screen, also logged.
function M.say(text)
    log.info(text)
    if ui and ui.notify then ui.notify(text) end
end

-- The game's own repair-orb and brush sounds (exact Sound.rpk member names, as
-- the package lists them).
M.REPAIR_SOUND = "reprspherea1"
M.CLEAN_SOUND = "cleanitem01"
function M.play(name)
    if ui and ui.sound then ui.sound(name) end
end

-- Event methods exist even when their capability was not granted, and calling
-- one then is a Lua error that disables the addon, so check both.
function M.can(event, method, capability)
    return event[method] ~= nil and api.has_capability(capability)
end

local warned = {}
function M.warn_once(text)
    if not warned[text] then log.warn(text) warned[text] = true end
end

-- Sharp means a cutting edge on either grip of this copy (factory weapons such
-- as axes only get their edge on the copy, so the template would say blunt).
function M.sharp(weapon)
    for _, grip in ipairs({weapon.grip, weapon.alternate_grip}) do
        if grip and (grip.cut or 0) > 0 then return true end
    end
    return false
end

-- Blunt means no edge but a crushing head; torches, mirrors and pans have neither.
function M.blunt(weapon)
    if M.sharp(weapon) then return false end
    for _, grip in ipairs({weapon.grip, weapon.alternate_grip}) do
        if grip and (grip.crush or 0) > 0 then return true end
    end
    return false
end

-- Armour layers 3 mail, 4 plate and 5 special plate are metal; 1 padded and
-- 2 cloth/leather are not.
local METAL_LAYERS = {[3] = true, [4] = true, [5] = true}
function M.metal(armour)
    return METAL_LAYERS[armour.layer or 0] == true
end

-- Item IDs in the player's pack lists, at most `limit` of them (items.stats
-- answers 32 times per callback).
function M.pack_ids(pack, lists, limit)
    local ids = {}
    for _, name in ipairs(lists) do
        for _, row in ipairs(pack[name] or {}) do
            local id = row.item_id or 0
            if id ~= 0 and #ids < limit then ids[#ids + 1] = id end
        end
    end
    return ids
end

return M
