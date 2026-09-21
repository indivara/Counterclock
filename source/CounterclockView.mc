import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Timer;
import Toybox.WatchUi;

class CounterclockView extends WatchUi.WatchFace {

    private const SHADOW_OFFSET as Float = 1.5;
    private const HAND_COLOR as Number = 0xEFEFEF;
    private const DIAL_COLOR as Number = 0xAAAAAA;
    private const NUMERAL_COLOR as Number = 0xFFFFFF;
    private const SECOND_HAND_COLOR as Number = 0xFF9800;
    private const NOTIFICATION_COLOR as Number = 0xFFC107;

    // Battery gauge: five outlined squares in the gaps of the minute track
    // between the 6 and 7 marks (minutes 30 to 35). Each square stands for an
    // equal fifth of the charge and is hidden when its fifth is empty, so the
    // gauge grows from the 6 towards the 7 as the charge rises. Every lit
    // square shares one color, chosen by charge: BATTERY_COLORS[i] applies
    // above BATTERY_THRESHOLDS[i], and the last color below all of them. At
    // or below BATTERY_FLASH_PERCENT the squares blink once a second.
    private const BATTERY_COLORS as Array<Number> = [0x325A64, 0xF1A512, 0xDD4111, 0x8C0027];
    private const BATTERY_THRESHOLDS as Array<Number> = [30, 20, 10];
    private const BATTERY_FLASH_PERCENT as Float = 3.0;
    private const BATTERY_SQUARE_COUNT as Number = 5;
    private const TRACK_SQUARE_RADIUS as Float = 0.9675;
    private const TRACK_SQUARE_HALF_SIDE as Float = 3.5;
    private const TRACK_SQUARE_OUTLINE as Float = 1.6;
    private const BATTERY_FIRST_MINUTE as Number = 30;

    // Every hour gets a numeral except this one, where the date window
    // sits. Because the dial is mirrored, hour 3 is on the left.
    private const DATE_HOUR as Number = 3;
    private const DATE_PADDING_X as Number = 8;
    private const DATE_PADDING_Y as Number = 5;
    private const DATE_OUTER_RADIUS as Float = 0.86;
    private const DATE_BOX_FILL_COLOR as Number = 0xCDDC39;
    private const DATE_TEXT_COLOR as Number = 0x000000;

    // Numerals sit at NUMERAL_RADIUS of the dial radius, moved inward if
    // their far corner would reach past NUMERAL_MAX_REACH, so wide ones like
    // 10 stay clear of the minute marks.
    private const NUMERAL_RADIUS as Float = 0.77;
    private const NUMERAL_MAX_REACH as Float = 0.89;

    // While the watch is awake (high-power mode) a timer redraws the face this
    // often so the second hand sweeps; the SDK forbids timers in low-power mode.
    private const SWEEP_INTERVAL_MS as Number = 200;

    private var mIsSleeping as Boolean = false;
    private var mSweepTimer as Timer.Timer? = null;
    private var mLastSecond as Number = -1;
    private var mSecondStartMs as Number = 0;
    private var mNumeralFont as Graphics.FontType = Graphics.FONT_SMALL;
    private var mDateFont as Graphics.FontType = Graphics.FONT_XTINY;

    function initialize() {
        WatchFace.initialize();
    }

    // Load your resources here
    function onLayout(dc as Dc) as Void {
        setLayout(Rez.Layouts.WatchFace(dc));

        // BhuTuka Expanded One (numerals) and Zilla Slab Highlight (date)
        // bitmap fonts, digits only (see tools/make_bitmap_font.py).
        mNumeralFont = WatchUi.loadResource(Rez.Fonts.NumeralFont) as Graphics.FontType;
        mDateFont = WatchUi.loadResource(Rez.Fonts.DateFont) as Graphics.FontType;
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() as Void {
        if (System has :getDisplayMode && System.getDisplayMode() == System.DISPLAY_MODE_LOW_POWER) {
            mIsSleeping = true;
        } else {
            startSweep();
        }
    }

    // Update the view
    function onUpdate(dc as Dc) as Void {
        // Draw the background first so the hands are drawn on top of it
        View.onUpdate(dc);

        var handColor = HAND_COLOR;
        var backgroundColor = getBackgroundColor();
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }

        var width = dc.getWidth();
        var height = dc.getHeight();
        var centerX = width / 2.0;
        var centerY = height / 2.0;
        var clockRadius = (width < height ? width : height) / 2.0 - 10.0;

        drawDial(dc, centerX, centerY, clockRadius, DIAL_COLOR, NUMERAL_COLOR);
        drawDateWindow(dc, centerX, centerY, clockRadius);
        drawNotificationMark(dc, centerX, centerY, clockRadius, backgroundColor);
        drawBatteryIndicator(dc, centerX, centerY, clockRadius, backgroundColor);

        var clockTime = System.getClockTime();
        var hours = clockTime.hour % 12;
        var minutes = clockTime.min;
        var seconds = clockTime.sec;

        // Fraction of the current second that has elapsed, for the sweep. The
        // clock only has whole seconds, so it is measured from when the
        // second was first seen to change; without the timer, redraws land
        // on the second and the hand simply ticks.
        var secondFraction = 0.0;
        if (!mIsSleeping) {
            var nowMs = System.getTimer();
            if (seconds != mLastSecond) {
                mLastSecond = seconds;
                mSecondStartMs = nowMs;
            }
            secondFraction = (nowMs - mSecondStartMs) / 1000.0;
            if (secondFraction > 1.0) {
                secondFraction = 1.0;
            }
        }

        var hourAngle = ((hours * 60 + minutes) / (12 * 60.0)) * 2 * Math.PI;
        var minuteAngle = ((minutes * 60 + seconds + secondFraction) / (60 * 60.0)) * 2 * Math.PI;
        var tailLength = clockRadius * 0.15;

        // Draw order is also z-order: hour hand on the bottom, then minute,
        // then second on top, covering the pivot where they all meet. The
        // hour hand is thicker than the minute hand so a sliver of it still
        // shows on both sides when they're parallel.
        drawHand(dc, centerX, centerY, hourAngle, clockRadius * 0.5, tailLength, 10, handColor, backgroundColor);
        drawHand(dc, centerX, centerY, minuteAngle, clockRadius * 0.75, tailLength, 4, handColor, backgroundColor);

        if (!mIsSleeping) {
            var secondAngle = ((seconds + secondFraction) / 60.0) * 2 * Math.PI;
            drawSecondHand(dc, centerX, centerY, secondAngle, clockRadius * 0.85, tailLength, 6, 2, SECOND_HAND_COLOR, backgroundColor);
        }
    }

    // Draw a single hand as a line running from a short tail past the
    // center out to the tip. The x term is mirrored (negated) so hands
    // sweep counterclockwise while 12 stays at the top and 6 at the bottom.
    // Its shadow fades from the pivot towards both ends; the hand body
    // itself is shaded across its width (see drawConvexHand) so it reads
    // as a slightly rounded rod rather than a flat bar.
    private function drawHand(dc as Dc, centerX as Float, centerY as Float, angle as Float, tipLength as Float, tailLength as Float, penWidth as Number, color as Number, backgroundColor as Number) as Void {
        var tipX = centerX - tipLength * Math.sin(angle);
        var tipY = centerY - tipLength * Math.cos(angle);
        var tailX = centerX + tailLength * Math.sin(angle);
        var tailY = centerY + tailLength * Math.cos(angle);

        var shadowCenterColor = lerpColor(backgroundColor, 0x000000, 0.25);
        drawGradientLine(dc, tailX + SHADOW_OFFSET, tailY + SHADOW_OFFSET, tipX + SHADOW_OFFSET, tipY + SHADOW_OFFSET,
            tailLength, tipLength, 0.0, 1.0, penWidth, shadowCenterColor, backgroundColor);

        drawConvexHand(dc, tailX, tailY, tipX, tipY, angle, penWidth, color);
    }

    // Shade a hand across its width -- light on one edge, dark on the
    // other -- giving it a slightly convex, rounded-rod look. Built from
    // overlapping filled polygons rather than thin parallel lines: the first
    // covers the full width in the dark color, and each later one is
    // narrower, stopping short of the dark edge, in a lighter color. Because
    // the layers overlap there are no seams, and polygon edges are
    // anti-aliased by the device (thin sub-pixel lines shimmered into a
    // moire pattern on the real display).
    private function drawConvexHand(dc as Dc, tailX as Float, tailY as Float, tipX as Float, tipY as Float, angle as Float, penWidth as Number, color as Number) as Void {
        var lightColor = lerpColor(color, 0xFFFFFF, 0.55);
        var darkColor = lerpColor(color, 0x000000, 0.55);

        // Perpendicular to the hand's direction (-sin, -cos): the light edge
        // is on the -perp side, the dark edge on the +perp side.
        var perpX = Math.cos(angle);
        var perpY = -Math.sin(angle);

        var half = penWidth / 2.0;
        var layers = 4;
        for (var i = 0; i < layers; i += 1) {
            var edge = half - penWidth * i / layers;
            dc.setColor(lerpColor(darkColor, lightColor, i / (layers - 1.0)), Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([
                [tailX - perpX * half, tailY - perpY * half],
                [tipX - perpX * half, tipY - perpY * half],
                [tipX + perpX * edge, tipY + perpY * edge],
                [tailX + perpX * edge, tailY + perpY * edge]
            ]);
        }
    }

    // Draw the second hand with a thick section spanning the pivot (tail
    // through to just past center) and a thin section for the rest of its
    // length out to the tip, e.g. ==.=---------  (. is the center). Its
    // shadow follows the same darker-at-the-pivot, fading-to-the-edges
    // shape as the other hands' shadows.
    private function drawSecondHand(dc as Dc, centerX as Float, centerY as Float, angle as Float, tipLength as Float, tailLength as Float, thickPenWidth as Number, thinPenWidth as Number, color as Number, backgroundColor as Number) as Void {
        var pastCenterLength = tailLength / 2.0;
        var boundary = (tailLength + pastCenterLength) / (tailLength + tipLength);

        var tailX = centerX + tailLength * Math.sin(angle);
        var tailY = centerY + tailLength * Math.cos(angle);
        var pastCenterX = centerX - pastCenterLength * Math.sin(angle);
        var pastCenterY = centerY - pastCenterLength * Math.cos(angle);
        var tipX = centerX - tipLength * Math.sin(angle);
        var tipY = centerY - tipLength * Math.cos(angle);

        var shadowTailX = tailX + SHADOW_OFFSET;
        var shadowTailY = tailY + SHADOW_OFFSET;
        var shadowTipX = tipX + SHADOW_OFFSET;
        var shadowTipY = tipY + SHADOW_OFFSET;
        var shadowCenterColor = lerpColor(backgroundColor, 0x000000, 0.25);

        drawGradientLine(dc, shadowTailX, shadowTailY, shadowTipX, shadowTipY, tailLength, tipLength,
            0.0, boundary, thickPenWidth, shadowCenterColor, backgroundColor);
        drawGradientLine(dc, shadowTailX, shadowTailY, shadowTipX, shadowTipY, tailLength, tipLength,
            boundary, 1.0, thinPenWidth, shadowCenterColor, backgroundColor);

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);

        dc.setPenWidth(thickPenWidth);
        dc.drawLine(tailX, tailY, pastCenterX, pastCenterY);

        dc.setPenWidth(thinPenWidth);
        dc.drawLine(pastCenterX, pastCenterY, tipX, tipY);
    }

    // Draw a line, from tail point (x1,y1) to tip point (x2,y2), as several
    // segments spanning the t range [tStart, tEnd] (0 at the tail, 1 at the
    // tip), colored centerColor at the pivot -- located at
    // tailLength / (tailLength + tipLength) -- fading to edgeColor at
    // t = 0 and t = 1. Used both for the hands themselves and, offset by a
    // couple pixels, for their shadows.
    private function drawGradientLine(dc as Dc, x1 as Float, y1 as Float, x2 as Float, y2 as Float, tailLength as Float, tipLength as Float, tStart as Float, tEnd as Float, penWidth as Number, centerColor as Number, edgeColor as Number) as Void {
        var tCenter = tailLength / (tailLength + tipLength);
        var segments = 6;
        dc.setPenWidth(penWidth);
        for (var i = 0; i < segments; i += 1) {
            var t0 = tStart + (tEnd - tStart) * (i / (segments * 1.0));
            var t1 = tStart + (tEnd - tStart) * ((i + 1) / (segments * 1.0));
            var tMid = (t0 + t1) / 2.0;
            var factor = (tMid < tCenter) ? (tCenter - tMid) / tCenter : (tMid - tCenter) / (1.0 - tCenter);

            var sx = x1 + (x2 - x1) * t0;
            var sy = y1 + (y2 - y1) * t0;
            var ex = x1 + (x2 - x1) * t1;
            var ey = y1 + (y2 - y1) * t1;
            dc.setColor(lerpColor(centerColor, edgeColor, factor), Graphics.COLOR_TRANSPARENT);
            dc.drawLine(sx, sy, ex, ey);
        }
    }

    // Linearly interpolate between two 0xRRGGBB colors; t is clamped to [0, 1].
    private function lerpColor(colorA as Number, colorB as Number, t as Float) as Number {
        var clampedT = t;
        if (clampedT < 0.0) {
            clampedT = 0.0;
        } else if (clampedT > 1.0) {
            clampedT = 1.0;
        }

        var ar = (colorA >> 16) & 0xFF;
        var ag = (colorA >> 8) & 0xFF;
        var ab = colorA & 0xFF;
        var br = (colorB >> 16) & 0xFF;
        var bg = (colorB >> 8) & 0xFF;
        var bb = colorB & 0xFF;

        var r = (ar + (br - ar) * clampedT).toNumber();
        var g = (ag + (bg - ag) * clampedT).toNumber();
        var b = (ab + (bb - ab) * clampedT).toNumber();

        return (r << 16) | (g << 8) | b;
    }

    // Draw the day of the month in a small inset frame on the left side of
    // the face, at the date's hour position (see DATE_HOUR). The frame is
    // sized for two digits so it doesn't change size from day to day, and its
    // outer edge sits well clear of the minute track and the perimeter; it
    // extends inward from there. Zilla Slab Highlight has old-style figures
    // (some digits hang below the baseline), so the text is nudged down a
    // pixel to centre the common digits in the frame. All coordinates are
    // whole pixels so nothing lands between pixels.
    private function drawDateWindow(dc as Dc, centerX as Float, centerY as Float, clockRadius as Float) as Void {
        var dayOfMonth = Gregorian.info(Time.now(), Time.FORMAT_SHORT).day.toString();

        var widest = dc.getTextDimensions("00", mDateFont);
        var width = widest[0] + 2 * DATE_PADDING_X;
        var height = widest[1] + 2 * DATE_PADDING_Y;

        var left = (centerX - clockRadius * DATE_OUTER_RADIUS).toNumber();
        var top = (centerY - height / 2.0).toNumber();

        drawInsetFrame(dc, left, top, width, height);

        dc.setColor(DATE_TEXT_COLOR, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left + width / 2, top + height / 2 + 1, mDateFont, dayOfMonth, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Draw a rectangular frame that looks pressed into the face: an inner
    // shadow all the way around that is darkest at the edge and fades into
    // the fill over a few pixels (the recess casting shadow onto its own
    // floor), plus a light rim just outside the bottom and right edges
    // (catching the light).
    private function drawInsetFrame(dc as Dc, left as Number, top as Number, w as Number, h as Number) as Void {
        var right = left + w;
        var bottom = top + h;

        dc.setColor(DATE_BOX_FILL_COLOR, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(left, top, w, h);

        var shadowDepth = 4;
        var shadowColor = lerpColor(DATE_BOX_FILL_COLOR, 0x000000, 0.4);
        dc.setPenWidth(1);
        for (var i = 0; i < shadowDepth; i += 1) {
            dc.setColor(lerpColor(shadowColor, DATE_BOX_FILL_COLOR, i / (shadowDepth * 1.0)), Graphics.COLOR_TRANSPARENT);
            dc.drawLine(left + i, top + i, right - 1 - i, top + i);
            dc.drawLine(left + i, bottom - 1 - i, right - 1 - i, bottom - 1 - i);
            dc.drawLine(left + i, top + i, left + i, bottom - 1 - i);
            dc.drawLine(right - 1 - i, top + i, right - 1 - i, bottom - 1 - i);
        }

        dc.setColor(lerpColor(DATE_BOX_FILL_COLOR, 0xFFFFFF, 0.5), Graphics.COLOR_TRANSPARENT);
        dc.drawLine(right, top, right, bottom);
        dc.drawLine(left, bottom, right, bottom);
    }

    // When there is an unread notification, draw a square identical to the
    // battery gauge's in the notification color in the gap right before the
    // 12 mark (between the 59 and 0 minute marks, on the right of the 12
    // because the dial is mirrored) -- nothing at all otherwise.
    // Deliberately just a marker rather than a count, to stay tiny and out of
    // the way. The hands never reach that far out, so they never cover it.
    private function drawNotificationMark(dc as Dc, centerX as Float, centerY as Float, clockRadius as Float, backgroundColor as Number) as Void {
        if (System.getDeviceSettings().notificationCount > 0) {
            drawTrackSquare(dc, centerX, centerY, clockRadius, 59, NOTIFICATION_COLOR, backgroundColor);
        }
    }

    // Draw the battery gauge: up to five small outlined squares in the gaps
    // between the minute marks from 6 to 7, not touching them. One square
    // per fifth of the charge, rounded up, filling from the 6 side; the rest
    // are not drawn at all. At very low charge they blink while the watch is
    // awake (the face redraws once a second then); in low-power mode, which
    // redraws only once a minute, they stay on so the warning is never lost.
    private function drawBatteryIndicator(dc as Dc, centerX as Float, centerY as Float, clockRadius as Float, backgroundColor as Number) as Void {
        var batteryPercent = System.getSystemStats().battery;

        if (batteryPercent <= BATTERY_FLASH_PERCENT && !mIsSleeping && System.getClockTime().sec % 2 == 1) {
            return;
        }

        var color = BATTERY_COLORS[BATTERY_COLORS.size() - 1];
        for (var i = 0; i < BATTERY_THRESHOLDS.size(); i += 1) {
            if (batteryPercent > BATTERY_THRESHOLDS[i]) {
                color = BATTERY_COLORS[i];
                break;
            }
        }

        var litSquares = Math.ceil(batteryPercent / 100.0 * BATTERY_SQUARE_COUNT).toNumber();

        for (var i = 0; i < litSquares && i < BATTERY_SQUARE_COUNT; i += 1) {
            drawTrackSquare(dc, centerX, centerY, clockRadius, BATTERY_FIRST_MINUTE + i, color, backgroundColor);
        }
    }

    // Draw a small outlined square in the gap of the minute track that
    // follows the given minute mark, not touching either mark. It is an outer
    // filled polygon with a smaller background-colored one on top, which
    // gives a crisp anti-aliased outline. Used by the battery gauge and the
    // notification marker so the two are identical apart from color.
    private function drawTrackSquare(dc as Dc, centerX as Float, centerY as Float, clockRadius as Float, minute as Number, color as Number, backgroundColor as Number) as Void {
        var angle = (minute + 0.5) * (Math.PI / 30.0);
        var squareRadius = clockRadius * TRACK_SQUARE_RADIUS;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(squareCorners(centerX, centerY, angle, squareRadius, TRACK_SQUARE_HALF_SIDE));
        dc.setColor(backgroundColor, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(squareCorners(centerX, centerY, angle, squareRadius, TRACK_SQUARE_HALF_SIDE - TRACK_SQUARE_OUTLINE));
    }

    // Corners of a square centered squareRadius from the center at the given
    // (mirrored) angle, with its sides parallel and perpendicular to the
    // radius.
    private function squareCorners(centerX as Float, centerY as Float, angle as Float, squareRadius as Float, halfSide as Float) as Array<Graphics.Point2D> {
        var s = Math.sin(angle);
        var c = Math.cos(angle);
        var x = centerX - squareRadius * s;
        var y = centerY - squareRadius * c;
        return [
            [x - halfSide * (s + c), y - halfSide * (c - s)],
            [x - halfSide * (s - c), y - halfSide * (c + s)],
            [x + halfSide * (s + c), y + halfSide * (c - s)],
            [x + halfSide * (s - c), y + halfSide * (c + s)]
        ] as Array<Graphics.Point2D>;
    }

    // Draw the dial: a minute track around the edge (the five-minute marks
    // longer and thicker) and BhuTuka Expanded One numerals for every hour except
    // DATE_HOUR. Everything is placed with the same mirrored transform as
    // the hands (x = cx - r*sin(angle)), so the numerals run counterclockwise
    // and each hand still points at the right one.
    private function drawDial(dc as Dc, centerX as Float, centerY as Float, radius as Float, color as Number, numeralColor as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        for (var m = 0; m < 60; m += 1) {
            var angle = m * (Math.PI / 30.0);
            var s = Math.sin(angle);
            var c = Math.cos(angle);
            var isHourMark = (m % 5 == 0);
            var innerRadius = radius * (isHourMark ? 0.925 : 0.945);
            dc.setPenWidth(isHourMark ? 2 : 1);
            dc.drawLine(centerX - innerRadius * s, centerY - innerRadius * c,
                centerX - radius * 0.99 * s, centerY - radius * 0.99 * c);
        }

        dc.setColor(numeralColor, Graphics.COLOR_TRANSPARENT);
        for (var hour = 1; hour <= 12; hour += 1) {
            if (hour != DATE_HOUR) {
                var angle = hour * (Math.PI / 6.0);
                var text = hour.toString();
                var size = dc.getTextDimensions(text, mNumeralFont);

                var numeralRadius = radius * NUMERAL_RADIUS;
                var x = centerX - numeralRadius * Math.sin(angle);
                var y = centerY - numeralRadius * Math.cos(angle);
                for (var i = 0; i < 20; i += 1) {
                    var reachX = (x - centerX).abs() + size[0] / 2.0;
                    var reachY = (y - centerY).abs() + size[1] / 2.0;
                    if (Math.sqrt(reachX * reachX + reachY * reachY) <= radius * NUMERAL_MAX_REACH) {
                        break;
                    }
                    numeralRadius *= 0.99;
                    x = centerX - numeralRadius * Math.sin(angle);
                    y = centerY - numeralRadius * Math.cos(angle);
                }
                dc.drawText(x, y, mNumeralFont, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            }
        }
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() as Void {
        stopSweep();
    }

    // The user has just looked at their watch: back to once-per-second
    // updates, so the sweep timer may start.
    function onExitSleep() as Void {
        mIsSleeping = false;
        startSweep();
    }

    // Timers must be stopped before low-power mode, where starting one
    // crashes the app; updates drop to once a minute.
    function onEnterSleep() as Void {
        mIsSleeping = true;
        stopSweep();
    }

    private function startSweep() as Void {
        if (mSweepTimer == null) {
            var timer = new Timer.Timer();
            timer.start(method(:onSweepTick), SWEEP_INTERVAL_MS, true);
            mSweepTimer = timer;
        }
    }

    private function stopSweep() as Void {
        var timer = mSweepTimer;
        if (timer != null) {
            timer.stop();
            mSweepTimer = null;
        }
    }

    function onSweepTick() as Void {
        WatchUi.requestUpdate();
    }

}
