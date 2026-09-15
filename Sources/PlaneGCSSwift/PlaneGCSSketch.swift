import PlaneGCSBridge

public enum SolveStatus: Int32, Sendable {
    case success = 0
    case converged = 1
    case failed = 2
    case successfulSolutionInvalid = 3
}

public struct PointID: Hashable, Sendable {
    public let rawValue: Int32
}

public struct LineID: Hashable, Sendable {
    public let rawValue: Int32
}

public struct CircleID: Hashable, Sendable {
    public let rawValue: Int32
}

public struct ArcID: Hashable, Sendable {
    public let rawValue: Int32
}

public struct ConstraintID: Hashable, Sendable {
    public let rawValue: Int32
}

/// A 2D constraint-solved sketch, backed by FreeCAD's PlaneGCS solver.
///
/// Swift never sees a raw pointer into the solver's parameter storage —
/// only opaque `PointID`/`LineID`/`CircleID` values. Dragging a point is
/// `setPosition(of:x:y:)` followed by `solve()`; there is no separate "drag"
/// API, because PlaneGCS itself works by mutating the parameter buffer in
/// place and re-resolving.
public final class PlaneGCSSketch {
    private let handle: PlaneGCSSketchRef

    public init() {
        handle = PlaneGCSSketchCreate()
    }

    deinit {
        PlaneGCSSketchRelease(handle)
    }

    // MARK: - Geometry

    @discardableResult
    public func addPoint(x: Double, y: Double, fixed: Bool = false) -> PointID {
        PointID(rawValue: PlaneGCSSketchAddPoint(handle, x, y, fixed))
    }

    public func setPosition(of point: PointID, x: Double, y: Double) {
        PlaneGCSSketchSetPointPosition(handle, point.rawValue, x, y)
    }

    public func position(of point: PointID) -> SIMD2<Double> {
        SIMD2(
            PlaneGCSSketchGetPointX(handle, point.rawValue),
            PlaneGCSSketchGetPointY(handle, point.rawValue)
        )
    }

    /// A Line is purely a reference to two existing points — no new
    /// parameters are allocated.
    @discardableResult
    public func addLine(_ p1: PointID, _ p2: PointID) -> LineID {
        LineID(rawValue: PlaneGCSSketchAddLine(handle, p1.rawValue, p2.rawValue))
    }

    /// A Circle references an existing center point plus one new radius
    /// parameter. A `fixed` circle's radius is reference geometry, excluded
    /// from solve()'s unknowns; a free circle's radius is something a
    /// constraint like `addRadiusConstraint` can actually adjust.
    @discardableResult
    public func addCircle(center: PointID, radius: Double, fixed: Bool = false) -> CircleID {
        CircleID(rawValue: PlaneGCSSketchAddCircle(handle, center.rawValue, radius, fixed))
    }

    public func radius(of circle: CircleID) -> Double {
        PlaneGCSSketchGetCircleRadius(handle, circle.rawValue)
    }

    /// An Arc's `start`/`end` points are only made geometrically consistent
    /// with its center/radius/angles once `addArcRulesConstraint` is added
    /// for it — GCS's own header comment: "start and end points are
    /// computed by an ArcRules constraint." Add that constraint right after
    /// creating the arc, before relying on its start/end positions.
    @discardableResult
    public func addArc(
        center: PointID, start: PointID, end: PointID,
        radius: Double, startAngle: Double, endAngle: Double,
        fixed: Bool = false
    ) -> ArcID {
        ArcID(rawValue: PlaneGCSSketchAddArc(
            handle, center.rawValue, start.rawValue, end.rawValue,
            radius, startAngle, endAngle, fixed))
    }

    public func radius(of arc: ArcID) -> Double {
        PlaneGCSSketchGetArcRadius(handle, arc.rawValue)
    }

    public func startAngle(of arc: ArcID) -> Double {
        PlaneGCSSketchGetArcStartAngle(handle, arc.rawValue)
    }

    public func endAngle(of arc: ArcID) -> Double {
        PlaneGCSSketchGetArcEndAngle(handle, arc.rawValue)
    }

    // MARK: - Constraints: Tier 1, Point-only

    @discardableResult
    public func addDistanceConstraint(
        _ p1: PointID, _ p2: PointID, distance: Double, tagId: Int32 = 0, driving: Bool = true
    ) -> ConstraintID {
        ConstraintID(rawValue: PlaneGCSSketchAddConstraintP2PDistance(
            handle, p1.rawValue, p2.rawValue, distance, tagId, driving))
    }

    @discardableResult
    public func addAngleConstraint(
        _ p1: PointID, _ p2: PointID, angle: Double, tagId: Int32 = 0, driving: Bool = true
    ) -> ConstraintID {
        ConstraintID(rawValue: PlaneGCSSketchAddConstraintP2PAngle(
            handle, p1.rawValue, p2.rawValue, angle, tagId, driving))
    }

    @discardableResult
    public func addPointOnLineConstraint(
        _ p: PointID, lineFrom lp1: PointID, to lp2: PointID, tagId: Int32 = 0, driving: Bool = true
    ) -> ConstraintID {
        ConstraintID(rawValue: PlaneGCSSketchAddConstraintPointOnLineByPoints(
            handle, p.rawValue, lp1.rawValue, lp2.rawValue, tagId, driving))
    }

    @discardableResult
    public func addPointOnPerpBisectorConstraint(
        _ p: PointID, lineFrom lp1: PointID, to lp2: PointID, tagId: Int32 = 0, driving: Bool = true
    ) -> ConstraintID {
        ConstraintID(rawValue: PlaneGCSSketchAddConstraintPointOnPerpBisectorByPoints(
            handle, p.rawValue, lp1.rawValue, lp2.rawValue, tagId, driving))
    }

    @discardableResult
    public func addPerpendicularConstraint(
        line1From l1p1: PointID, to l1p2: PointID,
        line2From l2p1: PointID, to l2p2: PointID,
        tagId: Int32 = 0, driving: Bool = true
    ) -> ConstraintID {
        ConstraintID(rawValue: PlaneGCSSketchAddConstraintPerpendicularByPoints(
            handle, l1p1.rawValue, l1p2.rawValue, l2p1.rawValue, l2p2.rawValue, tagId, driving))
    }

    @discardableResult
    public func addAngleConstraint(
        line1From l1p1: PointID, to l1p2: PointID,
        line2From l2p1: PointID, to l2p2: PointID,
        angle: Double, tagId: Int32 = 0, driving: Bool = true
    ) -> ConstraintID {
        ConstraintID(rawValue: PlaneGCSSketchAddConstraintL2LAngleByPoints(
            handle, l1p1.rawValue, l1p2.rawValue, l2p1.rawValue, l2p2.rawValue, angle, tagId, driving))
    }

    @discardableResult
    public func addMidpointOnLineConstraint(
        line1From l1p1: PointID, to l1p2: PointID,
        line2From l2p1: PointID, to l2p2: PointID,
        tagId: Int32 = 0, driving: Bool = true
    ) -> ConstraintID {
        ConstraintID(rawValue: PlaneGCSSketchAddConstraintMidpointOnLineByPoints(
            handle, l1p1.rawValue, l1p2.rawValue, l2p1.rawValue, l2p2.rawValue, tagId, driving))
    }

    /// Two circles (given by center point + radius) tangent to each other,
    /// without either circle needing to already exist as an `addCircle`
    /// geometry entity.
    @discardableResult
    public func addTangentCircumferenceConstraint(
        _ p1: PointID, radius1: Double, _ p2: PointID, radius2: Double,
        internalTangent: Bool = false, tagId: Int32 = 0, driving: Bool = true
    ) -> ConstraintID {
        ConstraintID(rawValue: PlaneGCSSketchAddConstraintTangentCircumf(
            handle, p1.rawValue, p2.rawValue, radius1, radius2, internalTangent, tagId, driving))
    }

    @discardableResult
    public func addCoincidentConstraint(
        _ p1: PointID, _ p2: PointID, tagId: Int32 = 0, driving: Bool = true
    ) -> ConstraintID {
        ConstraintID(rawValue: PlaneGCSSketchAddConstraintP2PCoincident(
            handle, p1.rawValue, p2.rawValue, tagId, driving))
    }

    @discardableResult
    public func addHorizontalConstraint(
        _ p1: PointID, _ p2: PointID, tagId: Int32 = 0, driving: Bool = true
    ) -> ConstraintID {
        ConstraintID(rawValue: PlaneGCSSketchAddConstraintHorizontalByPoints(
            handle, p1.rawValue, p2.rawValue, tagId, driving))
    }

    @discardableResult
    public func addVerticalConstraint(
        _ p1: PointID, _ p2: PointID, tagId: Int32 = 0, driving: Bool = true
    ) -> ConstraintID {
        ConstraintID(rawValue: PlaneGCSSketchAddConstraintVerticalByPoints(
            handle, p1.rawValue, p2.rawValue, tagId, driving))
    }

    @discardableResult
    public func addCoordinateXConstraint(
        _ p: PointID, x: Double, tagId: Int32 = 0, driving: Bool = true
    ) -> ConstraintID {
        ConstraintID(rawValue: PlaneGCSSketchAddConstraintCoordinateX(
            handle, p.rawValue, x, tagId, driving))
    }

    @discardableResult
    public func addCoordinateYConstraint(
        _ p: PointID, y: Double, tagId: Int32 = 0, driving: Bool = true
    ) -> ConstraintID {
        ConstraintID(rawValue: PlaneGCSSketchAddConstraintCoordinateY(
            handle, p.rawValue, y, tagId, driving))
    }

    @discardableResult
    public func addSymmetricConstraint(
        _ p1: PointID, _ p2: PointID, about: PointID, tagId: Int32 = 0, driving: Bool = true
    ) -> ConstraintID {
        ConstraintID(rawValue: PlaneGCSSketchAddConstraintP2PSymmetricByPoint(
            handle, p1.rawValue, p2.rawValue, about.rawValue, tagId, driving))
    }

    // MARK: - Constraints: Tier 2, need a Line

    @discardableResult
    public func addDistanceConstraint(
        _ p: PointID, to line: LineID, distance: Double, tagId: Int32 = 0, driving: Bool = true
    ) -> ConstraintID {
        ConstraintID(rawValue: PlaneGCSSketchAddConstraintP2LDistance(
            handle, p.rawValue, line.rawValue, distance, tagId, driving))
    }

    @discardableResult
    public func addPointOnLineConstraint(
        _ p: PointID, _ line: LineID, tagId: Int32 = 0, driving: Bool = true
    ) -> ConstraintID {
        ConstraintID(rawValue: PlaneGCSSketchAddConstraintPointOnLine(
            handle, p.rawValue, line.rawValue, tagId, driving))
    }

    @discardableResult
    public func addPointOnPerpBisectorConstraint(
        _ p: PointID, _ line: LineID, tagId: Int32 = 0, driving: Bool = true
    ) -> ConstraintID {
        ConstraintID(rawValue: PlaneGCSSketchAddConstraintPointOnPerpBisector(
            handle, p.rawValue, line.rawValue, tagId, driving))
    }

    @discardableResult
    public func addParallelConstraint(
        _ l1: LineID, _ l2: LineID, tagId: Int32 = 0, driving: Bool = true
    ) -> ConstraintID {
        ConstraintID(rawValue: PlaneGCSSketchAddConstraintParallel(
            handle, l1.rawValue, l2.rawValue, tagId, driving))
    }

    @discardableResult
    public func addPerpendicularConstraint(
        _ l1: LineID, _ l2: LineID, tagId: Int32 = 0, driving: Bool = true
    ) -> ConstraintID {
        ConstraintID(rawValue: PlaneGCSSketchAddConstraintPerpendicular(
            handle, l1.rawValue, l2.rawValue, tagId, driving))
    }

    @discardableResult
    public func addAngleConstraint(
        _ l1: LineID, _ l2: LineID, angle: Double, tagId: Int32 = 0, driving: Bool = true
    ) -> ConstraintID {
        ConstraintID(rawValue: PlaneGCSSketchAddConstraintL2LAngle(
            handle, l1.rawValue, l2.rawValue, angle, tagId, driving))
    }

    @discardableResult
    public func addMidpointOnLineConstraint(
        _ l1: LineID, _ l2: LineID, tagId: Int32 = 0, driving: Bool = true
    ) -> ConstraintID {
        ConstraintID(rawValue: PlaneGCSSketchAddConstraintMidpointOnLine(
            handle, l1.rawValue, l2.rawValue, tagId, driving))
    }

    @discardableResult
    public func addHorizontalConstraint(_ line: LineID, tagId: Int32 = 0, driving: Bool = true) -> ConstraintID {
        ConstraintID(rawValue: PlaneGCSSketchAddConstraintHorizontal(handle, line.rawValue, tagId, driving))
    }

    @discardableResult
    public func addVerticalConstraint(_ line: LineID, tagId: Int32 = 0, driving: Bool = true) -> ConstraintID {
        ConstraintID(rawValue: PlaneGCSSketchAddConstraintVertical(handle, line.rawValue, tagId, driving))
    }

    @discardableResult
    public func addEqualLengthConstraint(
        _ l1: LineID, _ l2: LineID, tagId: Int32 = 0, driving: Bool = true
    ) -> ConstraintID {
        ConstraintID(rawValue: PlaneGCSSketchAddConstraintEqualLength(
            handle, l1.rawValue, l2.rawValue, tagId, driving))
    }

    @discardableResult
    public func addSymmetricConstraint(
        _ p1: PointID, _ p2: PointID, about line: LineID, tagId: Int32 = 0, driving: Bool = true
    ) -> ConstraintID {
        ConstraintID(rawValue: PlaneGCSSketchAddConstraintP2PSymmetric(
            handle, p1.rawValue, p2.rawValue, line.rawValue, tagId, driving))
    }

    // MARK: - Constraints: Tier 3, need a Circle

    @discardableResult
    public func addPointOnCircleConstraint(
        _ p: PointID, _ circle: CircleID, tagId: Int32 = 0, driving: Bool = true
    ) -> ConstraintID {
        ConstraintID(rawValue: PlaneGCSSketchAddConstraintPointOnCircle(
            handle, p.rawValue, circle.rawValue, tagId, driving))
    }

    @discardableResult
    public func addRadiusConstraint(
        _ circle: CircleID, radius: Double, tagId: Int32 = 0, driving: Bool = true
    ) -> ConstraintID {
        ConstraintID(rawValue: PlaneGCSSketchAddConstraintCircleRadius(
            handle, circle.rawValue, radius, tagId, driving))
    }

    @discardableResult
    public func addDiameterConstraint(
        _ circle: CircleID, diameter: Double, tagId: Int32 = 0, driving: Bool = true
    ) -> ConstraintID {
        ConstraintID(rawValue: PlaneGCSSketchAddConstraintCircleDiameter(
            handle, circle.rawValue, diameter, tagId, driving))
    }

    @discardableResult
    public func addEqualRadiusConstraint(
        _ c1: CircleID, _ c2: CircleID, tagId: Int32 = 0, driving: Bool = true
    ) -> ConstraintID {
        ConstraintID(rawValue: PlaneGCSSketchAddConstraintEqualRadius(
            handle, c1.rawValue, c2.rawValue, tagId, driving))
    }

    @discardableResult
    public func addTangentConstraint(
        _ line: LineID, _ circle: CircleID, tagId: Int32 = 0, driving: Bool = true
    ) -> ConstraintID {
        ConstraintID(rawValue: PlaneGCSSketchAddConstraintTangentLineCircle(
            handle, line.rawValue, circle.rawValue, tagId, driving))
    }

    @discardableResult
    public func addTangentConstraint(
        _ c1: CircleID, _ c2: CircleID, tagId: Int32 = 0, driving: Bool = true
    ) -> ConstraintID {
        ConstraintID(rawValue: PlaneGCSSketchAddConstraintTangentCircles(
            handle, c1.rawValue, c2.rawValue, tagId, driving))
    }

    @discardableResult
    public func addDistanceConstraint(
        _ c1: CircleID, _ c2: CircleID, distance: Double, tagId: Int32 = 0, driving: Bool = true
    ) -> ConstraintID {
        ConstraintID(rawValue: PlaneGCSSketchAddConstraintC2CDistance(
            handle, c1.rawValue, c2.rawValue, distance, tagId, driving))
    }

    @discardableResult
    public func addDistanceConstraint(
        _ circle: CircleID, _ line: LineID, distance: Double, tagId: Int32 = 0, driving: Bool = true
    ) -> ConstraintID {
        ConstraintID(rawValue: PlaneGCSSketchAddConstraintC2LDistance(
            handle, circle.rawValue, line.rawValue, distance, tagId, driving))
    }

    @discardableResult
    public func addDistanceConstraint(
        _ p: PointID, _ circle: CircleID, distance: Double, tagId: Int32 = 0, driving: Bool = true
    ) -> ConstraintID {
        ConstraintID(rawValue: PlaneGCSSketchAddConstraintP2CDistance(
            handle, p.rawValue, circle.rawValue, distance, tagId, driving))
    }

    // MARK: - Constraints: Tier 4, need an Arc

    @discardableResult
    public func addArcRulesConstraint(_ arc: ArcID, tagId: Int32 = 0, driving: Bool = true) -> ConstraintID {
        ConstraintID(rawValue: PlaneGCSSketchAddConstraintArcRules(handle, arc.rawValue, tagId, driving))
    }

    @discardableResult
    public func addPointOnArcConstraint(
        _ p: PointID, _ arc: ArcID, tagId: Int32 = 0, driving: Bool = true
    ) -> ConstraintID {
        ConstraintID(rawValue: PlaneGCSSketchAddConstraintPointOnArc(
            handle, p.rawValue, arc.rawValue, tagId, driving))
    }

    @discardableResult
    public func addRadiusConstraint(
        _ arc: ArcID, radius: Double, tagId: Int32 = 0, driving: Bool = true
    ) -> ConstraintID {
        ConstraintID(rawValue: PlaneGCSSketchAddConstraintArcRadius(
            handle, arc.rawValue, radius, tagId, driving))
    }

    @discardableResult
    public func addDiameterConstraint(
        _ arc: ArcID, diameter: Double, tagId: Int32 = 0, driving: Bool = true
    ) -> ConstraintID {
        ConstraintID(rawValue: PlaneGCSSketchAddConstraintArcDiameter(
            handle, arc.rawValue, diameter, tagId, driving))
    }

    @discardableResult
    public func addLengthConstraint(
        _ arc: ArcID, length: Double, tagId: Int32 = 0, driving: Bool = true
    ) -> ConstraintID {
        ConstraintID(rawValue: PlaneGCSSketchAddConstraintArcLength(
            handle, arc.rawValue, length, tagId, driving))
    }

    @discardableResult
    public func addPerpendicularConstraint(
        lineFrom p1: PointID, to p2: PointID, _ arc: ArcID, tagId: Int32 = 0, driving: Bool = true
    ) -> ConstraintID {
        ConstraintID(rawValue: PlaneGCSSketchAddConstraintPerpendicularLine2Arc(
            handle, p1.rawValue, p2.rawValue, arc.rawValue, tagId, driving))
    }

    @discardableResult
    public func addPerpendicularConstraint(
        _ arc: ArcID, lineFrom p1: PointID, to p2: PointID, tagId: Int32 = 0, driving: Bool = true
    ) -> ConstraintID {
        ConstraintID(rawValue: PlaneGCSSketchAddConstraintPerpendicularArc2Line(
            handle, arc.rawValue, p1.rawValue, p2.rawValue, tagId, driving))
    }

    /// The "circle" here is given as a center point + radius, matching
    /// GCS's own overload — it doesn't need to be a pre-registered
    /// `addCircle` entity.
    @discardableResult
    public func addPerpendicularConstraint(
        circleCenter: PointID, circleRadius: Double, _ arc: ArcID,
        tagId: Int32 = 0, driving: Bool = true
    ) -> ConstraintID {
        ConstraintID(rawValue: PlaneGCSSketchAddConstraintPerpendicularCircle2Arc(
            handle, circleCenter.rawValue, circleRadius, arc.rawValue, tagId, driving))
    }

    @discardableResult
    public func addPerpendicularConstraint(
        _ arc: ArcID, circleCenter: PointID, circleRadius: Double,
        tagId: Int32 = 0, driving: Bool = true
    ) -> ConstraintID {
        ConstraintID(rawValue: PlaneGCSSketchAddConstraintPerpendicularArc2Circle(
            handle, arc.rawValue, circleCenter.rawValue, circleRadius, tagId, driving))
    }

    @discardableResult
    public func addPerpendicularConstraint(
        _ arc1: ArcID, reversed reverse1: Bool = false,
        _ arc2: ArcID, reversed reverse2: Bool = false,
        tagId: Int32 = 0, driving: Bool = true
    ) -> ConstraintID {
        ConstraintID(rawValue: PlaneGCSSketchAddConstraintPerpendicularArc2Arc(
            handle, arc1.rawValue, reverse1, arc2.rawValue, reverse2, tagId, driving))
    }

    @discardableResult
    public func addTangentConstraint(
        _ line: LineID, _ arc: ArcID, tagId: Int32 = 0, driving: Bool = true
    ) -> ConstraintID {
        ConstraintID(rawValue: PlaneGCSSketchAddConstraintTangentLineArc(
            handle, line.rawValue, arc.rawValue, tagId, driving))
    }

    @discardableResult
    public func addTangentConstraint(
        _ arc1: ArcID, _ arc2: ArcID, tagId: Int32 = 0, driving: Bool = true
    ) -> ConstraintID {
        ConstraintID(rawValue: PlaneGCSSketchAddConstraintTangentArcs(
            handle, arc1.rawValue, arc2.rawValue, tagId, driving))
    }

    @discardableResult
    public func addTangentConstraint(
        _ circle: CircleID, _ arc: ArcID, tagId: Int32 = 0, driving: Bool = true
    ) -> ConstraintID {
        ConstraintID(rawValue: PlaneGCSSketchAddConstraintTangentCircleArc(
            handle, circle.rawValue, arc.rawValue, tagId, driving))
    }

    @discardableResult
    public func addEqualRadiusConstraint(
        _ circle: CircleID, _ arc: ArcID, tagId: Int32 = 0, driving: Bool = true
    ) -> ConstraintID {
        ConstraintID(rawValue: PlaneGCSSketchAddConstraintEqualRadiusCircleArc(
            handle, circle.rawValue, arc.rawValue, tagId, driving))
    }

    @discardableResult
    public func addEqualRadiusConstraint(
        _ arc1: ArcID, _ arc2: ArcID, tagId: Int32 = 0, driving: Bool = true
    ) -> ConstraintID {
        ConstraintID(rawValue: PlaneGCSSketchAddConstraintEqualRadiusArcs(
            handle, arc1.rawValue, arc2.rawValue, tagId, driving))
    }

    // MARK: - Solve

    @discardableResult
    public func solve() -> SolveStatus {
        SolveStatus(rawValue: PlaneGCSSketchSolve(handle)) ?? .failed
    }
}
