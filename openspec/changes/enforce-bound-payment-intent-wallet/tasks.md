## Implementation Tasks
- [x] 1. Add a regression for canonical holder A with legacy payer absent and an authorization payer B; require `POINT_AUTHORIZATION_HOLDER_MISMATCH` before HTTP. (verification: test added; local Dart 3.7.2 VM currently crashes before test execution on macOS x64)

- [x] 2. Remove `connectedWalletAddress` from `authorizePoints`, `applyPoints`, and `provePayment` and update all SDK call sites and examples.

- [x] 3. Validate `applyPoints` authorization payer against canonical `points.authorization.holder_address`, with legacy `payer.address` fallback.

- [x] 4. Remove connected-wallet and duplicate terminal-status guards; retain backend action URLs and verified chain sender as authoritative boundaries.

- [x] 5. Update README, payload-format documentation, and OpenSpec to describe signed holder consistency and backend sender verification.

- [x] 6. Run focused/full Dart tests, analysis, scoped format checks, `git diff --check`, and strict OpenSpec validation; record exact results. (verification: 55 tests passed; `dart analyze`, scoped `dart format --output=none --set-exit-if-changed`, strict OpenSpec validation, and diff check passed outside the sandbox.)

- [x] 7. Align README, payload documentation, and OpenSpec with viewer-specific `points.account` while preserving the bound `points.authorization` and legacy `payer`; no SDK production contract change. (verification: 55 tests passed; `dart analyze`, strict OpenSpec validation, and `git diff --check` passed.)
