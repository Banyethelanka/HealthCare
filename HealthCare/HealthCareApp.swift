import SwiftUI

@main
struct HealthCareApp: App {
    @StateObject private var store = HealthStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}
