## Campaign context and required reading

On the `experiment/shepherd-control` branch, the directory `1-math-control-remove-before-merge` contains the plan (`math-tool-ignorance-reduction-plan.md`) and supporting resources (diagrams, decision records). Spike subdirectories are research artifacts — read the plan's Resolution sections for findings, not the spike source code.

Before working, read the entire plan. Then carefully re-read these exact sections:

- `## Ignorance reduction`
- `### Repository-owned validation`
- `### Output and ordering contracts`
- `## Implementation`
- `### 1. Implement Fibonacci with unit and isolated CLI coverage`

The resolved acceptance decision is concrete: use the committed canonical command `pwsh -NoLogo -NoProfile -File ./eng/test-math-tool.ps1`. The baseline workflow `.github/workflows/shepherd-task-math-tool.yml` installs exactly Pester 5.7.1 and invokes that repository-owned runner; do not replace or bypass it.

The resolved behavior decision is concrete: direct CLI execution writes exactly one result line to stdout in the form `Fibonacci(N) = value`; functions return only the numeric value without incidental output; inputs are non-negative integers; and the implementation and test files are the repository-root `math-tool.ps1` and `math-tool.Tests.ps1`.

No separate spike implementation is part of this campaign. The applicable research finding is that unit behavior and process-level CLI behavior must be tested separately: dot-source the production script to test the pure function, and invoke a child `pwsh` process to verify direct execution and stdout. Implement production code and tests from the stated contract; do not copy research artifacts.

## Branch and execution order

Use `experiment/shepherd-control` as the PR base branch. This is serial task 1 of 2. Tasks are assigned, completed, and merged in plan order. Do not begin work until this issue is assigned to the coding agent. Task 2 must not begin until this task is merged.

## Implement

Create these two repository-root files together:

- `math-tool.ps1`
- `math-tool.Tests.ps1`

In `math-tool.ps1`:

- Define an `N` parameter whose accepted domain is non-negative integers.
- Implement a pure `Get-Fibonacci` function.
- Return the Fibonacci value as a number with no incidental output from the function.
- Ensure dot-sourcing the script exposes the function without printing the CLI result line.
- When the script is executed directly, print exactly one stdout line formatted as `Fibonacci(N) = value`, substituting the supplied integer and computed value.

In `math-tool.Tests.ps1`:

- Dot-source the production `math-tool.ps1`; do not duplicate the algorithm in tests.
- Add unit coverage for `Get-Fibonacci` at `N=0`, `N=1`, and at least one small representative value greater than 1.
- Add isolated child-`pwsh` process coverage for direct CLI execution at the same boundary and representative values.
- Assert the child process exits successfully and stdout is exactly the single expected line, with no diagnostics or incidental function output mixed into it.
- Keep tests deterministic and compatible with Pester 5.7.1.

Use an objective, small implementation. Keep all behavior in the production script and exercise it through the repository-owned runner.

## Completion gates

- `Get-Fibonacci 0` returns numeric `0`, `Get-Fibonacci 1` returns numeric `1`, and the selected representative input returns the correct numeric Fibonacci value.
- Dot-sourcing `math-tool.ps1` produces no CLI result output.
- Direct child-process execution for every covered input exits zero and emits exactly one line matching `Fibonacci(N) = value`.
- Negative input is rejected rather than treated as a valid Fibonacci input.
- `pwsh -NoLogo -NoProfile -File ./eng/test-math-tool.ps1` exits zero using the repository-root implementation and tests.
- The pinned pull-request CI passes without changing or bypassing `.github/workflows/shepherd-task-math-tool.yml` or `eng/test-math-tool.ps1`.

## Out of scope

- Factorial calculation, an operation selector, and operation dispatch belong to serial task 2.
- Do not modify the canonical runner, pinned Pester version, workflow, campaign metadata, or plan.
- Do not add dependencies, unrelated refactors, additional math operations, interactive prompts, or output beyond the single required CLI line.
- Do not assign or start task 2 as part of this issue.
