import Toybox.Application.Storage;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

const BACKGROUND_COLOR_STORAGE_KEY = "BackgroundColor";
const DEFAULT_BACKGROUND_COLOR = 0x333333;

// Reads the on-device background color setting, falling back to dark grey on
// first run (before the slider below has ever been used to set one).
function getBackgroundColor() as Number {
    var stored = Storage.getValue(BACKGROUND_COLOR_STORAGE_KEY);
    return (stored != null) ? stored as Number : DEFAULT_BACKGROUND_COLOR;
}

// The one on-device setting: a slider for the background grey level, from
// jet black (0) to 50% grey (50). The screen itself is filled with the
// chosen color while adjusting, so it is a live preview. The value is saved
// when the screen is left.
class BackgroundSliderView extends WatchUi.View {
    private const MAX_LEVEL as Number = 50;
    private const BUTTON_STEP as Number = 2;

    private var mLevel as Number = 0;
    private var mBarLeft as Float = 0.0;
    private var mBarWidth as Float = 1.0;

    function initialize() {
        View.initialize();
        var red = (getBackgroundColor() >> 16) & 0xFF;
        setLevel((red * 100.0 / 255.0 + 0.5).toNumber());
    }

    function onUpdate(dc as Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var centerY = height / 2.0;

        dc.setColor(Graphics.COLOR_TRANSPARENT, levelToColor(mLevel));
        dc.clear();

        mBarWidth = width * 0.6;
        mBarLeft = (width - mBarWidth) / 2.0;
        var barHeight = 12.0;
        var barTop = centerY - barHeight / 2.0;

        var steps = 50;
        var stepWidth = mBarWidth / steps;
        for (var i = 0; i < steps; i += 1) {
            dc.setColor(levelToColor(MAX_LEVEL * i / (steps - 1.0)), Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(mBarLeft + i * stepWidth, barTop, stepWidth + 1, barHeight);
        }
        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRectangle(mBarLeft, barTop, mBarWidth, barHeight);

        var knobX = mBarLeft + mBarWidth * mLevel / MAX_LEVEL;
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(knobX, centerY, 11);

        dc.drawText(width / 2.0, centerY - 70, Graphics.FONT_XTINY, "BACKGROUND", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(width / 2.0, centerY - 40, Graphics.FONT_SMALL, mLevel.toString() + "%", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function onHide() as Void {
        Storage.setValue(BACKGROUND_COLOR_STORAGE_KEY, levelToColor(mLevel));
    }

    function adjust(delta as Number) as Void {
        setLevel(mLevel + delta * BUTTON_STEP);
    }

    function setLevelFromX(x as Number) as Void {
        setLevel(((x - mBarLeft) / mBarWidth * MAX_LEVEL + 0.5).toNumber());
    }

    private function setLevel(level as Number) as Void {
        mLevel = (level < 0) ? 0 : ((level > MAX_LEVEL) ? MAX_LEVEL : level);
        WatchUi.requestUpdate();
    }

    // Level is a percentage of white, so 50 is 0x808080.
    private function levelToColor(level as Numeric) as Number {
        var grey = (level * 255.0 / 100.0 + 0.5).toNumber();
        return (grey << 16) | (grey << 8) | grey;
    }
}

class BackgroundSliderDelegate extends WatchUi.BehaviorDelegate {
    private var mView as BackgroundSliderView;

    function initialize(view as BackgroundSliderView) {
        BehaviorDelegate.initialize();
        mView = view;
    }

    function onPreviousPage() as Boolean {
        mView.adjust(1);
        return true;
    }

    function onNextPage() as Boolean {
        mView.adjust(-1);
        return true;
    }

    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        mView.setLevelFromX(clickEvent.getCoordinates()[0]);
        return true;
    }

    function onDrag(dragEvent as WatchUi.DragEvent) as Boolean {
        mView.setLevelFromX(dragEvent.getCoordinates()[0]);
        return true;
    }

    // A horizontal drag would otherwise end as a swipe and exit the screen.
    function onSwipe(swipeEvent as WatchUi.SwipeEvent) as Boolean {
        return true;
    }

    function onSelect() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
}
