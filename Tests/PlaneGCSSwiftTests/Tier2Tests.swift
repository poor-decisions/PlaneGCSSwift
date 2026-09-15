import Foundation
import Testing
@testable import PlaneGCSSwift

@Suite("Tier 2: constraints needing a Line")
struct Tier2Tests {

    @Test("P2LDistance: point moves to the given perpendicular distance from a fixed line")
    func p2lDistance() {
        let sketch = PlaneGCSSketch()
        let lp1 = sketch.addPoint(x: 0, y: 0, fixed: true)
        let lp2 = sketch.addPoint(x: 10, y: 0, fixed: true)
        let line = sketch.addLine(lp1, lp2)
        let p = sketch.addPoint(x: 5, y: 1, fixed: false)
        sketch.addDistanceConstraint(p, to: line, distance: 4.0)

        let status = sketch.solve()

        #expect(status == .success)
        #expect(abs(abs(sketch.position(of: p).y) - 4.0) < 1e-6)
    }

    @Test("PointOnLine (Line overload): point moves onto the line")
    func pointOnLine() {
        let sketch = PlaneGCSSketch()
        let lp1 = sketch.addPoint(x: 0, y: 0, fixed: true)
        let lp2 = sketch.addPoint(x: 10, y: 4, fixed: true)
        let line = sketch.addLine(lp1, lp2)
        let p = sketch.addPoint(x: 5, y: 5, fixed: false)
        sketch.addPointOnLineConstraint(p, line)

        let status = sketch.solve()
        let pos = sketch.position(of: p)
        // Collinearity check against the line (0,0)-(10,4).
        let cross = 10.0 * pos.y - 4.0 * pos.x

        #expect(status == .success)
        #expect(abs(cross) < 1e-6)
    }

    @Test("PointOnPerpBisector (Line overload): point moves onto the segment's perpendicular bisector")
    func pointOnPerpBisector() {
        let sketch = PlaneGCSSketch()
        let lp1 = sketch.addPoint(x: 0, y: 0, fixed: true)
        let lp2 = sketch.addPoint(x: 10, y: 0, fixed: true)
        let line = sketch.addLine(lp1, lp2)
        let p = sketch.addPoint(x: 6, y: 4, fixed: false)
        sketch.addPointOnPerpBisectorConstraint(p, line)

        let status = sketch.solve()

        #expect(status == .success)
        #expect(abs(sketch.position(of: p).x - 5.0) < 1e-6)
    }

    @Test("Parallel: two lines become parallel")
    func parallel() {
        let sketch = PlaneGCSSketch()
        let l1p1 = sketch.addPoint(x: 0, y: 0, fixed: true)
        let l1p2 = sketch.addPoint(x: 10, y: 0, fixed: true)
        let line1 = sketch.addLine(l1p1, l1p2)
        let l2p1 = sketch.addPoint(x: 0, y: 5, fixed: true)
        let l2p2 = sketch.addPoint(x: 8, y: 8, fixed: false)
        let line2 = sketch.addLine(l2p1, l2p2)
        sketch.addParallelConstraint(line1, line2)

        let status = sketch.solve()
        let pos = sketch.position(of: l2p2)

        // line1 is horizontal, so a parallel line2 must also be horizontal.
        #expect(status == .success)
        #expect(abs(pos.y - sketch.position(of: l2p1).y) < 1e-6)
    }

    @Test("Perpendicular (Line, Line): two lines meet at 90 degrees")
    func perpendicular() {
        let sketch = PlaneGCSSketch()
        let l1p1 = sketch.addPoint(x: 0, y: 0, fixed: true)
        let l1p2 = sketch.addPoint(x: 10, y: 0, fixed: true)
        let line1 = sketch.addLine(l1p1, l1p2)
        let l2p1 = sketch.addPoint(x: 3, y: -5, fixed: true)
        let l2p2 = sketch.addPoint(x: 6, y: 5, fixed: false)
        let line2 = sketch.addLine(l2p1, l2p2)
        sketch.addPerpendicularConstraint(line1, line2)

        let status = sketch.solve()

        #expect(status == .success)
        #expect(abs(sketch.position(of: l2p2).x - sketch.position(of: l2p1).x) < 1e-6)
    }

    @Test("L2LAngle (Line, Line): sets the angle between two lines")
    func l2lAngle() {
        let sketch = PlaneGCSSketch()
        let l1p1 = sketch.addPoint(x: 0, y: 0, fixed: true)
        let l1p2 = sketch.addPoint(x: 10, y: 0, fixed: true)
        let line1 = sketch.addLine(l1p1, l1p2)
        let l2p1 = sketch.addPoint(x: 0, y: 0, fixed: true)
        let l2p2 = sketch.addPoint(x: 5, y: 5, fixed: false)
        let line2 = sketch.addLine(l2p1, l2p2)
        sketch.addAngleConstraint(line1, line2, angle: .pi / 6)

        let status = sketch.solve()
        let pos = sketch.position(of: l2p2)
        let resultingAngle = atan2(pos.y, pos.x)

        #expect(status == .success)
        #expect(abs(resultingAngle - .pi / 6) < 1e-6)
    }

    @Test("MidpointOnLine (Line, Line): midpoint of line1 lies on line2")
    func midpointOnLine() {
        let sketch = PlaneGCSSketch()
        let l1p1 = sketch.addPoint(x: 0, y: 0, fixed: true)
        let l1p2 = sketch.addPoint(x: 10, y: 0, fixed: true)
        let line1 = sketch.addLine(l1p1, l1p2)
        let l2p1 = sketch.addPoint(x: 5, y: 10, fixed: true)
        let l2p2 = sketch.addPoint(x: 8, y: -3, fixed: false)
        let line2 = sketch.addLine(l2p1, l2p2)
        sketch.addMidpointOnLineConstraint(line1, line2)

        let status = sketch.solve()
        let a = sketch.position(of: l2p1)
        let b = sketch.position(of: l2p2)
        let cross = (b.x - a.x) * (0 - a.y) - (b.y - a.y) * (5 - a.x)

        #expect(status == .success)
        #expect(abs(cross) < 1e-6)
    }

    @Test("Horizontal (Line overload)")
    func horizontal() {
        let sketch = PlaneGCSSketch()
        let p1 = sketch.addPoint(x: 0, y: 0, fixed: true)
        let p2 = sketch.addPoint(x: 5, y: 6, fixed: false)
        let line = sketch.addLine(p1, p2)
        sketch.addHorizontalConstraint(line)

        let status = sketch.solve()

        #expect(status == .success)
        #expect(abs(sketch.position(of: p2).y - sketch.position(of: p1).y) < 1e-6)
    }

    @Test("Vertical (Line overload)")
    func vertical() {
        let sketch = PlaneGCSSketch()
        let p1 = sketch.addPoint(x: 0, y: 0, fixed: true)
        let p2 = sketch.addPoint(x: 6, y: 5, fixed: false)
        let line = sketch.addLine(p1, p2)
        sketch.addVerticalConstraint(line)

        let status = sketch.solve()

        #expect(status == .success)
        #expect(abs(sketch.position(of: p2).x - sketch.position(of: p1).x) < 1e-6)
    }

    @Test("EqualLength: two lines end up the same length")
    func equalLength() {
        let sketch = PlaneGCSSketch()
        let l1p1 = sketch.addPoint(x: 0, y: 0, fixed: true)
        let l1p2 = sketch.addPoint(x: 6, y: 0, fixed: true)
        let line1 = sketch.addLine(l1p1, l1p2)
        let l2p1 = sketch.addPoint(x: 0, y: 5, fixed: true)
        let l2p2 = sketch.addPoint(x: 9, y: 5, fixed: false)
        let line2 = sketch.addLine(l2p1, l2p2)
        sketch.addEqualLengthConstraint(line1, line2)

        let status = sketch.solve()
        let length1 = gcsDistance(sketch.position(of: l1p1), sketch.position(of: l1p2))
        let length2 = gcsDistance(sketch.position(of: l2p1), sketch.position(of: l2p2))

        #expect(status == .success)
        #expect(abs(length1 - length2) < 1e-6)
    }

    @Test("P2PSymmetric (Line overload): two points end up mirrored about the given line")
    func symmetricAboutLine() {
        let sketch = PlaneGCSSketch()
        let lp1 = sketch.addPoint(x: 0, y: 0, fixed: true)
        let lp2 = sketch.addPoint(x: 10, y: 0, fixed: true)
        let line = sketch.addLine(lp1, lp2)
        let p1 = sketch.addPoint(x: 3, y: 4, fixed: true)
        let p2 = sketch.addPoint(x: 1, y: 1, fixed: false)
        sketch.addSymmetricConstraint(p1, p2, about: line)

        let status = sketch.solve()
        let pos2 = sketch.position(of: p2)

        // Mirrored about the x-axis: p2 should land at (3, -4).
        #expect(status == .success)
        #expect(abs(pos2.x - 3.0) < 1e-6)
        #expect(abs(pos2.y - (-4.0)) < 1e-6)
    }
}
