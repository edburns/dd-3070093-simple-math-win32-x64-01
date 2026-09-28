## Campaign context and required reading

On the `experiment/shepherd-control` branch, the directory `1-math-control-remove-before-merge` contains the plan (`math-tool-ignorance-reduction-plan.md`) and supporting resources (diagrams, decision records). Spike subdirectories are research artifacts — read the plan's Resolution sections for findings, not the spike source code.

Before working, read the entire plan. Then carefully re-read these exact sections:

- `## Ignorance reduction`
- `### Repository-owned validation`
- `### Output and ordering contracts`
- `## Implementation`
- `### 1. Implement Fibonacci with unit and isolated CLI coverage`
- `### 2. Add factorial and operation dispatch`

The resolved acceptance decision is concrete: use the committed canonical command `pwsh -NoLogo -NoProfile -File ./eng/test-math-tool.ps1`. The baseline workflow `.github/workflows/shepherd-task-math-tool.yml` installs exactly Pester 5.7.1 and invokes that repository-owned runner; do not replace or bypass it.

The resolved behavior decision is concrete: direct CLI execution writes exactly one result line to stdout in the form `Fibonacci(N) = value` or `Factorial(N) = value`; functions return only the numeric value without incidental output; inputs are non-negative integers; task 2 starts only after merged task 1; and the implementation and test files remain the repository-root `math-tool.ps1` and `math-tool.Tests.ps1`.

No separate spike implementation is part of this campaign. The applicable research findings are that Fibonacci behavior from task 1 is a compatibility contract, factorial must follow the same pure-function/isolated-CLI split, and process-level tests are required to detect dispatch or output regressions that function-only tests cannot detect. Implement production code and tests from these findings; do not copy research artifacts.

## Branch and execution order

Use `experiment/shepherd-control` as the PR base branch. This is serial task 2 of 2 and depends on task 1 already being merged into that branch. Tasks are assigned, completed, and merged in plan order. Do not begin work until task 1 is merged and this issue is assigned to the coding agent.

## Implement

Extend the existing repository-root `math-tool.ps1` and `math-tool.Tests.ps1` introduced by task 1.

In `math-tool.ps1`:

- Preserve the existing pure `Get-Fibonacci` function and its results.
- Add a pure `Get-Factorial` function accepting non-negative integer input and returning only the numeric factorial value.
- Add an `Operation` parameter that dispatches between `fibonacci` and `factorial` while retaining the existing `N` parameter.
- Preserve task 1's Fibonacci CLI behavior. Omitting `Operation` must continue to select Fibonacci so an existing invocation that supplies only `N` still prints `Fibonacci(N) = value`.
- For the factorial operation, direct execution must print exactly one stdout line formatted as `Factorial(N) = value`.
- Restrict operation values to the two supported operations and reject invalid values explicitly.
- Keep dot-sourcing behavior free of CLI result output so both pure functions can be unit tested.

In `math-tool.Tests.ps1`:

- Preserve the Fibonacci unit and isolated CLI regression coverage from task 1.
- Add unit coverage for `Get-Factorial` at `N=0`, `N=1`, and at least one small representative value greater than 1.
- Add isolated child-`pwsh` process coverage for factorial dispatch and exact factorial CLI output.
- Cover explicit Fibonacci dispatch and the compatibility path where `Operation` is omitted.
- Assert successful child-process exit and exactly one expected stdout line for valid operations.
- Keep tests deterministic and compatible with Pester 5.7.1.

Keep the interface and combined regression suite objective and small.

## Completion gates

- `Get-Factorial 0` and `Get-Factorial 1` each return numeric `1`; the selected representative input returns the correct numeric factorial value.
- Existing Fibonacci unit results and exact CLI output remain unchanged.
- Explicit `fibonacci` dispatch and omitted-operation compatibility both select Fibonacci; explicit `factorial` dispatch selects factorial.
- Direct factorial execution exits zero and emits exactly one line matching `Factorial(N) = value`.
- Unsupported operations and negative numeric inputs are rejected rather than silently dispatched or calculated.
- Dot-sourcing `math-tool.ps1` emits no CLI result output and both functions return numeric values without incidental output.
- `pwsh -NoLogo -NoProfile -File ./eng/test-math-tool.ps1` exits zero for the combined Fibonacci and factorial regression suite.
- The pinned pull-request CI passes without changing or bypassing `.github/workflows/shepherd-task-math-tool.yml` or `eng/test-math-tool.ps1`.

## Out of scope

- Do not add operations beyond `fibonacci` and `factorial`.
- Do not rename or relocate `math-tool.ps1` or `math-tool.Tests.ps1`.
- Do not modify the canonical runner, pinned Pester version, workflow, campaign metadata, or plan.
- Do not add dependencies, interactive prompts, unrelated refactors, or output beyond the one operation-specific result line.
