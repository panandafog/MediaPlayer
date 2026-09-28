import SwiftUI

extension ConcentricRectangle {
    init(uniformMinimumCornerRadius: CGFloat) {
        self.init(
            corners: .concentric(minimum: .fixed(uniformMinimumCornerRadius)),
            isUniform: true
        )
    }
}
