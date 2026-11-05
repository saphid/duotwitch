import Observation
import SwiftUI
import UIKit

@MainActor @Observable
final class FoldState {
    var division: CGRect?
    var size: CGSize = .zero
    var hingeAngle: Double?

    var hasVerticalDivision: Bool {
        guard let division else { return false }
        return division.height > division.width && division.minX > size.width * 0.25 && division.maxX < size.width * 0.75
    }

    var hasHorizontalDivision: Bool {
        guard let division else { return false }
        return division.width > division.height && division.minY > size.height * 0.25 && division.maxY < size.height * 0.75
    }
}

struct FoldReader: UIViewRepresentable {
    let state: FoldState
    func makeUIView(context: Context) -> ReaderView {
        let view = ReaderView()
        view.state = state
        return view
    }
    func updateUIView(_ view: ReaderView, context: Context) { view.state = state }

    final class ReaderView: UIView {
        weak var state: FoldState?
        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            addInteraction(UIHingeInteraction { [weak self] _, update in
                self?.state?.hingeAngle = update.hinge.map { Double($0.angle) }
                self?.setNeedsLayout()
            })
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
        override func layoutSubviews() {
            super.layoutSubviews()
            guard let state else { return }
            let frame = reservedRegions(kind: .division).first { $0.isActive && bounds.intersects($0.frame) }?.frame
            // SwiftUI may be laying out while UIKit reports its new geometry.
            // Publish on the next run-loop turn instead of mutating in body layout.
            let size = bounds.size
            DispatchQueue.main.async { [weak state] in
                guard let state else { return }
                if state.division != frame { state.division = frame }
                if state.size != size { state.size = size }
            }
        }
    }
}
