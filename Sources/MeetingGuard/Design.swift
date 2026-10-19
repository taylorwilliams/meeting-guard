import SwiftUI
import MeetingGuardCore

extension Color {
    init(hex: String) {
        let value = UInt64(hex, radix: 16) ?? 0x628BFF
        self.init(red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255)
    }
    static let guardBlue = Color(hex: "628BFF")
}

extension AlertTheme {
    var background: Color {
        switch self { case .midnight: Color(hex: "101625"); case .ocean: Color(hex: "073D45"); case .ember: Color(hex: "3D2025") }
    }
    var accent: Color {
        switch self { case .midnight: Color(hex: "91AEFF"); case .ocean: Color(hex: "7AE6CF"); case .ember: Color(hex: "FFC19B") }
    }
}

func relativeTime(_ date: Date, now: Date) -> String {
    let seconds = Int(date.timeIntervalSince(now))
    if seconds < 0 { return "Started \(max(0, -seconds / 60))m ago" }
    if seconds < 60 { return "In \(seconds)s" }
    let minutes = seconds / 60
    if minutes < 60 { return "In \(minutes)m" }
    if minutes < 1440 { return "In \(minutes / 60)h \(minutes % 60)m" }
    return date.formatted(.dateTime.weekday(.abbreviated).hour().minute())
}

struct BrandMark: View {
    var size: CGFloat = 36
    var body: some View {
        Image(systemName: "bell.badge.fill")
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(LinearGradient(colors: [Color(hex: "789DFF"), Color(hex: "4663D5")], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: size * 0.28))
            .accessibilityHidden(true)
    }
}

struct EmptyMessage: View {
    let icon: String
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 30)).foregroundStyle(Color.guardBlue)
            Text(title).font(.title3.weight(.semibold))
            Text(message).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 300)
        }.frame(maxWidth: .infinity).padding(28)
    }
}
