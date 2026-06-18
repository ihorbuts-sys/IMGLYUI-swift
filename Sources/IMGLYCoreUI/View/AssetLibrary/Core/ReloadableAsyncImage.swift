@_spi(Internal) import IMGLYCore
import IMGLYEngine
import Kingfisher
import SwiftUI

@_spi(Internal) public struct ReloadableAsyncImage<Content: View>: View {
  private let url: URL?
  private let accessibilityLabel: String
  @ViewBuilder let content: (KFImage) -> Content
  let onTap: () -> Void

  @_spi(Internal) public init(asset: AssetLoader.Asset, content: @escaping (KFImage) -> Content,
                              onTap: @escaping () -> Void) {
    // Only fall back to the asset `uri` as a thumbnail for assets whose `uri` is itself an image
    // (images/videos). Audio assets have an audio `uri` that can't be rendered as an image, so without a
    // real `thumbUri` we use no URL at all and show a clean empty tile instead of a failed-load badge.
    if asset.result.blockType == DesignBlockType.audio.rawValue {
      url = asset.result.thumbURL
    } else {
      url = asset.thumbURLorURL
    }
    accessibilityLabel = asset.result.label ?? ""
    self.content = content
    self.onTap = onTap
    // With no thumbnail URL there is nothing to load — start in `.loaded` so we show a clean empty tile
    // instead of an endless loading shimmer.
    _state = State(initialValue: url == nil ? .loaded : .loading)
  }

  @_spi(Internal) public init(url: URL?, accessibilityLabel: String,
                              content: @escaping (KFImage) -> Content,
                              onTap: @escaping () -> Void) {
    self.url = url
    self.accessibilityLabel = accessibilityLabel
    self.content = content
    self.onTap = onTap
    _state = State(initialValue: url == nil ? .loaded : .loading)
  }

  @State private var state: LoadingState

  @ViewBuilder private var background: some View {
    GridItemBackground()
      .aspectRatio(1, contentMode: .fit)
  }

  private enum LoadingState {
    case loading, error, loaded
  }

  @_spi(Internal) public var body: some View {
    ZStack {
      switch state {
      case .loading:
        background
          .imgly.shimmer()
      case .error:
        background
          .overlay {
            Image("custom.photo.badge.exclamationmark", bundle: .module)
              .imageScale(.large)
              .foregroundColor(.secondary)
          }
      case .loaded:
        background
      }

      if state != .error, let url {
        content(
          KFImage(url)
            .retry(maxCount: 3)
            .onSuccess { _ in
              state = .loaded
            }
            .onFailure { _ in
              state = .error
            }
            .fade(duration: 0.15),
        )
        // `contentShape` ensures the tappable area is correctly defined on the asset when using `onTapGesture`
        .contentShape(Rectangle())
        // `onTapGesture` instead of using **Button** fixes issues on iOS 18.1+ where scrolling the sheet accidentally
        // triggered the **Button**
        .onTapGesture(perform: onTap)
        .allowsHitTesting(state == .loaded)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
      }
    }
  }
}

struct ReloadableAsyncImage_Previews: PreviewProvider {
  static var previews: some View {
    defaultAssetLibraryPreviews
  }
}
