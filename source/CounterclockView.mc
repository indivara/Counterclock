import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

class CounterclockView extends WatchUi.WatchFace {

    private const SHADOW_OFFSET as Float = 1.5;
    private const DATE_BOX_FILL_COLOR as Number = 0xB0B0B0;
    private const DATE_BOX_HIGHLIGHT_COLOR as Number = 0xE0E0E0;
    private const DATE_TEXT_COLOR as Number = 0x000000;
    private const HAND_COLOR as Number = 0xFFFFFF;
    private const LOW_BATTERY_THRESHOLD as Float = 20.0;

    private var mIsSleeping as Boolean = false;

    function initialize() {
        WatchFace.initialize();
    }

    // Load your resources here
    function onLayout(dc as Dc) as Void {
        setLayout(Rez.Layouts.WatchFace(dc));
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

        drawNumbers(dc, centerX, centerY, clockRadius, handColor);
        drawDateWindow(dc, centerX, centerY, clockRadius);
        drawNotificationDot(dc, centerX, centerY, clockRadius);
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
            drawSecondHand(dc, centerX, centerY, secondAngle, clockRadius * 0.85, tailLength, 6, 2, Graphics.COLOR_RED, backgroundColor);
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

    // Draw the day of week and day of month, on one line, in a small inset
    // frame where the "3" used to be on the left side of the face (see the
    // matching skip in drawNumbers). Uses a fixed light grey / black
    // palette rather than the user's face colors, so the frame reads
    // clearly regardless of what BackgroundColor is set to.
    private function drawDateWindow(dc as Dc, centerX as Float, centerY as Float, clockRadius as Float) as Void {
        var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var weekday = (info.day_of_week as String).toUpper();
        var dayOfMonth = info.day.format("%02d");
        var dateText = weekday + " " + dayOfMonth;

        var font = Graphics.FONT_XTINY;
        var textDimensions = dc.getTextDimensions(dateText, font);
        var padding = 6.0;
        var boxWidth = textDimensions[0] + padding * 2;
        var boxHeight = textDimensions[1] + padding * 2;

        // Anchor to the left edge the "3" used to have, rather than its
        // center, so the wider date box doesn't creep closer to the
        // perimeter than the digit it replaced.
        var numberRadius = clockRadius * 0.80;
        var threeWidth = dc.getTextDimensions("3", Graphics.FONT_SMALL)[0];
        var left = (centerX - numberRadius) - threeWidth / 2.0;
        var boxCenterX = left + boxWidth / 2.0;
        var top = centerY - boxHeight / 2.0;

        drawInsetFrame(dc, left, top, boxWidth, boxHeight);

        // The built-in fonts have no bolder weight, so draw the text twice,
        // a pixel apart, to thicken the strokes.
        dc.setColor(DATE_TEXT_COLOR, Graphics.COLOR_TRANSPARENT);
        dc.drawText(boxCenterX - 0.5, centerY, font, dateText, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(boxCenterX + 0.5, centerY, font, dateText, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
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

        dc.setColor(DATE_BOX_HIGHLIGHT_COLOR, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(right, top, right, bottom);
        dc.drawLine(left, bottom, right, bottom);
    }

    // Draw a small dot above center when there's an unread notification --
    // nothing at all otherwise. Deliberately just a dot rather than a
    // count/text, to stay tiny and out of the way.
    private function drawNotificationDot(dc as Dc, centerX as Float, centerY as Float, clockRadius as Float) as Void {
        var notificationCount = System.getDeviceSettings().notificationCount;
        if (notificationCount > 0) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(centerX, centerY - clockRadius * 0.40, 2.5);
        }
    }

    // Draw a tiny battery level bar below center: a dim outline track plus
    // a fill proportional to charge, so no text/percentage is needed. Turns
    // red instead of the usual grey once charge drops below the threshold.
    private function drawBatteryIndicator(dc as Dc, centerX as Float, centerY as Float, clockRadius as Float) as Void {
        var batteryPercent = System.getSystemStats().battery;

        var barWidth = clockRadius * 0.26;
        var barHeight = 3.0;
        var left = centerX - barWidth / 2.0;
        var top = centerY + clockRadius * 0.40;

        dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRectangle(left, top, barWidth, barHeight);

        var fillWidth = barWidth * (batteryPercent / 100.0);
        var fillColor = (batteryPercent <= LOW_BATTERY_THRESHOLD) ? Graphics.COLOR_RED : 0xAAAAAA;
        dc.setColor(fillColor, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(left, top, fillWidth, barHeight);
    }

    // Draw the hour numbers around the edge of the face, laid out
    // counterclockwise (mirrored the same way as the hands) so each hand
    // still points at the correct number as time passes. The 3 is skipped
    // -- it falls on the left side of the face in this mirrored layout --
    // since the date window takes its place (see drawDateWindow).
    private function drawNumbers(dc as Dc, centerX as Float, centerY as Float, radius as Float, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var font = Graphics.FONT_SMALL;
        var numberRadius = radius * 0.80;
        for (var i = 1; i <= 12; i++) {
            if (i != 3) {
                var angle = i * (Math.PI / 6.0);
                var x = centerX - numberRadius * Math.sin(angle);
                var y = centerY - numberRadius * Math.cos(angle);
                dc.drawText(x, y, font, i.toString(), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
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
