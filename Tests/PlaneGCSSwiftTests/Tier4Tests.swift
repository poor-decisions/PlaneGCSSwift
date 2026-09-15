import Testing
@testable import PlaneGCSSwift

@Suite("Tier 4: constraints needing an Arc")
struct Tier4Tests {

    @Test("ArcRules: start/end points snap onto center+radius+angles")
    func arcRules() {
        let sketch = PlaneGCSSketch()
        let center = sketch.addPoint(x: 0, y: 0, fixed: true)
        let start = sketch.addPoint(x: 1, y: 1, fixed: false) // deliberately wrong
        let end = sketch.addPoint(x: -1, y: -1, fixed: false) // deliberately wrong
        let arc = sketch.addArc(center: center, start: start, end: end,
                                 radius: 5.0, startAngle: 0, endAngle: .pi / 2, fixed: true)
        sketch.addArcRulesConstraint(arc)

        let status = sketch.solve()

        #expect(status == .success)
        #expect(abs(sketch.position(of: start).x - 5.0) < 1e-6)
        #expect(abs(sketch.position(of: start).y) < 1e-6)
        #expect(abs(sketch.position(of: end).x) < 1e-6)
        #expect(abs(sketch.position(of: end).y - 5.0) < 1e-6)
    }

    @Test("PointOnArc: point moves onto the arc's underlying circle (distance == radius)")
    func pointOnArc() {
        let sketch = PlaneGCSSketch()
        let center = sketch.addPoint(x: 0, y: 0, fixed: true)
        let start = sketch.addPoint(x: 5, y: 0, fixed: true)
        let end = sketch.addPoint(x: 0, y: 5, fixed: true)
        let arc = sketch.addArc(center: center, start: start, end: end,
                                 radius: 5.0, startAngle: 0, endAngle: .pi / 2, fixed: true)
        let p = sketch.addPoint(x: 1, y: 1, fixed: false)
        sketch.addPointOnArcConstraint(p, arc)

        let status = sketch.solve()

        #expect(status == .success)
        #expect(abs(gcsDistance(sketch.position(of: p), sketch.position(of: center)) - 5.0) < 1e-6)
    }

    @Test("ArcRadius: a free arc's radius is driven to the target value")
    func arcRadius() {
        let sketch = PlaneGCSSketch()
        let center = sketch.addPoint(x: 0, y: 0, fixed: true)
        let start = sketch.addPoint(x: 1, y: 0, fixed: false)
        let end = sketch.addPoint(x: 0, y: 1, fixed: false)
        let arc = sketch.addArc(center: center, start: start, end: end,
                                 radius: 1.0, startAngle: 0, endAngle: .pi / 2)
        sketch.addRadiusConstraint(arc, radius: 6.0)

        let status = sketch.solve()

        #expect(status == .success)
        #expect(abs(sketch.radius(of: arc) - 6.0) < 1e-6)
    }

    @Test("ArcDiameter: a free arc's radius is driven to target diameter / 2")
    func arcDiameter() {
        let sketch = PlaneGCSSketch()
        let center = sketch.addPoint(x: 0, y: 0, fixed: true)
        let start = sketch.addPoint(x: 1, y: 0, fixed: false)
        let end = sketch.addPoint(x: 0, y: 1, fixed: false)
        let arc = sketch.addArc(center: center, start: start, end: end,
                                 radius: 1.0, startAngle: 0, endAngle: .pi / 2)
        sketch.addDiameterConstraint(arc, diameter: 14.0)

        let status = sketch.solve()

        #expect(status == .success)
        #expect(abs(sketch.radius(of: arc) - 7.0) < 1e-6)
    }

    @Test("ArcLength: radius * (endAngle - startAngle) matches the target length")
    func arcLength() {
        let sketch = PlaneGCSSketch()
        let center = sketch.addPoint(x: 0, y: 0, fixed: true)
        let start = sketch.addPoint(x: 1, y: 0, fixed: false)
        let end = sketch.addPoint(x: 0, y: 1, fixed: false)
        let arc = sketch.addArc(center: center, start: start, end: end,
                                 radius: 2.0, startAngle: 0, endAngle: 1.0)
        sketch.addRadiusConstraint(arc, radius: 4.0)
        sketch.addLengthConstraint(arc, length: 6.0)

        let status = sketch.solve()
        let sweep = sketch.endAngle(of: arc) - sketch.startAngle(of: arc)

        #expect(status == .success)
        #expect(abs(sketch.radius(of: arc) - 4.0) < 1e-6)
        #expect(abs(sketch.radius(of: arc) * sweep - 6.0) < 1e-6)
    }

    @Test("PerpendicularLine2Arc: p2 snaps to the arc's start, p1->p2 aligns with the radial direction")
    func perpendicularLine2Arc() {
        let sketch = PlaneGCSSketch()
        let center = sketch.addPoint(x: 0, y: 0, fixed: true)
        let start = sketch.addPoint(x: 2, y: 2, fixed: false)
        let end = sketch.addPoint(x: -5, y: -5, fixed: true)
        // startAngle 0 => radial direction (1, 0): the resulting line must be horizontal.
        let arc = sketch.addArc(center: center, start: start, end: end,
                                 radius: 5.0, startAngle: 0, endAngle: .pi / 2, fixed: true)
        let p1 = sketch.addPoint(x: -5, y: 0, fixed: true)
        let p2 = sketch.addPoint(x: 2, y: 3, fixed: false)
        sketch.addPerpendicularConstraint(lineFrom: p1, to: p2, arc)

        let status = sketch.solve()

        #expect(status == .success)
        #expect(gcsDistance(sketch.position(of: p2), sketch.position(of: start)) < 1e-6)
        #expect(abs(sketch.position(of: p2).y - sketch.position(of: p1).y) < 1e-6)
    }

    @Test("PerpendicularArc2Line: p1 snaps to the arc's end, p1->p2 aligns with the radial direction")
    func perpendicularArc2Line() {
        let sketch = PlaneGCSSketch()
        let center = sketch.addPoint(x: 0, y: 0, fixed: true)
        let start = sketch.addPoint(x: 5, y: 0, fixed: true)
        let end = sketch.addPoint(x: -2, y: 2, fixed: false)
        // endAngle pi => radial direction (-1, 0): the resulting line must be horizontal.
        let arc = sketch.addArc(center: center, start: start, end: end,
                                 radius: 5.0, startAngle: 0, endAngle: .pi, fixed: true)
        let p1 = sketch.addPoint(x: -2, y: 3, fixed: false)
        let p2 = sketch.addPoint(x: 5, y: 0, fixed: true)
        sketch.addPerpendicularConstraint(arc, lineFrom: p1, to: p2)

        let status = sketch.solve()

        #expect(status == .success)
        #expect(gcsDistance(sketch.position(of: p1), sketch.position(of: end)) < 1e-6)
        #expect(abs(sketch.position(of: p1).y - sketch.position(of: p2).y) < 1e-6)
    }

    @Test("PerpendicularCircle2Arc: arc's start point moves onto the given (center, radius) circle")
    func perpendicularCircle2Arc() {
        let sketch = PlaneGCSSketch()
        let center = sketch.addPoint(x: 10, y: 10, fixed: true)
        let start = sketch.addPoint(x: 1, y: 1, fixed: false)
        let end = sketch.addPoint(x: -1, y: -1, fixed: true)
        let arc = sketch.addArc(center: center, start: start, end: end,
                                 radius: 5.0, startAngle: 0, endAngle: .pi / 2, fixed: true)
        let circleCenter = sketch.addPoint(x: 0, y: 0, fixed: true)
        sketch.addPerpendicularConstraint(circleCenter: circleCenter, circleRadius: 20.0, arc)

        let status = sketch.solve()

        #expect(status == .success)
        #expect(abs(gcsDistance(sketch.position(of: start), sketch.position(of: circleCenter)) - 20.0) < 1e-6)
    }

    @Test("PerpendicularArc2Circle: arc's end point moves onto the given (center, radius) circle")
    func perpendicularArc2Circle() {
        let sketch = PlaneGCSSketch()
        let center = sketch.addPoint(x: 10, y: 10, fixed: true)
        let start = sketch.addPoint(x: 1, y: 1, fixed: true)
        let end = sketch.addPoint(x: -1, y: -1, fixed: false)
        let arc = sketch.addArc(center: center, start: start, end: end,
                                 radius: 5.0, startAngle: 0, endAngle: .pi / 2, fixed: true)
        let circleCenter = sketch.addPoint(x: 0, y: 0, fixed: true)
        sketch.addPerpendicularConstraint(arc, circleCenter: circleCenter, circleRadius: 15.0)

        let status = sketch.solve()

        #expect(status == .success)
        #expect(abs(gcsDistance(sketch.position(of: end), sketch.position(of: circleCenter)) - 15.0) < 1e-6)
    }

    @Test("PerpendicularArc2Arc: shared endpoint coincides, and the two radii there are perpendicular")
    func perpendicularArc2Arc() {
        // reverse1=false, reverse2=false picks a1.end and a2.start as the shared point (per
        // GCS.cpp). Both need to stay FREE: fixing either removes the degree of freedom the
        // solver needs to satisfy coincidence AND perpendicularity together (an earlier version
        // of this test fixed both, which made it unsatisfiable — solve() correctly returned
        // .failed rather than silently accepting a wrong answer).
        let sketch = PlaneGCSSketch()

        let center1 = sketch.addPoint(x: 0, y: 0, fixed: true)
        let start1 = sketch.addPoint(x: 0, y: 0, fixed: true) // unused end of arc1
        let end1 = sketch.addPoint(x: 4, y: 3, fixed: false)
        let arc1 = sketch.addArc(center: center1, start: start1, end: end1,
                                  radius: 5.0, startAngle: 0, endAngle: .pi / 2, fixed: true)

        let center2 = sketch.addPoint(x: 10, y: 0, fixed: true)
        let start2 = sketch.addPoint(x: 4, y: 3, fixed: false) // same initial guess as end1
        let end2 = sketch.addPoint(x: 20, y: 20, fixed: true) // unused end of arc2
        let arc2 = sketch.addArc(center: center2, start: start2, end: end2,
                                  radius: 5.0, startAngle: .pi, endAngle: .pi * 1.5, fixed: true)

        sketch.addPerpendicularConstraint(arc1, arc2)

        let status = sketch.solve()
        let sharedA = sketch.position(of: end1)
        let sharedB = sketch.position(of: start2)
        let r1 = sharedA - sketch.position(of: center1)
        let r2 = sharedB - sketch.position(of: center2)
        let dot = r1.x * r2.x + r1.y * r2.y

        #expect(status == .success)
        #expect(gcsDistance(sharedA, sharedB) < 1e-6) // coincident
        #expect(abs(dot) < 1e-6) // radii perpendicular at the shared point
        // Closed-form check: by Thales' theorem, a point whose vectors to two fixed
        // centers are perpendicular lies on the circle with those centers as diameter
        // endpoints — here centered at (5, 0) with radius 5.
        #expect(abs(gcsDistance(sharedA, SIMD2(5, 0)) - 5.0) < 1e-6)
    }

    @Test("Tangent (Line, Arc): a movable horizontal line settles at the arc's radius height")
    func tangentLineArc() {
        let sketch = PlaneGCSSketch()
        let center = sketch.addPoint(x: 0, y: 0, fixed: true)
        let start = sketch.addPoint(x: 3, y: 0, fixed: true)
        let end = sketch.addPoint(x: 0, y: 3, fixed: true)
        let arc = sketch.addArc(center: center, start: start, end: end,
                                 radius: 3.0, startAngle: 0, endAngle: .pi / 2, fixed: true)
        let l1 = sketch.addPoint(x: -5, y: 1, fixed: false)
        let l2 = sketch.addPoint(x: 5, y: 1, fixed: false)
        let line = sketch.addLine(l1, l2)
        sketch.addHorizontalConstraint(line)
        sketch.addTangentConstraint(line, arc)
        sketch.addCoordinateXConstraint(l1, x: -5.0)
        sketch.addCoordinateXConstraint(l2, x: 5.0)

        let status = sketch.solve()

        #expect(status == .success)
        #expect(abs(sketch.position(of: l1).y - 3.0) < 1e-5)
        #expect(abs(sketch.position(of: l2).y - 3.0) < 1e-5)
    }

    @Test("Tangent (Arc, Arc): two arcs' underlying circles end up externally tangent")
    func tangentArcs() {
        let sketch = PlaneGCSSketch()
        let center1 = sketch.addPoint(x: 0, y: 0, fixed: true)
        let s1 = sketch.addPoint(x: 3, y: 0, fixed: true)
        let e1 = sketch.addPoint(x: 0, y: 3, fixed: true)
        let arc1 = sketch.addArc(center: center1, start: s1, end: e1,
                                  radius: 3.0, startAngle: 0, endAngle: .pi / 2, fixed: true)

        let center2 = sketch.addPoint(x: 20, y: 0, fixed: false) // far enough that external tangency is picked
        let s2 = sketch.addPoint(x: 22, y: 0, fixed: true)
        let e2 = sketch.addPoint(x: 20, y: 2, fixed: true)
        let arc2 = sketch.addArc(center: center2, start: s2, end: e2,
                                  radius: 2.0, startAngle: 0, endAngle: .pi / 2, fixed: true)

        sketch.addTangentConstraint(arc1, arc2)
        sketch.addHorizontalConstraint(center1, center2)

        let status = sketch.solve()
        let d = gcsDistance(sketch.position(of: center1), sketch.position(of: center2))

        #expect(status == .success)
        #expect(abs(d - 5.0) < 1e-6) // external tangency: distance == r1 + r2
    }

    @Test("Tangent (Circle, Arc): a circle and an arc's underlying circle end up externally tangent")
    func tangentCircleArc() {
        let sketch = PlaneGCSSketch()
        let circleCenter = sketch.addPoint(x: 0, y: 0, fixed: true)
        let circle = sketch.addCircle(center: circleCenter, radius: 4.0, fixed: true)

        let arcCenter = sketch.addPoint(x: 20, y: 0, fixed: false)
        let s = sketch.addPoint(x: 22, y: 0, fixed: true)
        let e = sketch.addPoint(x: 20, y: 2, fixed: true)
        let arc = sketch.addArc(center: arcCenter, start: s, end: e,
                                 radius: 2.0, startAngle: 0, endAngle: .pi / 2, fixed: true)

        sketch.addTangentConstraint(circle, arc)
        sketch.addHorizontalConstraint(circleCenter, arcCenter)

        let status = sketch.solve()
        let d = gcsDistance(sketch.position(of: circleCenter), sketch.position(of: arcCenter))

        #expect(status == .success)
        #expect(abs(d - 6.0) < 1e-6) // external tangency: distance == r1 + r2
    }

    @Test("EqualRadius (Circle, Arc): the arc's radius is driven to match the fixed circle's radius")
    func equalRadiusCircleArc() {
        let sketch = PlaneGCSSketch()
        let circleCenter = sketch.addPoint(x: 0, y: 0, fixed: true)
        let circle = sketch.addCircle(center: circleCenter, radius: 8.0, fixed: true)

        let arcCenter = sketch.addPoint(x: 20, y: 20, fixed: true)
        let s = sketch.addPoint(x: 1, y: 0, fixed: false)
        let e = sketch.addPoint(x: 0, y: 1, fixed: false)
        let arc = sketch.addArc(center: arcCenter, start: s, end: e,
                                 radius: 1.0, startAngle: 0, endAngle: .pi / 2)

        sketch.addEqualRadiusConstraint(circle, arc)

        let status = sketch.solve()

        #expect(status == .success)
        #expect(abs(sketch.radius(of: arc) - 8.0) < 1e-6)
    }

    @Test("EqualRadius (Arc, Arc): the second arc's radius is driven to match the first")
    func equalRadiusArcs() {
        let sketch = PlaneGCSSketch()
        let center1 = sketch.addPoint(x: 0, y: 0, fixed: true)
        let s1 = sketch.addPoint(x: 6, y: 0, fixed: true)
        let e1 = sketch.addPoint(x: 0, y: 6, fixed: true)
        let arc1 = sketch.addArc(center: center1, start: s1, end: e1,
                                  radius: 6.0, startAngle: 0, endAngle: .pi / 2, fixed: true)

        let center2 = sketch.addPoint(x: 20, y: 20, fixed: true)
        let s2 = sketch.addPoint(x: 1, y: 0, fixed: false)
        let e2 = sketch.addPoint(x: 0, y: 1, fixed: false)
        let arc2 = sketch.addArc(center: center2, start: s2, end: e2,
                                  radius: 1.0, startAngle: 0, endAngle: .pi / 2)

        sketch.addEqualRadiusConstraint(arc1, arc2)

        let status = sketch.solve()

        #expect(status == .success)
        #expect(abs(sketch.radius(of: arc2) - 6.0) < 1e-6)
    }
}
