import SwiftUI

@main
struct CaptureLiteApp: App {
    @State private var environment: AppEnvironment
    @State private var state: AppState
    @State private var viewModel: MainViewModel

    init() {
        let env = AppEnvironment()
        let appState = AppState()
        let vm = MainViewModel(environment: env, state: appState)
        _environment = State(initialValue: env)
        _state = State(initialValue: appState)
        _viewModel = State(initialValue: vm)
    }

    var body: some Scene {
        WindowGroup {
            MainView(viewModel: viewModel)
        }
        .windowStyle(.hiddenTitleBar)

        Settings {
            SettingsView(settings: environment.settings)
        }
    }
}
