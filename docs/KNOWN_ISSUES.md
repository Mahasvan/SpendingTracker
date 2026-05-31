# Known Issues

## 1. Async `@MainActor` tests crash when invoking SwiftData through `Tool.run`

### Status
Open, tabled. Production code is unaffected; build succeeds; the app runs.
Only the test suite is impacted, and only a specific subset of tests.

### Symptom
When running `xcodebuild test` (parallel or serial), the following tests abort
the test runner with:

```
Restarting after unexpected exit, crash, or test timeout;
summary will include totals from previous launches.
```

Affected tests:

- `ChatServiceTests.toolCallLoopExecutesAndContinues`
- `ChatServiceTests.writePolicyConfirmHaltsLoop`
- `ToolTests.addTransactionViaTool`
- `ToolTests.listTransactionsFilters`
- `ToolTests.summaryTotals`
- `ToolTests.createCategoryDuplicateFails`
- `ToolTests.deleteTransaction`

Unaffected (all passing):

- All `RepositoryTests` (synchronous)
- All `ImportExportTests` (synchronous)
- `ChatServiceTests.plainTextResponse` (async, no SwiftData write)
- `ToolTests.addTransactionRejectsNegative` (async, throws before SwiftData)

### Reproduction
1. `xcodebuild test -project "Spending Tracker.xcodeproj" \
    -scheme "Spending Tracker" -destination 'platform=macOS' \
    -only-testing:"Spending TrackerTests" -parallel-testing-enabled NO \
    CODE_SIGNING_ALLOWED=NO`
2. Observe the listed tests start (`◇ Test … started.`) and immediately the
   runner reports a restart with no `✘` failure marker. The process is being
   killed, not the assertion.

### Root cause (high confidence)

Swift 6.2 + Xcode 26 beta introduces two interacting changes:

1. **Default actor isolation = `MainActor`** is applied to the app target
   (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` in `project.pbxproj`), but
   Xcode does **not** propagate that setting to the test target. The test
   target therefore runs under the old "nonisolated by default" rule.
   See: https://stackoverflow.com/q/79681292

2. **`nonisolated(nonsending)` semantics for `async` methods**: in Swift 6.2,
   `async` functions on actor-isolated types adopt caller isolation. When the
   caller (an async test in the non-isolated test target) is not on
   `MainActor`, the call into `Tool.run(...)` is *not* hopped to `MainActor`
   despite the `@MainActor` protocol annotation. SwiftData's `ModelContext`
   is thread-affine, and invoking it off main aborts the process.

This explains every observation:

- Sync tests stay on the calling thread, which for `@MainActor` suites is the
  main thread. They pass.
- Async tests that never touch SwiftData (`plainTextResponse`,
  `addTransactionRejectsNegative`) pass because there is nothing to crash.
- Async tests that route SwiftData ops through `Tool.run` crash at the
  SwiftData boundary.

### What was already tried

- Switched `CategoryRepository.findByName` and
  `PaymentMethodRepository.findByName` from `#Predicate { $0.name == target }`
  to in-memory filtering. This was a hypothesis that the captured-string
  `#Predicate` was crashing in this Xcode beta; it was **not** the cause. The
  in-memory implementation is still correct and remains.
- Verified the crash also occurs with `-parallel-testing-enabled NO`, ruling
  out a parallelism / shared-defaults issue.
- Confirmed the build itself succeeds (`xcodebuild build` → BUILD SUCCEEDED).
- **Added `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` to both Debug and
  Release build configurations of the `Spending TrackerTests` target**
  (project.pbxproj). The build still succeeds and the crash pattern is
  **unchanged**: the same async tests that invoke `Tool.run` and then touch
  SwiftData still abort the runner with "Restarting after unexpected exit".
  This setting is therefore retained (it does no harm and aligns the test
  target with the app target) but it is not sufficient on its own.
  Side note: with the setting applied, running the full suite with
  parallel testing **on** now reports every single test as failed at 0.000s
  (an XCTest-bridge artifact), while parallel **off** still produces
  per-test ✔/crash output. Use `-parallel-testing-enabled NO` for any
  meaningful test runs until this is resolved.

### Candidate fixes (try in this order when reopening)

1. ~~**Force MainActor default on the test target.**~~ Already done. Did
   not fix the crash. Kept in place.

2. **Mark each `@Test` function explicitly `@MainActor`** (in addition to
   the `@MainActor struct`). Suite-level `@MainActor` may not propagate to
   async members under the new isolation rules. Per-test annotation may
   force caller isolation to MainActor when invoking `Tool.run`.

3. **Make `Tool.run` synchronous on the test path** by introducing a
   `runSync(...)` requirement on the protocol, or by exposing a non-async
   convenience wrapper that the tests call via `MainActor.assumeIsolated`.
   This would mirror the working `RepositoryTests` (which are all sync).

4. **Wrap SwiftData calls inside `Tool.run` with `MainActor.run { … }`.**
   Heaviest hammer; pollutes production code; prefer options 2 or 3.

5. **Pin to a stable Xcode 16 / Swift 6.1 toolchain** to bypass the
   `nonisolated(nonsending)` migration entirely while Apple stabilizes the
   feature. Acceptable only if downgrade is otherwise harmless.

6. **File a TSI / radar with Apple** with a minimal repro: a `@MainActor`
   async function calling `ModelContext.save()` from a Swift Testing
   `async @Test`. If reproducible standalone, escalate.

### Decision

Tabled (second time). Re-evaluate when:
- Xcode 26 ships a release-candidate or GM build, or
- The next Swift Testing point release (>1902) lands, or
- We have a confirmed minimal repro to file with Apple, or
- We accept introducing a `runSync` path on `Tool` for test ergonomics.

### Current verified state of the test suite

Run with: `xcodebuild test -project "Spending Tracker.xcodeproj" \
    -scheme "Spending Tracker" -destination 'platform=macOS' \
    -only-testing:"Spending TrackerTests" -parallel-testing-enabled NO \
    CODE_SIGNING_ALLOWED=NO`

Passing (10):
- `RepositoryTests.transactionAddFetchDelete`
- `RepositoryTests.queryFilterByType`
- `RepositoryTests.budgetFindByCategory`
- `RepositoryTests.chatRepoSessionFlow`
- `ImportExportTests.roundTripPreservesData`
- `ImportExportTests.mergeIsUnionByUUID`
- `ImportExportTests.categoryDedupByNameRemapsReferences`
- `ImportExportTests.replaceWipesLocalFirst`
- `ChatServiceTests.plainTextResponse`
- `ToolTests.addTransactionRejectsNegative`

Crashing the runner (7):
- `ChatServiceTests.toolCallLoopExecutesAndContinues`
- `ChatServiceTests.writePolicyConfirmHaltsLoop`
- `ToolTests.addTransactionViaTool`
- `ToolTests.listTransactionsFilters`
- `ToolTests.summaryTotals`
- `ToolTests.createCategoryDuplicateFails`
- `ToolTests.deleteTransaction`

All seven crashing tests share: `async @Test` + `Tool.run` + SwiftData
write.

Production behavior is unaffected. The app itself runs on the same Swift 6.2
toolchain without issue because the app target *does* have
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.

### References

- Default Actor Isolation in Swift 6.2 — SwiftLee
  https://www.avanderlee.com/concurrency/default-actor-isolation-in-swift-6-2/
- Test target not inheriting default actor isolation — Stack Overflow
  https://stackoverflow.com/q/79681292
- `nonisolated(nonsending)` — caller-isolation semantics for async funcs
  https://www.massicotte.org/default-isolation-swift-6_2/
- XCTestCase compiler errors with Swift 6.2 default actor isolation
  https://forums.swift.org/t/xctestcase-compiler-error-with-swift-6-2-default-actor-isolation/82876
