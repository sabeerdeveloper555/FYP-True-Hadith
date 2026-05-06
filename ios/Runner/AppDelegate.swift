import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as! FlutterViewController
    let audioTrimChannel = FlutterMethodChannel(
      name: "com.example.true_hadith/audio_trim",
      binaryMessenger: controller.binaryMessenger
    )
    
    audioTrimChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      if call.method == "trimAudio" {
        guard let args = call.arguments as? [String: Any],
              let audioPath = args["audioPath"] as? String,
              let startSeconds = args["startSeconds"] as? Double,
              let endSeconds = args["endSeconds"] as? Double,
              let outputPath = args["outputPath"] as? String else {
          result(FlutterError(code: "INVALID_ARGUMENT", message: "Missing required arguments", details: nil))
          return
        }
        
        self.trimAudioFile(
          inputPath: audioPath,
          startSeconds: startSeconds,
          endSeconds: endSeconds,
          outputPath: outputPath,
          result: result
        )
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func trimAudioFile(
    inputPath: String,
    startSeconds: Double,
    endSeconds: Double,
    outputPath: String,
    result: @escaping FlutterResult
  ) {
    let inputURL = URL(fileURLWithPath: inputPath)
    let outputURL = URL(fileURLWithPath: outputPath)
    
    guard FileManager.default.fileExists(atPath: inputPath) else {
      result(FlutterError(code: "FILE_NOT_FOUND", message: "Input audio file not found: \(inputPath)", details: nil))
      return
    }
    
    let asset = AVAsset(url: inputURL)
    
    // Use M4A format for trimmed output (Whisper API supports M4A)
    // AVAssetExportSession works best with M4A format on iOS
    guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
      result(FlutterError(code: "EXPORT_ERROR", message: "Failed to create export session", details: nil))
      return
    }
    
    exportSession.outputURL = outputURL
    exportSession.outputFileType = .m4a
    exportSession.timeRange = CMTimeRange(
      start: CMTime(seconds: startSeconds, preferredTimescale: 600),
      duration: CMTime(seconds: endSeconds - startSeconds, preferredTimescale: 600)
    )
    
    exportSession.exportAsynchronously {
      switch exportSession.status {
      case .completed:
        result(outputPath)
      case .failed:
        result(FlutterError(
          code: "EXPORT_FAILED",
          message: exportSession.error?.localizedDescription ?? "Export failed",
          details: nil
        ))
      case .cancelled:
        result(FlutterError(code: "EXPORT_CANCELLED", message: "Export was cancelled", details: nil))
      default:
        result(FlutterError(code: "EXPORT_UNKNOWN", message: "Unknown export error", details: nil))
      }
    }
  }
}
