import AppKit

// MARK: - Crack model & generation

/// A single jagged crack ray: a polyline with a base stroke width that
/// tapers to nothing at the tip. Branches are stored as separate cracks.
struct Crack {
    var points: [CGPoint]
    var baseWidth: CGFloat
    /// Cumulative length at each point, used to animate propagation.
    var lengths: [CGFloat]
    /// Timeline instant the crack appeared, so later punches propagate too.
    var bornAt: CGFloat
    var totalLength: CGFloat { lengths.last ?? 0 }
}

extension Crack {
    /// Branching shattered-glass cracks radiating from the impact point.
    /// Each ray is a jagged polyline; longer rays spawn thinner side branches.
    static func burst(around center: CGPoint, rays: ClosedRange<Int>,
                      maxLength: CGFloat, bornAt: CGFloat) -> [Crack] {
        var result: [Crack] = []
        let rayCount = Int.random(in: rays)
        for i in 0..<rayCount {
            // Evenly spread base angles with jitter so rays don't clump.
            let angle = CGFloat(i) / CGFloat(rayCount) * .pi * 2 + CGFloat.random(in: -0.25...0.25)
            let length = CGFloat.random(in: (maxLength * 0.4)...maxLength)
            let main = makeRay(from: center, angle: angle, length: length,
                               width: CGFloat.random(in: 2.5...3.5), bornAt: bornAt)
            result.append(main)
            // Side branches fork off partway along the main ray.
            if Bool.random(), main.points.count > 3 {
                let forkIndex = Int.random(in: 1...(main.points.count - 2))
                let branchAngle = angle + CGFloat.random(in: 0.4...0.9) * (Bool.random() ? 1 : -1)
                result.append(makeRay(from: main.points[forkIndex], angle: branchAngle,
                                      length: length * CGFloat.random(in: 0.25...0.45),
                                      width: 1.5, bornAt: bornAt))
            }
        }
        return result
    }

    private static func makeRay(from start: CGPoint, angle: CGFloat, length: CGFloat,
                                width: CGFloat, bornAt: CGFloat) -> Crack {
        var points = [start]
        var lengths: [CGFloat] = [0]
        let segments = Int.random(in: 4...6)
        var current = start
        var currentAngle = angle
        for _ in 0..<segments {
            // Small heading drift per segment gives the jagged glass look
            // without the uniform diagonal jitter of pure point noise.
            currentAngle += CGFloat.random(in: -0.35...0.35)
            let segLength = length / CGFloat(segments) * CGFloat.random(in: 0.7...1.3)
            current = CGPoint(x: current.x + cos(currentAngle) * segLength,
                              y: current.y + sin(currentAngle) * segLength)
            points.append(current)
            lengths.append(lengths.last! + segLength)
        }
        return Crack(points: points, baseWidth: width, lengths: lengths, bornAt: bornAt)
    }
}
