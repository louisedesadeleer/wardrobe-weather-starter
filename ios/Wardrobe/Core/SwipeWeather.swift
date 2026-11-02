import Foundation
public enum SwipeWeather {
    /// UIKit/SwiftUI coordinates increase downward. Require a deliberate, dominant direction.
    public static func temperature(dx: Double, dy: Double, threshold: Double = 56) -> Temperature? {
        guard dx.isFinite, dy.isFinite, max(abs(dx), abs(dy)) >= threshold else { return nil }
        if abs(dx) > abs(dy) * 1.15 { return dx > 0 ? .mild : .cool }
        if abs(dy) > abs(dx) * 1.15 { return dy > 0 ? .cold : .hot }
        return nil
    }
}
