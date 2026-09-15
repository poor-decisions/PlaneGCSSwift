import Foundation
import Testing
@testable import PlaneGCSSwift

@Suite("Tier 1: Point-only constraints")
struct Tier1Tests {

    @Test("P2PAngle sets the angle of the p1->p2 vector")
    func p2pAngle() {
        let sketch = PlaneGCSSketch()
        let p1 = sketch.addPoint(x: 0, y: 0, fixed: true)
        let p2 = sketch.addPoint(x: 4, y: 1, fixed: false)
        sketch.addDistanceConstraint(p1, p2, distance: 5.0)
        sketch.addAngleConstraint(p1, p2, angle: .pi / 3)

        let status = sketch.solve()
        let pos = sketch.position(of: p2)

        #expect(status == .success)
        #expect(abs(pos.x - 5.0 * cos(.pi / 3)) < 1e-6)
        #expect(abs(pos.y - 5.0 * sin(.pi / 3)) < 1e-6)
    }

    @Test("PointOnLine (3-point overload): point moves onto the line through two fixed points")
    func pointOnLineByPoints() {
        let sketch = PlaneGCSSketch()
        let lp1 = sketch.addPoint(x: 0, y: 0, fixed: true)
        let lp2 = sketch.addPoint(x: 10, y: 0, fixed: true)
        let p = sketch.addPoint(x: 5, y: 3, fixed: false)
        sketch.addPointOnLineConstraint(p, lineFrom: lp1, to: lp2)

        let status = sketch.solve()

        #expect(status == .success)
        #expect(abs(sketch.position(of: p).y) < 1e-6)
    }

    @Test("PointOnPerpBisector (3-point overload): point moves onto the perpendicular bisector")
    func pointOnPerpBisectorByPoints() {
        let sketch = PlaneGCSSketch()
        let lp1 = sketch.addPoint(x: 0, y: 0, fixed: true)
        let lp2 = sketch.addPoint(x: 10, y: 0, fixed: true)
        let p = sketch.addPoint(x: 7, y: 3, fixed: false)
        sketch.addPointOnPerpBisectorConstraint(p, lineFrom: lp1, to: lp2)

        let status = sketch.solve()

        // The perpendicular bisector of (0,0)-(10,0) is the vertical line x=5.
        #expect(status == .success)
        #expect(abs(sketch.position(of: p).x - 5.0) < 1e-6)
    }

    @Test("Perpendicular (4-point overload): forces two point-defined lines to meet at 90 degrees")
    func perpendicularByPoints() {
        let sketch = PlaneGCSSketch()
        let l1p1 = sketch.addPoint(x: 0, y: 0, fixed: true)
        let l1p2 = sketch.addPoint(x: 10, y: 0, fixed: true)
        let l2p1 = sketch.addPoint(x: 5, y: -5, fixed: true)
        let l2p2 = sketch.addPoint(x: 7, y: 5, fixed: false)
        sketch.addPerpendicularConstraint(line1From: l1p1, to: l1p2, line2From: l2p1, to: l2p2)

        let status = sketch.solve()

        // line1 is horizontal, so a perpendicular line2 must be vertical: both x's equal.
        #expect(status == .success)
        #expect(abs(sketch.position(of: l2p2).x - sketch.position(of: l2p1).x) < 1e-6)
    }

    @Test("L2LAngle (4-point overload): sets the angle between two point-defined lines")
    func l2lAngleByPoints() {
        let sketch = PlaneGCSSketch()
        let l1p1 = sketch.addPoint(x: 0, y: 0, fixed: true)
        let l1p2 = sketch.addPoint(x: 10, y: 0, fixed: true)
        let l2p1 = sketch.addPoint(x: 0, y: 0, fixed: true)
        let l2p2 = sketch.addPoint(x: 5, y: 5, fixed: false)
        sketch.addAngleConstraint(
            line1From: l1p1, to: l1p2, line2From: l2p1, to: l2p2, angle: .pi / 4
        )

        let status = sketch.solve()
        let pos = sketch.position(of: l2p2)
        let resultingAngle = atan2(pos.y - sketch.position(of: l2p1).y, pos.x - sketch.position(of: l2p1).x)

        #expect(status == .success)
        #expect(abs(resultingAngle - .pi / 4) < 1e-6)
    }

    @Test("MidpointOnLine (4-point overload): the midpoint of line1 lies on the (infinite) line2")
    func midpointOnLineByPoints() {
        let sketch = PlaneGCSSketch()
        // line1: fixed segment (0,0)-(10,0), midpoint = (5, 0)
        let l1p1 = sketch.addPoint(x: 0, y: 0, fixed: true)
        let l1p2 = sketch.addPoint(x: 10, y: 0, fixed: true)
        // line2: one fixed point off to the side, one free point that must swing
        // so the line through both passes through (5, 0).
        let l2p1 = sketch.addPoint(x: 5, y: 10, fixed: true)
        let l2p2 = sketch.addPoint(x: 8, y: -3, fixed: false)
        sketch.addMidpointOnLineConstraint(line1From: l1p1, to: l1p2, line2From: l2p1, to: l2p2)

        let status = sketch.solve()
        let a = sketch.position(of: l2p1)
        let b = sketch.position(of: l2p2)
        // Collinearity of a, b, and (5,0): cross product of (b-a) and ((5,0)-a) is ~0.
        let cross = (b.x - a.x) * (0 - a.y) - (b.y - a.y) * (5 - a.x)

        #expect(status == .success)
        #expect(abs(cross) < 1e-6)
    }

    @Test("TangentCircumf: two circles (given as center points + radii) end up externally tangent")
    func tangentCircumf() {
        let sketch = PlaneGCSSketch()
        let p1 = sketch.addPoint(x: 0, y: 0, fixed: true)
        let p2 = sketch.addPoint(x: 3, y: 0, fixed: false)
        sketch.addTangentCircumferenceConstraint(p1, radius1: 2.0, p2, radius2: 1.0)

        let status = sketch.solve()
        let d = gcsDistance(sketch.position(of: p1), sketch.position(of: p2))

        #expect(status == .success)
        #expect(abs(d - 3.0) < 1e-6) // external tangency: distance == r1 + r2
    }

    @Test("P2PCoincident merges two points to the same position")
    func coincident() {
        let sketch = PlaneGCSSketch()
        let p1 = sketch.addPoint(x: 2, y: 3, fixed: true)
        let p2 = sketch.addPoint(x: 9, y: 9, fixed: false)
        sketch.addCoincidentConstraint(p1, p2)

        let status = sketch.solve()

        #expect(status == .success)
        #expect(gcsDistance(sketch.position(of: p1), sketch.position(of: p2)) < 1e-6)
    }

    @Test("Horizontal (2-point overload): forces equal y")
    func horizontalByPoints() {
        let sketch = PlaneGCSSketch()
        let p1 = sketch.addPoint(x: 0, y: 0, fixed: true)
        let p2 = sketch.addPoint(x: 5, y: 7, fixed: false)
        sketch.addHorizontalConstraint(p1, p2)

        let status = sketch.solve()

        #expect(status == .success)
        #expect(abs(sketch.position(of: p2).y - sketch.position(of: p1).y) < 1e-6)
    }

    @Test("Vertical (2-point overload): forces equal x")
    func verticalByPoints() {
        let sketch = PlaneGCSSketch()
        let p1 = sketch.addPoint(x: 0, y: 0, fixed: true)
        let p2 = sketch.addPoint(x: 7, y: 5, fixed: false)
        sketch.addVerticalConstraint(p1, p2)

        let status = sketch.solve()

        #expect(status == .success)
        #expect(abs(sketch.position(of: p2).x - sketch.position(of: p1).x) < 1e-6)
    }

    @Test("CoordinateX pins a point's x, leaving y free")
    func coordinateX() {
        let sketch = PlaneGCSSketch()
        let p = sketch.addPoint(x: 0, y: 3, fixed: false)
        sketch.addCoordinateXConstraint(p, x: 12.5)

        let status = sketch.solve()

        #expect(status == .success)
        #expect(abs(sketch.position(of: p).x - 12.5) < 1e-6)
    }

    @Test("CoordinateY pins a point's y, leaving x free")
    func coordinateY() {
        let sketch = PlaneGCSSketch()
        let p = sketch.addPoint(x: 3, y: 0, fixed: false)
        sketch.addCoordinateYConstraint(p, y: -8.25)

        let status = sketch.solve()

        #expect(status == .success)
        #expect(abs(sketch.position(of: p).y - (-8.25)) < 1e-6)
    }

    @Test("P2PSymmetric (3-point overload): p1 and p2 end up mirrored about the given point")
    func symmetricByPoint() {
        let sketch = PlaneGCSSketch()
        let about = sketch.addPoint(x: 5, y: 5, fixed: true)
        let p1 = sketch.addPoint(x: 0, y: 5, fixed: true)
        let p2 = sketch.addPoint(x: 1, y: 1, fixed: false)
        sketch.addSymmetricConstraint(p1, p2, about: about)

        let status = sketch.solve()
        let pos2 = sketch.position(of: p2)

        // Mirrored about (5,5): p2 should land at (10, 5).
        #expect(status == .success)
        #expect(abs(pos2.x - 10.0) < 1e-6)
        #expect(abs(pos2.y - 5.0) < 1e-6)
    }
}
