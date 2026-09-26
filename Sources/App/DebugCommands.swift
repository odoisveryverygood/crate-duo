import Foundation

/// Prompt-free control channel for the self-test: with `-crateCmdFile /tmp/crate-cmd.txt`, the app polls that
/// host file (the simulator can read host paths) and runs each new line as a crate:// URL via Router.
final class DebugCommands {
    private var timer: Timer?
    private var consumed = 0

    func start(state: AppState, hinge: HingeFX) {
        guard let path = UserDefaults.standard.string(forKey: "crateCmdFile"), !path.isEmpty else { return }
        consumed = (try? String(contentsOfFile: path, encoding: .utf8))?.split(separator: "\n").count ?? 0
        DebugLog.event("cmd_channel", ["path": path, "skipped": consumed])
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let text = try? String(contentsOfFile: path, encoding: .utf8) else { return }
            let lines = text.split(separator: "\n").map(String.init)
            guard lines.count > self.consumed else { return }
            for line in lines[self.consumed...] {
                if let url = URL(string: line.trimmingCharacters(in: .whitespaces)) { Router.handle(url, state: state, hinge: hinge) }
            }
            self.consumed = lines.count
        }
    }
}
