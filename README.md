# PlaneGCSSwift

**Work in progress.**

A Swift wrapper around [FreeCAD](https://www.freecad.org)'s PlaneGCS — the
2D geometric constraint solver behind FreeCAD's own Sketcher — built as
the sketch-constraint-solving foundation for a native macOS CAD app.

## What's here

- `CPlaneGCS` — the vendored PlaneGCS C++ core.
- `PlaneGCSBridge` — an Objective-C++ bridge layer.
- `PlaneGCSSwift` — the public Swift API: `Point`/`Line`/`Circle`/`Arc`
  geometry with ~62 constraint methods across four tiers, addressed
  through opaque handles (never raw pointers) into a `std::deque`-backed
  parameter store, chosen specifically for pointer stability under
  mutation.

52 tests, all passing. Not yet integrated into any consuming app.
