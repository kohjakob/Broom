import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(
      name: "com.broom/segmentation",
      binaryMessenger: controller.binaryMessenger
    )
    let segmentation = SubjectSegmentationHandler()
    channel.setMethodCallHandler(segmentation.handle)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
