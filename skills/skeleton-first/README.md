# skeleton-first

Put every file, contract, function and argument in its final place.
Implement nothing. The compiler reviews the architecture, not prose.

Use it after a spec is approved, before the implementation plan. Also on
"wiring only", "stubs only", "no logic yet". Not for bug fixes.

## The one rule
- No function body → contract, real and complete: types, schemas, tables,
  registry entries, DI constructors.
- Has a body → marker: `throw new Error('SKELETON_TODO: name')`, with the
  intent in comments. Trivial mappers included.
- Exception: a body that only calls other functions is composition. Write
  it for real, so the compiler checks the data flow.

## Never
Test files. Generated migrations.

## Output
Real files that typecheck, plus a short walkthrough in the scratchpad:
reading route, open decisions, risk surface. `grep -rn SKELETON_TODO`
gives the leaf list for the implementation plan.
