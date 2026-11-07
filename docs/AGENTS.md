# AGENTS.md

Counterclock: Monkey C / Connect IQ watch face. Read `README.md` for features. Keep instructions terse.

## Rules

- Personal project: no unrequested settings, permissions or abstractions.
- Target: `fr57042mm`, Forerunner 570 42mm, round AMOLED.
- Compile != visual validation. Owner tests simulator/watch; simulator can hide rendering defects.
- Signing key: `../developer_key`. Never commit or print it.
- `bin/` and `deploy/` are generated; stale `.mir` files require a clean build after source removal/rename.

## Code

- `CounterclockApp.mc`: initial face and `getSettingsView()` slider.
- `CounterclockView.mc`: drawing in `onUpdate`. Z-order: background, dial, date, notification, battery, hour, minute, second.
- `CounterclockBackground.mc`: layout drawable; clears with `getBackgroundColor()`.
- `CounterclockSettings.mc`: background via `Application.Storage`, default `#333333`; 0-50% grey slider, touch/up/down, saved in `onHide`.

## Drawing

- Mirrored dial: `x = cx - r*sin(a)`, `y = cy - r*cos(a)`, angle 0 at 12. Use this transform for all time-positioned elements.
- `clockRadius`: half the smaller screen dimension minus 10px. Keep new geometry proportional.
- Radius fractions: numerals 0.77, date outer edge 0.86, minute track 0.945-0.99, five-minute marks from 0.925.
- Date replaces hour 3, on the left (`DATE_HOUR`). `drawDial` skips its numeral.
- Notification/battery share `drawTrackSquare` and `TRACK_SQUARE_*`. Notification sits after minute 59, right of 12; after minute 0 its 1.6px outline looked uneven. Suspect sub-pixel alignment first.
- Battery: five squares in minute gaps 30-35, one per charge fifth, growing from 6. Hide unlit squares; faint outlines were ambiguous. Shared color uses `BATTERY_COLORS`/`BATTERY_THRESHOLDS`, independent of count. At/below `BATTERY_FLASH_PERCENT`, blink on odd seconds awake; steady asleep.
- Square outlines: outer polygon, smaller background-colored polygon over it.
- Hand shading: overlapping filled polygons. Parallel 1px lines caused on-watch moire despite looking fine in simulator; avoid sub-pixel-spaced lines.
- Keep `dc has :setAntiAlias` guard. For jagged shadows/second hand, consider polygons instead of thick lines.
- Fake gradients/shadows with `lerpColor`; fade to background, not alpha. Colors are view constants except stored background.

## Animation

- Normal updates: 1s awake, 1min asleep. Starting `Timer.start` or `WatchUi.animate` asleep crashes the face.
- Don't restore the old 200ms timer sweep: timer/clock boundary drift made motion uneven.
- Current sweep: 350ms native linear animation of public `secondSweepProgress` (0-1000); `getSecondHandAngle` applies cubic ease-out. `mLastSecond` prevents restart on animation frames.
- Unwrap 59-to-0 angle; snap on first display, wake or missed seconds. Cancel on sleep/hide; hide second hand asleep. Smoothness still needs simulator/watch validation.
- Owner considers normal Garmin animation battery impact negligible. Prioritize smoothness/correctness/power-state safety; flag drain only with evidence.

## Gotchas

- Sideloaded Garmin Connect settings don't work. Use `getSettingsView()` + `Application.Storage`; don't restore `Application.Properties`, settings/properties XML or the clunky RGB picker.
- Simulator: "Trigger App Settings" uses another mechanism. Storage: File > Edit Persistent Storage. Notifications: simulator settings.
- Test low battery, flashing and notifications in simulator; real-watch states aren't freely adjustable.
- Overrides must match base signatures; verify API docs. `PickerFactory.getValue`: `Object or Null`.
- Watch uses MTP, not Finder. Sideload `.prg` to `GARMIN/APPS/` via Windows/MTP tool with Garmin Express closed.

## Fonts

- Digits-only bitmaps in `resources/fonts/`, declared in `fonts.xml`. Generator: `tools/make_bitmap_font.py`; needs Pillow + Google Fonts TTFs (not in repo). OFL licenses alongside.
- Numerals: BhuTuka Expanded One, 46px. Check spacing before enlarging; `NUMERAL_MAX_REACH` shifts wide numerals inward (currently 10).
- Date: Zilla Slab Highlight, 32px, `--invert` to retain digits only. Black on lime `#cddc39` inset frame; old-style figures need the 1px downward nudge.
- Generate with 4x `--supersample`; trim glyph/line boxes for `TEXT_JUSTIFY_VCENTER`. Resize by regenerating `.fnt`/`.png`.
- `FONT_XTINY` has no bold; `getVectorFont` only exposes device faces. Custom typefaces need bitmaps.

## Build

Only build if asked. SDK isn't on PATH; `monkeybrains.jar` is under `~/Library/Application Support/Garmin/ConnectIQ/Sdks/`. Scratch output is fine.

```sh
monkeyc -f monkey.jungle -o bin/Counterclock.prg -y ../developer_key -d fr57042mm -w
```

Simulator: `-d fr57042mm_sim`. Harmless warnings: no declared languages (if present), 24x24 icon scaled to 54x54.

## TODO

- Shadows/second hand as anti-aliased polygons.
- Replace template launcher icon.
