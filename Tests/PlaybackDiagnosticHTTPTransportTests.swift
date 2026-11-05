import Foundation
import XCTest
#if canImport(DuoTwitch)
@testable import DuoTwitch
#else
@testable import PlaybackDiagnosticsCore
#endif

final class PlaybackDiagnosticHTTPTransportTests: XCTestCase {
    private final class Stub: URLProtocol, @unchecked Sendable {
        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        override func startLoading() {
            // All URLs are intercepted. This test can never fall through to DNS/network.
            XCTAssertEqual(request.url, PlaybackDiagnosticDestination.endpoint)
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            XCTAssertNil(request.value(forHTTPHeaderField: "Cookie"))
            let status = request.value(forHTTPHeaderField: "X-Test-Status").flatMap(Int.init) ?? 204
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1",
                                           headerFields: ["Retry-After": "90", "Content-Length": "0"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocolDidFinishLoading(self)
        }
        override func stopLoading() { }
    }

    func testRealSessionUsesOwnedHTTPSAndEphemeralNoCredentialConfiguration() async throws {
        let configurations = ConfigurationCapture()
        let transport = PlaybackDiagnosticHTTPTransport(configuration: {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [Stub.self]
            // The client must override these unsafe inherited defaults.
            configuration.httpShouldSetCookies = true
            configuration.urlCredentialStorage = .shared
            configurations.save(configuration)
            return configuration
        })
        let response = await withCheckedContinuation { continuation in
            transport.send(Data("{\"streams\":[]}".utf8)) { continuation.resume(returning: $0) }
        }
        XCTAssertTrue(response.accepted)
        XCTAssertEqual(response.status, 204)
        XCTAssertEqual(response.retryAfter, 90)
        let configuration = try XCTUnwrap(configurations.get())
        XCTAssertFalse(configuration.httpShouldSetCookies)
        XCTAssertNil(configuration.httpCookieStorage)
        XCTAssertNil(configuration.urlCredentialStorage)
        XCTAssertNil(configuration.urlCache)
        XCTAssertEqual(configuration.timeoutIntervalForRequest, 15)
        XCTAssertEqual(configuration.timeoutIntervalForResource, 20)
        XCTAssertEqual(PlaybackDiagnosticDestination.endpoint.absoluteString,
                       "https://lxso1.tail4e5636.ts.net/duotwitch-diagnostics")
    }

    func testRealSessionReturnsServerRateLimitWithoutReadingBody() async throws {
        let transport = PlaybackDiagnosticHTTPTransport(configuration: {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [Stub.self]
            configuration.httpAdditionalHeaders = ["X-Test-Status": "429"]
            return configuration
        })
        let response = await withCheckedContinuation { continuation in
            transport.send(Data("{}".utf8)) { continuation.resume(returning: $0) }
        }
        XCTAssertEqual(response.status, 429)
        XCTAssertTrue(response.retryable)
        XCTAssertFalse(response.accepted)
        XCTAssertEqual(response.retryAfter, 90)
    }

    func testOversizedRequestNeverCreatesASession() async throws {
        let created = ConfigurationCapture()
        let transport = PlaybackDiagnosticHTTPTransport(configuration: {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [Stub.self]
            created.save(configuration)
            return configuration
        })
        let response = await withCheckedContinuation { continuation in
            transport.send(Data(repeating: 0, count: 64 * 1024 + 1)) { continuation.resume(returning: $0) }
        }
        XCTAssertEqual(response.status, 413)
        XCTAssertNil(created.get())
    }

    private final class ConfigurationCapture: @unchecked Sendable {
        private let lock = NSLock()
        private var configuration: URLSessionConfiguration?
        func save(_ configuration: URLSessionConfiguration) {
            lock.lock(); defer { lock.unlock() }; self.configuration = configuration
        }
        func get() -> URLSessionConfiguration? { lock.lock(); defer { lock.unlock() }; return configuration }
    }
}
