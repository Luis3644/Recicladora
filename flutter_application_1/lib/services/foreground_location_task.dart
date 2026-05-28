import 'package:flutter_foreground_task/flutter_foreground_task.dart';

const String kStopLocationAction = 'stop_location';

@pragma('vm:entry-point')
void startLocationCallback() {
  FlutterForegroundTask.setTaskHandler(LocationForegroundTaskHandler());
}

class LocationForegroundTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onNotificationButtonPressed(String id) {
    if (id == kStopLocationAction) {
      FlutterForegroundTask.sendDataToMain({'action': kStopLocationAction});
      FlutterForegroundTask.stopService();
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {}
}
