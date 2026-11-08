package PACKAGE_NAME

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Transparent activity that runs the Dart `quickAddMain` entry point. */
class QuickAddActivity : FlutterActivity() {
    override fun getDartEntrypointFunctionName(): String = "quickAddMain"

    override fun getBackgroundMode(): FlutterActivityLaunchConfigs.BackgroundMode =
        FlutterActivityLaunchConfigs.BackgroundMode.transparent

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pocket_ledger/widget")
            .setMethodCallHandler { call, result ->
                if (call.method == "refresh") {
                    QuickAddWidget.refreshAll(applicationContext)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }
}
