import SwiftUI

@main
struct StreamiApp: App {
    @State private var services = AppServices()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(services)
                .preferredColorScheme(.dark)
        }
    }
}