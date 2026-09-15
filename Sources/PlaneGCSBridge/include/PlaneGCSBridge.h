#ifndef PLANEGCS_BRIDGE_H
#define PLANEGCS_BRIDGE_H

#include <stdbool.h>
#include <stdint.h>

typedef struct PlaneGCSSketchOpaque *PlaneGCSSketchRef;

#ifdef __cplusplus
extern "C" {
#endif

/// Create a new, empty sketch session. The session owns its own parameter
/// storage (a std::deque<double>, chosen so growing it never invalidates
/// pointers earlier points/constraints already hold into it) plus a
/// GCS::System instance.
PlaneGCSSketchRef _Nonnull PlaneGCSSketchCreate(void);
void PlaneGCSSketchRelease(PlaneGCSSketchRef _Nonnull sketch);

/// Add a point. `fixed` points are excluded from solve()'s unknowns (they
/// act as anchors/reference geometry); non-fixed points are free variables
/// the solver may move. Returns the point's id (0-based, in add order).
int32_t PlaneGCSSketchAddPoint(PlaneGCSSketchRef _Nonnull sketch, double x, double y, bool fixed);

/// Directly overwrite a point's stored coordinates without touching the
/// constraint system. This is the "drag" primitive: move the point, then
/// call solve() again to re-resolve the rest of the sketch around it.
void PlaneGCSSketchSetPointPosition(PlaneGCSSketchRef _Nonnull sketch, int32_t pointId, double x, double y);

double PlaneGCSSketchGetPointX(PlaneGCSSketchRef _Nonnull sketch, int32_t pointId);
double PlaneGCSSketchGetPointY(PlaneGCSSketchRef _Nonnull sketch, int32_t pointId);

// --- Line / Circle geometry ---
// Both are pure aggregates of already-allocated points (Line) plus at most
// one new scalar (Circle's radius) — no new kind of allocation beyond what
// Point already established. See GCS::Line / GCS::Circle in Geo.h.

/// A Line is just two existing points; nothing new is allocated.
int32_t PlaneGCSSketchAddLine(PlaneGCSSketchRef _Nonnull sketch, int32_t p1, int32_t p2);

/// A Circle is an existing center point plus one new radius parameter.
/// `fixed` works like a point's `fixed` flag: a fixed circle's radius is
/// excluded from solve()'s unknowns (reference geometry); a free circle's
/// radius is something a constraint (e.g. addConstraintCircleRadius) can
/// actually adjust.
int32_t PlaneGCSSketchAddCircle(PlaneGCSSketchRef _Nonnull sketch, int32_t centerPoint, double radius, bool fixed);

double PlaneGCSSketchGetCircleRadius(PlaneGCSSketchRef _Nonnull sketch, int32_t circleId);

/// An Arc is Circle's center + radius plus two new angle parameters, plus
/// two EXISTING points for its start/end. Those start/end points are only
/// made geometrically consistent with center/radius/angles once an
/// ArcRules constraint (below) is added — GCS::Arc's own header comment:
/// "start and end points are computed by an ArcRules constraint." `fixed`
/// controls whether radius/startAngle/endAngle are solver unknowns, same
/// meaning as Circle's `fixed`; the start/end points' own fixed-ness is
/// controlled separately, via whatever `addPoint` call created them.
int32_t PlaneGCSSketchAddArc(PlaneGCSSketchRef _Nonnull sketch,
                              int32_t center, int32_t start, int32_t end,
                              double radius, double startAngle, double endAngle,
                              bool fixed);

double PlaneGCSSketchGetArcRadius(PlaneGCSSketchRef _Nonnull sketch, int32_t arcId);
double PlaneGCSSketchGetArcStartAngle(PlaneGCSSketchRef _Nonnull sketch, int32_t arcId);
double PlaneGCSSketchGetArcEndAngle(PlaneGCSSketchRef _Nonnull sketch, int32_t arcId);

// --- Constraints: Tier 4, need an Arc ---

/// Makes an arc's start/end points consistent with its center/radius/
/// angles. Add this once per arc, right after `addArc`, before any other
/// constraint references that arc's start/end points geometrically.
int32_t PlaneGCSSketchAddConstraintArcRules(PlaneGCSSketchRef _Nonnull sketch,
                                             int32_t arc, int32_t tagId, bool driving);

int32_t PlaneGCSSketchAddConstraintPointOnArc(PlaneGCSSketchRef _Nonnull sketch,
                                               int32_t p, int32_t arc,
                                               int32_t tagId, bool driving);

int32_t PlaneGCSSketchAddConstraintArcRadius(PlaneGCSSketchRef _Nonnull sketch,
                                              int32_t arc, double radius,
                                              int32_t tagId, bool driving);

int32_t PlaneGCSSketchAddConstraintArcDiameter(PlaneGCSSketchRef _Nonnull sketch,
                                                int32_t arc, double diameter,
                                                int32_t tagId, bool driving);

int32_t PlaneGCSSketchAddConstraintArcLength(PlaneGCSSketchRef _Nonnull sketch,
                                              int32_t arc, double length,
                                              int32_t tagId, bool driving);

int32_t PlaneGCSSketchAddConstraintPerpendicularLine2Arc(PlaneGCSSketchRef _Nonnull sketch,
                                                          int32_t linePoint1, int32_t linePoint2,
                                                          int32_t arc, int32_t tagId, bool driving);

int32_t PlaneGCSSketchAddConstraintPerpendicularArc2Line(PlaneGCSSketchRef _Nonnull sketch,
                                                          int32_t arc,
                                                          int32_t linePoint1, int32_t linePoint2,
                                                          int32_t tagId, bool driving);

/// The "circle" here is specified as a center point + radius scalar (like
/// `addConstraintTangentCircumf`), not a pre-registered `addCircle` entity.
int32_t PlaneGCSSketchAddConstraintPerpendicularCircle2Arc(PlaneGCSSketchRef _Nonnull sketch,
                                                            int32_t circleCenterPoint, double circleRadius,
                                                            int32_t arc, int32_t tagId, bool driving);

int32_t PlaneGCSSketchAddConstraintPerpendicularArc2Circle(PlaneGCSSketchRef _Nonnull sketch,
                                                            int32_t arc,
                                                            int32_t circleCenterPoint, double circleRadius,
                                                            int32_t tagId, bool driving);

int32_t PlaneGCSSketchAddConstraintPerpendicularArc2Arc(PlaneGCSSketchRef _Nonnull sketch,
                                                         int32_t arc1, bool reverse1,
                                                         int32_t arc2, bool reverse2,
                                                         int32_t tagId, bool driving);

int32_t PlaneGCSSketchAddConstraintTangentLineArc(PlaneGCSSketchRef _Nonnull sketch,
                                                   int32_t line, int32_t arc,
                                                   int32_t tagId, bool driving);

int32_t PlaneGCSSketchAddConstraintTangentArcs(PlaneGCSSketchRef _Nonnull sketch,
                                                int32_t arc1, int32_t arc2,
                                                int32_t tagId, bool driving);

int32_t PlaneGCSSketchAddConstraintTangentCircleArc(PlaneGCSSketchRef _Nonnull sketch,
                                                     int32_t circle, int32_t arc,
                                                     int32_t tagId, bool driving);

int32_t PlaneGCSSketchAddConstraintEqualRadiusCircleArc(PlaneGCSSketchRef _Nonnull sketch,
                                                         int32_t circle, int32_t arc,
                                                         int32_t tagId, bool driving);

int32_t PlaneGCSSketchAddConstraintEqualRadiusArcs(PlaneGCSSketchRef _Nonnull sketch,
                                                    int32_t arc1, int32_t arc2,
                                                    int32_t tagId, bool driving);

// --- Constraints: Tier 1, Point-only (no Line/Circle needed) ---

int32_t PlaneGCSSketchAddConstraintP2PDistance(PlaneGCSSketchRef _Nonnull sketch,
                                                int32_t p1, int32_t p2,
                                                double distance, int32_t tagId, bool driving);

int32_t PlaneGCSSketchAddConstraintP2PAngle(PlaneGCSSketchRef _Nonnull sketch,
                                             int32_t p1, int32_t p2,
                                             double angle, int32_t tagId, bool driving);

int32_t PlaneGCSSketchAddConstraintPointOnLineByPoints(PlaneGCSSketchRef _Nonnull sketch,
                                                        int32_t p, int32_t lp1, int32_t lp2,
                                                        int32_t tagId, bool driving);

int32_t PlaneGCSSketchAddConstraintPointOnPerpBisectorByPoints(PlaneGCSSketchRef _Nonnull sketch,
                                                                int32_t p, int32_t lp1, int32_t lp2,
                                                                int32_t tagId, bool driving);

int32_t PlaneGCSSketchAddConstraintPerpendicularByPoints(PlaneGCSSketchRef _Nonnull sketch,
                                                          int32_t l1p1, int32_t l1p2,
                                                          int32_t l2p1, int32_t l2p2,
                                                          int32_t tagId, bool driving);

int32_t PlaneGCSSketchAddConstraintL2LAngleByPoints(PlaneGCSSketchRef _Nonnull sketch,
                                                     int32_t l1p1, int32_t l1p2,
                                                     int32_t l2p1, int32_t l2p2,
                                                     double angle, int32_t tagId, bool driving);

int32_t PlaneGCSSketchAddConstraintMidpointOnLineByPoints(PlaneGCSSketchRef _Nonnull sketch,
                                                           int32_t l1p1, int32_t l1p2,
                                                           int32_t l2p1, int32_t l2p2,
                                                           int32_t tagId, bool driving);

int32_t PlaneGCSSketchAddConstraintTangentCircumf(PlaneGCSSketchRef _Nonnull sketch,
                                                   int32_t p1, int32_t p2,
                                                   double rd1, double rd2, bool internal,
                                                   int32_t tagId, bool driving);

int32_t PlaneGCSSketchAddConstraintP2PCoincident(PlaneGCSSketchRef _Nonnull sketch,
                                                  int32_t p1, int32_t p2,
                                                  int32_t tagId, bool driving);

int32_t PlaneGCSSketchAddConstraintHorizontalByPoints(PlaneGCSSketchRef _Nonnull sketch,
                                                       int32_t p1, int32_t p2,
                                                       int32_t tagId, bool driving);

int32_t PlaneGCSSketchAddConstraintVerticalByPoints(PlaneGCSSketchRef _Nonnull sketch,
                                                     int32_t p1, int32_t p2,
                                                     int32_t tagId, bool driving);

int32_t PlaneGCSSketchAddConstraintCoordinateX(PlaneGCSSketchRef _Nonnull sketch,
                                                int32_t p, double x,
                                                int32_t tagId, bool driving);

int32_t PlaneGCSSketchAddConstraintCoordinateY(PlaneGCSSketchRef _Nonnull sketch,
                                                int32_t p, double y,
                                                int32_t tagId, bool driving);

int32_t PlaneGCSSketchAddConstraintP2PSymmetricByPoint(PlaneGCSSketchRef _Nonnull sketch,
                                                        int32_t p1, int32_t p2, int32_t about,
                                                        int32_t tagId, bool driving);

// --- Constraints: Tier 2, need a Line ---

int32_t PlaneGCSSketchAddConstraintP2LDistance(PlaneGCSSketchRef _Nonnull sketch,
                                                int32_t p, int32_t line,
                                                double distance, int32_t tagId, bool driving);

int32_t PlaneGCSSketchAddConstraintPointOnLine(PlaneGCSSketchRef _Nonnull sketch,
                                                int32_t p, int32_t line,
                                                int32_t tagId, bool driving);

int32_t PlaneGCSSketchAddConstraintPointOnPerpBisector(PlaneGCSSketchRef _Nonnull sketch,
                                                        int32_t p, int32_t line,
                                                        int32_t tagId, bool driving);

int32_t PlaneGCSSketchAddConstraintParallel(PlaneGCSSketchRef _Nonnull sketch,
                                             int32_t l1, int32_t l2,
                                             int32_t tagId, bool driving);

int32_t PlaneGCSSketchAddConstraintPerpendicular(PlaneGCSSketchRef _Nonnull sketch,
                                                  int32_t l1, int32_t l2,
                                                  int32_t tagId, bool driving);

int32_t PlaneGCSSketchAddConstraintL2LAngle(PlaneGCSSketchRef _Nonnull sketch,
                                             int32_t l1, int32_t l2,
                                             double angle, int32_t tagId, bool driving);

int32_t PlaneGCSSketchAddConstraintMidpointOnLine(PlaneGCSSketchRef _Nonnull sketch,
                                                   int32_t l1, int32_t l2,
                                                   int32_t tagId, bool driving);

int32_t PlaneGCSSketchAddConstraintHorizontal(PlaneGCSSketchRef _Nonnull sketch,
                                               int32_t line, int32_t tagId, bool driving);

int32_t PlaneGCSSketchAddConstraintVertical(PlaneGCSSketchRef _Nonnull sketch,
                                             int32_t line, int32_t tagId, bool driving);

int32_t PlaneGCSSketchAddConstraintEqualLength(PlaneGCSSketchRef _Nonnull sketch,
                                                int32_t l1, int32_t l2,
                                                int32_t tagId, bool driving);

int32_t PlaneGCSSketchAddConstraintP2PSymmetric(PlaneGCSSketchRef _Nonnull sketch,
                                                 int32_t p1, int32_t p2, int32_t line,
                                                 int32_t tagId, bool driving);

// --- Constraints: Tier 3, need a Circle ---

int32_t PlaneGCSSketchAddConstraintPointOnCircle(PlaneGCSSketchRef _Nonnull sketch,
                                                  int32_t p, int32_t circle,
                                                  int32_t tagId, bool driving);

int32_t PlaneGCSSketchAddConstraintCircleRadius(PlaneGCSSketchRef _Nonnull sketch,
                                                 int32_t circle, double radius,
                                                 int32_t tagId, bool driving);

int32_t PlaneGCSSketchAddConstraintCircleDiameter(PlaneGCSSketchRef _Nonnull sketch,
                                                   int32_t circle, double diameter,
                                                   int32_t tagId, bool driving);

int32_t PlaneGCSSketchAddConstraintEqualRadius(PlaneGCSSketchRef _Nonnull sketch,
                                                int32_t c1, int32_t c2,
                                                int32_t tagId, bool driving);

int32_t PlaneGCSSketchAddConstraintTangentLineCircle(PlaneGCSSketchRef _Nonnull sketch,
                                                      int32_t line, int32_t circle,
                                                      int32_t tagId, bool driving);

int32_t PlaneGCSSketchAddConstraintTangentCircles(PlaneGCSSketchRef _Nonnull sketch,
                                                   int32_t c1, int32_t c2,
                                                   int32_t tagId, bool driving);

int32_t PlaneGCSSketchAddConstraintC2CDistance(PlaneGCSSketchRef _Nonnull sketch,
                                                int32_t c1, int32_t c2,
                                                double distance, int32_t tagId, bool driving);

int32_t PlaneGCSSketchAddConstraintC2LDistance(PlaneGCSSketchRef _Nonnull sketch,
                                                int32_t circle, int32_t line,
                                                double distance, int32_t tagId, bool driving);

int32_t PlaneGCSSketchAddConstraintP2CDistance(PlaneGCSSketchRef _Nonnull sketch,
                                                int32_t p, int32_t circle,
                                                double distance, int32_t tagId, bool driving);

/// Gathers current non-fixed points as unknowns, re-initializes and solves.
/// Returns a GCS::SolveStatus value (0 Success, 1 Converged, 2 Failed,
/// 3 SuccessfulSolutionInvalid).
int32_t PlaneGCSSketchSolve(PlaneGCSSketchRef _Nonnull sketch);

#ifdef __cplusplus
}
#endif

#endif
