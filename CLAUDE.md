# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## Project Summary

PlaneGCSSwift is a Swift wrapper for [PlaneGCS](https://github.com/Salusoft89/planegcs),
FreeCAD's 2D geometric constraint solver (the engine behind FreeCAD's Sketcher). It's a sibling
package to [OCCTSwift](../OCCTSwift) inside the `mac_cad_projects` umbrella — both are dependencies
of the `draft` app (a parametric CAD tool), OCCTSwift providing the 3D B-Rep kernel, this package
providing 2D sketch constraint solving. Three-layer architecture, same shape as OCCTSwift: Swift
public API → Objective-C++ bridge (C functions) → vendored C++ core.

Much younger than OCCTSwift: no CI, no release process. Don't assume OCCTSwift-level process
maturity exists here — this file describes what's actually true, not an aspiration. There is now a
real Swift Testing suite (see below), added 2026-09-13.

See `draft/ARCHITECTURE.md` and `draft/EXPERIMENTS.md` (in the `draft` repo) for the broader design
this package serves — the feature-tree/document model, and the full history of spikes that led
here (OCCTSwift kernel spike, PlaneGCS feasibility + native-compile spikes, this package's own
build-out).

## Build & Test Commands

```bash
swift build               # Build the package
swift test                # Run the full test suite (52 tests as of 2026-09-13)
swift test --filter Tier3Tests   # Run one suite (matches the test *struct* name)
swift run PlaneGCSDemo    # Run the manual smoke-test executable (kept for quick eyeballing)
```

`Tests/PlaneGCSSwiftTests/` is organized one file per tier (`FoundationTests`, `Tier1Tests`,
`Tier2Tests`, `Tier3Tests`, `Tier4Tests`), mirroring OCCTSwift's per-domain layout, with one real,
checkable geometric scenario per wrapped constraint — never a bare "does it compile" test. Follow
the same shape when adding Tier 5 coverage.

**"Prove the test fails" applies here too**, per OCCTSwift's own policy: when the circle-radius-
unknowns bug was found (see "Free vs. fixed parameters" below), the fix was temporarily reverted,
`Tier3Tests` was re-run to confirm exactly the three radius-dependent tests failed (not more, not
fewer), then the fix was restored and the suite re-confirmed green. Do this for any new bug found
by a test, not just when writing a new one.

## Architecture

```
Sources/CPlaneGCS/           Vendored PlaneGCS core (GCS/Geo/Constraints/SubSystem/qp_eq .cpp+.h,
                              plus native shim headers replacing FreeCAD's own FCConfig.h/FCGlobal.h/
                              Console.h) — see include/ for the public headers PlaneGCSBridge depends on
Sources/PlaneGCSBridge/       Objective-C++ bridge: owns the session/buffer layer (see below)
Sources/PlaneGCSSwift/        Swift public API: PlaneGCSSketch + PointID/LineID/CircleID/ArcID/ConstraintID
Sources/PlaneGCSDemo/         Smoke-test executable (swift run PlaneGCSDemo)
```

### The session/buffer layer (`PlaneGCSBridge.mm`)

`GCS::Point`/`Line`/`Circle`/`Arc` hold raw `double*` into a caller-owned parameter array. The
bridge owns that array as a **`std::deque<double>`, never `std::vector`**: `push_back` on a deque
never invalidates references/pointers to elements already in it (only iterators), so points and
constraints added incrementally never dangle earlier ones. A `std::vector` would silently
invalidate every existing pointer on its first reallocation. This is the one load-bearing decision
the whole bridge depends on — don't "simplify" it to a vector.

Swift never sees a raw pointer, only opaque `PointID`/`LineID`/`CircleID`/`ArcID` (really indices
into bridge-side bookkeeping vectors). Geometry structs (`GCS::Point`/`Line`/`Circle`/`Arc`) are
reconstructed on demand from stored offsets via the `pointAt`/`lineAt`/`circleAt`/`arcAt` helpers in
`PlaneGCSBridge.mm` — never stored long-term as C++ objects themselves.

`solve()` hides PlaneGCS's own choreography: it gathers every non-`fixed` point (and non-`fixed`
circle/arc radius+angle parameters — see "Free vs. fixed" below), then calls
`declareUnknowns → initSolution → solve → applySolution` internally. Swift callers just call
`.solve()`.

**Dragging a point is not a separate API.** It's `setPosition(of:x:y:)` (writes straight into the
buffer) followed by `.solve()` — confirmed (see `draft/EXPERIMENTS.md`, 2026-09-13) to produce
correct, direction-sensitive resolution using PlaneGCS's own solve as the drag mechanism, no
special weighted-drag mode needed.

### Free vs. fixed parameters

Points, circle radii, and arc radius/angles all follow the same pattern: a `fixed` flag at creation
time controls whether that parameter is included in `solve()`'s unknowns list. **A "free" geometry
parameter that never gets registered as an unknown makes any constraint touching it silently do
nothing** — this bit us once already (circle radius, caught before shipping — see
`draft/EXPERIMENTS.md`). When adding a new geometry type with its own new scalar parameters, always
check whether `PlaneGCSSketchSolve`'s unknowns-gathering loop needs a new case for it.

### Adding a new wrapped constraint

1. **Bridge header** (`Sources/PlaneGCSBridge/include/PlaneGCSBridge.h`): add the C function
   declaration, grouped under the matching Tier comment.
2. **Bridge impl** (`Sources/PlaneGCSBridge/PlaneGCSBridge.mm`): call the matching `GCS::System`
   method. **Every `Point&`/`Line&`/`Circle&`/`Arc&` argument must be bound to a named local first**
   — `GCS::System`'s methods take non-const lvalue references, which cannot bind to a temporary.
   Passing `pointAt(sketch, id)` directly as a call argument is a real, seen-in-practice C++ compile
   error (`draft/EXPERIMENTS.md`, 2026-09-13), not a style nit.
3. **Swift wrapper** (`Sources/PlaneGCSSwift/PlaneGCSSketch.swift`): a `@discardableResult` method
   returning `ConstraintID`, grouped under the matching `// MARK: - Constraints: Tier N` section.
4. **Test**: add a `@Test` to the matching `Tests/PlaneGCSSwiftTests/TierNTests.swift` (or a new
   Tier 5 file) with a real, checkable scenario — deliberately wrong initial values, corrected via
   the new constraint, checked against the expected converged value. Before trusting a constraint's
   effect (e.g. does "distance" mean center-to-center or edge-to-edge?), check the real `error()`
   function in `Constraints.cpp` rather than assume — see "Distance to a circle/arc means
   edge-to-edge" below for a concrete case where the assumption would have been wrong.

The `gcs-constraint-wrapper` subagent (`.claude/agents/gcs-constraint-wrapper.md`) automates this
loop for GCS.h's remaining `addConstraint*` methods (Tier 5: Ellipse/Hyperbola/Parabola/BSpline/
internal-alignment — deliberately deferred so far, see below).

## Constraint coverage

`GCS::System` has ~77 `addConstraint*` methods, categorized by which geometry types they need
(full breakdown: `project_logs/2026-09-13-feature-tree-precedents.md` in the umbrella folder).

| Tier | Needs | Status |
|---|---|---|
| 1 | Point only | Done (~17 methods) |
| 2 | + Line | Done (~11 methods) |
| 3 | + Circle | Done (~10 methods) |
| 4 | + Arc | Done (~15 methods) |
| 5 | Ellipse/Hyperbola/Parabola/BSpline/internal-alignment | Deferred indefinitely |

Tier 5 is a deliberate scope decision, not an oversight: the target app is a SketchUp-Make-level
2D/3D modeler, not an engineering/conics tool. Tiers 1-4 already cover distance, angle, coincident,
horizontal/vertical, parallel, perpendicular, tangent, radius/diameter, and arcs/fillets — a
complete basic sketch constraint set.

### "Distance" to a circle/arc means edge-to-edge, not center-to-center

`C2CDistance`, `C2LDistance`, and `P2CDistance` all measure the **gap to the circle's/arc's edge**,
not center-to-center or point-to-center — confirmed from `Constraints.cpp`'s `error()` functions,
not assumed. Concretely (point/line starting outside the circle, the common case):
- `C2CDistance(c1, c2, target)` solves to `distance(centers) == r1 + r2 + target`.
- `C2LDistance(circle, line, target)` solves to `distance(center, line) == radius + target`.
- `P2CDistance(point, circle, target)` solves to `distance(point, center) == radius + target`.

This matches conventional CAD dimensioning (a "distance to a circle" dimension in FreeCAD/Fusion
means to its edge), so it's not a bug — but it's easy to assume center-to-center and get tests (or
a UI) that are off by exactly the radius. `Tests/PlaneGCSSwiftTests/Tier3Tests.swift` has this
wrong once already, caught by checking the actual solved value rather than trusting a plausible-
looking assumption.

## Vendored core (`Sources/CPlaneGCS/`)

The core solver files (`GCS`/`Geo`/`Constraints`/`SubSystem`/`qp_eq`) are FreeCAD's own
`src/Mod/Sketcher/App/planegcs` (LGPL-2.1), currently a **manual copy**, not synced via any
automated script. Salusoft89's own WASM port (`Salusoft89/planegcs`) has an `update_freecad.sh`
that does this via `git sparse-checkout` against a pinned FreeCAD commit — worth adopting a similar
script here once this package needs to track upstream FreeCAD fixes; right now it's a one-time
vendor, not a maintained sync.

`Console.h` was rewritten (the original uses `emscripten.h`/`EM_JS`, WASM-only) as a plain
`vprintf` shim — this is a deliberate native replacement, not a stub to "finish later."

## Workflow Automations

- **`/wrap-constraint <addConstraintName> [...]`**: wraps one or more `GCS::System::addConstraint*`
  methods (typically Tier 5) into the three required artifacts, following the exact pattern
  established for Tiers 1-4.
- Subagent in `.claude/agents/`: **`gcs-constraint-wrapper`** (reads the real signature from
  `GCS.h`, extends the geometry-type infrastructure if needed, generates bridge header/impl/Swift
  wrapper, adds a real checkable demo test).

## Known limitations

- **`Package.swift` hardcodes Homebrew include paths** for Eigen and Boost.Graph
  (`/opt/homebrew/opt/eigen`, `/opt/homebrew/opt/boost`). Both are header-only, so vendoring them
  directly (like OCCTSwift ships a self-contained xcframework) is the intended long-term fix, not
  yet done.
- **No CI.**
