import PlaneGCSSwift

func distance(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
    let d = a - b
    return (d.x * d.x + d.y * d.y).squareRoot()
}

func check(_ label: String, _ condition: Bool) -> Bool {
    print("[demo] \(label): \(condition ? "PASS" : "FAIL")")
    return condition
}

var allPassed = true

// --- Test 1: basic Point-only distance constraint + drag ---
do {
    let sketch = PlaneGCSSketch()
    let p1 = sketch.addPoint(x: 0, y: 0, fixed: true)
    let p2 = sketch.addPoint(x: 3, y: 0, fixed: false)
    sketch.addDistanceConstraint(p1, p2, distance: 5.0)

    let status1 = sketch.solve()
    let pos1 = sketch.position(of: p2)
    allPassed = check(
        "basic distance solve",
        status1 == .success && abs(distance(pos1, sketch.position(of: p1)) - 5.0) < 1e-6
    ) && allPassed

    sketch.setPosition(of: p2, x: 1, y: 1)
    let status2 = sketch.solve()
    let pos2 = sketch.position(of: p2)
    allPassed = check(
        "drag-then-resolve",
        status2 == .success && abs(distance(pos2, sketch.position(of: p1)) - 5.0) < 1e-6
    ) && allPassed
}

// --- Test 2: a Line-based quadrilateral (parallel + perpendicular + equal length + horizontal) ---
// Build a wonky quadrilateral, then constrain it toward an axis-aligned rectangle:
// bottom edge horizontal, left edge perpendicular to it, opposite sides parallel and equal length.
do {
    let sketch = PlaneGCSSketch()
    let a = sketch.addPoint(x: 0, y: 0, fixed: true)     // bottom-left, anchor
    let b = sketch.addPoint(x: 9, y: 1, fixed: false)    // bottom-right, should end up horizontal from a
    let c = sketch.addPoint(x: 10, y: 6, fixed: false)   // top-right
    let d = sketch.addPoint(x: -1, y: 5, fixed: false)   // top-left

    let bottom = sketch.addLine(a, b)
    let right = sketch.addLine(b, c)
    let top = sketch.addLine(d, c)
    let left = sketch.addLine(a, d)

    sketch.addHorizontalConstraint(bottom)
    sketch.addPerpendicularConstraint(bottom, left)
    sketch.addParallelConstraint(bottom, top)
    sketch.addParallelConstraint(left, right)
    sketch.addEqualLengthConstraint(bottom, top)
    sketch.addEqualLengthConstraint(left, right)
    sketch.addDistanceConstraint(a, b, distance: 8.0)
    sketch.addDistanceConstraint(a, d, distance: 4.0)

    let status = sketch.solve()
    let pa = sketch.position(of: a)
    let pb = sketch.position(of: b)
    let pc = sketch.position(of: c)
    let pd = sketch.position(of: d)
    print("[demo] quadrilateral solved to: a=\(pa) b=\(pb) c=\(pc) d=\(pd)")

    let isRectangle =
        abs(pa.y - pb.y) < 1e-6 &&                 // bottom horizontal
        abs(pb.x - pc.x) < 1e-6 &&                 // right vertical (perp to horizontal bottom + parallel sides)
        abs(pd.y - pc.y) < 1e-6 &&                 // top horizontal
        abs(distance(pa, pb) - 8.0) < 1e-6 &&
        abs(distance(pa, pd) - 4.0) < 1e-6

    allPassed = check("quadrilateral resolves to an 8x4 axis-aligned rectangle", status == .success && isRectangle) && allPassed
}

// --- Test 3: Circle radius + tangent-to-line constraints ---
do {
    let sketch = PlaneGCSSketch()
    let center = sketch.addPoint(x: 5, y: 5, fixed: true)
    let circle = sketch.addCircle(center: center, radius: 1.0) // free radius, wrong initial guess

    sketch.addRadiusConstraint(circle, radius: 3.0)

    let status = sketch.solve()
    let solvedRadius = sketch.radius(of: circle)
    print("[demo] circle radius solved to: \(solvedRadius)")
    allPassed = check("circle radius constraint", status == .success && abs(solvedRadius - 3.0) < 1e-6) && allPassed
}

// --- Test 4: line tangent to a circle ---
do {
    let sketch = PlaneGCSSketch()
    let center = sketch.addPoint(x: 0, y: 0, fixed: true)
    let circle = sketch.addCircle(center: center, radius: 2.0, fixed: true)

    // A horizontal-ish line that starts off NOT tangent (passes through the circle).
    let l1 = sketch.addPoint(x: -5, y: 1, fixed: false)
    let l2 = sketch.addPoint(x: 5, y: 1, fixed: false)
    let line = sketch.addLine(l1, l2)

    sketch.addHorizontalConstraint(line)
    sketch.addTangentConstraint(line, circle)
    // Pin the line's x-extent so it doesn't degenerate to a point during solving.
    sketch.addCoordinateXConstraint(l1, x: -5.0)
    sketch.addCoordinateXConstraint(l2, x: 5.0)

    let status = sketch.solve()
    let y1 = sketch.position(of: l1).y
    let y2 = sketch.position(of: l2).y
    print("[demo] tangent line y-height solved to: \(y1), \(y2) (expect ~2.0, the circle's radius)")
    allPassed = check(
        "line tangent to circle",
        status == .success && abs(y1 - 2.0) < 1e-5 && abs(y2 - 2.0) < 1e-5
    ) && allPassed
}

// --- Test 5: Arc (ArcRules + ArcRadius + PointOnArc) ---
do {
    let sketch = PlaneGCSSketch()
    let center = sketch.addPoint(x: 0, y: 0, fixed: true)
    let start = sketch.addPoint(x: 1, y: 0, fixed: false)
    let end = sketch.addPoint(x: 0, y: 1, fixed: false)
    let arc = sketch.addArc(center: center, start: start, end: end,
                             radius: 1.0, startAngle: 0, endAngle: .pi / 2)

    sketch.addArcRulesConstraint(arc)
    sketch.addRadiusConstraint(arc, radius: 5.0)

    let onArcPoint = sketch.addPoint(x: 3, y: 3, fixed: false)
    sketch.addPointOnArcConstraint(onArcPoint, arc)

    let status = sketch.solve()
    let centerPos = sketch.position(of: center)
    let startPos = sketch.position(of: start)
    let endPos = sketch.position(of: end)
    let onArcPos = sketch.position(of: onArcPoint)

    let startDist = distance(startPos, centerPos)
    let endDist = distance(endPos, centerPos)
    let onArcDist = distance(onArcPos, centerPos)

    print("[demo] arc solved: radius=\(sketch.radius(of: arc)), start=\(startPos) (dist \(startDist)), end=\(endPos) (dist \(endDist)), onArcPoint=\(onArcPos) (dist \(onArcDist))")

    allPassed = check(
        "arc rules + radius + point-on-arc",
        status == .success
            && abs(sketch.radius(of: arc) - 5.0) < 1e-6
            && abs(startDist - 5.0) < 1e-6
            && abs(endDist - 5.0) < 1e-6
            && abs(onArcDist - 5.0) < 1e-6
    ) && allPassed
}

print("\n[demo] Overall: \(allPassed ? "ALL PASS" : "SOME FAILED")")
