-- Runs scripts/main.lua against a stub of the runtime's gear.use contract
-- (runtime 0.26.0, API.md "Using weapons and armour on things"), including the
-- refusals restore_condition raises as Lua errors. Usage: lua harness.lua <mod folder>
local root = assert(arg[1], "mod folder")
local INSTANCED = 0xA0000000

local function new(opts)
    local s = {logs = {}, writes = {}, handlers = {}, stats = {}}
    local env = {
        math = math, string = string, table = table, ipairs = ipairs, pairs = pairs,
        tonumber = tonumber, tostring = tostring, type = type, print = print, error = error,
    }
    env.log = {
        info = function(m) s.logs[#s.logs + 1] = "info: " .. m end,
        warn = function(m) s.logs[#s.logs + 1] = "warn: " .. m end,
    }
    env.api = {has_capability = function(name) return name ~= "events.gear_use" or not opts.no_event end}
    env.events = {on = function(name, fn) s.handlers[name] = fn end}
    -- items.stats carries no condition here, so the addon must use the event's.
    env.items = {add_wear = function() end, stats = function(id)
        local st = s.stats[id & 0x0FFFFFFF]
        return st and {item_id = id, weapon = st.weapon, armour = st.armour}
    end}
    -- Core cases run with the realism settings off; they are checked on their own.
    local config = opts.config
    if not config then
        config = dofile(root .. "/scripts/config.lua")
        config.pass_wear, config.pass_dirt, config.quality_matters, config.anvil_needs_hammer, config.ruined_wear = 255, 255, false, false, 256
        config.combat_wear = false
    end
    local modules = {}
    env.require = function(name)
        if name == "config" then return config end
        if name == "common" then
            modules.common = modules.common or assert(loadfile(root .. "/scripts/common.lua", "t", env))()
            return modules.common
        end
        if name == "options" then
            modules.options = modules.options or assert(loadfile(root .. "/scripts/options.lua", "t", env))()
            return modules.options
        end
        assert(name == "wear", name)
        modules.wear = modules.wear or assert(loadfile(root .. "/scripts/wear.lua", "t", env))()
        return modules.wear
    end
    assert(loadfile(root .. "/scripts/main.lua", "t", env))()
    -- Clicking item `n` (double-clicked onto the cursor) on a placed object.
    s.use = function(n, name, distance, item)
        local st = s.stats[n]
        local cond = st and st.condition
        item = item or {}
        local event = {
            item = {id = item.id or (INSTANCED | n), model = "x", kind = st and (st.weapon and "weapon" or "apparel"),
                    carried = item.carried ~= false, condition = cond and {quality = cond.quality, wear = cond.wear, dirt = cond.dirt}},
            target = {kind = name and "object" or "other", name = name, record_id = 0, distance = name and (distance or 120) or nil},
        }
        local requested
        if not opts.no_write then
            event.restore_condition = function(self, t)
                assert(not requested, "restore_condition was already requested for this event")
                assert(type(t) == "table")
                assert(self.item.carried, "carried items only")
                assert(self.item.id & 0xF0000000 ~= 0, "instanced items only")
                assert(t.wear ~= nil or t.dirt ~= nil, "restore_condition needs wear or dirt")
                for _, k in ipairs({"wear", "dirt"}) do
                    local v = t[k]
                    if v ~= nil then
                        assert(math.type(v) == "integer" and v >= 0 and v <= 255, k .. " is an integer 0..255")
                        assert(v <= self.item.condition[k], "restore_condition only lowers " .. k)
                    end
                end
                requested = true
                s.writes[#s.writes + 1] = {id = self.item.id & 0x0FFFFFFF, wear = t.wear, dirt = t.dirt}
                return true
            end
        end
        local handled = s.handlers["gear.use"](event)
        assert(handled == nil or type(handled) == "boolean", "gear.use handlers return a boolean or nil")
        assert(not requested or handled, "restore_condition requires a handled (true) result")
        return handled
    end
    return s
end

local function grip(cut, crush, point) return {kind = 1, cut = cut, crush = crush, point = point} end
local function weapon(g, alt, wear, dirt)
    return {weapon = {grip = g, alternate_grip = alt}, condition = {quality = 128, wear = wear, dirt = dirt}}
end
local function armour(layer, wear, dirt)
    return {armour = {layer = layer, cut = 0.5}, condition = {quality = 128, wear = wear, dirt = dirt}}
end
local SWORD, MACE = grip(0.4, 0, 0.2), grip(0, 0.5, 0)
local passed = 0
local function case(name, fn) fn() passed = passed + 1 print("ok  " .. name) end

case("sword on a wheel is ground to the floors", function()
    local s = new{}
    s.stats = {[1] = weapon(SWORD, nil, 150, 90)}
    assert(s.use(1, "sharpeningwheel") == true)
    assert(#s.writes == 1 and s.writes[1].id == 1 and s.writes[1].wear == 64 and s.writes[1].dirt == 32)
    assert(s.use(1, "sharpenwheel a01") == true and #s.writes == 2)
end)

case("blunt weapons get nothing from a wheel", function()
    local s = new{}
    s.stats = {[1] = weapon(MACE, nil, 200, 200), [2] = weapon(grip(0, 0.4, 0.4), nil, 200, 200),
               [3] = weapon(grip(0, 0.1, 0.5), nil, 200, 200)}
    for id = 1, 3 do s.use(id, "sharpeningwheel") end
    assert(#s.writes == 0)
end)

case("an edge on the alternate grip counts", function()
    local s = new{}
    s.stats = {[1] = weapon(MACE, grip(0.3, 0, 0), 120, 0)}
    s.use(1, "sharpeningwheel")
    assert(#s.writes == 1 and s.writes[1].wear == 64 and s.writes[1].dirt == nil)
end)

case("only lowers what is above its floor; nothing to do at the floors", function()
    local s = new{}
    s.stats = {[1] = weapon(SWORD, nil, 30, 10), [2] = weapon(SWORD, nil, 40, 90)}
    assert(s.use(1, "sharpeningwheel") == true)
    s.use(2, "sharpeningwheel")
    assert(#s.writes == 1 and s.writes[1].id == 2 and s.writes[1].wear == nil and s.writes[1].dirt == 32)
end)

case("too far away is refused with a message; no target or other scenery passes the click on", function()
    local s = new{}
    s.stats = {[1] = weapon(SWORD, nil, 200, 0)}
    assert(s.use(1, "sharpeningwheel", 260) == true)
    assert(s.use(1, "seedgrinder a01a") == false)
    assert(s.use(1, nil) == false)
    assert(#s.writes == 0)
end)

case("worn/held or non-generated items are never sent to restore", function()
    local s = new{}
    s.stats = {[1] = weapon(SWORD, nil, 200, 90)}
    assert(s.use(1, "sharpeningwheel", 100, {carried = false}) == false)
    assert(s.use(1, "sharpeningwheel", 100, {id = 0x00000123}) == false)
    assert(#s.writes == 0)
end)

case("anvil hammers a blunt weapon's wear down and leaves dirt", function()
    local s = new{}
    s.stats = {[1] = weapon(MACE, nil, 180, 90)}
    s.use(1, "anvil mtod a01")
    assert(#s.writes == 1 and s.writes[1].wear == 64 and s.writes[1].dirt == nil)
end)

case("anvil ignores sharp weapons and headless things (torch)", function()
    local s = new{}
    s.stats = {[1] = weapon(SWORD, nil, 180, 90), [2] = weapon(grip(0, 0, 0), nil, 180, 90)}
    s.use(1, "anvil") s.use(2, "anvil log a01")
    assert(#s.writes == 0)
end)

case("anvil can be switched off", function()
    local s = new{config = {enabled = true, anvil_enabled = false}}
    s.stats = {[1] = weapon(MACE, nil, 180, 0)}
    assert(s.use(1, "anvil") == false and #s.writes == 0)
end)

case("settings are clamped", function()
    local s = new{config = {enabled = true, reach_cm = 9999, wear_floor = 999, dirt_floor = -5, ruined_wear = 999, pass_wear = 255, pass_dirt = 255, quality_matters = false}}
    s.stats = {[1] = weapon(SWORD, nil, 254, 3)}
    s.use(1, "sharpeningwheel", 399)
    assert(#s.writes == 1 and s.writes[1].wear == nil and s.writes[1].dirt == 0)
    assert(s.use(1, "sharpeningwheel", 401) == true and #s.writes == 1)
end)

case("disabled passes every click on", function()
    local s = new{config = {enabled = false}}
    s.stats = {[1] = weapon(SWORD, nil, 200, 0)}
    assert(s.use(1, "sharpeningwheel") == false and #s.writes == 0)
end)

case("idles with one warning on a runtime without gear.use", function()
    local s = new{no_event = true}
    assert(s.handlers["gear.use"] == nil)
    s.handlers["runtime.phase"]({phase = "session"}) s.handlers["runtime.phase"]({phase = "session"})
    assert(#s.logs == 1 and s.logs[1]:find("idle"), s.logs[1])
end)

case("warns once without items.condition, still takes the click", function()
    local s = new{no_write = true}
    s.stats = {[1] = weapon(SWORD, nil, 200, 0)}
    assert(s.use(1, "sharpeningwheel") == true) s.use(1, "sharpeningwheel")
    assert(#s.logs == 1 and s.logs[1]:find("cannot change"), s.logs[1])
end)

case("anvil mends mail, plate and special plate to the floor, leaving dirt", function()
    local s = new{}
    s.stats = {[1] = armour(3, 200, 90), [2] = armour(4, 120, 0), [3] = armour(5, 65, 10)}
    for id = 1, 3 do assert(s.use(id, "anvil") == true) end
    assert(#s.writes == 3)
    for _, w in ipairs(s.writes) do assert(w.wear == 64 and w.dirt == nil) end
end)

case("cloth, leather and padding are not mended; armour gets nothing from a wheel", function()
    local s = new{}
    s.stats = {[1] = armour(1, 200, 0), [2] = armour(2, 200, 0), [3] = armour(4, 200, 90)}
    s.use(1, "anvil") s.use(2, "anvillong") s.use(3, "sharpeningwheel")
    assert(#s.writes == 0)
end)

case("armour at or below the floor is left alone", function()
    local s = new{}
    s.stats = {[1] = armour(4, 64, 200)}
    assert(s.use(1, "anvil") == true and #s.writes == 0)
end)

case("armour mending can be switched off on its own", function()
    local s = new{config = {enabled = true, anvil_armour = false, ruined_wear = 256}}
    s.stats = {[1] = armour(4, 200, 0), [2] = weapon(MACE, nil, 200, 0)}
    s.use(1, "anvil") s.use(2, "anvil")
    assert(#s.writes == 1 and s.writes[1].id == 2)
end)

print(passed .. " cases passed")
