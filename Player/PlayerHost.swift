import SwiftUI
import WebKit

struct PlayerHost: UIViewRepresentable {
    let session: PlaybackSession

    func makeUIView(context: Context) -> UIView {
        let host = UIView()
        host.backgroundColor = .black
        attach(to: host)
        return host
    }

    func updateUIView(_ host: UIView, context: Context) {
        attach(to: host)
    }

    private func attach(to host: UIView) {
        guard session.webView.superview !== host else { return }
        session.webView.removeFromSuperview()
        session.webView.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(session.webView)
        NSLayoutConstraint.activate([
            session.webView.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            session.webView.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            session.webView.topAnchor.constraint(equalTo: host.topAnchor),
            session.webView.bottomAnchor.constraint(equalTo: host.bottomAnchor)
        ])
    }
}
