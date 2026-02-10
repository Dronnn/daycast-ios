import SwiftUI

// MARK: - Colors matching web design-spec.md

extension Color {
    // Accent
    static let dcBlue = Color(hex: "#0071e3")
    static let dcBlueBg = Color(hex: "#0071e3").opacity(0.07)
    static let dcGreen = Color(hex: "#30d158")
    static let dcRed = Color(hex: "#ff453a")
    static let dcPurple = Color(hex: "#bf5af2")

    // Channel gradients
    static let blogGrad1 = Color(hex: "#0071e3")
    static let blogGrad2 = Color(hex: "#00c6fb")
    static let diaryGrad1 = Color(hex: "#bf5af2")
    static let diaryGrad2 = Color(hex: "#ff6bcb")
    static let tgGrad1 = Color(hex: "#2AABEE")
    static let tgGrad2 = Color(hex: "#229ED9")
    static let xGrad1 = Color(hex: "#1d1d1f")
    static let xGrad2 = Color(hex: "#555555")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Channel Icon View

struct ChannelIconView: View {
    let channel: ChannelMeta
    var size: CGFloat = 44

    var body: some View {
        Text(channel.letter)
            .font(.system(size: size * 0.45, weight: .black))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(gradient(for: channel.id))
            .clipShape(RoundedRectangle(cornerRadius: size * 0.3))
    }

    private func gradient(for id: String) -> LinearGradient {
        let colors: [Color] = switch id {
        case "blog": [.blogGrad1, .blogGrad2]
        case "diary": [.diaryGrad1, .diaryGrad2]
        case "tg_personal", "tg_public": [.tgGrad1, .tgGrad2]
        case "twitter": [.xGrad1, .xGrad2]
        default: [.gray, .gray.opacity(0.7)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Date Helpers

func todayISO() -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: Date())
}

func formatFeedDate() -> String {
    let f = DateFormatter()
    f.dateFormat = "MMMM d"
    f.locale = Locale(identifier: "en_US")
    return f.string(from: Date())
}

func formatTime(_ iso: String) -> String {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = f.date(from: iso) {
        let tf = DateFormatter()
        tf.dateFormat = "h:mm a"
        return tf.string(from: date)
    }
    // fallback: try without fractional seconds
    f.formatOptions = [.withInternetDateTime]
    if let date = f.date(from: iso) {
        let tf = DateFormatter()
        tf.dateFormat = "h:mm a"
        return tf.string(from: date)
    }
    return ""
}

func formatHistoryDate(_ dateStr: String) -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    guard let date = f.date(from: dateStr) else { return dateStr }
    let out = DateFormatter()
    out.dateFormat = "EEE, MMM d"
    out.locale = Locale(identifier: "en_US")
    return out.string(from: date)
}

func formatFullDate(_ dateStr: String) -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    guard let date = f.date(from: dateStr) else { return dateStr }
    let out = DateFormatter()
    out.dateFormat = "EEEE, MMMM d, yyyy"
    out.locale = Locale(identifier: "en_US")
    return out.string(from: date)
}

func monthYearLabel(_ dateStr: String) -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    guard let date = f.date(from: dateStr) else { return "" }
    let out = DateFormatter()
    out.dateFormat = "MMMM yyyy"
    out.locale = Locale(identifier: "en_US")
    return out.string(from: date)
}

func getDomain(_ urlString: String) -> String {
    guard let url = URL(string: urlString) else { return urlString }
    return url.host?.replacingOccurrences(of: "www.", with: "") ?? urlString
}
