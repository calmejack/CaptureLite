import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private weak var viewModel: MainViewModel?

    func configure(viewModel: MainViewModel) {
        self.viewModel = viewModel
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let viewModel else { return .terminateNow }

        switch viewModel.state.recordingState {
        case .recording, .starting, .stopping:
            return confirmTerminateWhileRecording()
        case .idle, .failed:
            return .terminateNow
        }
    }

    private func confirmTerminateWhileRecording() -> NSApplication.TerminateReply {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "正在录制视频"
        alert.informativeText = "停止录制并退出？"
        alert.addButton(withTitle: "停止并退出")
        alert.addButton(withTitle: "取消")

        guard alert.runModal() == .alertFirstButtonReturn else {
            return .terminateCancel
        }

        Task {
            await viewModel?.stopRecording()
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
