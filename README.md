# Grindstone

Repair your own gear in Exanima. Take a blade to a sharpening wheel, or a blunt
weapon, armour or shield to an anvil, the same way you use keys and blue Repair
Spheres. Gear also wears down in fights, so the stations matter.

## Features

**Sharpening wheels.** Double-click a sharp weapon in your inventory, then click
a sharpening wheel. Each click is one pass that takes off some wear and scours
off dirt.

**Anvils.** Double-click a blunt weapon (mace, hammer, club), a piece of metal
armour (mail, plate or special plate) or a shield, then click an anvil. The
anvil hammers wear down but does not clean. Cloth, leather and padded armour
cannot be mended here.

- You need a hammer: any blunt weapon you carry or hold, other than the piece
  being worked.
- Anvils standing next to a forge (in the first and third levels) need the
  forge burning. Double-click a torch and click a cold forge to light it.

**The Whetstone.** The game's Whetstone becomes a field tool. Double-click it,
then click a sharp weapon in your pack to hone it a little. It cannot bring an
edge back as far as a wheel can.

**Realistic limits.**

- One click is one pass, so a badly worn piece needs several.
- Stations stop short of new. With the default settings a wheel or anvil brings
  wear down to 25%, about where freshly found loot sits, and a wheel cleans dirt
  to the level a brush does. A blue Repair Sphere is still the way back to like
  new.
- Poorly made steel cannot be restored as far as well made steel.
- Pieces worn to 75% or worse are ruined: wheels and anvils refuse them, and
  only a Repair Sphere helps.
- Repairs never raise wear or dirt, and never change an item's quality.

**Combat wear.** Every hit wears the striking weapon a little and every blow
wears the armour piece that takes it, for every character. Edges dull faster
when they strike armour, shields or a parry, and bloody hits add dirt. Your
shield wears when it blocks, and when it is fully worn it splits and drops at
your feet. Better made pieces wear more slowly.

**Blood rust.** Your metal gear that is left very dirty slowly gains wear with
each in-game hour. Clean it with a brush to stop it.

**Oil Flask.** A new item. A piece you have just repaired at a wheel, anvil or
whetstone wears three times faster until you oil it: double-click an Oil Flask,
then click the piece. The flask is used up. Oil Flasks turn up in civilian loot
and beside the forges in the first and third levels (only in levels not yet
generated in your save).

## Requirements

- Exanima (Steam).
- EMTK with the script-runtime startup patch, shipped with the Exanima Lua
  Runtime release.
- Exanima Lua Runtime 0.28.0 or later.

## Install

1. Download `Grindstone-<version>.zip` from the Releases page.
2. Close Exanima.
3. Copy the `mods` folder from the ZIP into your Exanima game folder, so you end
   up with `Exanima\mods\com.necrosis.grindstone`.
4. Enable Grindstone in your EMTK profile.
5. Launch the game through EMTK.

## Using it

Stand at the wheel or anvil (within 2 m by default), double-click the piece in
your inventory, then click the station. A short message at the bottom of the
screen tells you what happened or why nothing could be done, and the game's own
repair or cleaning sound plays.

## Settings

Open Settings > Mod Settings > Grindstone. Wear and dirt limits are shown as
percent.

| Group | Setting | What it does |
|---|---|---|
| Stations | Repairs | Grindstones, anvils and whetstones can repair gear. |
| | Reach | How close you must stand to a station, in cm. |
| Limits | Grindstone | Lowest wear a grindstone can bring an item to. |
| | Cleaning | Lowest dirt a grindstone can bring an item to. |
| | Anvil | Lowest wear an anvil can bring an item to. |
| | Whetstone | Lowest wear a whetstone can bring an edge to. |
| | Per click | Most wear one click removes. |
| | Ruined at | From this much wear, only a Repair Sphere helps. |
| | Quality cap | Poorly made steel cannot be restored as far. |
| Anvil | Hammer | The anvil needs a blunt weapon in your pack. |
| | Forge | Anvils next to a forge need it lit. |
| | Armour | The anvil mends mail and plate. |
| Whetstone | Whetstone | The Whetstone item can sharpen edges. |
| Combat wear | Combat wear | Hits, blocks and blood rust wear down gear. |
| | Blades | Wear per hit for an edged weapon. |
| | Blunt | Wear per hit for a blunt weapon. |
| | Armour | Wear per blow on the armour piece hit. |
| | Shields | Wear per blocked blow. |
| | On metal | Extra blade wear when hitting armour, shields or parries. |
| | Unoiled | Extra wear until fresh work is oiled. |
| | Quality | How much quality speeds up or slows wear. |
| | Blood rust | Wear per in-game hour on very dirty steel. |

The defaults are in `scripts/config.lua` inside the mod folder.

## Saves and uninstalling

- Repairs and combat wear change the items themselves, through the game's own
  item condition.
- The mod keeps a small record in your save: which repaired pieces still need
  oil, and your shield's wear.
- Oil Flasks are an item this mod adds. Back up your saves before removing the
  mod.
- To uninstall, disable Grindstone in your EMTK profile, or delete
  `Exanima\mods\com.necrosis.grindstone`.

## Building from source

The build reads the installed game: it takes the item database, string table
and two level files from `Resource.rpk` to make the Oil Flask, the Whetstone
change and the flask placements. It also needs an ExaniMate workspace, for its
format library and the Lua runtime's records tool. Python 3 is required.

```
python -X utf8 -B release.py --workspace <ExaniMate workspace> --game <Exanima folder>
```

`--workspace` can instead come from the `EXANIMATE_WORKSPACE` environment
variable. Always pass `--game` with your own Exanima folder.

This writes the mod folder to `dist/mods/com.necrosis.grindstone/` and the
release to `dist/Grindstone-<version>.zip`, with a `.sha256` file beside it. An
earlier build in `dist/mods/` is moved to `dist/previous/` first. Other options:

- `--zip-only` packages the mod folder already in `dist/` without rebuilding.
- `--tag v<version>` stops unless the tag matches the version in
  `manifest.toml`.

Author: NecrosisDev
