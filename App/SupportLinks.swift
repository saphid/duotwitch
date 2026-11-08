import Foundation

enum SupportLinks {
    static let privacy = URL(string: "https://saphid.app/apps/duotwitch/privacy/")!
    static let support = URL(string: "https://saphid.app/apps/duotwitch/")!
    static let email = "saphid@gmail.com"

    static func report(_ message: ChatMessage) -> URL? {
        var url = URLComponents()
        url.scheme = "mailto"
        url.path = email
        url.queryItems = [
            URLQueryItem(name: "subject", value: "Foldstream chat safety report"),
            URLQueryItem(name: "body", value: "Please describe the concern:\n\n\nUser: \(message.login)\nMessage ID: \(message.id)\nMessage: \(message.text)\n\nThis report is sent only when you send this email.")
        ]
        return url.url
    }
}
