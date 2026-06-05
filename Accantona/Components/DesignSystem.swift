import SwiftUI

enum AppColor {
    static let background = Color(red: 0.965, green: 0.952, blue: 0.925)
    static let darkBackground = Color(red: 0.105, green: 0.105, blue: 0.095)
    static let ink = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.95, green: 0.94, blue: 0.90, alpha: 1)
            : UIColor(red: 0.14, green: 0.13, blue: 0.11, alpha: 1)
    })
    static let sage = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.43, green: 0.72, blue: 0.59, alpha: 1)
            : UIColor(red: 0.23, green: 0.42, blue: 0.34, alpha: 1)
    })
    static let mint = Color(red: 0.67, green: 0.82, blue: 0.72)
    static let amber = Color(red: 0.78, green: 0.55, blue: 0.18)
    static let coral = Color(red: 0.77, green: 0.27, blue: 0.22)
    static let petrol = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.34, green: 0.72, blue: 0.78, alpha: 1)
            : UIColor(red: 0.08, green: 0.29, blue: 0.34, alpha: 1)
    })
}

struct GlassSurface<Content: View>: View {
    var cornerRadius: CGFloat = 16
    var interactive: Bool = false
    var tint: Color? = nil
    @ViewBuilder var content: Content

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 12) {
                content
                    .background(.clear)
                    .glassEffect(glassEffect, in: .rect(cornerRadius: cornerRadius))
            }
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(.white.opacity(0.28), lineWidth: 1)
                }
        }
    }

    @available(iOS 26.0, *)
    private var glassEffect: Glass {
        let base = tint.map { Glass.regular.tint($0.opacity(0.16)) } ?? Glass.regular
        return interactive ? base.interactive() : base
    }
}

struct MoneyText: View {
    let value: Decimal
    var style: Font = .body
    var color: Color? = nil

    var body: some View {
        let formatted = MoneyFormatting.money(value.roundedMoney)
        Text(formatted)
            .font(style)
            .foregroundStyle(color ?? .primary)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .accessibilityLabel(formatted)
    }
}

struct StatusBadge: View {
    let title: String
    let symbol: String
    let color: Color

    init(_ title: String, symbol: String, color: Color) {
        self.title = title
        self.symbol = symbol
        self.color = color
    }

    init(status: CoverageStatus) {
        self.title = status.title
        self.symbol = status.symbol
        self.color = switch status {
        case .covered: AppColor.sage
        case .lowMargin: AppColor.amber
        case .deficit: AppColor.coral
        case .unknown: .secondary
        }
    }

    var body: some View {
        let label = Label(title, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .foregroundStyle(color)
            .accessibilityElement(children: .combine)

        if #available(iOS 26.0, *) {
            label
                .glassEffect(.regular.tint(color.opacity(0.12)), in: Capsule())
        } else {
            label
                .background(color.opacity(0.14), in: Capsule())
        }
    }
}

struct BadgeStack<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                content
            }
            VStack(alignment: .leading, spacing: 8) {
                content
            }
        }
    }
}

struct CoverageBar: View {
    let result: CoverageResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { proxy in
                let width = proxy.size.width
                let progress = CGFloat(truncating: result.ratio as NSDecimalNumber)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.secondary.opacity(0.16))
                    Capsule()
                        .fill(color)
                        .frame(width: max(8, width * progress))
                    Rectangle()
                        .fill(AppColor.ink.opacity(0.52))
                        .frame(width: 2)
                        .offset(x: max(0, width - 2))
                }
            }
            .frame(height: 12)

            HStack {
                Text("Saldo disponibile")
                    .foregroundStyle(.secondary)
                MoneyText(value: result.available, style: .caption.weight(.semibold))
                Spacer()
                Text("Importo scadenza")
                    .foregroundStyle(.secondary)
                MoneyText(value: result.required, style: .caption.weight(.semibold))
            }
            .font(.caption)
        }
    }

    private var color: Color {
        switch result.status {
        case .covered: AppColor.sage
        case .lowMargin: AppColor.amber
        case .deficit: AppColor.coral
        case .unknown: .gray
        }
    }
}

struct ReserveBreakdownView: View {
    let breakdown: ReserveBreakdown

    var body: some View {
        GlassSurface(cornerRadius: 18, tint: AppColor.mint) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Label("Resta dopo accantonamento", systemImage: "wallet.pass.fill")
                        .font(.headline)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                    Spacer()
                    Text(MoneyFormatting.percentage(breakdown.appliedRate))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                MoneyText(value: breakdown.availableAfterReserve, style: .system(size: 28, weight: .bold, design: .rounded), color: AppColor.sage)
                Text("Parte dell'incasso che resta usabile dopo aver messo da parte tasse e INPS.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                    GridRow {
                        Text("Incasso lordo")
                        MoneyText(value: breakdown.income, style: .subheadline.weight(.semibold))
                    }
                    GridRow {
                        Text("Da mettere da parte")
                        MoneyText(value: breakdown.prudentialReserve, style: .subheadline.weight(.semibold), color: AppColor.petrol)
                    }
                    GridRow {
                        Text("Stima tasse e INPS")
                        MoneyText(value: breakdown.theoreticalReserve, style: .subheadline)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding(14)
        }
    }
}

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(AppColor.sage)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct ScreenIntro: View {
    let title: String
    let subtitle: String
    let symbol: String
    var tint: Color = AppColor.petrol

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 38, height: 38)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                    .lineLimit(2)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct Panel<Content: View>: View {
    let title: String
    let subtitle: String?
    let symbol: String?
    var tint: Color = AppColor.petrol
    @ViewBuilder var content: Content

    var body: some View {
        let panel = VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 30, height: 30)
                        .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .foregroundStyle(tint)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }

            content
        }
        .padding(14)

        if #available(iOS 26.0, *) {
            panel
                .glassEffect(.regular.tint(tint.opacity(0.08)), in: .rect(cornerRadius: 14))
        } else {
            panel
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

struct AppTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.sentences)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(.background.opacity(0.54), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.secondary.opacity(0.16), lineWidth: 1)
                }
        }
    }
}

extension View {
    func appBackground() -> some View {
        modifier(AppBackgroundModifier())
    }

    func primaryActionStyle() -> some View {
        modifier(PrimaryActionStyleModifier())
    }

    func secondaryActionStyle() -> some View {
        modifier(SecondaryActionStyleModifier())
    }
}

private struct AppBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background {
                (colorScheme == .dark ? AppColor.darkBackground : AppColor.background)
                    .ignoresSafeArea()
            }
    }
}

private struct PrimaryActionStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .buttonStyle(.glassProminent)
                .controlSize(.regular)
        } else {
            content
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
        }
    }
}

private struct SecondaryActionStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .buttonStyle(.glass)
                .controlSize(.regular)
        } else {
            content
                .buttonStyle(.bordered)
                .controlSize(.regular)
        }
    }
}
