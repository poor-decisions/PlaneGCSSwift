#include "PlaneGCSBridge.h"
#include "GCS.h"

#include <deque>
#include <vector>

// Backing store for every point's x/y (and every constraint's/geometry's own
// scalar parameters, e.g. a distance or a circle radius). std::deque, not
// std::vector: push_back never invalidates references/pointers to elements
// already in the deque (only iterators), so GCS::Point/Line/Circle objects
// built from &params[offset] stay valid no matter how many more points or
// scalars get added later. A std::vector would silently dangle every
// existing pointer on the first reallocation.
struct PlaneGCSSketchOpaque {
    std::deque<double> params;
    GCS::System system;

    std::vector<size_t> pointXOffset;
    std::vector<size_t> pointYOffset;
    std::vector<bool> pointFixed;

    // A Line is just two existing points (GCS::Line has no parameters of
    // its own), so we only need to remember which two point ids form it.
    std::vector<int32_t> lineP1;
    std::vector<int32_t> lineP2;

    // A Circle is an existing center point plus one new radius parameter.
    std::vector<int32_t> circleCenter;
    std::vector<size_t> circleRadiusOffset;
    std::vector<bool> circleRadiusFixed;

    // An Arc is Circle's center+radius, two new angle parameters, and two
    // EXISTING points for its start/end (made consistent with the rest via
    // an ArcRules constraint, not by construction).
    std::vector<int32_t> arcCenter;
    std::vector<int32_t> arcStart;
    std::vector<int32_t> arcEnd;
    std::vector<size_t> arcRadiusOffset;
    std::vector<size_t> arcStartAngleOffset;
    std::vector<size_t> arcEndAngleOffset;
    std::vector<bool> arcParamsFixed;
};

static size_t pushParam(PlaneGCSSketchOpaque *sketch, double value) {
    size_t offset = sketch->params.size();
    sketch->params.push_back(value);
    return offset;
}

static GCS::Point pointAt(PlaneGCSSketchOpaque *sketch, int32_t pointId) {
    return GCS::Point(&sketch->params[sketch->pointXOffset[pointId]],
                       &sketch->params[sketch->pointYOffset[pointId]]);
}

static GCS::Line lineAt(PlaneGCSSketchOpaque *sketch, int32_t lineId) {
    GCS::Line line;
    line.p1 = pointAt(sketch, sketch->lineP1[lineId]);
    line.p2 = pointAt(sketch, sketch->lineP2[lineId]);
    return line;
}

static GCS::Circle circleAt(PlaneGCSSketchOpaque *sketch, int32_t circleId) {
    GCS::Circle circle;
    circle.center = pointAt(sketch, sketch->circleCenter[circleId]);
    circle.rad = &sketch->params[sketch->circleRadiusOffset[circleId]];
    return circle;
}

static GCS::Arc arcAt(PlaneGCSSketchOpaque *sketch, int32_t arcId) {
    GCS::Arc arc;
    arc.center = pointAt(sketch, sketch->arcCenter[arcId]);
    arc.start = pointAt(sketch, sketch->arcStart[arcId]);
    arc.end = pointAt(sketch, sketch->arcEnd[arcId]);
    arc.rad = &sketch->params[sketch->arcRadiusOffset[arcId]];
    arc.startAngle = &sketch->params[sketch->arcStartAngleOffset[arcId]];
    arc.endAngle = &sketch->params[sketch->arcEndAngleOffset[arcId]];
    return arc;
}

PlaneGCSSketchRef PlaneGCSSketchCreate(void) {
    return new PlaneGCSSketchOpaque();
}

void PlaneGCSSketchRelease(PlaneGCSSketchRef sketch) {
    delete sketch;
}

int32_t PlaneGCSSketchAddPoint(PlaneGCSSketchRef sketch, double x, double y, bool fixed) {
    size_t xOff = pushParam(sketch, x);
    size_t yOff = pushParam(sketch, y);

    sketch->pointXOffset.push_back(xOff);
    sketch->pointYOffset.push_back(yOff);
    sketch->pointFixed.push_back(fixed);

    return static_cast<int32_t>(sketch->pointXOffset.size() - 1);
}

void PlaneGCSSketchSetPointPosition(PlaneGCSSketchRef sketch, int32_t pointId, double x, double y) {
    sketch->params[sketch->pointXOffset[pointId]] = x;
    sketch->params[sketch->pointYOffset[pointId]] = y;
}

double PlaneGCSSketchGetPointX(PlaneGCSSketchRef sketch, int32_t pointId) {
    return sketch->params[sketch->pointXOffset[pointId]];
}

double PlaneGCSSketchGetPointY(PlaneGCSSketchRef sketch, int32_t pointId) {
    return sketch->params[sketch->pointYOffset[pointId]];
}

int32_t PlaneGCSSketchAddLine(PlaneGCSSketchRef sketch, int32_t p1, int32_t p2) {
    sketch->lineP1.push_back(p1);
    sketch->lineP2.push_back(p2);
    return static_cast<int32_t>(sketch->lineP1.size() - 1);
}

int32_t PlaneGCSSketchAddCircle(PlaneGCSSketchRef sketch, int32_t centerPoint, double radius, bool fixed) {
    size_t radOff = pushParam(sketch, radius);
    sketch->circleCenter.push_back(centerPoint);
    sketch->circleRadiusOffset.push_back(radOff);
    sketch->circleRadiusFixed.push_back(fixed);
    return static_cast<int32_t>(sketch->circleCenter.size() - 1);
}

double PlaneGCSSketchGetCircleRadius(PlaneGCSSketchRef sketch, int32_t circleId) {
    return sketch->params[sketch->circleRadiusOffset[circleId]];
}

int32_t PlaneGCSSketchAddArc(PlaneGCSSketchRef sketch, int32_t center, int32_t start, int32_t end,
                              double radius, double startAngle, double endAngle, bool fixed) {
    size_t radOff = pushParam(sketch, radius);
    size_t startAngleOff = pushParam(sketch, startAngle);
    size_t endAngleOff = pushParam(sketch, endAngle);
    sketch->arcCenter.push_back(center);
    sketch->arcStart.push_back(start);
    sketch->arcEnd.push_back(end);
    sketch->arcRadiusOffset.push_back(radOff);
    sketch->arcStartAngleOffset.push_back(startAngleOff);
    sketch->arcEndAngleOffset.push_back(endAngleOff);
    sketch->arcParamsFixed.push_back(fixed);
    return static_cast<int32_t>(sketch->arcCenter.size() - 1);
}

double PlaneGCSSketchGetArcRadius(PlaneGCSSketchRef sketch, int32_t arcId) {
    return sketch->params[sketch->arcRadiusOffset[arcId]];
}

double PlaneGCSSketchGetArcStartAngle(PlaneGCSSketchRef sketch, int32_t arcId) {
    return sketch->params[sketch->arcStartAngleOffset[arcId]];
}

double PlaneGCSSketchGetArcEndAngle(PlaneGCSSketchRef sketch, int32_t arcId) {
    return sketch->params[sketch->arcEndAngleOffset[arcId]];
}

// --- Tier 1: Point-only constraints ---
// GCS::System's addConstraint* methods take Point&/Line&/Circle& as
// non-const lvalue references, which cannot bind to a temporary — every
// geometry value below is bound to a named local first, never passed as a
// bare pointAt(...)/lineAt(...)/circleAt(...) call expression.

int32_t PlaneGCSSketchAddConstraintP2PDistance(PlaneGCSSketchRef sketch, int32_t p1, int32_t p2,
                                                double distance, int32_t tagId, bool driving) {
    GCS::Point gp1 = pointAt(sketch, p1);
    GCS::Point gp2 = pointAt(sketch, p2);
    size_t distOff = pushParam(sketch, distance);
    return sketch->system.addConstraintP2PDistance(gp1, gp2, &sketch->params[distOff], tagId, driving);
}

int32_t PlaneGCSSketchAddConstraintP2PAngle(PlaneGCSSketchRef sketch, int32_t p1, int32_t p2,
                                             double angle, int32_t tagId, bool driving) {
    GCS::Point gp1 = pointAt(sketch, p1);
    GCS::Point gp2 = pointAt(sketch, p2);
    size_t angleOff = pushParam(sketch, angle);
    return sketch->system.addConstraintP2PAngle(gp1, gp2, &sketch->params[angleOff], tagId, driving);
}

int32_t PlaneGCSSketchAddConstraintPointOnLineByPoints(PlaneGCSSketchRef sketch, int32_t p, int32_t lp1,
                                                        int32_t lp2, int32_t tagId, bool driving) {
    GCS::Point gp = pointAt(sketch, p);
    GCS::Point glp1 = pointAt(sketch, lp1);
    GCS::Point glp2 = pointAt(sketch, lp2);
    return sketch->system.addConstraintPointOnLine(gp, glp1, glp2, tagId, driving);
}

int32_t PlaneGCSSketchAddConstraintPointOnPerpBisectorByPoints(PlaneGCSSketchRef sketch, int32_t p,
                                                                int32_t lp1, int32_t lp2, int32_t tagId,
                                                                bool driving) {
    GCS::Point gp = pointAt(sketch, p);
    GCS::Point glp1 = pointAt(sketch, lp1);
    GCS::Point glp2 = pointAt(sketch, lp2);
    return sketch->system.addConstraintPointOnPerpBisector(gp, glp1, glp2, tagId, driving);
}

int32_t PlaneGCSSketchAddConstraintPerpendicularByPoints(PlaneGCSSketchRef sketch, int32_t l1p1,
                                                          int32_t l1p2, int32_t l2p1, int32_t l2p2,
                                                          int32_t tagId, bool driving) {
    GCS::Point gl1p1 = pointAt(sketch, l1p1);
    GCS::Point gl1p2 = pointAt(sketch, l1p2);
    GCS::Point gl2p1 = pointAt(sketch, l2p1);
    GCS::Point gl2p2 = pointAt(sketch, l2p2);
    return sketch->system.addConstraintPerpendicular(gl1p1, gl1p2, gl2p1, gl2p2, tagId, driving);
}

int32_t PlaneGCSSketchAddConstraintL2LAngleByPoints(PlaneGCSSketchRef sketch, int32_t l1p1, int32_t l1p2,
                                                     int32_t l2p1, int32_t l2p2, double angle,
                                                     int32_t tagId, bool driving) {
    GCS::Point gl1p1 = pointAt(sketch, l1p1);
    GCS::Point gl1p2 = pointAt(sketch, l1p2);
    GCS::Point gl2p1 = pointAt(sketch, l2p1);
    GCS::Point gl2p2 = pointAt(sketch, l2p2);
    size_t angleOff = pushParam(sketch, angle);
    return sketch->system.addConstraintL2LAngle(gl1p1, gl1p2, gl2p1, gl2p2, &sketch->params[angleOff],
                                                 tagId, driving);
}

int32_t PlaneGCSSketchAddConstraintMidpointOnLineByPoints(PlaneGCSSketchRef sketch, int32_t l1p1,
                                                           int32_t l1p2, int32_t l2p1, int32_t l2p2,
                                                           int32_t tagId, bool driving) {
    GCS::Point gl1p1 = pointAt(sketch, l1p1);
    GCS::Point gl1p2 = pointAt(sketch, l1p2);
    GCS::Point gl2p1 = pointAt(sketch, l2p1);
    GCS::Point gl2p2 = pointAt(sketch, l2p2);
    return sketch->system.addConstraintMidpointOnLine(gl1p1, gl1p2, gl2p1, gl2p2, tagId, driving);
}

int32_t PlaneGCSSketchAddConstraintTangentCircumf(PlaneGCSSketchRef sketch, int32_t p1, int32_t p2,
                                                   double rd1, double rd2, bool internal,
                                                   int32_t tagId, bool driving) {
    GCS::Point gp1 = pointAt(sketch, p1);
    GCS::Point gp2 = pointAt(sketch, p2);
    size_t rd1Off = pushParam(sketch, rd1);
    size_t rd2Off = pushParam(sketch, rd2);
    return sketch->system.addConstraintTangentCircumf(gp1, gp2, &sketch->params[rd1Off],
                                                        &sketch->params[rd2Off], internal, tagId, driving);
}

int32_t PlaneGCSSketchAddConstraintP2PCoincident(PlaneGCSSketchRef sketch, int32_t p1, int32_t p2,
                                                  int32_t tagId, bool driving) {
    GCS::Point gp1 = pointAt(sketch, p1);
    GCS::Point gp2 = pointAt(sketch, p2);
    return sketch->system.addConstraintP2PCoincident(gp1, gp2, tagId, driving);
}

int32_t PlaneGCSSketchAddConstraintHorizontalByPoints(PlaneGCSSketchRef sketch, int32_t p1, int32_t p2,
                                                       int32_t tagId, bool driving) {
    GCS::Point gp1 = pointAt(sketch, p1);
    GCS::Point gp2 = pointAt(sketch, p2);
    return sketch->system.addConstraintHorizontal(gp1, gp2, tagId, driving);
}

int32_t PlaneGCSSketchAddConstraintVerticalByPoints(PlaneGCSSketchRef sketch, int32_t p1, int32_t p2,
                                                     int32_t tagId, bool driving) {
    GCS::Point gp1 = pointAt(sketch, p1);
    GCS::Point gp2 = pointAt(sketch, p2);
    return sketch->system.addConstraintVertical(gp1, gp2, tagId, driving);
}

int32_t PlaneGCSSketchAddConstraintCoordinateX(PlaneGCSSketchRef sketch, int32_t p, double x,
                                                int32_t tagId, bool driving) {
    GCS::Point gp = pointAt(sketch, p);
    size_t xOff = pushParam(sketch, x);
    return sketch->system.addConstraintCoordinateX(gp, &sketch->params[xOff], tagId, driving);
}

int32_t PlaneGCSSketchAddConstraintCoordinateY(PlaneGCSSketchRef sketch, int32_t p, double y,
                                                int32_t tagId, bool driving) {
    GCS::Point gp = pointAt(sketch, p);
    size_t yOff = pushParam(sketch, y);
    return sketch->system.addConstraintCoordinateY(gp, &sketch->params[yOff], tagId, driving);
}

int32_t PlaneGCSSketchAddConstraintP2PSymmetricByPoint(PlaneGCSSketchRef sketch, int32_t p1, int32_t p2,
                                                        int32_t about, int32_t tagId, bool driving) {
    GCS::Point gp1 = pointAt(sketch, p1);
    GCS::Point gp2 = pointAt(sketch, p2);
    GCS::Point gabout = pointAt(sketch, about);
    return sketch->system.addConstraintP2PSymmetric(gp1, gp2, gabout, tagId, driving);
}

// --- Tier 2: constraints needing a Line ---

int32_t PlaneGCSSketchAddConstraintP2LDistance(PlaneGCSSketchRef sketch, int32_t p, int32_t line,
                                                double distance, int32_t tagId, bool driving) {
    GCS::Point gp = pointAt(sketch, p);
    GCS::Line gl = lineAt(sketch, line);
    size_t distOff = pushParam(sketch, distance);
    return sketch->system.addConstraintP2LDistance(gp, gl, &sketch->params[distOff], tagId, driving);
}

int32_t PlaneGCSSketchAddConstraintPointOnLine(PlaneGCSSketchRef sketch, int32_t p, int32_t line,
                                                int32_t tagId, bool driving) {
    GCS::Point gp = pointAt(sketch, p);
    GCS::Line gl = lineAt(sketch, line);
    return sketch->system.addConstraintPointOnLine(gp, gl, tagId, driving);
}

int32_t PlaneGCSSketchAddConstraintPointOnPerpBisector(PlaneGCSSketchRef sketch, int32_t p, int32_t line,
                                                        int32_t tagId, bool driving) {
    GCS::Point gp = pointAt(sketch, p);
    GCS::Line gl = lineAt(sketch, line);
    return sketch->system.addConstraintPointOnPerpBisector(gp, gl, tagId, driving);
}

int32_t PlaneGCSSketchAddConstraintParallel(PlaneGCSSketchRef sketch, int32_t l1, int32_t l2,
                                             int32_t tagId, bool driving) {
    GCS::Line gl1 = lineAt(sketch, l1);
    GCS::Line gl2 = lineAt(sketch, l2);
    return sketch->system.addConstraintParallel(gl1, gl2, tagId, driving);
}

int32_t PlaneGCSSketchAddConstraintPerpendicular(PlaneGCSSketchRef sketch, int32_t l1, int32_t l2,
                                                  int32_t tagId, bool driving) {
    GCS::Line gl1 = lineAt(sketch, l1);
    GCS::Line gl2 = lineAt(sketch, l2);
    return sketch->system.addConstraintPerpendicular(gl1, gl2, tagId, driving);
}

int32_t PlaneGCSSketchAddConstraintL2LAngle(PlaneGCSSketchRef sketch, int32_t l1, int32_t l2,
                                             double angle, int32_t tagId, bool driving) {
    GCS::Line gl1 = lineAt(sketch, l1);
    GCS::Line gl2 = lineAt(sketch, l2);
    size_t angleOff = pushParam(sketch, angle);
    return sketch->system.addConstraintL2LAngle(gl1, gl2, &sketch->params[angleOff], tagId, driving);
}

int32_t PlaneGCSSketchAddConstraintMidpointOnLine(PlaneGCSSketchRef sketch, int32_t l1, int32_t l2,
                                                   int32_t tagId, bool driving) {
    GCS::Line gl1 = lineAt(sketch, l1);
    GCS::Line gl2 = lineAt(sketch, l2);
    return sketch->system.addConstraintMidpointOnLine(gl1, gl2, tagId, driving);
}

int32_t PlaneGCSSketchAddConstraintHorizontal(PlaneGCSSketchRef sketch, int32_t line, int32_t tagId,
                                               bool driving) {
    GCS::Line gl = lineAt(sketch, line);
    return sketch->system.addConstraintHorizontal(gl, tagId, driving);
}

int32_t PlaneGCSSketchAddConstraintVertical(PlaneGCSSketchRef sketch, int32_t line, int32_t tagId,
                                             bool driving) {
    GCS::Line gl = lineAt(sketch, line);
    return sketch->system.addConstraintVertical(gl, tagId, driving);
}

int32_t PlaneGCSSketchAddConstraintEqualLength(PlaneGCSSketchRef sketch, int32_t l1, int32_t l2,
                                                int32_t tagId, bool driving) {
    GCS::Line gl1 = lineAt(sketch, l1);
    GCS::Line gl2 = lineAt(sketch, l2);
    return sketch->system.addConstraintEqualLength(gl1, gl2, tagId, driving);
}

int32_t PlaneGCSSketchAddConstraintP2PSymmetric(PlaneGCSSketchRef sketch, int32_t p1, int32_t p2,
                                                 int32_t line, int32_t tagId, bool driving) {
    GCS::Point gp1 = pointAt(sketch, p1);
    GCS::Point gp2 = pointAt(sketch, p2);
    GCS::Line gl = lineAt(sketch, line);
    return sketch->system.addConstraintP2PSymmetric(gp1, gp2, gl, tagId, driving);
}

// --- Tier 3: constraints needing a Circle ---

int32_t PlaneGCSSketchAddConstraintPointOnCircle(PlaneGCSSketchRef sketch, int32_t p, int32_t circle,
                                                  int32_t tagId, bool driving) {
    GCS::Point gp = pointAt(sketch, p);
    GCS::Circle gc = circleAt(sketch, circle);
    return sketch->system.addConstraintPointOnCircle(gp, gc, tagId, driving);
}

int32_t PlaneGCSSketchAddConstraintCircleRadius(PlaneGCSSketchRef sketch, int32_t circle, double radius,
                                                 int32_t tagId, bool driving) {
    GCS::Circle gc = circleAt(sketch, circle);
    size_t radOff = pushParam(sketch, radius);
    return sketch->system.addConstraintCircleRadius(gc, &sketch->params[radOff], tagId, driving);
}

int32_t PlaneGCSSketchAddConstraintCircleDiameter(PlaneGCSSketchRef sketch, int32_t circle,
                                                   double diameter, int32_t tagId, bool driving) {
    GCS::Circle gc = circleAt(sketch, circle);
    size_t diamOff = pushParam(sketch, diameter);
    return sketch->system.addConstraintCircleDiameter(gc, &sketch->params[diamOff], tagId, driving);
}

int32_t PlaneGCSSketchAddConstraintEqualRadius(PlaneGCSSketchRef sketch, int32_t c1, int32_t c2,
                                                int32_t tagId, bool driving) {
    GCS::Circle gc1 = circleAt(sketch, c1);
    GCS::Circle gc2 = circleAt(sketch, c2);
    return sketch->system.addConstraintEqualRadius(gc1, gc2, tagId, driving);
}

int32_t PlaneGCSSketchAddConstraintTangentLineCircle(PlaneGCSSketchRef sketch, int32_t line,
                                                      int32_t circle, int32_t tagId, bool driving) {
    GCS::Line gl = lineAt(sketch, line);
    GCS::Circle gc = circleAt(sketch, circle);
    return sketch->system.addConstraintTangent(gl, gc, tagId, driving);
}

int32_t PlaneGCSSketchAddConstraintTangentCircles(PlaneGCSSketchRef sketch, int32_t c1, int32_t c2,
                                                   int32_t tagId, bool driving) {
    GCS::Circle gc1 = circleAt(sketch, c1);
    GCS::Circle gc2 = circleAt(sketch, c2);
    return sketch->system.addConstraintTangent(gc1, gc2, tagId, driving);
}

int32_t PlaneGCSSketchAddConstraintC2CDistance(PlaneGCSSketchRef sketch, int32_t c1, int32_t c2,
                                                double distance, int32_t tagId, bool driving) {
    GCS::Circle gc1 = circleAt(sketch, c1);
    GCS::Circle gc2 = circleAt(sketch, c2);
    size_t distOff = pushParam(sketch, distance);
    return sketch->system.addConstraintC2CDistance(gc1, gc2, &sketch->params[distOff], tagId, driving);
}

int32_t PlaneGCSSketchAddConstraintC2LDistance(PlaneGCSSketchRef sketch, int32_t circle, int32_t line,
                                                double distance, int32_t tagId, bool driving) {
    GCS::Circle gc = circleAt(sketch, circle);
    GCS::Line gl = lineAt(sketch, line);
    size_t distOff = pushParam(sketch, distance);
    return sketch->system.addConstraintC2LDistance(gc, gl, &sketch->params[distOff], tagId, driving);
}

int32_t PlaneGCSSketchAddConstraintP2CDistance(PlaneGCSSketchRef sketch, int32_t p, int32_t circle,
                                                double distance, int32_t tagId, bool driving) {
    GCS::Point gp = pointAt(sketch, p);
    GCS::Circle gc = circleAt(sketch, circle);
    size_t distOff = pushParam(sketch, distance);
    return sketch->system.addConstraintP2CDistance(gp, gc, &sketch->params[distOff], tagId, driving);
}

// --- Tier 4: constraints needing an Arc ---

int32_t PlaneGCSSketchAddConstraintArcRules(PlaneGCSSketchRef sketch, int32_t arc, int32_t tagId,
                                             bool driving) {
    GCS::Arc ga = arcAt(sketch, arc);
    return sketch->system.addConstraintArcRules(ga, tagId, driving);
}

int32_t PlaneGCSSketchAddConstraintPointOnArc(PlaneGCSSketchRef sketch, int32_t p, int32_t arc,
                                               int32_t tagId, bool driving) {
    GCS::Point gp = pointAt(sketch, p);
    GCS::Arc ga = arcAt(sketch, arc);
    return sketch->system.addConstraintPointOnArc(gp, ga, tagId, driving);
}

int32_t PlaneGCSSketchAddConstraintArcRadius(PlaneGCSSketchRef sketch, int32_t arc, double radius,
                                              int32_t tagId, bool driving) {
    GCS::Arc ga = arcAt(sketch, arc);
    size_t radOff = pushParam(sketch, radius);
    return sketch->system.addConstraintArcRadius(ga, &sketch->params[radOff], tagId, driving);
}

int32_t PlaneGCSSketchAddConstraintArcDiameter(PlaneGCSSketchRef sketch, int32_t arc, double diameter,
                                                int32_t tagId, bool driving) {
    GCS::Arc ga = arcAt(sketch, arc);
    size_t diamOff = pushParam(sketch, diameter);
    return sketch->system.addConstraintArcDiameter(ga, &sketch->params[diamOff], tagId, driving);
}

int32_t PlaneGCSSketchAddConstraintArcLength(PlaneGCSSketchRef sketch, int32_t arc, double length,
                                              int32_t tagId, bool driving) {
    GCS::Arc ga = arcAt(sketch, arc);
    size_t lenOff = pushParam(sketch, length);
    return sketch->system.addConstraintArcLength(ga, &sketch->params[lenOff], tagId, driving);
}

int32_t PlaneGCSSketchAddConstraintPerpendicularLine2Arc(PlaneGCSSketchRef sketch, int32_t linePoint1,
                                                          int32_t linePoint2, int32_t arc, int32_t tagId,
                                                          bool driving) {
    GCS::Point gp1 = pointAt(sketch, linePoint1);
    GCS::Point gp2 = pointAt(sketch, linePoint2);
    GCS::Arc ga = arcAt(sketch, arc);
    return sketch->system.addConstraintPerpendicularLine2Arc(gp1, gp2, ga, tagId, driving);
}

int32_t PlaneGCSSketchAddConstraintPerpendicularArc2Line(PlaneGCSSketchRef sketch, int32_t arc,
                                                          int32_t linePoint1, int32_t linePoint2,
                                                          int32_t tagId, bool driving) {
    GCS::Arc ga = arcAt(sketch, arc);
    GCS::Point gp1 = pointAt(sketch, linePoint1);
    GCS::Point gp2 = pointAt(sketch, linePoint2);
    return sketch->system.addConstraintPerpendicularArc2Line(ga, gp1, gp2, tagId, driving);
}

int32_t PlaneGCSSketchAddConstraintPerpendicularCircle2Arc(PlaneGCSSketchRef sketch,
                                                            int32_t circleCenterPoint,
                                                            double circleRadius, int32_t arc,
                                                            int32_t tagId, bool driving) {
    GCS::Point gcenter = pointAt(sketch, circleCenterPoint);
    size_t radOff = pushParam(sketch, circleRadius);
    GCS::Arc ga = arcAt(sketch, arc);
    return sketch->system.addConstraintPerpendicularCircle2Arc(gcenter, &sketch->params[radOff], ga,
                                                                 tagId, driving);
}

int32_t PlaneGCSSketchAddConstraintPerpendicularArc2Circle(PlaneGCSSketchRef sketch, int32_t arc,
                                                            int32_t circleCenterPoint,
                                                            double circleRadius, int32_t tagId,
                                                            bool driving) {
    GCS::Arc ga = arcAt(sketch, arc);
    GCS::Point gcenter = pointAt(sketch, circleCenterPoint);
    size_t radOff = pushParam(sketch, circleRadius);
    return sketch->system.addConstraintPerpendicularArc2Circle(ga, gcenter, &sketch->params[radOff],
                                                                 tagId, driving);
}

int32_t PlaneGCSSketchAddConstraintPerpendicularArc2Arc(PlaneGCSSketchRef sketch, int32_t arc1,
                                                         bool reverse1, int32_t arc2, bool reverse2,
                                                         int32_t tagId, bool driving) {
    GCS::Arc ga1 = arcAt(sketch, arc1);
    GCS::Arc ga2 = arcAt(sketch, arc2);
    return sketch->system.addConstraintPerpendicularArc2Arc(ga1, reverse1, ga2, reverse2, tagId, driving);
}

int32_t PlaneGCSSketchAddConstraintTangentLineArc(PlaneGCSSketchRef sketch, int32_t line, int32_t arc,
                                                   int32_t tagId, bool driving) {
    GCS::Line gl = lineAt(sketch, line);
    GCS::Arc ga = arcAt(sketch, arc);
    return sketch->system.addConstraintTangent(gl, ga, tagId, driving);
}

int32_t PlaneGCSSketchAddConstraintTangentArcs(PlaneGCSSketchRef sketch, int32_t arc1, int32_t arc2,
                                                int32_t tagId, bool driving) {
    GCS::Arc ga1 = arcAt(sketch, arc1);
    GCS::Arc ga2 = arcAt(sketch, arc2);
    return sketch->system.addConstraintTangent(ga1, ga2, tagId, driving);
}

int32_t PlaneGCSSketchAddConstraintTangentCircleArc(PlaneGCSSketchRef sketch, int32_t circle, int32_t arc,
                                                     int32_t tagId, bool driving) {
    GCS::Circle gc = circleAt(sketch, circle);
    GCS::Arc ga = arcAt(sketch, arc);
    return sketch->system.addConstraintTangent(gc, ga, tagId, driving);
}

int32_t PlaneGCSSketchAddConstraintEqualRadiusCircleArc(PlaneGCSSketchRef sketch, int32_t circle,
                                                         int32_t arc, int32_t tagId, bool driving) {
    GCS::Circle gc = circleAt(sketch, circle);
    GCS::Arc ga = arcAt(sketch, arc);
    return sketch->system.addConstraintEqualRadius(gc, ga, tagId, driving);
}

int32_t PlaneGCSSketchAddConstraintEqualRadiusArcs(PlaneGCSSketchRef sketch, int32_t arc1, int32_t arc2,
                                                    int32_t tagId, bool driving) {
    GCS::Arc ga1 = arcAt(sketch, arc1);
    GCS::Arc ga2 = arcAt(sketch, arc2);
    return sketch->system.addConstraintEqualRadius(ga1, ga2, tagId, driving);
}

// --- Solve ---

int32_t PlaneGCSSketchSolve(PlaneGCSSketchRef sketch) {
    GCS::VEC_pD unknowns;
    for (size_t i = 0; i < sketch->pointXOffset.size(); ++i) {
        if (!sketch->pointFixed[i]) {
            unknowns.push_back(&sketch->params[sketch->pointXOffset[i]]);
            unknowns.push_back(&sketch->params[sketch->pointYOffset[i]]);
        }
    }
    for (size_t i = 0; i < sketch->circleRadiusOffset.size(); ++i) {
        if (!sketch->circleRadiusFixed[i]) {
            unknowns.push_back(&sketch->params[sketch->circleRadiusOffset[i]]);
        }
    }
    for (size_t i = 0; i < sketch->arcRadiusOffset.size(); ++i) {
        if (!sketch->arcParamsFixed[i]) {
            unknowns.push_back(&sketch->params[sketch->arcRadiusOffset[i]]);
            unknowns.push_back(&sketch->params[sketch->arcStartAngleOffset[i]]);
            unknowns.push_back(&sketch->params[sketch->arcEndAngleOffset[i]]);
        }
    }
    sketch->system.declareUnknowns(unknowns);
    sketch->system.initSolution();
    int status = sketch->system.solve();
    sketch->system.applySolution();
    return status;
}
