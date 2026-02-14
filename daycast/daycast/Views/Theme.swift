import SwiftUI

// MARK: - Design V2 Color System

extension Color {
    // Accent
    static let dcBlue = Color(hex: "#0071e3")
    static let dcBlueBg = Color(hex: "#0071e3").opacity(0.07)
    static let dcGreen = Color(hex: "#30d158")
    static let dcRed = Color(hex: "#ff453a")
    static let dcPurple = Color(hex: "#bf5af2")
    static let dcOrange = Color(hex: "#FF9F0A")

    // Dark mode specific
    static let dcDarkBg = Color(hex: "#000000")
    static let dcDarkCard = Color(hex: "#1C1C1E")
    static let dcDarkTextPrimary = Color(hex: "#F5F5F7")
    static let dcDarkTextSecondary = Color(hex: "#86868B")

    // Light mode specific
    static let dcLightBg = Color(hex: "#FFFFFF")
    static let dcLightSection = Color(hex: "#FAFAF8")
    static let dcLightTextPrimary = Color(hex: "#1D1D1F")
    static let dcLightTextSecondary = Color(hex: "#86868B")

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

// MARK: - Accent Gradient

extension LinearGradient {
    static let dcAccent = LinearGradient(
        colors: [.dcBlue, .dcPurple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let dcAccentWide = LinearGradient(
        colors: [Color(hex: "#0071e3"), Color(hex: "#5856d6"), Color(hex: "#bf5af2")],
        startPoint: .leading,
        endPoint: .trailing
    )
}

// MARK: - Design V2 Card Style

struct DCCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(colorScheme == .dark ? Color.dcDarkCard : Color(.secondarySystemGroupedBackground))
            )
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .shadow(color: .black.opacity(0.04), radius: 16, y: 4)
    }
}

extension View {
    func dcCard() -> some View {
        modifier(DCCardModifier())
    }
}

// MARK: - Interactive Card (scale on tap)

struct DCInteractiveCardModifier: ViewModifier {
    @State private var isPressed = false
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(colorScheme == .dark ? Color.dcDarkCard : Color(.secondarySystemGroupedBackground))
            )
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .shadow(color: .black.opacity(0.04), radius: 16, y: 4)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

extension View {
    func dcInteractiveCard() -> some View {
        modifier(DCInteractiveCardModifier())
    }
}

// MARK: - Scale Button Style

struct DCScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == DCScaleButtonStyle {
    static var dcScale: DCScaleButtonStyle { DCScaleButtonStyle() }
}

// MARK: - Scroll-Triggered Reveal

struct DCScrollRevealModifier: ViewModifier {
    let index: Int
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .scaleEffect(appeared ? 1 : 0.95)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.8)
                .delay(Double(index) * 0.05),
                value: appeared
            )
            .onAppear {
                appeared = true
            }
    }
}

extension View {
    func dcScrollReveal(index: Int) -> some View {
        modifier(DCScrollRevealModifier(index: index))
    }
}

// MARK: - Gradient Mesh Background

struct GradientMeshBackground: View {
    @State private var animateBlobs = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Base color
                (colorScheme == .dark ? Color.dcDarkBg : Color.dcLightBg)

                // Blob 1 — blue
                Circle()
                    .fill(Color.dcBlue.opacity(colorScheme == .dark ? 0.15 : 0.06))
                    .frame(width: geo.size.width * 0.7)
                    .blur(radius: 80)
                    .offset(
                        x: animateBlobs ? -geo.size.width * 0.15 : geo.size.width * 0.15,
                        y: animateBlobs ? -geo.size.height * 0.1 : geo.size.height * 0.15
                    )

                // Blob 2 — purple
                Circle()
                    .fill(Color.dcPurple.opacity(colorScheme == .dark ? 0.12 : 0.05))
                    .frame(width: geo.size.width * 0.6)
                    .blur(radius: 80)
                    .offset(
                        x: animateBlobs ? geo.size.width * 0.2 : -geo.size.width * 0.1,
                        y: animateBlobs ? geo.size.height * 0.2 : -geo.size.height * 0.05
                    )

                // Blob 3 — orange (subtle)
                Circle()
                    .fill(Color.dcOrange.opacity(colorScheme == .dark ? 0.06 : 0.03))
                    .frame(width: geo.size.width * 0.5)
                    .blur(radius: 60)
                    .offset(
                        x: animateBlobs ? -geo.size.width * 0.05 : geo.size.width * 0.1,
                        y: animateBlobs ? geo.size.height * 0.3 : geo.size.height * 0.1
                    )
            }
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 8)
                    .repeatForever(autoreverses: true)
                ) {
                    animateBlobs = true
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Pulsing Glow

struct PulsingGlowModifier: ViewModifier {
    let color: Color
    let radius: CGFloat
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .background(
                Circle()
                    .fill(color.opacity(0.3))
                    .scaleEffect(isPulsing ? 1.3 : 1.0)
                    .opacity(isPulsing ? 0.0 : 0.4)
                    .animation(
                        .easeInOut(duration: 2.0)
                        .repeatForever(autoreverses: true),
                        value: isPulsing
                    )
            )
            .onAppear { isPulsing = true }
    }
}

extension View {
    func dcPulsingGlow(color: Color = .dcBlue, radius: CGFloat = 30) -> some View {
        modifier(PulsingGlowModifier(color: color, radius: radius))
    }
}

// MARK: - Input Focus Glow

struct DCInputFocusModifier: ViewModifier {
    let isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isFocused
                            ? LinearGradient.dcAccent
                            : LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing),
                        lineWidth: isFocused ? 2 : 0
                    )
            )
            .shadow(
                color: isFocused ? Color.dcBlue.opacity(0.25) : .clear,
                radius: isFocused ? 8 : 0,
                y: 0
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

extension View {
    func dcInputFocus(_ isFocused: Bool) -> some View {
        modifier(DCInputFocusModifier(isFocused: isFocused))
    }
}

// MARK: - Design V2 Typography Helpers

extension Font {
    static func dcHeading(_ size: CGFloat = 34, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func dcBody(_ size: CGFloat = 17, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
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

func formatPublishDate(_ iso: String) -> String {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let date = f.date(from: iso) ?? {
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: iso)
    }()
    guard let date else { return "" }
    let out = DateFormatter()
    out.dateFormat = "MMM d, yyyy"
    out.locale = Locale(identifier: "en_US")
    return out.string(from: date)
}

// MARK: - Shimmer Effect

struct ShimmerView: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        Color(.tertiarySystemFill)
            .overlay(
                LinearGradient(
                    colors: [
                        .clear,
                        Color.white.opacity(0.3),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
            )
            .clipped()
            .onAppear {
                withAnimation(
                    .linear(duration: 1.4)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 350
                }
            }
    }
}
