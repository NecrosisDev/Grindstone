-- Grindstone settings. Condition bytes run 0..255: 0 wear is a new edge, 255 is ruined.
return {
    enabled = true,
    -- How close the wheel or anvil must be when you click it, in cm.
    reach_cm = 200,
    -- The wheel grinds wear down to this and no further. 64 (25%) is the wear a
    -- freshly found weapon is rolled around; a blue Repair Sphere goes to 0.
    wear_floor = 64,
    -- The wheel also scours dirt down to this; 32 is where the brush stops.
    -- 255 leaves dirt alone.
    dirt_floor = 32,
    -- Anvils hammer dents out of blunt weapons (maces, hammers, clubs). They lower
    -- wear only, to the same floor as the wheel; they don't clean.
    anvil_enabled = true,
    anvil_wear_floor = 64,
    -- Anvils also mend carried mail and plate armour, to the same floor.
    -- Cloth, leather and padding are left alone.
    anvil_armour = true,
    -- Realism. One click is one pass: it takes off at most this much wear/dirt,
    -- so a badly worn piece needs several passes (255 = all at once).
    pass_wear = 48,
    pass_dirt = 64,
    -- Poorly made steel won't take as fine an edge: the best wear reachable rises
    -- by a quarter of what the quality lacks (quality 128 stops ~32 above the floor).
    quality_matters = true,
    -- The anvil needs a blunt weapon (hammer, mace...) in your pack to strike with.
    anvil_needs_hammer = true,
    -- At or past this wear a piece is ruined: wheel and anvil refuse it and only
    -- a blue Repair Sphere can bring it back. 192 = 75% worn; 256 turns it off.
    ruined_wear = 192,
    -- The anvil needs a burning forge nearby; use a torch on a cold forge to light
    -- it. The grindstone is cold work and needs no heat.
    anvil_needs_heat = true,
    -- Combat wear: every hit wears the striking weapon and the armour piece that
    -- takes the blow, for every character (values are wear per hit, 0..255 scale).
    combat_wear = true,
    edge_wear_per_hit = 0.6,
    blunt_wear_per_hit = 0.3,
    armour_wear_per_blow = 0.8,
    -- An edge striking armour, a shield or a parry dulls this much faster.
    edge_on_armour_factor = 2,
    -- A bloody hit on flesh adds this much dirt to the weapon.
    blood_dirt_per_hit = 1,
    -- A shield that blocks a blow wears this much; a weapon that parries one
    -- wears like an edge striking armour (needs the runtime to report blocks).
    shield_wear_per_block = 0.8,
    -- A wheel or anvil repair wears this many times faster until it is oiled
    -- with an Oil Flask (double-click the flask, click the repaired piece).
    unoiled_factor = 3,
    -- Quality changes the wear rate: the best-made pieces wear 25% slower and
    -- the worst 25% faster at 0.5 (0 = quality doesn't matter).
    quality_wear_effect = 0.5,
    -- Blood left on steel corrodes it: carried, held and worn metal with dirt at
    -- or above corrode_dirt gains this much wear per in-game hour. Brush it clean.
    corrode_dirt = 96,
    corrode_wear_per_hour = 1,
    -- The game's Whetstone becomes a field tool: double-click it, click a sharp
    -- weapon in the pack. Each pass takes off up to 24 wear, never below 50%.
    whetstone = true,
    whetstone_wear_floor = 128,
    whetstone_pass_wear = 24,
    -- Each pass can move the world clock on by this many minutes (0 = off).
    -- Off by default: nothing in the game is known to follow the clock, so the
    -- only effect would be this mod's own blood corrosion.
    wheel_minutes_per_pass = 0,
    anvil_minutes_per_pass = 0,
    whetstone_minutes_per_pass = 0,
}
