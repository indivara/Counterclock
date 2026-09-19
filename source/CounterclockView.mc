import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

class CounterclockView extends WatchUi.WatchFace {

    private const SHADOW_OFFSET as Float = 1.5;
    private const DATE_BOX_FILL_COLOR as Number = 0xCDDC39;
    private const DATE_TEXT_COLOR as Number = 0x000000;
    private const HAND_COLOR as Number = 0xFFFFFF;
    private const DIAL_COLOR as Number = 0xAAAAAA;
    private const SECOND_HAND_COLOR as Number = 0xFF9800;
    private const NOTIFICATION_COLOR as Number = 0xFFC107;
    private const BATTERY_CRITICAL_PERCENT as Float = 10.0;
    private const BATTERY_LOW_PERCENT as Float = 20.0;
    private const BATTERY_WARNING_PERCENT as Float = 25.0;
    private const BATTERY_FRAME_COLOR as Number = 0x666666;
    private const BATTERY_DOT_COLOR as Number = 0xAAAAAA;
    private const BATTERY_DOT_BACKGROUND_COLOR as Number = 0x111111;
    private const BATTERY_WARNING_COLOR as Number = 0xFFEB3B;
    private const BATTERY_LOW_COLOR as Number = 0xFF7A00;
    private const BATTERY_CRITICAL_COLOR as Number = 0xFF0000;
    private const BATTERY_DOT_COUNT as Number = 8;
    private const BATTERY_DOT_RADIUS as Float = 1.6;
    private const BATTERY_DOT_PITCH as Float = 6.0;
    private const BATTERY_FRAME_PADDING as Float = 3.0;

    // Every hour gets a numeral except this one, where the date window
    // sits. Because the dial is mirrored, hour 3 is on the left.
    private const DATE_HOUR as Number = 3;

    private var mIsSleeping as Boolean = false;
    private var mNumeralFont as Graphics.FontType = Graphics.FONT_SMALL;
    private var mDateFont as Graphics.FontType = Graphics.FONT_XTINY;

    function initialize() {
        WatchFace.initialize();
    }

    // Load your resources here
    function onLayout(dc as Dc) as Void {
        setLayout(Rez.Layouts.WatchFace(dc));

        // Josefin Sans bitmap fonts, digits only (see tools/make_bitmap_font.py).
        mNumeralFont = WatchUi.loadResource(Rez.Fonts.NumeralFont) as Graphics.FontType;
        mDateFont = WatchUi.loadResource(Rez.Fonts.DateFont) as Graphics.FontType;
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() as Void {
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

        drawDial(dc, centerX, centerY, clockRadius, DIAL_COLOR);
        drawDateWindow(dc, centerX, centerY, clockRadius);
        drawNotificationMark(dc, centerX, centerY, clockRadius);
        drawBatteryIndicator(dc, centerX, centerY, clockRadius);

        var clockTime = System.getClockTime();
        var hours = clockTime.hour % 12;
        var minutes = clockTime.min;
        var seconds = clockTime.sec;

        var hourAngle = ((hours * 60 + minutes) / (12 * 60.0)) * 2 * Math.PI;
        var minuteAngle = ((minutes * 60 + seconds) / (60 * 60.0)) * 2 * Math.PI;
        var tailLength = clockRadius * 0.15;

        // Draw order is also z-order: hour hand on the bottom, then minute,
        // then second on top, covering the pivot where they all meet. The
        // hour hand is thicker than the minute hand so a sliver of it still
        // shows on both sides when they're parallel.
        drawHand(dc, centerX, centerY, hourAngle, clockRadius * 0.5, tailLength, 10, handColor, backgroundColor);
        drawHand(dc, centerX, centerY, minuteAngle, clockRadius * 0.75, tailLength, 4, handColor, backgroundColor);

        if (!mIsSleeping) {
            var secondAngle = (seconds / 60.0) * 2 * Math.PI;
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
    // the face, at the date's hour position (see DATE_HOUR). Uses a fixed
    // light grey / black palette rather than the face colors. The frame is
    // sized for two digits so it doesn't change size from day to day.
    private function drawDateWindow(dc as Dc, centerX as Float, centerY as Float, clockRadius as Float) as Void {
        var dayOfMonth = Gregorian.info(Time.now(), Time.FORMAT_SHORT).day.toString();

        var widest = dc.getTextDimensions("00", mDateFont);
        var padding = 6.0;
        var boxWidth = widest[0] + padding * 2;
        var boxHeight = widest[1] + padding * 2;

        // The outer edge sits well clear of the minute track and the
        // perimeter; the box extends inward from it.
        var left = centerX - clockRadius * 0.90;
        var boxCenterX = left + boxWidth / 2.0;
        var top = centerY - boxHeight / 2.0;

        drawInsetFrame(dc, left, top, boxWidth, boxHeight);

        dc.setColor(DATE_TEXT_COLOR, Graphics.COLOR_TRANSPARENT);
        dc.drawText(boxCenterX, centerY, mDateFont, dayOfMonth, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Draw a rectangular frame that looks pressed into the face: an inner
    // shadow along the top and left edges that is darkest at the edge and
    // fades into the fill over a few pixels (the recess casting shadow onto
    // its own floor), plus a light rim along the bottom and right edges
    // (catching the light).
    private function drawInsetFrame(dc as Dc, left as Float, top as Float, w as Float, h as Float) as Void {
        var right = left + w;
        var bottom = top + h;

        dc.setColor(DATE_BOX_FILL_COLOR, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(left, top, w, h);

        var shadowDepth = 4;
        var shadowColor = lerpColor(DATE_BOX_FILL_COLOR, 0x000000, 0.6);
        dc.setPenWidth(1);
        for (var i = 0; i < shadowDepth; i += 1) {
            dc.setColor(lerpColor(shadowColor, DATE_BOX_FILL_COLOR, i / (shadowDepth * 1.0)), Graphics.COLOR_TRANSPARENT);
            dc.drawLine(left + i, top + i, right - i, top + i);
            dc.drawLine(left + i, top + i, left + i, bottom - i);
        }

        dc.setColor(lerpColor(DATE_BOX_FILL_COLOR, 0xFFFFFF, 0.5), Graphics.COLOR_TRANSPARENT);
        dc.drawLine(right, top, right, bottom);
        dc.drawLine(left, bottom, right, bottom);
    }

    // When there is an unread notification, draw over the five-minute mark
    // at 12 in the notification color, a little thicker than the mark under
    // it -- nothing at all otherwise. Deliberately just a recolored mark
    // rather than a count, to stay tiny and out of the way. The hands never
    // reach that far out, so they never cover it.
    private function drawNotificationMark(dc as Dc, centerX as Float, centerY as Float, clockRadius as Float) as Void {
        var notificationCount = System.getDeviceSettings().notificationCount;
        if (notificationCount > 0) {
            dc.setColor(NOTIFICATION_COLOR, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(3);
            dc.drawLine(centerX, centerY - clockRadius * 0.925, centerX, centerY - clockRadius * 0.99);
        }
    }

    // Draw a tiny battery gauge below center: a row of dots, each an equal
    // share of charge (rounded up), inside a frame with a small gap around
    // them and a very dark fill showing between them. The dots are grey
    // normally, yellow at BATTERY_WARNING_PERCENT or below, orange at
    // BATTERY_LOW_PERCENT or below and red at BATTERY_CRITICAL_PERCENT or below.
    private function drawBatteryIndicator(dc as Dc, centerX as Float, centerY as Float, clockRadius as Float) as Void {
        var batteryPercent = System.getSystemStats().battery;

        var dotsWidth = (BATTERY_DOT_COUNT - 1) * BATTERY_DOT_PITCH + 2 * BATTERY_DOT_RADIUS;
        var frameWidth = dotsWidth + 2 * BATTERY_FRAME_PADDING;
        var frameHeight = 2 * BATTERY_DOT_RADIUS + 2 * BATTERY_FRAME_PADDING;
        var frameLeft = centerX - frameWidth / 2.0;
        var frameTop = centerY + clockRadius * 0.40;

        dc.setColor(BATTERY_DOT_BACKGROUND_COLOR, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(frameLeft, frameTop, frameWidth, frameHeight);
        dc.setColor(BATTERY_FRAME_COLOR, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRectangle(frameLeft, frameTop, frameWidth, frameHeight);

        var dotColor = BATTERY_DOT_COLOR;
        if (batteryPercent <= BATTERY_CRITICAL_PERCENT) {
            dotColor = BATTERY_CRITICAL_COLOR;
        } else if (batteryPercent <= BATTERY_LOW_PERCENT) {
            dotColor = BATTERY_LOW_COLOR;
        } else if (batteryPercent <= BATTERY_WARNING_PERCENT) {
            dotColor = BATTERY_WARNING_COLOR;
        }

        var litDots = Math.ceil(batteryPercent / 100.0 * BATTERY_DOT_COUNT).toNumber();
        dc.setColor(dotColor, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < litDots && i < BATTERY_DOT_COUNT; i += 1) {
            dc.fillCircle(frameLeft + BATTERY_FRAME_PADDING + BATTERY_DOT_RADIUS + i * BATTERY_DOT_PITCH,
                frameTop + frameHeight / 2.0, BATTERY_DOT_RADIUS);
        }
    }

    // Draw the dial: a minute track around the edge (the five-minute marks
    // longer and thicker) and Josefin Sans numerals for every hour except
    // DATE_HOUR. Everything is placed with the same mirrored transform as
    // the hands (x = cx - r*sin(angle)), so the numerals run counterclockwise
    // and each hand still points at the right one.
    private function drawDial(dc as Dc, centerX as Float, centerY as Float, radius as Float, color as Number) as Void {
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

        for (var hour = 1; hour <= 12; hour += 1) {
            if (hour != DATE_HOUR) {
                var angle = hour * (Math.PI / 6.0);
                var x = centerX - radius * 0.77 * Math.sin(angle);
                var y = centerY - radius * 0.77 * Math.cos(angle);
                dc.drawText(x, y, mNumeralFont, hour.toString(), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            }
        }
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() as Void {
    }

    // The user has just looked at their watch. Timers and animations may be started here.
    function onExitSleep() as Void {
        mIsSleeping = false;
    }

    // Terminate any active timers and prepare for slow updates.
    function onEnterSleep() as Void {
        mIsSleeping = true;
    }

}
