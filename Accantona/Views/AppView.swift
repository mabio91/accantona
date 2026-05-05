import SwiftData
import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case today = "Oggi"
    case invoices = "Fatture"
    case deadlines = "Scadenze"
    case cash = "Cassa"
    case more = "Altro"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .today: "gauge.with.dots.needle.bottom.50percent"
        case .invoices: "doc.text.fill"
        case .deadlines: "calendar.badge.clock"
        case .cash: "building.columns.fill"
        case .more: "ellipsis.circle.fill"
        }
    }
}

struct AppView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var setups: [AppSetup]
    @State private var selectedTab: AppTab = .today

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppTab.allCases) { tab in
                NavigationStack {
                    tabContent(tab)
                }
                .tabItem {
                    Label(tab.rawValue, systemImage: tab.symbol)
                }
                .tag(tab)
            }
        }
        .task {
            SeedData.installIfNeeded(context: modelContext)
        }
        .fullScreenCover(isPresented: onboardingRequired) {
            OnboardingView(mode: .firstRun)
        }
    }

    private var onboardingRequired: Binding<Bool> {
        Binding(
            get: { setups.first?.onboardingCompleted != true },
            set: { _ in }
        )
    }

    @ViewBuilder
    private func tabContent(_ tab: AppTab) -> some View {
        switch tab {
        case .today:
            DashboardView()
        case .invoices:
            InvoicesView()
        case .deadlines:
            DeadlinesView()
        case .cash:
            CashView()
        case .more:
            MoreView()
        }
    }
}
