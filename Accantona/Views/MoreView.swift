import SwiftData
import SwiftUI

struct MoreView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ScreenIntro(
                    title: "Strumenti",
                    subtitle: "Parametri, versamenti e preferenze operative raccolti senza sembrare un pannello tecnico.",
                    symbol: "square.grid.2x2.fill",
                    tint: AppColor.sage
                )

                VStack(spacing: 12) {
                    NavigationLink {
                        OnboardingView(mode: .settings)
                    } label: {
                        MoreActionRow(
                            title: "Setup iniziale",
                            subtitle: "Regime, parametri, saldo e scadenze base",
                            symbol: "sparkles.rectangle.stack.fill",
                            tint: AppColor.sage
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        SimulatorView()
                    } label: {
                        MoreActionRow(
                            title: "Simulatore",
                            subtitle: "Prova incassi, recuperi e margini sulle scadenze",
                            symbol: "function",
                            tint: AppColor.petrol
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        ImportCSVView()
                    } label: {
                        MoreActionRow(
                            title: "Import CSV",
                            subtitle: "Carica fatture dal template Accantona",
                            symbol: "square.and.arrow.down.fill",
                            tint: AppColor.amber
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        ReservesView()
                    } label: {
                        MoreActionRow(
                            title: "Accantonamenti",
                            subtitle: "Quote da trasferire, parziali e recuperi",
                            symbol: "tray.and.arrow.down.fill",
                            tint: AppColor.amber
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        TaxParametersView()
                    } label: {
                        MoreActionRow(
                            title: "Parametri fiscali",
                            subtitle: "Aliquote, coefficiente e margine prudenziale",
                            symbol: "slider.horizontal.3",
                            tint: AppColor.petrol
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        TaxPaymentsView()
                    } label: {
                        MoreActionRow(
                            title: "F24 e versamenti",
                            subtitle: "Saldo, acconti, INPS e altri pagamenti",
                            symbol: "doc.plaintext.fill",
                            tint: AppColor.sage
                        )
                    }
                    .buttonStyle(.plain)
                }

                Panel(title: "Base locale", subtitle: "La MVP resta concentrata su inserimento manuale e calcoli verificabili.", symbol: "externaldrive.fill", tint: AppColor.amber) {
                    VStack(spacing: 12) {
                        InfoLine(symbol: "eye.slash", title: "OCR e import PDF non ancora inclusi")
                        InfoLine(symbol: "lock.doc", title: "Dati locali con SwiftData")
                    }
                }
            }
            .padding(18)
        }
        .navigationTitle("Altro")
        .appBackground()
    }
}

struct MoreActionRow: View {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 42, height: 42)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(15)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct InfoLine: View {
    let symbol: String
    let title: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .frame(width: 24)
                .foregroundStyle(AppColor.petrol)
            Text(title)
                .font(.subheadline)
            Spacer()
        }
    }
}
