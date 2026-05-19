import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var eventMonitor: EventMonitor?
    private var updateTimer: Timer?

    private let service: GitHubCopilotService

    override init() {
        service = GitHubCopilotService()
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        registerFonts()
        setupStatusItem()
        setupPopover()

        Task { @MainActor in
            service.startAutoRefresh(interval: 300)
        }

        updateTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateStatusItemTitle()
            }
        }
    }

    private func registerFonts() {
        let binaryDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
        let searchDirs: [URL] = [
            Bundle.main.resourceURL,
            binaryDir.appendingPathComponent("CopilotUsage_CopilotUsage.bundle/Resources"),
            binaryDir,
        ].compactMap { $0 }

        for name in ["IBMPlexMono-Regular", "IBMPlexMono-Medium"] {
            for dir in searchDirs {
                let url = dir.appendingPathComponent("\(name).ttf")
                if FileManager.default.fileExists(atPath: url.path) {
                    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
                    break
                }
            }
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.action = #selector(togglePopover)
            button.target = self
        }
        Task { @MainActor in self.updateStatusItemTitle() }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.behavior = .transient
        let hc = NSHostingController(rootView: CopilotPopoverView(service: service))
        hc.sizingOptions = .preferredContentSize
        popover.contentViewController = hc
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, self.popover.isShown else { return }
            self.popover.performClose(nil)
            self.eventMonitor?.stop()
        }
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
            eventMonitor?.stop()
        } else {
            guard let button = statusItem.button else { return }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            eventMonitor?.start()
        }
    }

    @MainActor
    private func updateStatusItemTitle() {
        guard let button = statusItem.button else { return }

        let fontSize: CGFloat = NSStatusBar.system.thickness - 10
        let font = NSFont(name: "IBMPlexMono", size: fontSize)
            ?? NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let result = NSMutableAttributedString()

        // Copilot icon — tinted with labelColor so it matches text exactly
        if let iconURL = Bundle.main.resourceURL?.appendingPathComponent("copilot_statusbar.png"),
           let srcImage = NSImage(contentsOf: iconURL) {
        let iconSize = NSStatusBar.system.thickness - 6
            let tinted = NSImage(size: NSSize(width: iconSize, height: iconSize), flipped: false) { rect in
                guard let ctx = NSGraphicsContext.current?.cgContext,
                      let cg = srcImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return false }
                // Use PNG as alpha mask, fill with labelColor
                ctx.clip(to: rect, mask: cg)
                NSColor.labelColor.setFill()
                NSBezierPath.fill(rect)
                return true
            }
            let a = NSTextAttachment()
            a.image = tinted
            a.bounds = CGRect(x: 0, y: (font.capHeight - iconSize) / 2, width: iconSize, height: iconSize)
            result.append(NSAttributedString(attachment: a))
            result.append(NSAttributedString(string: " ", attributes: attrs))
        }

        if let data = service.usageData {
            let pct = data.usagePercent
            result.append(NSAttributedString(string: "\(pct)%", attributes: attrs))

            if data.overageCount > 0 {
                let lineH = fontSize
                let lineImg = NSImage(size: NSSize(width: 7, height: lineH), flipped: false) { _ in
                    NSColor.labelColor.setFill()
                    NSBezierPath(rect: NSRect(x: 3, y: lineH * 0.1, width: 1, height: lineH * 0.8)).fill()
                    return true
                }
                let la = NSTextAttachment()
                la.image = lineImg
                la.bounds = CGRect(x: 0, y: (font.capHeight - lineH) / 2, width: 7, height: lineH)
                result.append(NSAttributedString(string: " ", attributes: attrs))
                result.append(NSAttributedString(attachment: la))
                result.append(NSAttributedString(string: " ", attributes: attrs))
                let cny = data.overageCost * service.settings.cnyRate
                let usdPart = "$\(String(format: "%.2f", data.overageCost)) ≈ "
                result.append(NSAttributedString(string: usdPart, attributes: attrs))
                let yenFont = NSFont.systemFont(ofSize: fontSize)
                result.append(NSAttributedString(string: "¥", attributes: [.font: yenFont]))
                result.append(NSAttributedString(string: String(format: "%.0f", cny), attributes: attrs))
            }
        } else if service.isLoading {
            result.append(NSAttributedString(string: "...", attributes: attrs))
        } else {
            result.append(NSAttributedString(string: "--", attributes: attrs))
        }

        button.attributedTitle = result
    }
}

// MARK: - Event Monitor

class EventMonitor {
    private var monitor: Any?
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent?) -> Void

    init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent?) -> Void) {
        self.mask = mask
        self.handler = handler
    }

    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
    }

    func stop() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }

    deinit { stop() }
}
