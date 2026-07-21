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
    @AppStorage(AppAppearance.userDefaultsKey) private var appearance = AppAppearance.system.rawValue
    @State private var viewModel = DomainViewModel()
    @State private var purchaseService = PurchaseService.shared
    @State private var cloudSyncService = CloudSyncService.shared
    @State private var localAPIService = LocalAPIService.shared

    init() {
        LocalNotificationService.shared.configureForegroundPresentation()
        DomainMonitoringScheduler.shared.registerBackgroundTask()
        ScheduledReportScheduler.shared.registerBackgroundTask()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView(viewModel: viewModel)
                .environment(\.appDensity, AppDensity(rawValue: density) ?? .compact)
                // The single place appearance is applied. Keep it that way.
                .preferredColorScheme((AppAppearance(rawValue: appearance) ?? .system).colorScheme)
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
                    ScheduledReportScheduler.shared.syncSchedule()
                    IntegrationService.shared.processQueueNow()
                    viewModel.refreshWidgetData()
                    consumeShareInbox()
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
            ScheduledReportScheduler.shared.syncSchedule()
            IntegrationService.shared.processQueueNow()
            viewModel.refreshWidgetData()
            consumeShareInbox()
        }
    }

    /// Picks up a domain shared via the share extension and routes it into an
    /// inspection through the intent router (consumed by `RootTabView`).
    private func consumeShareInbox() {
        guard let domain = DomainDigShareInbox.consume() else { return }
        DomainDigIntentRouter.shared.pendingAction = .inspect(domain)
    }
}
