import UIKit
import IMGLYEngine
@_spi(Fork) import IMGLYCamera
@_spi(Internal) import IMGLYCamera
@_spi(Internal) import IMGLYCore
@_spi(Internal) import IMGLYCoreUI
@_spi(Internal) import IMGLYEditor

public extension OnCreate {
  /// Creates a callback that loads the output of the camera as scene and the default and demo asset sources.
  /// - Parameter result: The camera result to load a scene with.
  /// - Returns: The callback.
  static func loadVideos(from result: CameraResult) -> Callback {
    { engine in
      try await engine.createScene(from: result)
      try await engine.loadDefaultAndDemoAssetSources()
    }
  }
}

@_spi(Fork) public extension OnCreate {
  /// Creates a callback that loads the camera output as a scene and then loads the default and demo asset sources.
  /// - Parameters:
  ///   - result: The `CameraResult` produced by the camera that should be used to create the scene.
  ///   - size: An optional target `CGSize` to which the created scene should be constrained. Pass `nil` to use the source dimensions.
  ///   - maxTrimmingDuration: An optional maximum duration, in seconds, used to trim the loaded video(s). Pass `nil` to keep the full duration.
  /// - Returns: A `Callback` that, when executed with an engine, creates a scene from the provided camera result (respecting the optional size and trimming limit) and loads the default and demo asset sources.
  /// - Note: This variant is available via the Fork SPI and extends the basic loader with optional sizing and trimming controls.
  static func loadVideos(
    from result: CameraResult,
    size: CGSize? = nil,
    maxTrimmingDuration: Double? = nil
  ) -> Callback {
    { engine in
      try await engine.createScene(from: result, size: size, maxTrimmingDuration: maxTrimmingDuration)
      try await engine.loadDefaultAndDemoAssetSources()
    }
  }
}

private extension Engine {
  /// Registers the default and demo asset sources plus the text and photo-roll sources.
  /// Replaces the removed `OnCreate.loadAssetSources` helper (upstream folded asset loading into
  /// per-solution defaults as of 1.76).
  func loadDefaultAndDemoAssetSources() async throws {
    async let loadDefault: () = addDefaultAssetSources()
    async let loadDemo: () = addDemoAssetSources(withUploadAssetSources: true)
    _ = try await (loadDefault, loadDemo)
    try await asset.addSource(TextAssetSource(engine: self))
    try asset.addSource(PhotoRollAssetSource(engine: self))
  }
}
