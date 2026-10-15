---
name: skeleton-first
description: Use when a spec or design is approved and the next step would be an implementation plan or real code, and the architecture, data flow and naming should be reviewable before anything is implemented. Also use on any request for wiring only, skeleton only, scaffold only, stubs only, structure without logic, or "no logic yet".
---

# Skeleton First

## Overview

Put every file, folder, contract, function, argument and switch in its final place. Implement nothing.

**The compiler reviews the architecture, not prose.** A markdown plan can lie about the data flow. A skeleton that typechecks cannot.

A wrong body costs nothing — you write it later anyway. A wrong name is already in call sites, in JSDoc, and in a durable step journal where it can never be renamed. This phase buys the expensive review cheaply.

## When to Use

After a spec or design is approved, before the implementation plan. Also for structural refactors: agree the shape before behavior moves.

spec approved → **skeleton** → human review → implementation plan → implementation

Not for bug fixes or single-function changes.

## The One Rule

- **No function body → contract → real and complete.** Types, schemas, table definitions, registry entries, decorators, class declarations, DI constructor parameters.
- **Has a function body → marker.** However trivial, however pure. Mappers, formatters, parsers, comparators, predicates and one-line transforms included. *How* it maps is the reviewer's decision, not yours to pre-empt.

You cannot stub a schema — it *is* the architecture.

**One exception, and it is the point:** a body that only calls other functions is **composition**. Write it for real, so the compiler checks the data flow end to end. A body that both composes and computes must be split — that function was doing two things.

```ts
/** Import one file into the store, row by row. */
export async function importFile(
  path: string,
  store: RowStore,
): Promise<ImportReport> {

  // Read the file as one string
  const raw = await readRaw(path);

  // Turn the raw text into typed rows
  const rows = parseRows(raw);

  // Write the rows and count what was stored
  return storeRows(rows, store);
}

/** Turn the raw text into typed rows. */
function parseRows(raw: string): Row[] {

  // Split the raw text on newlines, drop empty lines → lines: string[]

  // Map each line to a Row, fail on the first bad line → rows: Row[]

  throw new Error('SKELETON_TODO: parseRows');
}
```

Other languages keep the literal token: `raise NotImplementedError('SKELETON_TODO: name')`.

## Names Are the Deliverable

Names get reviewed here: files, folders, functions, arguments, types, fields, durable step names. Locals are named in the intent comment with their type, never declared. Competing names go in the walkthrough as an open decision.

## Never

- **Test files.** Not even `it.todo`. Tests are the bottleneck this phase exists to defer.
- **Generated migrations.** The table definition is enough; a migration collides as soon as the branch moves.

## Output

Real files, plus a short walkthrough in the scratchpad — not committed: reading route, open decisions, risk surface.

## Stop Conditions

The reading route is a measuring instrument, not a crutch. Report a design finding instead of writing better prose:

- No single obvious entry point → responsibilities are scattered.
- The route does not fit in a few lines → too many hops or branches.

## Verify

- Typecheck green. Dependencies and typechecking are cheap — spend that time freely.
- `grep -rn SKELETON_TODO` — the count is the leaf list and the input for the implementation plan. **Zero hits means you implemented something by accident.**
- Formatter once, at the end.

## Red Flag

| Rationalization | Reality |
|---|---|
| "This one is trivial / pure / it only reshapes — I will just implement it" | Observed failure, round one. It has a body. Marker. |
