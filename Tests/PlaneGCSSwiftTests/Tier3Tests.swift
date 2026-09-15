import Testing
@testable import PlaneGCSSwift

@Suite("Tier 3: constraints needing a Circle")
struct Tier3Tests {

    @Test("PointOnCircle: point moves onto the circle's circumference")
    func pointOnCircle() {
        let sketch = PlaneGCSSketch()
        let center = sketch.addPoint(x: 0, y: 0, fixed: true)
        let circle = sketch.addCircle(center: center, radius: 5.0, fixed: true)
        let p = sketch.addPoint(x: 1, y: 1, fixed: false)
        sketch.addPointOnCircleConstraint(p, circle)

        let status = sketch.solve()

        #expect(status == .success)
        #expect(abs(gcsDistance(sketch.position(of: p), sketch.position(of: center)) - 5.0) < 1e-6)
    }

    @Test("CircleRadius: a free circle's radius is driven to the target value")
    func circleRadius() {
        let sketch = PlaneGCSSketch()
        let center = sketch.addPoint(x: 0, y: 0, fixed: true)
        let circle = sketch.addCircle(center: center, radius: 1.0)
        sketch.addRadiusConstraint(circle, radius: 7.5)

        let status = sketch.solve()

        #expect(status == .success)
        #expect(abs(sketch.radius(of: circle) - 7.5) < 1e-6)
    }

    @Test("CircleDiameter: a free circle's radius is driven to target diameter / 2")
    func circleDiameter() {
        let sketch = PlaneGCSSketch()
        let center = sketch.addPoint(x: 0, y: 0, fixed: true)
        let circle = sketch.addCircle(center: center, radius: 1.0)
        sketch.addDiameterConstraint(circle, diameter: 9.0)

        let status = sketch.solve()

        #expect(status == .success)
        #expect(abs(sketch.radius(of: circle) - 4.5) < 1e-6)
    }

    @Test("EqualRadius (Circle, Circle): two circles end up the same radius")
    func equalRadius() {
        let sketch = PlaneGCSSketch()
        let c1Center = sketch.addPoint(x: 0, y: 0, fixed: true)
        let circle1 = sketch.addCircle(center: c1Center, radius: 3.0, fixed: true)
        let c2Center = sketch.addPoint(x: 20, y: 0, fixed: true)
        let circle2 = sketch.addCircle(center: c2Center, radius: 1.0)
        sketch.addEqualRadiusConstraint(circle1, circle2)

        let status = sketch.solve()

        #expect(status == .success)
        #expect(abs(sketch.radius(of: circle2) - 3.0) < 1e-6)
    }

    @Test("Tangent (Line, Circle): a movable horizontal line settles at the circle's radius height")
    func tangentLineCircle() {
        let sketch = PlaneGCSSketch()
        let center = sketch.addPoint(x: 0, y: 0, fixed: true)
        let circle = sketch.addCircle(center: center, radius: 2.0, fixed: true)
        let l1 = sketch.addPoint(x: -5, y: 1, fixed: false)
        let l2 = sketch.addPoint(x: 5, y: 1, fixed: false)
        let line = sketch.addLine(l1, l2)
        sketch.addHorizontalConstraint(line)
        sketch.addTangentConstraint(line, circle)
        sketch.addCoordinateXConstraint(l1, x: -5.0)
        sketch.addCoordinateXConstraint(l2, x: 5.0)

        let status = sketch.solve()

        #expect(status == .success)
        #expect(abs(sketch.position(of: l1).y - 2.0) < 1e-5)
        #expect(abs(sketch.position(of: l2).y - 2.0) < 1e-5)
    }

    @Test("Tangent (Circle, Circle): two circles end up externally tangent")
    func tangentCircles() {
        let sketch = PlaneGCSSketch()
        let c1Center = sketch.addPoint(x: 0, y: 0, fixed: true)
        let circle1 = sketch.addCircle(center: c1Center, radius: 3.0, fixed: true)
        let c2Center = sketch.addPoint(x: 10, y: 0, fixed: false)
        let circle2 = sketch.addCircle(center: c2Center, radius: 2.0, fixed: true)
        sketch.addTangentConstraint(circle1, circle2)
        sketch.addHorizontalConstraint(c1Center, c2Center)

        let status = sketch.solve()
        let d = gcsDistance(sketch.position(of: c1Center), sketch.position(of: c2Center))

        #expect(status == .success)
        #expect(abs(d - 5.0) < 1e-6) // external tangency: distance == r1 + r2
    }

    @Test("C2CDistance: the GAP between the two circles' edges (not center-to-center) matches the target")
    func c2cDistance() {
        // ConstraintC2CDistance::error (outer case): distance(centers) - (r1 + r2 + target) == 0,
        // i.e. `distance` is the edge-to-edge gap, not center-to-center — confirmed from
        // Constraints.cpp rather than assumed.
        let sketch = PlaneGCSSketch()
        let c1Center = sketch.addPoint(x: 0, y: 0, fixed: true)
        let circle1 = sketch.addCircle(center: c1Center, radius: 1.0, fixed: true)
        let c2Center = sketch.addPoint(x: 3, y: 4, fixed: false)
        let circle2 = sketch.addCircle(center: c2Center, radius: 1.0, fixed: true)
        sketch.addDistanceConstraint(circle1, circle2, distance: 20.0)

        let status = sketch.solve()

        #expect(status == .success)
        #expect(abs(gcsDistance(sketch.position(of: c1Center), sketch.position(of: c2Center)) - 22.0) < 1e-6)
    }

    @Test("C2LDistance: the GAP between the circle's edge and the line (not center-to-line) matches the target")
    func c2lDistance() {
        // ConstraintC2LDistance::error: distance() + circle.rad - h == 0, i.e. h (the actual
        // center-to-line distance) == target + radius — confirmed from Constraints.cpp.
        let sketch = PlaneGCSSketch()
        let lp1 = sketch.addPoint(x: 0, y: 0, fixed: true)
        let lp2 = sketch.addPoint(x: 10, y: 0, fixed: true)
        let line = sketch.addLine(lp1, lp2)
        let center = sketch.addPoint(x: 5, y: 1, fixed: false)
        let circle = sketch.addCircle(center: center, radius: 1.0, fixed: true)
        sketch.addDistanceConstraint(circle, line, distance: 6.0)

        let status = sketch.solve()

        #expect(status == .success)
        #expect(abs(abs(sketch.position(of: center).y) - 7.0) < 1e-6)
    }

    @Test("P2CDistance: the GAP between the point and the circle's edge (not point-to-center) matches the target")
    func p2cDistance() {
        // ConstraintP2CDistance::error (point starts outside the circle, our case):
        // circle.rad + distance() - length == 0, i.e. point-to-center length == radius + target —
        // confirmed from Constraints.cpp.
        let sketch = PlaneGCSSketch()
        let center = sketch.addPoint(x: 0, y: 0, fixed: true)
        let circle = sketch.addCircle(center: center, radius: 1.0, fixed: true)
        let p = sketch.addPoint(x: 2, y: 0, fixed: false)
        sketch.addDistanceConstraint(p, circle, distance: 15.0)

        let status = sketch.solve()

        #expect(status == .success)
        #expect(abs(gcsDistance(sketch.position(of: p), sketch.position(of: center)) - 16.0) < 1e-6)
    }
}
