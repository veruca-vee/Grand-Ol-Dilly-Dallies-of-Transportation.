# METHOD — how code gets written here

Set by Vee, 2026-10-30, her words: gates run "spec, plan, task"
(spec-driven), and "I want the code of each thing to be written
with TDD philosophy" (red → green → refactor). This applies to
every gate from now on, engine core and game alike.

## Per gate (spec-driven, GitHub Spec Kit shape)

0. **CLARIFY** — define the behavior in concrete terms before
   anything else: what it does, constraints, edge cases, success
   criteria. Settled in Vee's words under the skeleton rules
   (one question at a time, blanks stay blank). [Adopted from the
   Copilot TDD study prompt, 2026-10-30.]
1. **SPEC** — a short doc in `design/` stating what the thing
   should do, in checkable statements. No code yet.
2. **PLAN** — the technical approach: which modules/files, what
   changes, what deliberately does NOT change.
3. **TASKS** — the plan broken into an ordered task list, each
   task independently verifiable.
4. **IMPLEMENT** — the tasks, in order, each under TDD below.
5. **VALIDATE & REVIEW** — after green: edge cases, failure
   modes, security risks where relevant (auth, data handling,
   public-facing surfaces get explicit callouts). [Adopted from
   the same study prompt.]

## Per task (TDD, red → green → refactor)

Template questions, asked in order for every task:
"What behavior are we trying to achieve? / What is the smallest
failing test that captures it? / What is the minimal
implementation? / What can we refactor safely after it passes? /
What edge cases or risks come next?"

1. **RED** — write the test first (autotest / smoketest check),
   run it, and record it FAILING for the right reason. A test that
   has never been red is not a test. The test describes the
   *contract* (behavior), not the implementation.
2. **GREEN** — write the minimum code that makes it pass. No
   speculative features, no broad refactors in this step. Run the
   FULL suite (all existing PASS lines must stay verbatim) plus
   the new line.
3. **REFACTOR** — only after green: improve readability,
   structure, naming. Behavior unchanged; suite identically
   green after. Never refactor while a test is red.

## Deliberately NOT adopted from the study prompt

- "Ask clarifying questions often." Conflicts with Vee's standing
  Decoder rule: she is not to be made to pick through lists of
  clarifying questions; the assistant carries open uncertainties
  itself and confirms settled points in one line. Clarify (step 0)
  happens inside that rule, not against it.

## Standing evidence rules (unchanged, now explicit)

- PASS lines are contracts: a gate is done when its spec's checks
  print PASS in the project AND in the exported binary.
- Verification happens on the real surface (exported binary,
  Vee's hardware) not just the editor project.
- Deviations and cuts get written into the gate's README section
  with reasons — nothing silently dropped.

## Retrofit note

Gates 3D-0 → Engine Core were built test-*verified* (autotest as
contract after the fact). From the next gate on, tests are written
*first* per this method, and the red run is recorded in the gate's
notes as proof.
