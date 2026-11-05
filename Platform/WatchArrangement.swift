import SwiftUI

/// Explicit viewing preferences are independent of posture. Active system
/// divisions take precedence, keeping the video out of the hinge region.
struct WatchPaneGeometry {
    let video: CGRect
    let chat: CGRect

    init(size: CGSize, compact: Bool, division: CGRect?, mode: WatchMode, chatLeading: Bool) {
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
        } else if compact {
            let height = min(size.height * 0.52, max(360, size.width * 9 / 16 + 76))
            video = CGRect(x: 0, y: 0, width: size.width, height: max(0, height))
            chat = CGRect(x: 0, y: height + 1, width: size.width, height: max(0, size.height - height - 1))
        } else {
            let chatWidth = size.width * (mode == .slim ? 0.28 : 0.39)
            let videoWidth = max(0, size.width - chatWidth - 1)
            video = CGRect(x: chatLeading ? chatWidth + 1 : 0, y: 0, width: videoWidth, height: size.height)
            chat = CGRect(x: chatLeading ? 0 : videoWidth + 1, y: 0, width: chatWidth, height: size.height)
        }
    }
}

struct WatchArrangementStyle: ArrangementViewStyle {
    let compact: Bool
    let division: CGRect?
    let mode: WatchMode
    let chatLeading: Bool

    func makeBody(configuration: Configuration) -> some View {
        WatchPaneLayout(compact: compact, division: division, mode: mode, chatLeading: chatLeading) {
            configuration.primary
            configuration.secondary
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

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let panes = WatchPaneGeometry(size: bounds.size, compact: compact, division: division, mode: mode, chatLeading: chatLeading)
        for (index, rect) in [panes.video, panes.chat].enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + rect.minX, y: bounds.minY + rect.minY),
                                 anchor: .topLeading, proposal: ProposedViewSize(rect.size))
        }
    }
}
