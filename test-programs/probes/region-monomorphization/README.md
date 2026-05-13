# Region Monomorphization Probes

These are exploratory compiler probes for region-generic monomorphization and
nearby typeclass behavior. They are intentionally kept out of the default
`test-programs/suites` tree because several cases describe bugs that should
compile, but currently fail.

Run them with:

```sh
test-programs/probes/region-monomorphization/run.sh
```

All cases are expected to compile to C, compile with the C compiler, and run
successfully. A failure here is a compiler/runtime bug or a reduction that needs
more investigation.

Issue-derived cases:

- `001-issue-603-recursive-region`: upstream #603, recursion in a generic
  function over a region parameter.
- `003-issue-583-region-generic-dispose`: upstream #583, returning and
  disposing a linear type indexed by a region.
- `004-issue-598-buffer-span-return`: upstream #598, returning
  `Buffer[Span[Nat8, R]]` from a region-generic function.
- `008-issue-564-typeclass-return-polymorphism`: upstream #564, typeclass
  method with return-type polymorphism.

## Current Results

On the current `dev` compiler, 2 cases pass and 6 fail.

| Case | Result | Notes |
| --- | --- | --- |
| `001-issue-603-recursive-region` | FAIL `austral-compile` | Recursive generic call loses the region binding: `No binding for this parameter: R`. |
| `002-region-linear-direct-dispose` | PASS | Baseline: a region-indexed linear record can be constructed and disposed directly inside the borrow region. |
| `003-issue-583-region-generic-dispose` | FAIL `c-compile` | Generic function returns `Bar[Region 0]`, caller expects `Bar[Region 2]`; the generated structs are layout-equivalent but nominally distinct C types. |
| `004-issue-598-buffer-span-return` | FAIL `c-compile` | Same nominal mismatch through `Buffer[Span[Nat8, R]]`. |
| `005-reduced-region-spanbox-return` | FAIL `c-compile` | Reduced form of #598: `SpanBox[R]` containing a single `Span[Nat8, R]` still produces incompatible named C structs. |
| `006-region-span-return-direct` | PASS | Returning bare `Span[Nat8, R]` works because it erases to `au_span_t` rather than a region-indexed named C struct. |
| `007-region-record-return-direct` | FAIL `c-compile` | Minimal named-record repro: `RegionValue[R]` with only an `Int32` field still gets duplicate C monomorphs for caller/callee regions. |
| `008-issue-564-typeclass-return-polymorphism` | FAIL `austral-compile` | Still hits `Internal compiler error: You shouldn't be asking for the type_universe of a MonoTy`. |

The strongest reduction is `007-region-record-return-direct`: the bug does not
require spans, buffers, linearity, or destructuring. A named type whose only type
parameter is a region is monomorphized separately for the caller's concrete
borrow region and the callee's generic region parameter, even though that region
does not affect the runtime layout.
