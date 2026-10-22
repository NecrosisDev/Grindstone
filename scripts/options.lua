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

local ROWS = {
    {key = "enabled", label = "Grindstone and anvil", type = "toggle"},
    {key = "reach_cm", label = "Reach (cm)", type = "number", min = 50, max = 400, step = 10},
    {key = "wear_floor", label = "Wheel best result (% worn)", type = "number", min = 0, max = 100, step = 1, pct = true},
    {key = "dirt_floor", label = "Wheel cleans to (% dirty)", type = "number", min = 0, max = 100, step = 1, pct = true},
    {key = "anvil_wear_floor", label = "Anvil best result (% worn)", type = "number", min = 0, max = 100, step = 1, pct = true},
    {key = "pass_wear", label = "Wear removed per pass (%)", type = "number", min = 1, max = 100, step = 1, pct = true},
    {key = "ruined_wear", label = "Ruined at (% worn)", type = "number", min = 25, max = 100, step = 1, pct = true},
    {key = "quality_matters", label = "Quality limits the edge", type = "toggle"},
    {key = "anvil_needs_hammer", label = "Anvil needs a hammer", type = "toggle"},
    {key = "anvil_needs_heat", label = "Anvil needs a lit forge", type = "toggle"},
    {key = "anvil_armour", label = "Anvil mends metal armour", type = "toggle"},
    {key = "whetstone", label = "Whetstone sharpens", type = "toggle"},
    {key = "whetstone_wear_floor", label = "Whetstone best (% worn)", type = "number", min = 0, max = 100, step = 1, pct = true},
    {key = "combat_wear", label = "Gear wears in fights", type = "toggle"},
    {key = "edge_wear_per_hit", label = "Edge wear per hit", type = "number", min = 0, max = 4, step = 0.1},
    {key = "blunt_wear_per_hit", label = "Blunt wear per hit", type = "number", min = 0, max = 4, step = 0.1},
    {key = "armour_wear_per_blow", label = "Armour wear per blow", type = "number", min = 0, max = 4, step = 0.1},
    {key = "shield_wear_per_block", label = "Shield wear per block", type = "number", min = 0, max = 4, step = 0.1},
    {key = "edge_on_armour_factor", label = "Edge on armour: wear x", type = "number", min = 1, max = 5, step = 0.25},
    {key = "unoiled_factor", label = "Unoiled repair: wear x", type = "number", min = 1, max = 6, step = 0.5},
    {key = "quality_wear_effect", label = "Quality effect on wear", type = "number", min = 0, max = 1.5, step = 0.1},
    {key = "corrode_wear_per_hour", label = "Blood rust per hour", type = "number", min = 0, max = 5, step = 0.25},
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
    for _, row in ipairs(ROWS) do
        by_key[row.key] = row
        local def = {key = row.key, label = row.label, type = row.type, default = to_setting(row, defaults[row.key])}
        if row.type == "number" then
            def.default = math.max(row.min, math.min(row.max, def.default))
            def.min, def.max, def.step = row.min, row.max, row.step
        end
        defs[#defs + 1] = def
    end
    settings.define("Grindstone", defs)
    for _, row in ipairs(ROWS) do
        local value = settings.get(row.key)
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
