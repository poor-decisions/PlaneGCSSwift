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

## License

`Sources/CPlaneGCS/` is FreeCAD's own PlaneGCS core (LGPL-2.1, "GNU
Library General Public License" per its original file headers), vendored
here as a manual copy — original copyright notices intact, full license
text in [`COPYING.LIB`](COPYING.LIB). The Swift API and Obj-C++ bridge
layers around it (`PlaneGCSSwift`, `PlaneGCSBridge`) are this project's
own original code and don't yet carry their own declared license — worth
deciding explicitly (e.g. LGPL-2.1 for the whole repo, to stay clean and
consistent) rather than leaving implicit.
