#!/usr/bin/env bash
set -euo pipefail
python3 - "$@" <<'PY'
import json, os, pathlib, shutil, subprocess, sys, tempfile

START = '-- BEGIN asahi-xdr-color\n'
END = '-- END asahi-xdr-color\n'
HOME = pathlib.Path.home()
CONFIG = HOME / '.config/hypr/hyprland.lua'
MODULE = HOME / '.config/hypr/asahi-xdr-color.lua'

def run(*args):
    return subprocess.check_output(args, text=True).strip()

def main():
    if os.geteuid() == 0:
        raise RuntimeError('Run as your normal desktop user, without sudo.')
    if sys.argv[1:] not in ([], ['--uninstall']):
        raise RuntimeError('Usage: bash install.sh [--uninstall]')
    original = CONFIG.read_text()
    uninstall = sys.argv[1:] == ['--uninstall']
    if START in original:
        if original.count(START) != 1 or original.count(END) != 1:
            raise RuntimeError('Unexpected managed block; inspect your configuration first.')
        first, rest = original.split(START)
        _, last = rest.split(END)
        updated = first + last
        if not uninstall:
            print('Already installed. Use --uninstall before changing the preset.'); return
    elif uninstall:
        print('No managed installation found.'); return
    else:
        model = pathlib.Path('/sys/firmware/devicetree/base/model').read_bytes().rstrip(b'\0').decode()
        if model != 'Apple MacBook Pro (16-inch, M1 Max, 2021)':
            raise RuntimeError('This experimental preset is limited to the tested 2021 16-inch M1 Max model.')
        version = run('hyprctl', 'version')
        if 'Hyprland 0.56.2' not in version:
            raise RuntimeError('This installer currently targets Hyprland 0.56.2 with Lua configuration.')
        if (CONFIG.parent / 'builtin-color.lua').exists():
            raise RuntimeError('The earlier bespoke built-in color override is already present. No changes needed.')
        if MODULE.exists():
            raise RuntimeError('An unmanaged asahi-xdr-color.lua exists; refusing to overwrite it.')
        anchor = 'require("hypr.omacontrol")\n'
        if original.count(anchor) != 1 or original.find('require("default.hypr.toggles")') < original.find(anchor):
            raise RuntimeError('Expected Omarchy Lua load order not found; no configuration changed.')
        before = json.loads(run('hyprctl', 'monitors', 'all', '-j'))
        internal = [m for m in before if m['name'] == 'eDP-1' and not m.get('disabled')]
        if len(internal) != 1:
            raise RuntimeError('One active eDP-1 display is required.')
        m = internal[0]
        module = '-- Nominal Display P3 SDR; not measured calibration and not HDR.\n'
        module += '-- Layout captured at install time; update this rule if moving the laptop display.\n'
        rule = dict(output='eDP-1', mode=f"{m['width']}x{m['height']}@{m['refreshRate']:.5f}",
                    scale=m['scale'], position=f"{m['x']}x{m['y']}", transform=m['transform'],
                    vrr=int(m['vrr']), cm='dp3', bitdepth=10, sdr_eotf='srgb')
        module += 'hl.monitor({\n' + ''.join(f'  {k} = {json.dumps(v)},\n' for k,v in rule.items()) + '})\n'
        updated = original.replace(anchor, anchor + START + 'require("hypr.asahi-xdr-color")\n' + END)
    if run('hyprctl', 'configerrors'):
        raise RuntimeError('Existing Hyprland errors must be resolved first.')
    backup_root = HOME / '.local/state/asahi-xdr-color'
    backup_root.mkdir(parents=True, exist_ok=True)
    backup = pathlib.Path(tempfile.mkdtemp(prefix='backup-', dir=backup_root))
    shutil.copy2(CONFIG, backup / CONFIG.name)
    old_module = MODULE.read_bytes() if MODULE.exists() else None
    if old_module is not None:
        (backup / MODULE.name).write_bytes(old_module)
    try:
        if not uninstall:
            MODULE.write_text(module)
        CONFIG.write_text(updated)
        run('hyprctl', 'reload')
        errors = run('hyprctl', 'configerrors')
        if errors:
            raise RuntimeError(errors)
        if not uninstall:
            after = json.loads(run('hyprctl', 'monitors', 'all', '-j'))
            new = next(x for x in after if x['name'] == 'eDP-1')
            if new['colorManagementPreset'] != 'dp3' or new['currentFormat'] != 'XRGB2101010':
                raise RuntimeError('P3/10-bit output did not activate.')
            keys = ['width','height','refreshRate','x','y','scale','transform','vrr','currentFormat','colorManagementPreset','sdrBrightness','sdrSaturation']
            for old in before:
                if old['name'] == 'eDP-1': continue
                new = next(x for x in after if x['name'] == old['name'])
                if any(old.get(k) != new.get(k) for k in keys):
                    raise RuntimeError('External display state changed; restoring configuration.')
        else:
            MODULE.unlink(missing_ok=True)
    except BaseException:
        CONFIG.write_text(original)
        if old_module is None: MODULE.unlink(missing_ok=True)
        else: MODULE.write_bytes(old_module)
        subprocess.run(['hyprctl', 'reload'], check=False)
        raise
    print(('Removed.' if uninstall else 'Applied nominal Display P3 / 10-bit SDR to eDP-1 only.') + f' Backup: {backup}')

try:
    main()
except Exception as exc:
    print(f'Error: {exc}', file=sys.stderr)
    sys.exit(1)
PY
