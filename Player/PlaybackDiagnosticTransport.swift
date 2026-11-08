import Foundation

enum PlaybackDiagnosticDestination {
    // Public client ingest metadata, not an admin credential. This route is
    // private to Alex's tailnet and accepts only validated DuoTwitch records.
    static let endpoint = URL(string: "https://lxso1.tail4e5636.ts.net/duotwitch-diagnostics")!
    static let disclosure = "Alex’s private Foldstream JSON log storage at lxso1.tail4e5636.ts.net over HTTPS and Tailscale"
}

struct PlaybackDiagnosticUploadResponse: Sendable {
    let status: Int?
    var retryAfter: TimeInterval? = nil
    var accepted: Bool { status == 204 } // Durable receiver acknowledgement; never accept a login page's 200.
    var retryable: Bool { status == nil || status == 408 || status == 429 || (500...599).contains(status ?? 0) }
}

protocol PlaybackDiagnosticTransport: Sendable {
    func send(_ body: Data, completion: @escaping @Sendable (PlaybackDiagnosticUploadResponse) -> Void)
}

/// No cookies, credentials, response body, redirects, SDK/device identity or
/// third-party fallback. The ephemeral session exists only for one bounded POST.
final class PlaybackDiagnosticHTTPTransport: PlaybackDiagnosticTransport, @unchecked Sendable {
    private let configuration: @Sendable () -> URLSessionConfiguration

    init(configuration: @escaping @Sendable () -> URLSessionConfiguration = { .ephemeral }) {
        self.configuration = configuration
    }

    func send(_ body: Data, completion: @escaping @Sendable (PlaybackDiagnosticUploadResponse) -> Void) {
        guard body.count <= 64 * 1024 else {
            completion(PlaybackDiagnosticUploadResponse(status: 413)); return
        }
        let delegate = ResponseDelegate(completion: completion)
        let configuration = configuration()
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 20
        #if os(iOS)
        configuration.waitsForConnectivity = false
        #endif
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        var request = URLRequest(url: PlaybackDiagnosticDestination.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        session.dataTask(with: request).resume()
        session.finishTasksAndInvalidate()
    }

    private final class ResponseDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
        private let completion: @Sendable (PlaybackDiagnosticUploadResponse) -> Void
        // URLSession's private serial delegate queue owns these fields.
        private var response = PlaybackDiagnosticUploadResponse(status: nil)

        init(completion: @escaping @Sendable (PlaybackDiagnosticUploadResponse) -> Void) { self.completion = completion }

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
            if let http = response as? HTTPURLResponse {
                let retry = http.value(forHTTPHeaderField: "Retry-After").flatMap(Double.init)
                self.response = PlaybackDiagnosticUploadResponse(status: http.statusCode,
                    retryAfter: retry.flatMap { $0.isFinite && $0 >= 0 ? min(3600, $0) : nil })
            }
            completionHandler(.cancel) // Status suffices. Never download or retain the response body.
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            completion(response)
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                        newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
            self.response = PlaybackDiagnosticUploadResponse(status: response.statusCode)
            completionHandler(nil)
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge,
                        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
                completionHandler(.performDefaultHandling, nil)
            } else {
                completionHandler(.rejectProtectionSpace, nil)
            }
        }
    }
}
