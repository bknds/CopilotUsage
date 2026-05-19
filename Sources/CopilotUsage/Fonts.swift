import SwiftUI

extension Font {
    static let ibm = IBMFont()

    struct IBMFont {
        let headline  = Font.custom("IBMPlexMono", size: 13).weight(.semibold)
        let body      = Font.custom("IBMPlexMono", size: 13)
        let subheadline = Font.custom("IBMPlexMono", size: 12)
        let caption   = Font.custom("IBMPlexMono", size: 11)
        let caption2  = Font.custom("IBMPlexMono", size: 10)
        let mono      = Font.custom("IBMPlexMono", size: 13)
    }
}
