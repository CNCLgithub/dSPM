# MIGRATION — Phase 1 core refactor (`dspm_reservoir`)

The 2,731-line monolith `core/dspm_reservoir.m` is now a class folder
`core/@dspm_reservoir/` with a ~700-line core classdef plus one file per
carried-over method (display, I/O, basis-query, and programming helpers were
**extracted verbatim** — their behavior is unchanged). The old monolith is
preserved at `archive/dspm_reservoir_v3_monolith.m`. The four symbolic engine
files (`decompile_reservoir.m`, `jet_expansion_.m`,
`polynomial_basis_expansion_.m`, `eval_coefficients_.m`) are **untouched**.

Nothing changes about how you get the class on your path: `addpath('core')`
picks up the `@dspm_reservoir` folder automatically.

## What stays exactly the same

- The symbolic three-tier decompilation and its caches.
- `compile(P)` (lsqminnorm + stats), `buildProgramMatrixSymbolic`, the basis
  query family (`getColumnIndex`, `printBasis`, `displayBasis`, …),
  `render_program`, `summary`, `save`/`load`/`toStruct`/`fromStruct`,
  `loadProgram`, `programming_gui`, and all JSON presets.
- Old-style construction: `dspm_reservoir(n_neurons=500, n_recurrent_inputs=3,
  n_external_inputs=0, gamma=…, dt=…)` works unchanged, as does a leading
  positional N: `dspm_reservoir(500, …)`.
- `decompile()`, `close_loop()`, `condition(x_rec_0, x_ext_0, T)`,
  `readout()`, `reset()`, `get_status()`, `disp_status()` keep their
  signatures.

## Behavioral changes (intentional)

1. **Lazy decompilation.** The constructor no longer runs the symbolic solve;
   `program(dx)` triggers it automatically on first need. To restore the old
   timing: `dspm_reservoir(…, decompile="eager")`, or call `res.decompile()`
   yourself. `dspm_reservoir.load`/`fromStruct` remain **eager** (identical
   observable behavior for the GUI/JSON path). Re-programming with a
   same-signature `dx` still skips straight to the `lsqminnorm` — the cache
   economics are unchanged.

2. **`program()` auto-closes.** `program(dx)` now performs
   decompile-if-needed → P̂ → W → `close_loop()`. Existing scripts that call
   `close_loop()` right after `program()` still work: `close_loop()` is
   idempotent (it recomputes A from provenance).

3. **Pipeline flags are gone as stored state.** `is_decompiled`,
   `is_compiled`, `is_closed`, `is_conditioned`, `ready_to_run`,
   `is_initialized` are still *readable* — now derived live from artifact
   presence — but **read-only**. Any script that *assigned* them
   (`res.is_conditioned = true`) must drop that line; the state it tried to
   assert is now implied by the data (e.g. `condition()` storing `r0`).
   `require()`, `invalidate_from()`, `update_ready_to_run()` no longer exist;
   setters clear downstream data directly.

4. **`d_star` now means the identity value** d⋆ = atanh(r⋆) − A₀r⋆ − B·x₀ —
   i.e. what the old code called `bias` (the d inside tanh). The old
   `d_star` (= atanh(r⋆) alone) had no independent consumer; with the default
   x₀ = 0 and A₀ = 0 the two coincide anyway. `bias` remains as a read-only
   alias of `d_star`, so the decompiler and all extracted code see identical
   values.

5. **Ports.** Input channels now carry roles
   (`"recurrent"`/`"exogenous"`/`"external"`) in `res.ports`, with immutable
   ascii ids (`rec1`, `exo1`, …), math-symbol labels (`x̃₁`, `x̅₁`, `x̂₁`), and
   optional aliases. New constructions can use
   `ports=["rec","exo","exo"]` (+ `port_names=[…]`) or `ports="infer"` (m̃
   provisioned by the first `program(dx)`). Old `n_recurrent_inputs=` /
   `n_external_inputs=` still work and map onto roles (legacy "external" =
   non-recurrent). `res.port_table()` prints the table.

6. **`condition()` no longer toggles flags.** It integrates the retained
   pre-closure tuple (provenance) under constant drive and stores `r0`.
   Consequently a reservoir built from a bare externally-supplied `A` (tier
   `"none"`) cannot `condition()` — set `res.r0` yourself or supply provenance.

7. **New surface.** `status()` (pipeline + capabilities), `capabilities()`,
   `reopen()` (undo closure from provenance), `port_table()`,
   `live_input_width`, and the declarative factory
   `dspm_reservoir.from_matrices(…)` with identity give-one/derive-other/
   assert-both semantics on {r⋆, d⋆}.

8. **`simulate(T, x)`** now checks that `x` has `live_input_width` rows and
   accepts a single column as constant drive. Passing `r0` as the second
   argument (an old v1 idiom still present in two tests) is an error by
   design — set `res.r0` (or call `condition()`) and call `simulate(T)`.

## Path hygiene (IMPORTANT)

Add **`core/` only** to your path: `addpath(fullfile(root,'core'))`. Do NOT
`addpath(genpath(root))`: `archive/` sorts before `core/`, so archived helper
variants would shadow the live ones. (This bit once already: the archived
sandbox `jet_expansion_` uses `jet_order+1` and, paired with the core basis
stage, produces phantom `y7…` coefficient variables — the classic
`Unrecognized function or variable 'y7'` failure. The archived sandbox
helpers are now renamed `*.m.archived` so they cannot shadow, and
`decompile()` converts this failure class into a self-explaining error.)

## New in program(): arbitrary variable names + live constants

- `dx` may use ANY symbolic names. Canonical index names (`x1…`, `y1…`,
  `x_1…`) map by index exactly as before. Any other names map onto basis
  slots in `symvar` (alphabetical) order — announced in verbose mode with the
  port each symbol binds to — or explicitly via
  `program(dx, vars=[theta; omega; …])`, where slot i is recurrent port i
  (equation i's state variable) and slots m̃+1… are the drive ports in port
  order.
- `constants=struct('sigma',10,…)` values are now **substituted into dx**
  before coefficient extraction (previously storage-only), so symbolic
  parameters in the dynamics are supported directly.

## Files touched in this pass

- `core/@dspm_reservoir/…` — new class folder (core classdef + 28 extracted
  method files + `from_matrices.m`).
- `unit-tests/test_vanderpol_dspm.m`, `unit-tests/test_oscillator_dspm.m` —
  three-line call-site edits each (flag assignment removed; `simulate(T, r0)`
  → `condition` + `simulate(T)`).
- `unit-tests/test_phase1_smoke.m` — new; fast end-to-end exercise of the
  refactored surface. **Run this first.**
- Archived: `core/dspm_reservoir.m` → `archive/dspm_reservoir_v3_monolith.m`,
  plus `core/dspm_reservoir_v1.m`, `core/Reservoir_v1.m`, `core/sandbox/`.

## Downstream sweep (tests, tutorials, sandbox, JSON)

- **Rewritten on the new API:** `unit-tests/test_basic_construction.m` (quick
  checks), `unit-tests/test_construction_and_validation.m` (comprehensive:
  construction paths, port ontology, read-only derived flags, §1.9
  invalidation matrix, alias coherence, all three `from_matrices` identity
  paths, drive-width guards, signature validation; Symbolic-Toolbox sections
  skip gracefully), `sandbox/demo_user_interface.m` (guided tour of the new
  surface).
- **Patched (minimal):** `test_lorenz_dspm.m`, `s01`, `s02` — the hand-built-P
  workflows construct with `decompile="eager"` so the basis exists before
  `getColumnIndex`; everything else in them runs unmodified.
- **Unchanged and expected to pass:** `test_preditor_prey_method_comparison.m`
  and `sandbox/complex_valued_reservoirs.m` (they call `decompile()`
  explicitly; `close_loop()` after `program()` is idempotent).
- **Archived (v0/v2-era API, no modern equivalent):**
  `sandbox/test_reservoir_v2.m`, `sandbox/test_against_Jason_with_Reservoir.m`
  → `archive/*.archived`. `test_lorenz_guest_exact.m` and
  `test_against_Jason.m` don't touch the class and are untouched.
- **JSON schema v2 (backward-compatible superset):** `toStruct`/`save` now
  emit `schema_version: 2` with a `ports` array (id/label/role/x0/aliases)
  and a `provenance` block; `parseJSONConfig`/`fromStruct`/`load` read the
  `ports` block when present (roles override topology counts) and still read
  v1 files unchanged. All five presets under `saved-networks/presets/` were
  upgraded in place (old fields retained).

## Known-stale files (pre-existing, unrelated to this refactor)

- `README.md` still documents `Reservoir_v2` (rewrite queued for Phase 2/3
  alongside the wiki vocabulary).

## What Phase 2 adds (not in this zip)

`dspm_composer` (netlist verbs, edge list, `build()`), the graph shorthand,
the modules tree with hierarchical addressing, the d⋆꜀ verify-else-derive
policy with per-edge handshake blame, and the ring-oscillator parity test
against `verify/ring_oscillator.m`. The `modules` property, capability
predicates, port ids, and provenance tiers shipped now are the hooks it
builds on.

## Not executed here

This refactor was produced without a MATLAB runtime available, so nothing in
this zip has been executed. Start with `unit-tests/test_phase1_smoke.m`, then
`test_vanderpol_dspm`, `test_oscillator_dspm`, `test_lorenz_dspm`, and the
two tutorials. Syntax and API-compat were reviewed carefully, but treat the
first run as the actual Phase-1 acceptance gate.
