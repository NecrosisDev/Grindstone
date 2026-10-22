"""Builds the Grindstone EMTK mod folder: the Lua addon plus an Oil Flask item.

The flask clones Brush Scrub 01 (device 1/9, so the game's own double-click use
mode applies) with the Flask 05 model and joins two civilian loot tables. Its
spots beside each forge in story levels 1 and 3 are written to
scripts/placements.lua and added by the runtime (levels.add_placement), so no
level file is shipped. The database members are still replaced whole, so pass
inputs that already contain other mods' objdb.rdb/objstrings.rdb to compose.

    python -B assets.py --inputs <folder> --out <new folder>

Inputs: objdb.rdb, objstrings.rdb, exanima01.rfc, exanima03.rfc. Placements
only appear in freshly generated levels. The ExaniMate format library is found
through EXANIMATE_TOOLS (its tools/exanimate folder); tools/make_dist.py sets it."""
import argparse
import math
import os
import shutil
import struct
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if os.environ.get('EXANIMATE_TOOLS'):
    sys.path.insert(0, os.environ['EXANIMATE_TOOLS'])
from exanimate import level, rdb  # noqa: E402

MOD_ID = 'com.necrosis.grindstone'
MOD_NAME = 'Grindstone'
VERSION = '0.1.0'
OIL_NAME = 'Oil Flask'
OIL_MODEL = 'Jar05'  # Flask 05's model; must match OIL_MODEL in scripts/wear.lua
OIL_TEXT = ('A small flask of oil for steel. Double-click it, then click a blade or armour piece '
            'freshly worked at a grindstone or anvil: oiled work holds up far longer.')
FORGES = ('uw1_furnace a', 'uw1_furnace b', 'furnace', 'furnace mtob a1', 'furnace mtob a2', 'furnace uaa a1',
          'hm_furnace_top', 'hm_furnace_uwb01')  # Hellmode levels use the hm_ models
LOOT_TABLES = ('+Drop Tables/Civ LC Personal', '+Drop Tables/Civ MC Personal')


def build(inputs: Path, output: Path) -> Path:
    if output.exists():
        raise ValueError('output must be a new folder')
    data = (inputs / 'objdb.rdb').read_bytes()
    strings_data = (inputs / 'objstrings.rdb').read_bytes()
    db, strings = rdb.parse(data), rdb.strings_package(strings_data)
    if any(r.name == OIL_NAME for r in db.records):
        raise ValueError('input database already has an Oil Flask; build from inputs without this mod')
    brush = next(r for r in db.records if r.name == 'Brush Scrub 01')
    flask = next(r for r in db.records if r.model == OIL_MODEL)
    oil = rdb.clone_record(db, brush.id, OIL_NAME, OIL_MODEL)
    rdb.set_item_size(oil, rdb.item_size(flask) or 3)
    # The shipped Whetstone (header and look chunks only) gets the brush's device
    # chunk so the game's double-click use mode applies to it too.
    whet = next(r for r in db.records if r.model == 'WhetStone01')
    if whet.chunk(0x10000) is None:
        device = brush.chunk(0x10000)
        whet.data += struct.pack('<II', 0x10000, len(device) + 8) + device
        whet.flags |= 0x10000
        whet.size = len(whet.data)
    strings += [(0, 1, OIL_NAME), (0, 1, OIL_TEXT)]
    rdb.set_display_strings(oil, len(strings) - 1, len(strings))
    for table in (r for r in db.records if db.path(r) in LOOT_TABLES):
        rdb.add_drop_entry(db, table.id, oil.id, a=8)

    mod = output / 'mods' / MOD_ID
    resources = mod / 'assets/packages/Resource'
    resources.mkdir(parents=True)
    (resources / 'objdb.rdb').write_bytes(rdb.pack(db))
    (resources / 'objstrings.rdb').write_bytes(rdb.pack_strings(strings, strings_data))
    # Vanilla and Hellmode lay these levels out differently: spots for each known layout (inputs/<level> plus any
    # inputs/layouts/*/<level>), keyed by that level file's size; the script picks the installed one.
    placements = {}
    for name in ('exanima01.rfc', 'exanima03.rfc'):
        for source in [inputs / name, *sorted((inputs / 'layouts').glob(f'*/{name}'))]:
            data = source.read_bytes()
            lv = level.parse(data)
            anvils = [p.pos for _, _, p in level.find(lv, 'anvil')]
            spots = placements.setdefault(name, {}).setdefault(len(data), [])
            for forge in lv.objects:
                if forge.name not in FORGES or not anvils:
                    continue
                # A third of the way from the forge toward its nearest anvil, a little
                # above the forge's base so physics settles it onto the floor.
                near = min(anvils, key=lambda a: math.dist(a, forge.pos))
                pos = [forge.pos[i] + (near[i] - forge.pos[i]) / 3 for i in range(3)]
                pos[1] = forge.pos[1] + 15.0
                spots.append(pos)

    shutil.copyfile(HERE / 'manifest.toml', mod / 'manifest.toml')
    shutil.copytree(HERE / 'scripts', mod / 'scripts')
    # The runtime adds the flasks as the game reads each level (levels.add_placement),
    # so no whole level file is shipped; this records the built item ID and spots.
    rows = ''
    for name, layouts in placements.items():
        rows += f'    ["{name}"] = {{\n'
        for size in sorted(layouts):
            spots = ', '.join(f'{{x = {p[0]:.1f}, y = {p[1]:.1f}, z = {p[2]:.1f}}}' for p in layouts[size])
            rows += f'        [{size}] = {{{spots}}},\n'
        rows += '    },\n'
    (mod / 'scripts/placements.lua').write_text(
        '-- Generated by assets.py from its input levels; do not edit by hand. Spots per level, for each known\n'
        '-- layout of it, keyed by the level file\'s size.\n'
        f'return {{oil_item_id = {oil.id:#x}, oil = {{\n{rows}}}}}\n', newline='\n')
    shutil.copyfile(HERE / 'README.md', mod / 'README.md')
    (mod / 'config.toml').write_text(
        f'[plugin]\nid = "{MOD_ID}"\nname = "{MOD_NAME}"\nversion = "{VERSION}"\nsupported_versions = []\n'
        f'url = ""\nenabled = false\n[plugin.author]\nname = "NecrosisDev"\n')
    print(f'oil flask id {oil.id:#x}; placements {placements}; mod at {mod}')
    return mod


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--inputs', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    build(args.inputs.resolve(), args.out.resolve())
