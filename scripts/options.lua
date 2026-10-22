-- Grindstone's settings: scripts/config.lua holds the defaults, and the runtime's
-- Mod Settings tab (Settings > Mod Settings, runtime 0.27.0, capability
-- ui.settings) lets the player change them in game. Wear values show there as
-- percent and are kept here on the game's 0..255 scale.
local defaults = require("config")
-- The runtime gives addons no metatables, so this is a plain copy of the defaults.
local M = {}
for key, value in pairs(defaults) do M[key] = value end
local listeners = {}

function M.on_change(fn) listeners[#listeners + 1] = fn end

-- Labels stay short so they fit the tab; `help` (at most 160 bytes) carries the
-- detail.
local ROWS = {
    {type = "header", label = "Stations"},
    {key = "enabled", label = "Repairs", type = "toggle", help = "Grindstones, anvils and whetstones can repair gear."},
    {key = "reach_cm", label = "Reach", type = "number", min = 50, max = 400, step = 10, help = "How close you must stand to a station, in cm."},
    {type = "header", label = "Limits"},
    {key = "wear_floor", label = "Grindstone", type = "number", min = 0, max = 100, step = 1, pct = true, help = "Lowest wear a grindstone can bring an item to, % worn."},
    {key = "dirt_floor", label = "Cleaning", type = "number", min = 0, max = 100, step = 1, pct = true, help = "Lowest dirt a grindstone can bring an item to, % dirty."},
    {key = "anvil_wear_floor", label = "Anvil", type = "number", min = 0, max = 100, step = 1, pct = true, help = "Lowest wear an anvil can bring an item to, % worn."},
    {key = "whetstone_wear_floor", label = "Whetstone", type = "number", min = 0, max = 100, step = 1, pct = true, help = "Lowest wear a whetstone can bring an edge to, % worn."},
    {key = "pass_wear", label = "Per click", type = "number", min = 1, max = 100, step = 1, pct = true, help = "Most wear one click removes, %."},
    {key = "ruined_wear", label = "Ruined at", type = "number", min = 25, max = 100, step = 1, pct = true, help = "From this much wear (%), only a Repair Sphere helps."},
    {key = "quality_matters", label = "Quality cap", type = "toggle", help = "Poorly made steel can't be restored as far."},
    {type = "header", label = "Anvil"},
    {key = "anvil_needs_hammer", label = "Hammer", type = "toggle", help = "The anvil needs a blunt weapon in your pack."},
    {key = "anvil_needs_heat", label = "Forge", type = "toggle", help = "Anvils next to a forge need it lit."},
    {key = "anvil_armour", label = "Armour", type = "toggle", help = "The anvil mends mail and plate."},
    {type = "header", label = "Whetstone"},
    {key = "whetstone", label = "Whetstone", type = "toggle", help = "The Whetstone item can sharpen edges."},
    {type = "header", label = "Combat wear"},
    {key = "combat_wear", label = "Combat wear", type = "toggle", help = "Hits, blocks and blood rust wear down gear."},
    {key = "edge_wear_per_hit", label = "Blades", type = "number", min = 0, max = 4, step = 0.1, help = "Wear per hit for that weapon type (0..255 scale)."},
    {key = "blunt_wear_per_hit", label = "Blunt", type = "number", min = 0, max = 4, step = 0.1, help = "Wear per hit for that weapon type (0..255 scale)."},
    {key = "armour_wear_per_blow", label = "Armour", type = "number", min = 0, max = 4, step = 0.1, help = "Wear per blow on the piece hit."},
    {key = "shield_wear_per_block", label = "Shields", type = "number", min = 0, max = 4, step = 0.1, help = "Wear per blocked blow."},
    {key = "edge_on_armour_factor", label = "On metal", type = "number", min = 1, max = 5, step = 0.25, help = "Extra blade wear when hitting armour, shields or parries (multiplier)."},
    {key = "unoiled_factor", label = "Unoiled", type = "number", min = 1, max = 6, step = 0.5, help = "Extra wear until fresh work is oiled (multiplier)."},
    {key = "quality_wear_effect", label = "Quality", type = "number", min = 0, max = 1.5, step = 0.1, help = "How much quality speeds up or slows wear."},
    {key = "corrode_wear_per_hour", label = "Blood rust", type = "number", min = 0, max = 5, step = 0.25, help = "Wear per in-game hour on very dirty steel."},
}

local function to_game(row, value)
    if row.pct and type(value) == "number" then return math.min(255, math.floor(value * 255 / 100 + 0.5)) end
    return value
end

local function to_setting(row, value)
    if row.pct then return math.floor((tonumber(value) or 0) * 100 / 255 + 0.5) end
    if row.type == "toggle" then return value ~= false end
    return math.max(row.min, math.min(row.max, tonumber(value) or row.min))
end

if settings and settings.define and api.has_capability("ui.settings") then
    local by_key, defs = {}, {}
    local plain = {}   -- the same rows without sub-headers, for a runtime before 0.28.0-r42
    for _, row in ipairs(ROWS) do
        if row.type == "header" then
            defs[#defs + 1] = {type = "header", label = row.label}
        else
            by_key[row.key] = row
            local def = {key = row.key, label = row.label, help = row.help, type = row.type,
                default = to_setting(row, defaults[row.key])}
            if row.type == "number" then
                def.default = math.max(row.min, math.min(row.max, def.default))
                def.min, def.max, def.step = row.min, row.max, row.step
            end
            defs[#defs + 1] = def
            plain[#plain + 1] = def
        end
    end
    if not pcall(settings.define, "Grindstone", defs) then settings.define("Grindstone", plain) end
    for _, row in ipairs(ROWS) do
        local value = row.key and settings.get(row.key)
        if value ~= nil then M[row.key] = to_game(row, value) end
    end
    events.on("settings.changed", function(event)
        local row = by_key[event.key]
        if not row then return end
        M[row.key] = to_game(row, event.value)
        for _, fn in ipairs(listeners) do fn() end
    end)
end

return M
