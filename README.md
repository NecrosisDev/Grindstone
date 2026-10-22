# Grindstone 0.1.0 — Lua addon (needs runtime 0.26.0)

Double-click a weapon or armour piece in your inventory, then click a
sharpening wheel or an anvil, the same way keys and blue Repair Spheres are used.

- **Sharp weapons go to the wheel.** It lowers wear and scours dirt.
  Sharp means the weapon copy has a cutting edge on either grip, read from the
  copy with `items.stats` (axes only get their edge on the copy).
- **Blunt weapons go to the anvil.** It hammers wear down but does not clean.
  Blunt means no edge but a crushing head; torches and other headless items
  get nothing.
- **Metal armour goes to the anvil too.** Carried mail, plate and special plate
  (armour layers 3, 4 and 5) are mended to the same wear floor; cloth, leather
  and padding are not. Worn pieces are left to the runtime to refuse.
- The station must be within 200 cm. Clicking anything else, or a station
  that has nothing to do for that weapon, changes nothing.

Wheels (`sharpeningwheel`, `sharpenwheel a01`) are placed in levels 1, 2, 3, 7
and 67. Anvils (`anvil`, `anvillong`, `anvilball`, `anvil mtod a01` and the
`anvil log` stands) are in levels 1, 3, 7 and 67; level 2 has none.

## Realism

- **Passes.** One click takes off at most 48 wear and 64 dirt, so a badly worn
  piece needs several trips to the wheel or anvil.
- **Steel quality sets the best edge.** The lowest wear reachable is the floor
  plus a quarter of what the quality lacks: quality 255 reaches 64, quality 128
  stops near 96, quality 0 near 127.
- **The anvil needs a hammer.** You must carry or hold a blunt weapon other
  than the piece being mended. If the pack can't be read, this isn't enforced.

- **Ruined pieces.** At 75% wear (192) or worse, the wheel and anvil refuse
  the piece; only a blue Repair Sphere can bring it back.

Settings: `pass_wear` (48), `pass_dirt` (64), `quality_matters` (true),
`anvil_needs_hammer` (true), `ruined_wear` (192; 256 turns it off). The offline tests run with these off.

## The cap, compared with the blue orb

The blue Repair Sphere only lowers **wear**: one sphere removes 255 ÷ max(1,
⌊(size + 5) ÷ 10⌋) wear, down to 0, so a dagger or most one-handed swords come
back like new from one sphere. It never touches quality or dirt. The brush
cleans dirt down to 32.

The stations stop earlier: wear down to **64** (25%), the value fresh loot is
rolled around, which leaves 90% of a new edge's cutting and stabbing, and of
a new armour piece's protection (the game scales both by 1 − 0.4 × wear/255). The wheel cleans dirt down to **32**, where
the brush stops. Quality is how well the weapon was made and stays as it is.
Neither station ever raises wear or dirt.

Settings are in `scripts/config.lua`: `enabled`, `reach_cm` (200),
`wear_floor` (64), `dirt_floor` (32; 255 leaves dirt alone), `anvil_enabled`
(true), `anvil_wear_floor` (64), `anvil_armour` (true).

## Status

Built against the runtime's 0.26.0 `gear.use` event (capability
`events.gear_use`) and `event:restore_condition{wear, dirt}` (capability
`items.condition`). The runtime lets carried weapons and armour into the
game's double-click use mode, reports the clicked object's name and distance,
and lowers wear/dirt through the same repair jobs the blue orb uses (about two
seconds). Only carried, generated items are accepted; worn or held ones are
refused, and no sound plays yet. On an older runtime the addon loads, logs one
"idle" line and does nothing.

## Test

```powershell
python -X utf8 -B mods/grindstone/test_grindstone.py
```

This builds stock Lua 5.4 from the runtime's vendored source into TEMP and runs
17 cases against a stubbed API. It checks this addon's logic only; nothing here
has run in the game or in the real runtime.

## Combat wear and oil

The game never wears gear in a fight, so this addon does (needs the runtime's
`items.add_wear` and `character.hit` `armour_id`): each weapon hit adds 0.6 wear
to an edge (0.3 to a blunt weapon, ×2 for an edge striking armour or a parry),
each blow adds 0.8 wear to the armour piece that took it, and a bloody hit adds
1 dirt. This applies to every character. A piece repaired at a wheel or anvil
wears 3× faster until you oil it: double-click an **Oil Flask** and click the
piece. The flask is used up (if the runtime offers `event:consume()`).
Repaired-but-unoiled items are remembered in the save by item ID; an unknown ID
counts as oiled. All rates are in `scripts/config.lua`.

The Oil Flask is a new item built by `assets.py` (a Brush Scrub clone with the
Flask 05 model): in the civilian personal loot tables, and beside each forge in
levels 1 and 3 (fresh levels only). The flasks are placed by the runtime's
`levels.add_placement` from `scripts/placements.lua`, which `assets.py`
generates with the built item ID, so no level file is shipped. `objdb.rdb` and
`objstrings.rdb` are still replaced whole, so build from inputs that already
contain other mods' versions of those two files.
