"""Builds the ready-to-ship mod into dist/mods/com.necrosis.grindstone from source.

Reads the installed game's own Resource.rpk members, runs assets.py (Oil Flask
record, Whetstone device, flask placements), then the Lua runtime's
records_delta.py to cut that down to this mod's [script.records] range, and
assembles manifest, scripts and records. Files already in the dist folder are
overwritten; nothing else is touched.

    python -B tools/make_dist.py [--game <Exanima folder>] [--workspace <Exanimate workspace>]
"""
import argparse
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MOD_ID = 'com.necrosis.grindstone'
ID_RANGE = ('0x591', '0x59f')
STRING_RANGE = ('1217', '1248')
INPUT_MEMBERS = ('objdb.rdb', 'objstrings.rdb', 'exanima01.rfc', 'exanima03.rfc')
SOURCE_SCRIPTS = ('common.lua', 'config.lua', 'main.lua', 'options.lua', 'wear.lua')


def run(*args, env=None):
    subprocess.run([sys.executable, '-X', 'utf8', '-B', *map(str, args)], check=True, env=env)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--game', type=Path, default=Path(r'D:\SteamLibrary\steamapps\common\Exanima'))
    parser.add_argument('--workspace', type=Path, default=Path(os.environ['EXANIMATE_WORKSPACE']) if os.environ.get('EXANIMATE_WORKSPACE') else None,
                        required=not os.environ.get('EXANIMATE_WORKSPACE'))
    args = parser.parse_args()
    tools = args.workspace / 'tools' / 'exanimate'
    delta_tool = args.workspace / 'mods' / 'script-runtime' / 'records_delta.py'
    for needed in (tools, delta_tool, args.game / 'Resource.rpk'):
        if not needed.exists():
            parser.error(f'missing {needed}')
    env = dict(os.environ, EXANIMATE_TOOLS=str(tools))
    sys.path.insert(0, str(tools))
    from exanimate import rpk

    stage = Path(tempfile.mkdtemp(prefix='grindstone-dist-'))
    inputs = stage / 'inputs'
    inputs.mkdir()
    for member in INPUT_MEMBERS:
        (inputs / member).write_bytes(rpk.read(args.game / 'Resource.rpk', member))
    run(ROOT / 'assets.py', '--inputs', inputs, '--out', stage / 'full', env=env)
    built = stage / 'full' / 'mods' / MOD_ID
    run(delta_tool, '--game', args.game, '--full', built / 'assets/packages/Resource',
        '--ids', *ID_RANGE, '--strings', *STRING_RANGE, '--out', stage / 'delta',
        '--map-lua', built / 'scripts/placements.lua')

    dist = ROOT / 'dist' / 'mods' / MOD_ID
    (dist / 'scripts').mkdir(parents=True, exist_ok=True)
    (dist / 'records').mkdir(exist_ok=True)
    for name in SOURCE_SCRIPTS:
        shutil.copyfile(ROOT / 'scripts' / name, dist / 'scripts' / name)
    shutil.copyfile(stage / 'delta' / 'placements.lua', dist / 'scripts' / 'placements.lua')
    for name in ('objdb.rdb', 'objstrings.rdb'):
        shutil.copyfile(stage / 'delta' / 'records' / name, dist / 'records' / name)
    manifest = (ROOT / 'manifest.toml').read_text(encoding='utf-8').rstrip('\n')
    block = (stage / 'delta' / 'manifest-records.toml').read_text(encoding='utf-8').strip('\n')
    (dist / 'manifest.toml').write_text(f'{manifest}\n\n{block}\n', encoding='utf-8')
    print(f'dist ready: {dist} (staging kept at {stage})')
    return 0


if __name__ == '__main__':
    sys.exit(main())
