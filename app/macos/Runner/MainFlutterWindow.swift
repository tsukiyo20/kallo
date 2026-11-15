import Cocoa
import FlutterMacOS
import ImageIO
import UniformTypeIdentifiers

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    registerFrameChannel(flutterViewController)
    registerThumbnailChannel(flutterViewController)

    super.awakeFromNib()
  }

  /// The app draws its own caption, so the gesture a system title bar would
  /// have handled is the app's to perform. This hands the app the Mac's word
  /// for that gesture: the person's choice in System Settings, kept in the
  /// global defaults. An unset value is the system's own default.
  private func registerFrameChannel(_ controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "com.kallo.app/frame",
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "titleBarDoubleClick" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(UserDefaults.standard.string(forKey: "AppleActionOnDoubleClick"))
    }
  }

  /// Thumbnails are made by ImageIO, which can ask a decoder for a small image
  /// instead of decoding a 26-megapixel PNG and throwing most of it away.
  ///
  /// The channel runs off the main thread: a print that takes a moment must not
  /// stop the window. The result is the path the Dart side already chose.
  private func registerThumbnailChannel(_ controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "com.kallo.app/thumbnails",
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      guard
        call.method == "make",
        let arguments = call.arguments as? [String: Any],
        let input = arguments["input"] as? String,
        let output = arguments["output"] as? String,
        let width = arguments["width"] as? Int,
        width > 0
      else {
        result(FlutterMethodNotImplemented)
        return
      }
      DispatchQueue.global(qos: .utility).async {
        do {
          try Self.makeThumbnail(input: input, output: output, width: width)
          DispatchQueue.main.async { result(nil) }
        } catch {
          DispatchQueue.main.async {
            result(
              FlutterError(
                code: "thumbnail",
                message: "\(error)",
                details: nil
              )
            )
          }
        }
      }
    }
  }

  private static func makeThumbnail(
    input: String,
    output: String,
    width: Int
  ) throws {
    let sourceURL = URL(fileURLWithPath: input)
    let outputURL = URL(fileURLWithPath: output)
    guard
      let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil)
    else {
      throw ThumbnailFailure("the print could not be opened")
    }
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceShouldCacheImmediately: true,
      kCGImageSourceThumbnailMaxPixelSize: width,
    ]
    guard
      let image = CGImageSourceCreateThumbnailAtIndex(
        source,
        0,
        options as CFDictionary
      )
    else {
      throw ThumbnailFailure("the print has no thumbnail")
    }
    try? FileManager.default.removeItem(at: outputURL)
    guard
      let destination = CGImageDestinationCreateWithURL(
        outputURL as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
      )
    else {
      throw ThumbnailFailure("the thumbnail could not be written")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
      throw ThumbnailFailure("the thumbnail could not be finished")
    }
  }
}

private struct ThumbnailFailure: LocalizedError {
  init(_ message: String) {
    self.message = message
  }

  let message: String
  var errorDescription: String? { message }
}
