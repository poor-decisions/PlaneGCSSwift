# GCS Constraint Wrapper Agent

Wrap one or more `GCS::System::addConstraint*` methods from `GCS.h` into PlaneGCSSwift, generating
the three artifacts the pattern requires: bridge header declaration, bridge Obj-C++ implementation,
Swift wrapper method.

## Input

A list of `addConstraint*` method names (e.g. `addConstraintPointOnEllipse`,
`addConstraintTangentAtBSplineKnot`), usually from Tier 5 (the deferred Ellipse/Hyperbola/Parabola/
BSpline/internal-alignment methods — see `CLAUDE.md`'s coverage table).

## Process

### 1. Read the real signature

Read the method's declaration in `Sources/CPlaneGCS/include/GCS.h` — never guess a signature.
Note every parameter's type: `Point&`/`Line&`/`Circle&`/`Arc&` (existing geometry helpers),
a not-yet-wrapped geometry type (`Ellipse&`/`Hyperbola&`/`Parabola&`/`BSpline&`/`ArcOfEllipse&`/etc.
— check `Sources/CPlaneGCS/include/Geo.h` for its fields), `double*` (a new scalar parameter),
`unsigned int` (a plain index, e.g. a knot index — passed through as-is), or `int tagId`/`bool driving`
(the standard trailing pair, always present).

### 2. If a new geometry type is needed

Check `Geo.h` for its exact fields. Every PlaneGCS geometry type so far has turned out to be either:
- a pure aggregate of already-allocated points (like `Line`: `Point p1; Point p2;`), or
- an aggregate of existing points plus a small number of *new* scalar parameters (like `Circle`:
  `Point center; double* rad;`, or `Arc`: adds `startAngle`/`endAngle` plus `start`/`end` points).

If the new type fits this shape, follow the exact pattern already established for `Circle`/`Arc` in
`PlaneGCSBridge.mm`: a registry (parallel vectors keyed by a new `<Type>ID`), a `<type>At(sketch, id)`
helper reconstructing the GCS struct from stored offsets, an `AddX` bridge function allocating any
new scalars via `pushParam`, a `fixed` flag if it has free scalar parameters, and — critically — a
new case in `PlaneGCSSketchSolve`'s unknowns-gathering loop for any non-`fixed` new scalars (see
CLAUDE.md's "Free vs. fixed parameters" — a free parameter never registered as an unknown makes
every constraint touching it silently do nothing, and this has already caused one real bug here).

If it doesn't fit this shape (e.g. requires `PushOwnParams`/`ReconstructOnNewPvec` machinery, or a
callback/law hierarchy), stop and flag it rather than forcing the existing pattern — note it as a
genuinely new kind of problem, not a Tier 5 checkbox.

### 3. Generate the three artifacts

**Bridge header** (`Sources/PlaneGCSBridge/include/PlaneGCSBridge.h`): append under the matching
Tier comment (or a new `// --- Constraints: Tier 5, need a <Type> ---` section). Pattern:
```c
int32_t PlaneGCSSketchAddConstraint<Name>(PlaneGCSSketchRef _Nonnull sketch,
                                           /* one int32_t id param per geometry arg,
                                              one double param per new scalar */
                                           int32_t tagId, bool driving);
```

**Bridge implementation** (`Sources/PlaneGCSBridge/PlaneGCSBridge.mm`): append after the last Tier
section, before `// --- Solve ---`. Pattern (every geometry arg bound to a named local — GCS's
methods take non-const references, which cannot bind to a temporary; this is a real, seen-in-practice
compile error here, not a style preference):
```cpp
int32_t PlaneGCSSketchAddConstraint<Name>(PlaneGCSSketchRef sketch, /* ... */) {
    GCS::<Type> g<name> = <type>At(sketch, <id>);   // one per geometry arg
    size_t someOff = pushParam(sketch, someScalar);  // one per new scalar
    return sketch->system.addConstraint<Name>(g<name>, /* ..., */ &sketch->params[someOff], tagId, driving);
}
```

**Swift wrapper** (`Sources/PlaneGCSSwift/PlaneGCSSketch.swift`): append under the matching
`// MARK: - Constraints: Tier N` section (or a new one):
```swift
@discardableResult
public func add<Name>Constraint(
    /* ... */, tagId: Int32 = 0, driving: Bool = true
) -> ConstraintID {
    ConstraintID(rawValue: PlaneGCSSketchAddConstraint<Name>(handle, /* ... */, tagId, driving))
}
```

### 4. Verify

`swift build` must succeed. Then extend `Sources/PlaneGCSDemo/main.swift` with a real, checkable
test — not just "does it compile": pick a scenario where the constraint's effect is verifiable
(e.g. a deliberately-wrong initial value that the constraint should correct), run `swift run
PlaneGCSDemo`, and confirm the printed result actually matches what the constraint should produce.

## Output format

For each requested method, report:
- The method's real signature (quoted from `GCS.h`).
- Whether a new geometry type was needed, and if so, its registry/helper additions.
- The three generated artifacts, each in its own labeled code block.
- The demo test added and its actual output.
- Anything that didn't fit the established pattern, flagged plainly rather than forced.
