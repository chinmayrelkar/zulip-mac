import AppKit
import AVKit
import Observation
import SwiftUI
import ZulipCore

public struct LightboxItem: Identifiable, Sendable {
    public var id: String { fullSrc }
    public var src: String
    public var fullSrc: String
    public var data: Data
    public var alt: String
    public var kind: MediaKind

    public init(src: String, fullSrc: String, data: Data, alt: String, kind: MediaKind) {
        self.src = src
        self.fullSrc = fullSrc
        self.data = data
        self.alt = alt
        self.kind = kind
    }
}

@MainActor
@Observable
public final class MediaLoader {
    private let client: ZulipClient
    public let site: URL
    private var bytes: [String: Data] = [:]
    private var playable: [String: URL] = [:]

    public init(client: ZulipClient, site: URL) {
        self.client = client
        self.site = site
    }

    public func data(for raw: String) async -> Data? {
        if let cached = bytes[raw] { return cached }
        guard let url = MediaURL.resolve(raw, site: site) else { return nil }
        do {
            let data = try await client.fetchData(url)
            bytes[raw] = data
            return data
        } catch {
            return nil
        }
    }

    public func data(firstOf urls: [String]) async -> Data? {
        var seen = Set<String>()
        for raw in urls where !raw.isEmpty && seen.insert(raw).inserted {
            if let data = await data(for: raw) { return data }
        }
        return nil
    }

    public func playURL(for raw: String) async -> URL? {
        if let cached = playable[raw] { return cached }
        guard let url = MediaURL.resolve(raw, site: site) else { return nil }
        do {
            if MediaURL.uploadAPIPath(for: url) != nil {
                let signed = try await client.signedUploadURL(url)
                playable[raw] = signed
                return signed
            }
            if MediaURL.needsAuth(url, site: site) {
                let data = try await client.fetchData(url)
                let ext = url.pathExtension.isEmpty ? "bin" : url.pathExtension
                let file = FileManager.default.temporaryDirectory
                    .appending(path: "zulip-mac-\(UUID().uuidString).\(ext)")
                try data.write(to: file)
                playable[raw] = file
                return file
            }
            playable[raw] = url
            return url
        } catch {
            return nil
        }
    }
}

public struct MediaBlockView: View {
    public let src: String
    public var original: String?
    public let alt: String
    public let kind: MediaKind
    public var loader: MediaLoader?
    public var onOpen: ((LightboxItem) -> Void)?

    @State private var data: Data?
    @State private var playURL: URL?
    @State private var failed = false

    // Fixed boxes per kind: the size is the same while loading, loaded, or failed,
    // so rows never change height when media arrives.
    private static let imageBox = CGSize(width: 480, height: 280)
    private static let videoBox = CGSize(width: 400, height: 225)
    private static let audioBox = CGSize(width: 360, height: 44)

    public init(src: String, original: String? = nil, alt: String, kind: MediaKind, loader: MediaLoader? = nil, onOpen: ((LightboxItem) -> Void)? = nil) {
        self.src = src
        self.original = original
        self.alt = alt
        self.kind = kind
        self.loader = loader
        self.onOpen = onOpen
    }

    public var body: some View {
        Group {
            switch kind {
            case .image:
                stillImage
                    .frame(maxWidth: Self.imageBox.width, alignment: .leading)
                    .frame(height: Self.imageBox.height, alignment: .leading)
            case .gif:
                gifImage
                    .frame(maxWidth: Self.imageBox.width, alignment: .leading)
                    .frame(height: Self.imageBox.height, alignment: .leading)
            case .video:
                Group {
                    if let playURL {
                        NativeVideoPlayer(url: playURL)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        placeholder
                    }
                }
                .frame(width: Self.videoBox.width, height: Self.videoBox.height, alignment: .leading)
            case .audio:
                Group {
                    if let playURL {
                        NativeVideoPlayer(url: playURL)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        placeholder
                    }
                }
                .frame(width: Self.audioBox.width, height: Self.audioBox.height, alignment: .leading)
            }
        }
        .help(alt.isEmpty ? "Open media" : alt)
        .contentShape(Rectangle())
        .onTapGesture { openIfPossible() }
        .onHover { hovering in
            if inspectable { NSCursor.pointingHand.set() }
            if !hovering { NSCursor.arrow.set() }
        }
        .task(id: src + (original ?? "")) { await load() }
    }

    private var displaySrc: String {
        MediaURL.sharperPreview(src)
    }

    private var fullSrc: String {
        if let original, !original.isEmpty { return original }
        return displaySrc
    }

    private var inspectable: Bool {
        (kind == .image || kind == .gif) && data != nil
    }

    private func openIfPossible() {
        guard inspectable, let data else { return }
        onOpen?(LightboxItem(src: displaySrc, fullSrc: fullSrc, data: data, alt: alt, kind: kind))
    }

    @ViewBuilder
    private var stillImage: some View {
        if let data, let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(maxWidth: Self.imageBox.width, maxHeight: Self.imageBox.height, alignment: .leading)
        } else {
            placeholder
        }
    }

    @ViewBuilder
    private var gifImage: some View {
        if let data, let image = NSImage(data: data) {
            let imgSize = image.size
            let maxW = Self.imageBox.width
            let maxH = Self.imageBox.height
            let (targetW, targetH): (CGFloat, CGFloat) = {
                if imgSize.width > 0 && imgSize.height > 0 {
                    let wRatio = maxW / imgSize.width
                    let hRatio = maxH / imgSize.height
                    let scale = min(1.0, min(wRatio, hRatio))
                    return (imgSize.width * scale, imgSize.height * scale)
                }
                return (min(maxW, 360), min(maxH, 240))
            }()
            AnimatedImage(data: data)
                .frame(width: targetW, height: targetH)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            placeholder
        }
    }

    @ViewBuilder
    private var placeholder: some View {
        // Fills whatever fixed box the caller gives it, so loading/failed states keep the final size.
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.08))
            if failed {
                Text(alt.isEmpty ? "media failed to load" : alt)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(8)
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @MainActor
    private func load() async {
        guard let loader else {
            failed = true
            return
        }
        switch kind {
        case .image, .gif:
            data = await loader.data(firstOf: [displaySrc, src, original ?? ""])
            failed = data == nil
        case .video, .audio:
            if let url = await loader.playURL(for: fullSrc) {
                playURL = url
            } else {
                failed = true
            }
        }
    }
}

public struct NativeVideoPlayer: NSViewRepresentable {
    public let url: URL
    public var autoPlay: Bool = false

    public init(url: URL, autoPlay: Bool = false) {
        self.url = url
        self.autoPlay = autoPlay
    }

    public func makeNSView(context: Context) -> AVPlayerView {
        let playerView = AVPlayerView()
        playerView.controlsStyle = .inline
        playerView.showsFullScreenToggleButton = true
        let player = AVPlayer(url: url)
        playerView.player = player
        if autoPlay {
            player.play()
        }
        return playerView
    }

    public func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if let currentAsset = (nsView.player?.currentItem?.asset as? AVURLAsset), currentAsset.url != url {
            let player = AVPlayer(url: url)
            nsView.player = player
        }
    }

    public static func dismantleNSView(_ nsView: AVPlayerView, coordinator: ()) {
        nsView.player?.pause()
        nsView.player = nil
    }
}

public struct AnimatedImage: NSViewRepresentable {
    public let data: Data

    public init(data: Data) {
        self.data = data
    }

    public func makeNSView(context: Context) -> NSImageView {
        let view = NSImageView()
        view.imageScaling = .scaleProportionallyUpOrDown
        view.animates = true
        view.canDrawSubviewsIntoLayer = true
        view.image = NSImage(data: data)
        view.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        view.setContentHuggingPriority(.defaultHigh, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return view
    }

    public func updateNSView(_ view: NSImageView, context: Context) {
        view.animates = true
        if view.image == nil {
            view.image = NSImage(data: data)
        }
    }
}

public struct LightboxView: View {
    public let item: LightboxItem
    public var loader: MediaLoader?
    public var onClose: () -> Void

    @State private var fullData: Data?
    @State private var scale: CGFloat = 1
    @State private var gestureBase: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var dragStart: CGSize = .zero

    public init(item: LightboxItem, loader: MediaLoader? = nil, onClose: @escaping () -> Void) {
        self.item = item
        self.loader = loader
        self.onClose = onClose
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.88)
                .ignoresSafeArea()
                .onTapGesture(perform: close)

            VStack(spacing: 0) {
                toolbar
                GeometryReader { geo in
                    ZStack {
                        image
                            .scaleEffect(scale)
                            .offset(offset)
                            .frame(width: geo.size.width, height: geo.size.height)
                    }
                    .contentShape(Rectangle())
                    .gesture(magnify)
                    .simultaneousGesture(pan)
                    .onTapGesture(count: 2, perform: toggleZoom)
                }
            }
        }
        .focusable()
        .onExitCommand { close() }
        .onKeyPress(.escape) { close(); return .handled }
        .onKeyPress(keys: ["+", "="]) { _ in bump(0.25); return .handled }
        .onKeyPress(keys: ["-", "_"]) { _ in bump(-0.25); return .handled }
        .onKeyPress("0") { reset(); return .handled }
        .onKeyPress(keys: ["c"]) { press in
            guard !press.modifiers.contains(.control) else { return .ignored }
            copyToClipboard()
            return .handled
        }
        .onKeyPress(keys: ["s"]) { press in
            guard !press.modifiers.contains(.control) else { return .ignored }
            saveToDisk()
            return .handled
        }
        .task(id: item.fullSrc) {
            guard item.fullSrc != item.src else { return }
            fullData = await loader?.data(for: item.fullSrc)
        }
    }

    private var shown: Data { fullData ?? item.data }

    @ViewBuilder
    private var image: some View {
        switch item.kind {
        case .gif:
            AnimatedImage(data: shown)
        case .image:
            if let ns = NSImage(data: shown) {
                Image(nsImage: ns)
                    .resizable()
                    .scaledToFit()
            }
        case .video, .audio:
            EmptyView()
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Text(item.alt.isEmpty ? "Image" : item.alt)
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer()
            Text("\(Int(scale * 100))%")
                .foregroundStyle(.white.opacity(0.7))
                .monospacedDigit()
            Button("-") { bump(-0.25) }
            Button("+") { bump(0.25) }
            Button("Reset") { reset() }
            Button("Copy") { copyToClipboard() }
            Button("Save") { saveToDisk() }
            Button("Close", action: close)
        }
        .buttonStyle(.bordered)
        .padding(12)
        .background(.black.opacity(0.45))
    }

    private func copyToClipboard() {
        guard let nsImage = NSImage(data: shown) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([nsImage])
    }

    private func saveToDisk() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = (item.alt.isEmpty ? "image" : item.alt) + (item.kind == .gif ? ".gif" : ".png")
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? shown.write(to: url)
            }
        }
    }

    private var magnify: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = clamp(gestureBase * value.magnification)
            }
            .onEnded { _ in
                gestureBase = scale
            }
    }

    private var pan: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1 else { return }
                offset = CGSize(
                    width: dragStart.width + value.translation.width,
                    height: dragStart.height + value.translation.height
                )
            }
            .onEnded { _ in
                dragStart = offset
            }
    }

    private func bump(_ delta: CGFloat) {
        scale = clamp(scale + delta)
        if scale == 1 { offset = .zero; dragStart = .zero }
    }

    private func toggleZoom() {
        if scale > 1 { reset() } else { scale = 2 }
    }

    private func reset() {
        scale = 1
        gestureBase = 1
        offset = .zero
        dragStart = .zero
    }

    private func close() {
        reset()
        onClose()
    }

    private func clamp(_ value: CGFloat) -> CGFloat {
        min(8, max(1, value))
    }
}
