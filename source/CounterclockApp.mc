import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class CounterclockApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {
    }

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void {
    }

    // Return the initial view of your application here
    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [ new CounterclockView() ];
    }

    // The one on-device setting: background color, picked digit by digit as
    // a #RGB hex shorthand and stored locally (see CounterclockSettings.mc).
    function getSettingsView() as [Views] or [Views, InputDelegates] or Null {
        return [ buildBackgroundColorPicker(), new BackgroundColorPickerDelegate() ];
    }

}
