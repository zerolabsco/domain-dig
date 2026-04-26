//
//  DomainDigApp.swift
//  DomainDig
//
//  Created by cmc on 2026-03-10.
//

import SwiftUI

@main
struct DomainDigApp: App {
    @UIApplicationDelegateAdaptor(DomainDigAppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppDensity.userDefaultsKey) private var density = AppDensity.compact.rawValue
    @State private var viewModel = DomainViewModel()
    @State private var purchaseService = PurchaseService.shared
    @State private var cloudSyncService = CloudSyncService.shared
    @State private var localAPIService = LocalAPIService.shared

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
                    let _ = cloudSyncService.status
                    let _ = localAPIService.isRunning
                    let _ = IntegrationService.shared.targets.count
                    await purchaseService.refreshEntitlements()
                    viewModel.refreshMonitoringState()
                    await viewModel.refreshMonitoringAuthorizationStatus()
                    await cloudSyncService.refreshAvailability()
                    localAPIService.refresh()
                    cloudSyncService.scheduleSyncIfNeeded(trigger: .launch)
                    viewModel.monitoringStatusMessage = DomainMonitoringScheduler.shared.syncSchedule()
                    IntegrationService.shared.processQueueNow()
                }
                .onReceive(NotificationCenter.default.publisher(for: .cloudSyncDidApplyChanges)) { _ in
                    viewModel.refreshPersistedData()
                    viewModel.monitoringStatusMessage = DomainMonitoringScheduler.shared.syncSchedule()
                    IntegrationService.shared.refresh()
                }
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else { return }
            viewModel.refreshMonitoringState()
            Task {
                await viewModel.refreshMonitoringAuthorizationStatus()
                await cloudSyncService.refreshAvailability()
            }
            localAPIService.refresh()
            cloudSyncService.scheduleSyncIfNeeded(trigger: .launch)
            viewModel.monitoringStatusMessage = DomainMonitoringScheduler.shared.syncSchedule()
            IntegrationService.shared.processQueueNow()
        }
    }
}
