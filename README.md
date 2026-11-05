# Asahi XDR Color

Experimental, reversible **Display P3 / 10-bit SDR** preset for the built-in Liquid Retina XDR display on the **2021 16-inch M1 Max MacBook Pro**, running **Omarchy with Hyprland 0.56.2 Lua configuration**.

This is a nominal color-space preset, not a measured ICC calibration or an HDR enabler. Tested on one machine with linux-aurora 7.2.11.aurora14-1. Other kernels/firmware can behave differently. Hardware accuracy and native P3 output have not been verified with a meter.

## Install

Run from your normal desktop session, without sudo:

```bash
(d=$(mktemp -d) && trap 'rm -rf "$d"' EXIT && curl -fsSL https://raw.githubusercontent.com/RobbieUK1/asahi-xdr-color/main/install.sh -o "$d/install.sh" && bash "$d/install.sh")
```

The command downloads to a private temporary directory. Read the script before running it if desired. The download command fetches the current main branch.

The installer checks the model, compositor version and expected Omarchy Lua load order. It copies your current built-in resolution, refresh rate, position, scale and VRR into an explicit eDP-1 rule. It applies `cm = "dp3"`, `bitdepth = 10` and `sdr_eotf = "srgb"`, then checks compositor errors, active output format and external monitor settings. A failed validation restores the original configuration. No packages, kernel settings or external display rules are changed.

Backups are stored in `~/.local/state/asahi-xdr-color/`. The generated rule is in `~/.config/hypr/asahi-xdr-color.lua`, loaded after OmaControl and before Omarchy display toggles. If you change the laptop's layout later, update this rule too. Installation is idempotent; uninstall before recapturing a new layout.

The earlier bespoke `builtin-color.lua` configuration is detected and left alone; this installer is unnecessary on that already-configured machine.

## Undo

```bash
(d=$(mktemp -d) && trap 'rm -rf "$d"' EXIT && curl -fsSL https://raw.githubusercontent.com/RobbieUK1/asahi-xdr-color/main/install.sh -o "$d/install.sh" && bash "$d/install.sh") --uninstall
```

Uninstall removes only this installer's marked config block and its module, preserving unrelated edits. It does not remove an earlier bespoke installation.

## What to expect

- Hyprland reports `dp3` and `XRGB2101010` on eDP-1; this verifies framebuffer format, not optical accuracy or physical panel-link depth.
- Applications must communicate content color spaces correctly for wide-gamut content to be rendered correctly. sRGB content should retain its intended appearance.
- No saturation boost or brightness increase is applied. Apple specifies **500 nits SDR**, **1000 nits sustained full-screen XDR** and **1600 nits peak HDR** for this model. The inspected driver exposes no HDR signaling controls; an ICC file cannot add them.
- Current Aurora RGB surface handling uses native color tagging. Together with Apple's specified P3 panel, that motivates this nominal preset. This is an inference from current project source, not confirmation of the exact installed firmware's behavior. If your output path clamps to sRGB, this preset is inappropriate: undo it if colors look washed out or worse.
- Reliable calibration requires measuring this particular panel under its Linux output path with suitable instrumentation, then creating and validating a per-display SDR ICC. Generic P3 profiles and profiles from another laptop are not unit calibration.

## Sources

- [Apple specifications](https://support.apple.com/en-gb/111901)
- [Hyprland color and ICC documentation](https://wiki.hypr.land/configuring/core/monitors/colors/)
- [Aurora RGB surface tagging](https://github.com/omacom/linux-aurora/blob/integration/aurora/drivers/gpu/drm/apple/plane.c)
- [Aurora internal panel presentation](https://github.com/omacom/linux-aurora/blob/integration/aurora/drivers/gpu/drm/apple/iomfb_template.c)

## Development checks

`bash -n install.sh` and `python3 test_installer.py` (isolated mock desktop; does not change your display).
