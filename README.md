# Counterclock

An analog watch face for Garmin watches, written in Monkey C (Connect IQ), in which time runs **backwards**: the numbers are laid out counterclockwise and the hands sweep counterclockwise. 12 stays at the top and 6 at the bottom, and the hands still point at the right number.

Built as a personal watch face for the Forerunner 570 (42mm). It is sideloaded rather than published to the Connect IQ Store.

## Features

- Mirrored dial: numbers run 12, 1, 2 ... counterclockwise, and all three hands sweep counterclockwise.
- Hour and minute hands are shaded across their width so they look slightly rounded. The hour hand is wider than the minute hand, so it still shows from behind when they overlap.
- Red second hand with a thick hub and a thin needle. It is hidden in low-power mode.
- Soft drop shadows under all hands. Stacking order is hour, minute, second.
- Date (weekday and day of month) in an inset panel, in the place where the 3 would be.
- Tiny unread-notification dot above the center, drawn only when there is a notification.
- Tiny battery bar below the center. It turns red at 20% or below.
- One on-device setting: background color, entered as a `#RGB` hex value.

## Requirements

- [Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) (developed against 9.2.0)
- Visual Studio Code with the Garmin Monkey C extension (or the SDK command line)
- A Connect IQ developer key

The target device is set in `manifest.xml` (`fr57042mm`). Add more `<iq:product>` entries to support other watches. Colors and layout are proportional to the screen size, but only the Forerunner 570 42mm has been tested.

## Build and run

In VS Code, run **Monkey C: Build Current Project** or press F5 to launch the simulator. From the command line:

```sh
monkeyc -f monkey.jungle -o bin/Counterclock.prg -y /path/to/developer_key -d fr57042mm -w
```

Keep your developer key outside the repository.

## Install on a watch

1. Build a `.prg` for the target device (above).
2. Connect the watch by USB. The Forerunner 570 uses MTP, so it does not mount as a drive on macOS. Use Windows, or an MTP tool such as [OpenMTP](https://openmtp.ganeshrvel.com/), and quit Garmin Express first.
3. Copy `Counterclock.prg` to `GARMIN/APPS/` on the watch and eject.
4. Choose Counterclock from the watch's watch-face menu.

## Settings

The background color is set on the watch, not in Garmin Connect. Open the watch face's settings and enter the color one hex digit at a time; each digit is doubled, so `#F80` becomes `#FF8800`. The value is stored with `Application.Storage`. The default is black.

Garmin Connect Mobile only shows `settings.xml` app settings for apps that are registered with the Connect IQ Store, so a sideloaded face can't use them.

## Project layout

```
manifest.xml                 App id, target devices, permissions
monkey.jungle                Build configuration
source/CounterclockApp.mc    App entry point, settings entry point
source/CounterclockView.mc   All drawing: dial, date, hands, indicators
source/CounterclockBackground.mc  Clears the screen to the background color
source/CounterclockSettings.mc    Background color storage and hex picker
resources/                   Strings, layout, launcher icon
docs/AGENTS.md               Notes for future development
```

## License

Licensed under the [GNU General Public License v3.0](LICENSE).

## Limitations

- Watch faces can update at most once per second while awake (once a minute in low-power mode), so the second hand ticks rather than sweeps. This is a platform limit.
- The built-in fonts have no bolder weight, so the date text is drawn twice, a pixel apart, to thicken it.
