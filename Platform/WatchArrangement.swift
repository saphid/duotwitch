import SwiftUI
import UIKit

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

/// Keep the full touch target reachable while the visible divider stays at
/// the true pane boundary, including one-point panes against a screen edge.
struct WatchSplitTarget {
    let frame: CGRect
    let dividerPosition: CGFloat

    init(panes: WatchPaneGeometry, size: CGSize, side: Bool) {
        let center = side ? min(panes.video.maxX, panes.chat.maxX) + 6 : panes.video.maxY + 6
        let extent = side ? size.width : size.height
        let length = min(44, max(0, extent))
        let origin = min(max(0, center - length / 2), max(0, extent - length))
        frame = side ? CGRect(x: origin, y: 0, width: length, height: size.height)
                     : CGRect(x: 0, y: origin, width: size.width, height: length)
        dividerPosition = center - origin
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
        GeometryReader { geometry in
            let panes = WatchPaneGeometry(size: geometry.size, compact: compact, division: division,
                mode: mode, chatLeading: chatLeading, placement: placement,
                chatWidth: chatWidth, chatHeight: chatHeight)
            let side = panes.chat.width < geometry.size.width && panes.chat.height > 0
            let target = WatchSplitTarget(panes: panes, size: geometry.size, side: side)
            let adjustable = mode != .video && panes.chat.width > 0 && panes.chat.height > 0
                && (division == nil || !CGRect(origin: .zero, size: geometry.size).intersects(division!))
            WatchPaneLayout(compact: compact, division: division, mode: mode, chatLeading: chatLeading,
                            placement: placement, chatWidth: chatWidth, chatHeight: chatHeight) {
                configuration.primary
                configuration.secondary
                WatchSplitHandle(side: side, chatLeading: chatLeading, dividerPosition: target.dividerPosition,
                                 enabled: adjustable, resize: resize,
                                 sizeDescription: chatSizeDescription)
            }
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
        // A real system division is reserved space, not a draggable separator.
        let adjustable = mode != .video && panes.chat.width > 0 && panes.chat.height > 0
            && (division == nil || !CGRect(origin: .zero, size: bounds.size).intersects(division!))
        let target = WatchSplitTarget(panes: panes, size: bounds.size, side: side)
        let handle = adjustable ? target.frame : CGRect(x: bounds.width + 1, y: 0, width: 0, height: 0)
        for (index, rect) in [panes.video, panes.chat, handle].enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + rect.minX, y: bounds.minY + rect.minY),
                                 anchor: .topLeading, proposal: ProposedViewSize(rect.size))
        }
    }
}


/// One direct-manipulation divider, including while the keyboard is visible.
/// A native pan recognizer does not ask the composer to resign first responder.
private struct WatchSplitHandle: UIViewRepresentable {
    let side: Bool
    let chatLeading: Bool
    let dividerPosition: CGFloat
    let enabled: Bool
    let resize: ((Bool, CGFloat) -> Void)?
    let sizeDescription: String

    func makeUIView(context: Context) -> WatchSplitHandleView { WatchSplitHandleView() }

    func updateUIView(_ view: WatchSplitHandleView, context: Context) {
        view.side = side
        view.chatLeading = chatLeading
        view.dividerPosition = dividerPosition
        view.resize = resize
        view.accessibilityValue = sizeDescription
        view.isUserInteractionEnabled = enabled && resize != nil
        view.accessibilityElementsHidden = !enabled
        view.isAccessibilityElement = enabled && resize != nil
        view.setNeedsDisplay()
    }
}

final class WatchSplitHandleView: UIView {
    var side = false
    var chatLeading = false
    var dividerPosition: CGFloat = 22
    var resize: ((Bool, CGFloat) -> Void)?

    init() {
        super.init(frame: .zero)
        backgroundColor = .clear
        isOpaque = false
        accessibilityIdentifier = "chatResizeHandle"
        accessibilityLabel = "Chat size"
        accessibilityHint = "Drag to resize video and chat, or adjust up and down."
        accessibilityTraits = .adjustable
        addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(pan(_:))))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        let strip = side ? CGRect(x: dividerPosition - 6, y: 0, width: 12, height: bounds.height)
                         : CGRect(x: 0, y: dividerPosition - 6, width: bounds.width, height: 12)
        UIColor.secondarySystemBackground.setFill()
        UIRectFill(strip)
        let grip = side ? CGRect(x: dividerPosition - 2, y: bounds.midY - min(18, bounds.height / 2),
                                  width: 4, height: min(36, bounds.height))
                        : CGRect(x: bounds.midX - min(18, bounds.width / 2), y: dividerPosition - 2,
                                 width: min(36, bounds.width), height: 4)
        UIColor.secondaryLabel.setFill()
        UIBezierPath(roundedRect: grip, cornerRadius: 2).fill()
    }

    @objc private func pan(_ gesture: UIPanGestureRecognizer) {
        // Window coordinates stay still when the divider itself moves. Consume
        // each delta so reversing at a clamped edge responds immediately.
        let movement = gesture.translation(in: window)
        gesture.setTranslation(.zero, in: window)
        guard gesture.state == .began || gesture.state == .changed else { return }
        resizeFromPan(movement)
    }

    func resizeFromPan(_ movement: CGPoint) {
        let delta = side ? movement.x : movement.y
        resize?(side, delta * (side && chatLeading ? 1 : -1))
    }

    override func accessibilityIncrement() { resize?(side, 32) }
    override func accessibilityDecrement() { resize?(side, -32) }
}
