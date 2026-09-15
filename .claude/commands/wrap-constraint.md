Wrap one or more `GCS::System::addConstraint*` methods into PlaneGCSSwift using the
`gcs-constraint-wrapper` subagent.

Usage: `/wrap-constraint <addConstraintName1> [addConstraintName2] ...`

Dispatch to the `gcs-constraint-wrapper` agent (`.claude/agents/gcs-constraint-wrapper.md`) with
the requested method name(s). This is the standard path for picking up Tier 5 methods (Ellipse/
Hyperbola/Parabola/BSpline/internal-alignment — see `CLAUDE.md`'s coverage table) one at a time or
in small batches, rather than hand-writing them inline each time.
