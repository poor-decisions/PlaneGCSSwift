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

This project is licensed under the **GNU General Public License v3.0** —
see [`LICENSE`](LICENSE).

`Sources/CPlaneGCS/` is FreeCAD's own PlaneGCS core, vendored here as a
manual copy with its original copyright notices intact. Its own header
licenses it under "the GNU Library General Public License... either
version 2 of the License, or (at your option) any later version" — full
text in [`COPYING.LIB`](COPYING.LIB). LGPL-3.0 (one of those later
versions) is defined as GPL-3.0 plus additional permissions (chiefly,
permission to link into proprietary code without that code also becoming
GPL), so combining this LGPL-2-or-later core into a GPL-3.0 project and
simply not exercising those extra permissions is a use the license's own
"or later version" clause is designed to allow.
