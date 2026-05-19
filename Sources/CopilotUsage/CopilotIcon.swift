import SwiftUI
import AppKit

/// Official Copilot icon loaded from bundle, falls back to SF Symbol
struct CopilotIcon: View {
    let size: CGFloat

    var body: some View {
        if let img = loadCopilotImage() {
            Image(nsImage: img)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: "cpu.fill")
                .frame(width: size, height: size)
        }
    }

    private func loadCopilotImage() -> NSImage? {
        let dirs: [URL] = [Bundle.main.resourceURL].compactMap { $0 }
        for dir in dirs {
            let url = dir.appendingPathComponent("copilot_panel.png")
            if let img = NSImage(contentsOf: url) { return img }
        }
        return nil
    }
}
