//
//  DomainDigApp.swift
//  DomainDig
//
//  Created by cmc on 2026-03-10.
//

import SwiftUI

@main
struct DomainDigApp: App {
    @AppStorage(AppDensity.userDefaultsKey) private var density = AppDensity.compact.rawValue

    init() {
        LocalNotificationService.shared.configureForegroundPresentation()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.appDensity, AppDensity(rawValue: density) ?? .compact)
        }
    }
}
