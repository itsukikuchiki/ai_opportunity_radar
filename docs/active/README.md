# SignalPath Current Documentation

Last updated: 2026-07-14

`app_design.md` is the sole final product/page design. `data_flow.md` is the canonical data contract. Other files in this directory are scoped technical, UI, privacy, purchase, QA, or operations contracts; none creates a second product design.

## Start Here

1. [Final app design](app_design.md)
2. [Canonical data flow](data_flow.md)
3. [Main-tab UI standard](main_tab_ui_standard.md)

## Technical Contracts

- [AI orchestration and level boundaries](ai_orchestration.md)
- [Feedback event read model](feedback_event.md)
- [Trace and evidence](trace_evidence.md)
- [Sync, privacy, and delete](sync_privacy_delete.md)
- [Pro purchase and entitlement](purchase_entitlement.md)
- [iOS native schemes and privacy configuration](ios_native_privacy_configuration.md)

## Delivery And Operations

- [CI gates](ci_gates.md)
- [Device build matrix](device_build_matrix.md)
- [Device diagnostics](device_diagnostics.md)
- [Device test accounts](device_test_accounts.md)
- [Device-test dependency closeout](device_test_dependency_closeout.md)
- [Preflight, privacy, performance, and rollback](preflight_privacy_network_performance_rollback.md)
- [Staging backend confirmation](staging_backend_confirmation.md)

## Conflict Rule

Use this order when text disagrees:

1. the latest explicitly confirmed user decision;
2. `app_design.md`;
3. `data_flow.md` and the relevant scoped technical contract;
4. current automated/TestFlight QA for observed implementation status;
5. retained historical Phase/ReleaseQA evidence for context only.

Target behavior remains Target until implementation and proportional verification exist. A historical Passed result cannot override a later reopened real-device issue.
