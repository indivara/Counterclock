# AGENTS.md

Notes for anyone (human or AI) continuing work on Counterclock, a Monkey C / Connect IQ watch face. Read `README.md` first for what it does.

## Ground rules

- **Don't claim visual changes work.** The owner checks them in the simulator or on the watch. A compile only proves the code builds (see Build).
- Keep it simple. This is a personal watch face. Don't add settings, permissions, or abstractions that weren't asked for.
- Target device is `fr57042mm` (Forerunner 570 42mm, round AMOLED). Test visual changes on the real watch when possible; the simulator hides some problems (see Lessons).
- The developer signing key lives outside the repo (`../developer_key`). Never commit it or read it into output.
- `bin/` and `deploy/` are build output, including stale `.mir` files. After deleting or renaming source files, do a clean build.

## Architecture

- `CounterclockApp.mc`: `AppBase`. Returns `CounterclockView` as the initial view and the settings slider from `getSettingsView()`.
- `CounterclockView.mc`: everything visual, in `onUpdate`. Draw order is z-order: background layout, dial, date window, notification mark, battery squares, hour hand, minute hand, second hand.
- `CounterclockBackground.mc`: a `Drawable` used by `resources/layouts/layout.xml`. It only clears the screen using `getBackgroundColor()`.
- `CounterclockSettings.mc`: `getBackgroundColor()` (reads `Application.Storage`, default dark grey `#333333`), and the slider view and delegate for the one setting (grey level 0-50%, touch drag or up/down buttons, saved in `onHide`).

## Conventions

- **The dial is mirrored.** A point at angle `a` (0 = 12 o'clock, clockwise in ordinary maths) is drawn at `x = cx - r*sin(a)`, `y = cy - r*cos(a)`. The negated x is what makes everything run counterclockwise. Hands, numbers and any new element that follows the time must use the same transform, or the hands won't point at their numbers.
- Because of the mirroring, hour 3 is on the literal left of the screen, not the right. The date window sits there (`DATE_HOUR`): `drawDial` skips that numeral, and `drawDateWindow` puts its outer edge at `DATE_OUTER_RADIUS` (0.86) of `clockRadius`.
- Sizes are fractions of `clockRadius` (screen half-width minus 10px). Numerals sit at 0.77 of it (the date frame's outer edge at 0.86), the minute track at 0.945-0.99 (five-minute marks from 0.925). Keep new elements proportional, not in fixed pixels.
- The notification marker and the battery gauge share `drawTrackSquare` (outlined square in the gap after a given minute mark; size in the `TRACK_SQUARE_*` constants), so they stay identical. The notification square sits after minute 59 (just right of the 12, because the dial is mirrored; it was tried after minute 0, on the left, where its nearly horizontal top edge rendered visibly thicker than the rest of the outline because of how the 1.6px edge fell on the pixel grid; the right side looks normal on the watch. If an outlined square ever looks uneven, suspect sub-pixel alignment before the drawing method).
- The battery gauge lives in the minute track: `drawBatteryIndicator` draws one outlined square per fifth of the charge in the gaps of minutes 30-35, filling from the 6 side, and hides the rest. All lit squares use one color chosen from `BATTERY_COLORS` by `BATTERY_THRESHOLDS`; the count and the color change at different charge levels. At or below `BATTERY_FLASH_PERCENT` it blinks on odd seconds while awake (redraws are once a second then) and stays steady in low-power mode (`mIsSleeping`). Squares are an outer filled polygon with a smaller background-colored one on top, which gives a crisp anti-aliased outline. Unlit squares were tried as a faint outline and were too hard to tell apart from lit ones at this size.
- Gradients are faked. `Dc` has no gradient or alpha, so the code interpolates RGB with `lerpColor`. Shadows fade toward the background color rather than using transparency.
- Colors are constants at the top of `CounterclockView.mc`, except the background, which comes from storage.

## Lessons learned (don't repeat these)

- **Settings.** `settings.xml` / `properties.xml` app settings are not visible in Garmin Connect for sideloaded apps, so they were removed. The only setting uses `getSettingsView()` plus `Application.Storage` (an RGB hex picker was tried and dropped as too clunky), which works without the Store. Don't reintroduce `Application.Properties` for it.
- **Simulator settings.** "Trigger App Settings" is greyed out because it is for a different mechanism. The stored value can be inspected under File > Edit Persistent Storage. Simulated phone notifications are in the simulator's settings.
- **Moiré on device.** Drawing hand shading as thin parallel 1px lines looked fine in the simulator but shimmered on the watch. Hands are now overlapping filled polygons. Avoid sub-pixel-spaced lines. If edges look jagged, the shadow gradient segments and the second hand (thick `drawLine` calls) are the next candidates to convert to polygons.
- **Anti-aliasing.** `dc.setAntiAlias(true)` is guarded with `dc has :setAntiAlias`. Keep the guard.
- **Update rate.** In high-power (awake) mode `onUpdate` runs once a second, and per the SDK docs timers and animations may be used there (`onExitSleep` says so); in low-power mode it runs once a minute and `Timer.start` in a watch face *crashes the app*. So the second-hand sweep runs a repeating `Timer` (`SWEEP_INTERVAL_MS`) started in `onExitSleep`/`onShow` and stopped in `onEnterSleep`/`onHide`, and the second hand is hidden while `mIsSleeping`. Keep every `startSweep` behind a not-sleeping check. An earlier note here claimed timers were impossible; that was wrong (it came from a forum thread about low-power mode). Sub-second position comes from `System.getTimer()` since the clock has only whole seconds.
- **Override return types.** Monkey C requires overrides to match the base signature (e.g. an override of `PickerFactory.getValue` must return `Object or Null`). Check the API docs when overriding.
- **Fonts.** Numerals and date use digits-only bitmap fonts (`resources/fonts/`, declared in `fonts.xml`) generated with `tools/make_bitmap_font.py` (needs Pillow and the TTFs from Google Fonts, which are not in the repo; both fonts are OFL, licenses alongside): numerals are BhuTuka Expanded One at 46px (very wide, so check that neighbouring numerals and the minute marks still clear each other before enlarging), and the date is Zilla Slab Highlight at 32px. `drawDial` moves a numeral inward if its far corner would pass `NUMERAL_MAX_REACH` (currently only 10 is affected), so wide numerals stay clear of the minute marks. Zilla Slab Highlight draws each digit as a solid block with the digit cut out, so the date font is generated with `--invert` (only the digit remains, and the glyph and line box are trimmed to it) and drawn in black on the lime inset frame (`drawInsetFrame`, lime `#cddc39` fill with an inner shadow on all four sides). Its figures are old-style (3-9 hang below the baseline), hence the 1px text nudge in `drawDateWindow`. The frame's outer edge is at `DATE_OUTER_RADIUS` (0.86) of the dial radius, clear of the 3 o'clock minute mark. The script renders 4x supersampled and averages down (`--supersample`), because small hinted text looked jagged, and it fits each font's line box to the glyphs, so `TEXT_JUSTIFY_VCENTER` centers them exactly. Bitmap fonts are fixed-size; to change a size, rerun the script and update the `.fnt`/`.png`. The built-in `FONT_XTINY` has no bold weight, and `getVectorFont` only offers the device's own faces, so a different typeface needs a bitmap font.
- **Testing states you can't reach.** On the real watch the battery and notification states are whatever the watch currently has (the battery only goes down), so the low-charge colors, the flashing and the notification mark are checked in the simulator. The flash only works while the watch is awake, because low-power mode redraws once a minute.
- **Sideloading.** The watch uses MTP, so it doesn't appear in macOS Finder. Copy the `.prg` to `GARMIN/APPS/` from Windows or an MTP tool with Garmin Express closed.

## Build

The SDK is installed on the owner's machine (not on PATH); `monkeybrains.jar` under `~/Library/Application Support/Garmin/ConnectIQ/Sdks/` can compile to a scratch folder to catch errors. Only build if asked; the owner tests in the simulator and on the watch.

```sh
monkeyc -f monkey.jungle -o bin/Counterclock.prg -y ../developer_key -d fr57042mm -w
```

Use `-d fr57042mm_sim` for the simulator target. Expected harmless warnings: no languages declared in the manifest, and the 24x24 launcher icon being scaled to 54x54.

## Ideas not yet done

- Convert the shadows and second hand to anti-aliased polygons.
- Replace the template launcher icon.
