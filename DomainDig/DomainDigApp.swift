//
//  DomainDigApp.swift
//  DomainDig
//
//  Created by cmc on 2026-03-10.
//

import SwiftUI

@main
struct DomainDigApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppDensity.userDefaultsKey) private var density = AppDensity.compact.rawValue
    @State private var viewModel = DomainViewModel()
    @State private var purchaseService = PurchaseService.shared

    init() {
        LocalNotificationService.shared.configureForegroundPresentation()
        DomainMonitoringScheduler.shared.registerBackgroundTask()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView(viewModel: viewModel)
                .environment(\.appDensity, AppDensity(rawValue: density) ?? .compact)
                .task {
                    let _ = purchaseService.currentTier
                    await purchaseService.refreshEntitlements()
                    viewModel.refreshMonitoringState()
                    await viewModel.refreshMonitoringAuthorizationStatus()
                    viewModel.monitoringStatusMessage = DomainMonitoringScheduler.shared.syncSchedule()
                }
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else { return }
            viewModel.refreshMonitoringState()
            Task {
                await viewModel.refreshMonitoringAuthorizationStatus()
            }
            viewModel.monitoringStatusMessage = DomainMonitoringScheduler.shared.syncSchedule()
        }
    }
}
