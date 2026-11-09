import AppKit
import ServiceManagement

// Chocofi HUD: a floating panel while a layer is held or a one-shot is armed. No menu bar item
// and no Dock icon; it starts at login. Quit it from Activity Monitor or with `pkill ChocofiHUD`.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let link = HIDLink()
    private let panel = HUDPanel()
    private var showTimer: Timer?, hideTimer: Timer?
    // Panel position: "bottomCenter" (default), "bottomRight" or "topRight".
    // Change with: defaults write studio.screensavers.chocofi-hud position bottomRight
    private var position: String { UserDefaults.standard.string(forKey: "position") ?? "bottomCenter" }

    func applicationDidFinishLaunching(_ note: Notification) {
        if SMAppService.mainApp.status != .enabled { try? SMAppService.mainApp.register() }
        link.onChange = { [weak self] s in self?.render(s) }
        link.start()
    }

    private func render(_ s: BoardState) {
        if ProcessInfo.processInfo.environment["CHOCOFI_DEBUG"] != nil { print("state:", s, "open:", link.openError); fflush(stdout) }
        // one-shots show at once; a held layer shows after a short hold so quick symbol taps
        // don't flash it; going idle hides it after a moment to avoid flicker
        showTimer?.invalidate(); hideTimer?.invalidate()
        guard s.connected, !s.isIdle else {
            hideTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: false) { [weak self] _ in self?.panel.hide() }
            return
        }
        let delay = s.oneShot != 0 || panel.alphaValue > 0 ? 0 : 0.25
        showTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.panel.show(s, position: self.position)
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
