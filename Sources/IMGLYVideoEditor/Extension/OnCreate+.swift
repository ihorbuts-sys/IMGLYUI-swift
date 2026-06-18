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
      await engine.loadDefaultAndDemoAssetSources()
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
      await engine.loadDefaultAndDemoAssetSources()
    }
  }
}

private extension Engine {
  /// Registers the default and demo asset sources plus the text and photo-roll sources.
  ///
  /// Uses the v5 `addLocalAssetSourceFromJSON(<baseURL>/<id>/content.json)` registration instead of the
  /// deprecated `addDefaultAssetSources()` / `addDemoAssetSources()` helpers. Those helpers SKIP the
  /// sources that were renamed/merged in v5 (`filter.lut`+`filter.duotone`→`ly.img.filter`,
  /// `vectorpath`→`ly.img.vector.shape`, …) when run against the v5 CDN, which left the inspector-bar
  /// Filter/Effect/Blur pickers showing "Cannot connect to service". This mirrors upstream's own v5
  /// registration recipe (see `AssetLibraryInteractorMock`).
  ///
  /// Each registration is isolated so a single source failure can't abort the rest — most importantly it
  /// must not prevent the caller from registering its own custom sources afterwards.
  func loadDefaultAndDemoAssetSources() async {
    let baseURL = configuredAssetBaseURL

    // Default content sources (effects, filters, blur, shapes, stickers, text, presets, …).
    let defaultSourceIDs = [
      "ly.img.sticker", "ly.img.vector.shape", "ly.img.filter", "ly.img.color.palette",
      "ly.img.effect", "ly.img.blur", "ly.img.typeface", "ly.img.crop.presets",
      "ly.img.page.presets", "ly.img.text", "ly.img.text.components",
      "ly.img.caption.presets",
    ]
    // Remote demo content sources.
    let remoteDemoSourceIDs = ["ly.img.image", "ly.img.audio", "ly.img.video"]

    for id in defaultSourceIDs + remoteDemoSourceIDs {
      await registerQuietly(id) {
        _ = try await self.asset.addLocalAssetSourceFromJSON(
          baseURL.appendingPathComponent(id).appendingPathComponent("content.json"),
        )
      }
    }

    // Upload demo sources (let the user import their own media).
    let uploadDemoSources: [(id: String, mimeTypes: [String])] = [
      ("ly.img.image.upload", ["image/jpeg", "image/png", "image/svg+xml", "image/gif", "image/apng", "image/bmp"]),
      ("ly.img.audio.upload", ["audio/x-m4a", "audio/mp3", "audio/mpeg"]),
      ("ly.img.video.upload", ["video/mp4"]),
    ]
    for source in uploadDemoSources {
      registerQuietly(source.id) {
        try self.asset.addLocalSource(sourceID: source.id, supportedMimeTypes: source.mimeTypes)
      }
    }

    await registerQuietly("text asset source") { try await self.asset.addSource(TextAssetSource(engine: self)) }
    registerQuietly("photo-roll asset source") { try self.asset.addSource(PhotoRollAssetSource(engine: self)) }
  }

  /// The asset base URL the engine was configured with (via `EngineSettings.baseURL` → `basePath`
  /// setting), falling back to the framework default.
  private var configuredAssetBaseURL: URL {
    if let basePath = try? editor.getSettingString("basePath"),
       let url = URL(string: basePath) {
      return url
    }
    return Engine.assetBaseURL
  }

  private func registerQuietly(_ label: String, _ work: () async throws -> Void) async {
    do {
      try await work()
    } catch {
      print("[IMGLY] Skipped registering \(label): \(error)")
    }
  }

  private func registerQuietly(_ label: String, _ work: () throws -> Void) {
    do {
      try work()
    } catch {
      print("[IMGLY] Skipped registering \(label): \(error)")
    }
  }
}
