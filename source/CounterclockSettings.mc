import Toybox.Application.Storage;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

const BACKGROUND_COLOR_STORAGE_KEY = "BackgroundColor";
const DEFAULT_BACKGROUND_COLOR = 0x000000;

// Reads the on-device background color setting, falling back to black on
// first run (before the picker below has ever been used to set one).
function getBackgroundColor() as Number {
    var stored = Storage.getValue(BACKGROUND_COLOR_STORAGE_KEY);
    return (stored != null) ? stored as Number : DEFAULT_BACKGROUND_COLOR;
}

// One hex digit (0-F) per Picker column.
class HexDigitFactory extends WatchUi.PickerFactory {
    private const DIGITS as Array<String> = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F"];

    function initialize() {
        PickerFactory.initialize();
    }

    function getSize() as Number {
        return DIGITS.size();
    }

    function getValue(index as Number) as Object or Null {
        return index;
    }

    function getDrawable(index as Number, selected as Boolean) as WatchUi.Drawable? {
        return new WatchUi.Text({
            :text => DIGITS[index],
            :color => selected ? Graphics.COLOR_WHITE : Graphics.COLOR_LT_GRAY,
            :font => Graphics.FONT_NUMBER_MEDIUM,
            :locX => WatchUi.LAYOUT_HALIGN_CENTER,
            :locY => WatchUi.LAYOUT_VALIGN_CENTER
        });
    }
}

// The on-device settings entry point: a single #RGB (shorthand hex, each
// digit doubled to make a full byte) picker for the background color.
function buildBackgroundColorPicker() as WatchUi.Picker {
    var current = getBackgroundColor();
    var r = (current >> 16) & 0xFF;
    var g = (current >> 8) & 0xFF;
    var b = current & 0xFF;
    var defaults = [ (r >> 4) & 0xF, (g >> 4) & 0xF, (b >> 4) & 0xF ];

    var title = new WatchUi.Text({
        :text => "BG #RGB",
        :color => Graphics.COLOR_WHITE,
        :font => Graphics.FONT_TINY,
        :locX => WatchUi.LAYOUT_HALIGN_CENTER,
        :locY => WatchUi.LAYOUT_VALIGN_BOTTOM
    });

    return new WatchUi.Picker({
        :title => title,
        :pattern => [ new HexDigitFactory(), new HexDigitFactory(), new HexDigitFactory() ],
        :defaults => defaults
    });
}

class BackgroundColorPickerDelegate extends WatchUi.PickerDelegate {
    function initialize() {
        PickerDelegate.initialize();
    }

    function onAccept(values as Array) as Boolean {
        var r = values[0] as Number;
        var g = values[1] as Number;
        var b = values[2] as Number;
        var color = ((r * 16 + r) << 16) | ((g * 16 + g) << 8) | (b * 16 + b);

        Storage.setValue(BACKGROUND_COLOR_STORAGE_KEY, color);
        WatchUi.requestUpdate();
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    function onCancel() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
}
