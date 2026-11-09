import Foundation
import IOKit.hid

// The board's state as reported by the firmware over raw HID (see keymap.c).
struct BoardState: Equatable {
    var connected = false
    var layer = 0
    var oneShot: UInt8 = 0   // QMK mod bits: 0 Ctrl, 1 Shift, 2 Alt, 3 Gui; 4-7 right-hand versions
    var held: UInt8 = 0
    var capsLock = false

    var isIdle: Bool { layer == 0 && oneShot == 0 }

    static func symbols(_ bits: UInt8) -> String {
        let m = bits | (bits >> 4)
        var s = ""
        if m & 0x01 != 0 { s += "⌃" }
        if m & 0x04 != 0 { s += "⌥" }
        if m & 0x02 != 0 { s += "⇧" }
        if m & 0x08 != 0 { s += "⌘" }
        return s
    }
}

final class HIDLink {
    var onChange: ((BoardState) -> Void)?
    private(set) var state = BoardState()
    private(set) var openError: IOReturn = kIOReturnSuccess
    private let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    private var buffers: [IOHIDDevice: UnsafeMutablePointer<UInt8>] = [:]

    func start() {
        let match: [String: Any] = [
            kIOHIDVendorIDKey: 0xFEED, kIOHIDProductIDKey: 0x3636,
            kIOHIDPrimaryUsagePageKey: 0xFF60, kIOHIDPrimaryUsageKey: 0x61,
        ]
        IOHIDManagerSetDeviceMatching(manager, match as CFDictionary)
        let ctx = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { ctx, _, _, device in
            Unmanaged<HIDLink>.fromOpaque(ctx!).takeUnretainedValue().attach(device)
        }, ctx)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { ctx, _, _, device in
            Unmanaged<HIDLink>.fromOpaque(ctx!).takeUnretainedValue().detach(device)
        }, ctx)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        openError = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    private func attach(_ device: IOHIDDevice) {
        let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)
        buffers[device] = buf
        let ctx = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(device, buf, 64, { ctx, _, _, _, _, report, length in
            Unmanaged<HIDLink>.fromOpaque(ctx!).takeUnretainedValue().received(report, length)
        }, ctx)
        update { $0.connected = true }
        requestState(device)
        // ask again shortly after, in case the first request raced the device opening
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.requestState(device) }
    }

    private func detach(_ device: IOHIDDevice) {
        buffers.removeValue(forKey: device)?.deallocate()
        if buffers.isEmpty { update { $0 = BoardState() } }
    }

    private func requestState(_ device: IOHIDDevice) {
        var out = [UInt8](repeating: 0, count: 32)
        out[0] = 0xC0
        IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, 0, &out, out.count)
    }

    private func received(_ report: UnsafeMutablePointer<UInt8>, _ length: Int) {
        guard length >= 5, report[0] == 0xC0 else { return }
        update {
            $0.connected = true
            $0.layer = Int(report[1]) < Keymap.layerNames.count ? Int(report[1]) : 0
            $0.oneShot = report[2]
            $0.held = report[3]
            $0.capsLock = report[4] != 0
        }
    }

    private func update(_ change: (inout BoardState) -> Void) {
        var s = state
        change(&s)
        guard s != state else { return }
        state = s
        onChange?(s)
    }
}
