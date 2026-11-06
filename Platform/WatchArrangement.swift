import SwiftUI

enum WatchChatPlacement: String, CaseIterable, Identifiable {
    case automatic = "Automatic", beside = "Beside video", below = "Below video"
    var id: Self { self }
}

/// Enforce the allocated size even when content has larger intrinsic minima.
/// Clipping alone would clip to the content's expanded size, not this pane.
struct WatchPaneBounds<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        GeometryReader { geometry in
            content.frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
                .clipped()
                .contentShape(Rectangle())
        }
    }
}

extension WatchMode {
    var defaultChatExtent: CGFloat { self == .slim ? 160 : 240 }
}

/// Explicit viewing preferences are independent of posture. Active system
/// divisions take precedence, keeping the video out of the hinge region.
struct WatchPaneGeometry {
    let video: CGRect
    let chat: CGRect

    init(size: CGSize, compact: Bool, division: CGRect?, mode: WatchMode, chatLeading: Bool,
         placement: WatchChatPlacement = .automatic,
         chatWidth: CGFloat? = nil, chatHeight: CGFloat? = nil) {
        let requestedWidth = chatWidth ?? mode.defaultChatExtent
        let requestedHeight = chatHeight ?? mode.defaultChatExtent
        let bounds = CGRect(origin: .zero, size: size)
        let fold = division.flatMap { bounds.intersects($0) ? $0.intersection(bounds) : nil }
        if mode == .video {
            if let fold, fold.width > fold.height,
               fold.minY > size.height * 0.2, fold.maxY < size.height * 0.8 {
                video = CGRect(x: 0, y: 0, width: size.width, height: fold.minY)
            } else if let fold, fold.height > fold.width,
                      fold.minX > size.width * 0.2, fold.maxX < size.width * 0.8 {
                video = chatLeading
                    ? CGRect(x: fold.maxX, y: 0, width: size.width - fold.maxX, height: size.height)
                    : CGRect(x: 0, y: 0, width: fold.minX, height: size.height)
            } else { video = bounds }
            chat = CGRect(x: size.width + 1, y: 0, width: 0, height: size.height)
            return
        }
        if let fold, fold.width > fold.height,
           fold.minY > size.height * 0.2, fold.maxY < size.height * 0.8 {
            video = CGRect(x: 0, y: 0, width: size.width, height: fold.minY)
            chat = CGRect(x: 0, y: fold.maxY, width: size.width, height: size.height - fold.maxY)
        } else if let fold, fold.height > fold.width,
                  fold.minX > size.width * 0.2, fold.maxX < size.width * 0.8 {
            let left = CGRect(x: 0, y: 0, width: fold.minX, height: size.height)
            let right = CGRect(x: fold.maxX, y: 0, width: size.width - fold.maxX, height: size.height)
            video = chatLeading ? right : left
            chat = chatLeading ? left : right
        } else {
            let separator: CGFloat = 12
            let canSplit = size.width > separator + 1 && size.height > 0
            let preferBeside = placement == .beside
                || (placement == .automatic && size.width > size.height)
            if canSplit && preferBeside {
                let requested = requestedWidth.isFinite ? requestedWidth : mode.defaultChatExtent
                let width = min(max(1, requested), size.width - 1 - separator)
                video = CGRect(x: chatLeading ? width + separator : 0, y: 0,
                               width: size.width - width - separator, height: size.height)
                chat = CGRect(x: chatLeading ? 0 : video.maxX + separator, y: 0,
                              width: width, height: size.height)
            } else {
                let requested = requestedHeight.isFinite ? requestedHeight : mode.defaultChatExtent
                let height = min(max(1, requested), max(0, size.height - 1 - separator))
                let videoHeight = max(0, size.height - height - (height > 0 ? separator : 0))
                video = CGRect(x: 0, y: 0, width: size.width, height: videoHeight)
                chat = CGRect(x: 0, y: videoHeight + (height > 0 ? separator : 0),
                              width: size.width, height: height)
            }
        }
    }
}

struct WatchArrangementStyle: ArrangementViewStyle {
    let compact: Bool
    let division: CGRect?
    let mode: WatchMode
    let chatLeading: Bool
    var placement: WatchChatPlacement = .automatic
    var chatWidth: CGFloat? = nil
    var chatHeight: CGFloat? = nil
    var resize: ((Bool, CGFloat) -> Void)?
    var chatSizeDescription = ""

    func makeBody(configuration: Configuration) -> some View {
        WatchPaneLayout(compact: compact, division: division, mode: mode, chatLeading: chatLeading,
                        placement: placement, chatWidth: chatWidth, chatHeight: chatHeight) {
            configuration.primary
            configuration.secondary
            WatchSplitHandle(chatLeading: chatLeading, resize: resize, sizeDescription: chatSizeDescription)
        }
    }
}

/// The two hosts keep their structural identity when preferences or geometry
/// change. In particular the native composer is never moved between branches.
private struct WatchPaneLayout: Layout {
    let compact: Bool
    let division: CGRect?
    let mode: WatchMode
    let chatLeading: Bool
    let placement: WatchChatPlacement
    let chatWidth: CGFloat?
    let chatHeight: CGFloat?

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 3 else { return }
        let panes = WatchPaneGeometry(size: bounds.size, compact: compact, division: division, mode: mode,
            chatLeading: chatLeading, placement: placement, chatWidth: chatWidth, chatHeight: chatHeight)
        let side = panes.chat.width < bounds.width && panes.chat.height > 0
        let gap = side
            ? CGRect(x: min(panes.video.maxX, panes.chat.maxX), y: 0, width: 12, height: bounds.height)
            : CGRect(x: 0, y: panes.video.maxY, width: bounds.width, height: 12)
        // A real system division is reserved space, not a draggable separator.
        let adjustable = mode != .video && panes.chat.width > 0 && panes.chat.height > 0
            && (division == nil || !CGRect(origin: .zero, size: bounds.size).intersects(division!))
        let handle = adjustable ? gap : CGRect(x: bounds.width + 1, y: 0, width: 0, height: 0)
        for (index, rect) in [panes.video, panes.chat, handle].enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + rect.minX, y: bounds.minY + rect.minY),
                                 anchor: .topLeading, proposal: ProposedViewSize(rect.size))
        }
    }
}


/// A visible direct-manipulation affordance, with the same operation available
/// through VoiceOver and the Viewing options menu. It never covers the player.
private struct WatchSplitHandle: View {
    let chatLeading: Bool
    let resize: ((Bool, CGFloat) -> Void)?
    let sizeDescription: String
    @State private var translation = CGSize.zero
    @GestureState private var dragging = false

    var body: some View {
        GeometryReader { proxy in
            let side = proxy.size.height > proxy.size.width
            ZStack {
                AppTheme.surface
                Capsule().fill(.secondary)
                    .frame(width: side ? 4 : 44, height: side ? 44 : 4)
            }
            .contentShape(Rectangle().inset(by: -16))
            .gesture(DragGesture(minimumDistance: 2, coordinateSpace: .named("watchPanes"))
                .updating($dragging) { _, active, _ in active = true }
                .onChanged { value in
                    let delta = side ? value.translation.width - translation.width
                                     : value.translation.height - translation.height
                    translation = value.translation
                    resize?(side, delta * (side && chatLeading ? 1 : -1))
                }
                .onEnded { _ in translation = .zero })
            .onChange(of: dragging) { _, active in if !active { translation = .zero } }
            .accessibilityElement()
            .accessibilityLabel("Chat size")
            .accessibilityValue(sizeDescription)
            .accessibilityHint("Adjust to give more room to chat or video. Also available in Viewing options.")
            .accessibilityAdjustableAction { direction in
                resize?(side, direction == .increment ? 32 : -32)
            }
        }
        .allowsHitTesting(resize != nil)
    }
}
