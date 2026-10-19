import Foundation

public enum MeetingLink {
    private static let hosts = [
        "meet.google.com", "zoom.us", "zoomgov.com", "teams.microsoft.com", "teams.live.com", "teams.cloud.microsoft",
        "webex.com", "webexgov.us", "gotomeet.me", "gotomeeting.com", "goto.com", "whereby.com", "meet.jit.si",
        "facetime.apple.com", "chime.aws", "ringcentral.com", "8x8.vc", "join.me", "discord.gg", "discord.com",
        "slack.com", "meet.zoho.com", "doxy.me", "cal.com", "meet.proton.me"
    ]

    public static func safeWebURL(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "https" && url.host?.isEmpty == false &&
            (url.port == nil || url.port == 443) && url.user == nil && url.password == nil
    }

    public static func find(in fields: [String]) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        for field in fields {
            // Calendar descriptions often contain HTML anchors and entity-escaped query parameters.
            let text = field.replacingOccurrences(of: "&amp;", with: "&")
            for match in detector.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                guard let raw = match.url, safeWebURL(raw), let host = raw.host?.lowercased() else { continue }
                if hosts.contains(where: { host == $0 || host.hasSuffix("." + $0) }) { return raw }
            }
        }
        return nil
    }

    public static func service(for url: URL?) -> String {
        guard let host = url?.host?.lowercased() else { return "Video call" }
        if host.contains("google") { return "Google Meet" }
        if host.contains("zoom") { return "Zoom" }
        if host.contains("teams") { return "Microsoft Teams" }
        if host.contains("webex") { return "Webex" }
        if host.contains("facetime") { return "FaceTime" }
        return host
    }
}
