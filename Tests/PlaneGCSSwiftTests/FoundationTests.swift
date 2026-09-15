import Testing
@testable import PlaneGCSSwift

func gcsDistance(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
    let d = a - b
    return (d.x * d.x + d.y * d.y).squareRoot()
}

@Suite("Foundation: session/buffer layer")
struct FoundationTests {

    @Test("A basic distance constraint solves correctly")
    func basicDistanceSolve() {
        let sketch = PlaneGCSSketch()
        let p1 = sketch.addPoint(x: 0, y: 0, fixed: true)
        let p2 = sketch.addPoint(x: 3, y: 0, fixed: false)
        sketch.addDistanceConstraint(p1, p2, distance: 5.0)

        let status = sketch.solve()
        let pos = sketch.position(of: p2)

        #expect(status == .success)
        #expect(abs(gcsDistance(pos, sketch.position(of: p1)) - 5.0) < 1e-6)
    }

    @Test("Dragging a point (direct buffer write + re-solve) resolves toward the drag direction")
    func dragThenResolve() {
        let sketch = PlaneGCSSketch()
        let p1 = sketch.addPoint(x: 0, y: 0, fixed: true)
        let p2 = sketch.addPoint(x: 3, y: 0, fixed: false)
        sketch.addDistanceConstraint(p1, p2, distance: 5.0)
        sketch.solve()

        // (1, 1) clearly violates distance = 5 (actual distance ~1.41).
        sketch.setPosition(of: p2, x: 1, y: 1)
        let status = sketch.solve()
        let pos = sketch.position(of: p2)

        #expect(status == .success)
        #expect(abs(gcsDistance(pos, sketch.position(of: p1)) - 5.0) < 1e-6)
        // Resolved toward the drag target's direction, not an arbitrary point
        // on the constraint circle: both coordinates should keep the sign
        // implied by dragging into the first quadrant.
        #expect(pos.x > 0)
        #expect(pos.y > 0)
    }

    @Test("A fixed point never moves, even when it participates in a constraint")
    func fixedPointStaysPut() {
        let sketch = PlaneGCSSketch()
        let p1 = sketch.addPoint(x: 2, y: 2, fixed: true)
        let p2 = sketch.addPoint(x: 10, y: 10, fixed: false)
        sketch.addDistanceConstraint(p1, p2, distance: 1.0)

        sketch.solve()

        #expect(sketch.position(of: p1) == SIMD2(2, 2))
    }

    @Test("Solving with no constraints at all succeeds trivially")
    func solveWithNoConstraints() {
        let sketch = PlaneGCSSketch()
        _ = sketch.addPoint(x: 1, y: 1, fixed: false)

        let status = sketch.solve()

        #expect(status == .success)
    }
}
