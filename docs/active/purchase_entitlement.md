# Pro Purchase And Entitlement

Last updated: 2026-07-14

Status: **final target contract; manual restore and silent current-entitlement refresh baselines implemented; native transaction lifecycle/server modernization Target; Restore Purchase Platform QA open**.

Purchase and entitlement form an independent control plane. They may control Pro surfaces and quota, but must never block direct recording, hide a user's own facts, or write SignalCard/eligibility/reflection evidence.

## 1. Product Boundary

Free users retain direct recording, the SignalCard timeline, editable AI/Library timeline decisions, adopted action/experiment feedback, and the Free Weekly/Journey fact layer. Pro may unlock This Week Deep Read, Journey L3 evidence and period comparison, follow-up grounded in a selected real SignalCard, structured self-review, L1 Attune short dialogue, and expanded AI quota.

That is the final current Pro product range. Pro does not sell access to the
user's own SignalCards, the Free Weekly/Journey fact layer, raw Health data,
Calendar data, or a response-style switch. The local StoreKit product copy must
use this same boundary and must not advertise the future independent 28-day
interpretive generator as already available.

Entitlement and report readiness are separate:

- Weekly and This Week Deep Read: 3 eligible current-week SignalCards.
- Free Journey monthly synthesis: 7 eligible SignalCards across 3 local dates.
- Journey Pro L3: 14 eligible SignalCards across 7 local dates and 2 local Monday-Sunday weeks in the latest 28 local dates.

A subscription never lowers an evidence threshold.

## 2. Entitlement Sources And Precedence

```text
verified StoreKit current entitlement / transaction update
  -> immediate local Pro unlock or verified revocation
  -> local entitlement cache for launch/offline continuity
  -> asynchronous server reconciliation
  -> App Store Server API / Notifications status convergence
```

Rules:

1. A locally verified matching StoreKit transaction can unlock Pro immediately.
2. Backend unavailability does not revoke that verified access.
3. Network, sync, timeout, or unverified results preserve the last verified local state and show reconciliation status.
4. Only a successful matching-environment StoreKit evaluation with no current entitlement, or a verified expired/refunded/revoked status, may disable cached Pro.
5. Product matching uses only SignalPath Pro product IDs owned by the purchase controller; visible price/currency comes from StoreKit.

## 3. Automatic, Silent Recovery

The normal path must not wait for a Restore button:

```text
app launch / foreground / Pro surface entry
  -> silently read Transaction.currentEntitlements
  -> verify matching Pro transaction
  -> immediately update local cache, all Pro gates, and quota view

target lifecycle
  -> long-lived Transaction.updates listener
  -> receive out-of-app or lifecycle transaction changes
  -> verify and recompute entitlement
  -> refresh gates without requiring manual restore

target server
  -> send signed transaction evidence for asynchronous reconciliation
```

`AppStore.sync()` is not called on launch because it may require App Store authentication. Silent `currentEntitlements` refresh is the implemented quiet lifecycle baseline; the native long-lived `Transaction.updates` listener remains Target.

## 4. Manual Restore

The Restore Purchase button is an explicit forced-sync path:

```text
user taps Restore Purchase
  -> announce "checking with App Store"
  -> call AppStore.sync()
  -> read and verify Transaction.currentEntitlements again
  -> matching Pro found: unlock immediately and refresh every gate/quota reader
  -> no match: show the resolved StoreKit environment and channel explanation
  -> sync/network/unverified failure: keep existing verified access unchanged
```

Manual restore must still query StoreKit when local Pro is already active; it cannot short-circuit on the cache. During migration, a delayed plugin restore stream may be observed for up to 6 seconds, but it is not a replacement for the native transaction-update lifecycle.

## 5. Server Target And Legacy Migration

The target server path is:

1. accept StoreKit 2 signed transaction JWS or a transaction ID, product ID, original transaction ID, and environment;
2. verify the Apple signature or query App Store Server API;
3. resolve active, expired, billing-retry, grace-period, refunded, and revoked states;
4. consume App Store Server Notifications V2 idempotently;
5. recover missed events through notification history and retry safely.

Apple's App Receipt / `verifyReceipt` flow is deprecated and remains compatibility-only. While it exists, the endpoint receives a refreshed App Receipt. A StoreKit 2 transaction JWS must never be disguised as receipt data.

If SignalPath later introduces an explicit login identity, purchases may use `appAccountToken` to associate the transaction with a stable account UUID. That future design must define duplicate-account and transfer rules. Until such an account exists, StoreKit/device entitlement is the unlock source and the app does not promise cross-device restoration of diary content.

## 6. Xcode Schemes, Environment, And Purchase-Channel Isolation

StoreKit selection is explicit in the shared Xcode schemes:

| Xcode scheme | StoreKit configuration | Allowed use |
| --- | --- | --- |
| `Runner` | No local `.storekit` file attached | Normal development, real-device QA against App Store Connect, archive, TestFlight, and release work. The resulting StoreKit environment still depends on the install channel. |
| `Runner-LocalStoreKit` | `SignalPath.storekit` attached to the Debug launch action | Local Xcode StoreKit purchase/restore simulation only. |

`Runner` is the default and the only scheme allowed for a TestFlight archive.
`Runner-LocalStoreKit` must never be used as evidence that TestFlight Sandbox or
App Store Production restore works. The local configuration is an Xcode launch
fixture; it is not a TestFlight purchase source and must not be included as an
app resource.

| Environment/channel | What it can restore |
| --- | --- |
| `Runner-LocalStoreKit` / Xcode StoreKit configuration | Transactions created in that local StoreKit test session. |
| `Runner` launched from Xcode | App Store Connect/Sandbox behavior available to the development install; never local `SignalPath.storekit` transactions. |
| TestFlight | Sandbox IAP transactions for the TestFlight tester environment. |
| App Store Production | Production purchases made through the released App Store app. |
| Web/another billing channel | Must be managed and restored through that channel; StoreKit cannot manufacture an App Store transaction. |

TestFlight builds always use the Sandbox IAP environment. TestFlight subscription renewals are accelerated, so a long production-style annual renewal date is not proof of a TestFlight entitlement. The screenshot for issue 25 shows a SignalPath annual subscription renewing on 2027-05-18 while the tested build is TestFlight; this is a **high-probability environment-mismatch hypothesis, not a confirmed diagnosis**. Validate it by creating a Sandbox/TestFlight subscription for TestFlight QA, and separately test the production subscription in the released App Store build.

The default error must not blame the Apple ID. Apple ID, app login identity, purchase channel, StoreKit environment, and backend reconciliation are distinct diagnostic dimensions.

## 7. User-Facing States

| State | Required Chinese copy direction |
| --- | --- |
| Silent check | `正在确认 Pro 权益…` without blocking the page. |
| Manual restore | `正在向 App Store 检查订阅…` |
| Found | `已找到 SignalPath Pro，Pro 功能已恢复。` |
| Local verified / backend pending | `Pro 已恢复；订阅状态正在同步，不影响使用。` |
| TestFlight no entitlement | `这个 TestFlight 版本只能读取测试环境中的购买，正式 App Store 订阅不会显示在这里。` |
| Production no entitlement | `当前 App Store 环境中没有找到有效的 SignalPath Pro。` |
| Sync unavailable | `暂时无法连接 App Store。现有 Pro 权益没有改变，请稍后再试。` |
| Unverified transaction | `检测到购买信息，但设备暂时无法验证。现有权限没有改变。` |
| User cancelled authentication | `已取消恢复，没有更改现有权限。` |

Every failure state preserves access to core records and offers retry/support. Support diagnostics should capture app version/build, StoreKit environment, product ID, transaction/original transaction IDs when safe, verification stage, and current SignalPath account ID if one exists—never the user's Apple ID password or raw diary content.

## 8. Publicly Observable Industry Patterns

Only public help-center behavior is used here; this section makes no claim about another app's private implementation.

- ChatGPT places Restore purchases under Settings → Account and explicitly separates App Store subscriptions from web subscriptions.
- Headspace asks the user to verify the app account associated with the purchase, then restore from the subscription page and contact support if unresolved.
- Day One checks app User ID, purchase platform, and purchase history, with separate guidance for duplicate accounts/platform purchases.
- Strava exposes Restore Purchases in settings and escalates unresolved cases with receipt plus current/historical account information.

SignalPath should follow the shared pattern: make Restore easy to find, identify the purchase channel/environment, avoid generic Apple-ID blame, and provide a clear support escalation path.

## 9. Current Implementation And Acceptance

### Implemented baseline

- Shared Xcode schemes separate normal StoreKit (`Runner`) from the explicit local fixture (`Runner-LocalStoreKit`).
- Local monthly/yearly product descriptions match the final Pro range in English, Simplified Chinese, Traditional Chinese, and Japanese.
- Manual restore reads StoreKit 2 current entitlements and can invoke explicit sync.
- Silent current-entitlement refresh runs on launch and foreground without invoking account sync.
- A verified local entitlement unlocks before backend reconciliation.
- The verified StoreKit environment is persisted; an empty result can revoke a cached entitlement only when both environments are known and equal.
- Failures preserve existing verified local Pro.
- StoreKit 2 JWS is not uploaded as a legacy App Receipt.
- Environment concepts are separated in diagnostics.

### Partial / Target

- native `Transaction.updates` lifecycle management rather than relying only on the Flutter purchase stream;
- StoreKit 2 signed-JWS/App Store Server API verification;
- App Store Server Notifications V2 and notification-history recovery;
- clearer TestFlight/Production user copy;
- future `appAccountToken` and transfer policy only after a real SignalPath account model exists.

### Release QA

Restore remains open until both matrices are tested independently:

1. Archive with `Runner`, install the TestFlight build, and verify that a Sandbox/TestFlight subscription restores on a physical device and refreshes all Pro gates/quota. `Runner-LocalStoreKit` is not part of this pass.
2. Released App Store build + Production subscription restores on a physical device.

A Production subscription failing to appear in TestFlight does not by itself prove a restore-code defect.

## 10. References

Apple:

- [Transaction.currentEntitlements](https://developer.apple.com/documentation/storekit/transaction/currententitlements)
- [Transaction and transaction updates](https://developer.apple.com/documentation/storekit/transaction)
- [AppStore.sync](https://developer.apple.com/documentation/storekit/appstore/sync%28%29)
- [In-App Purchase](https://developer.apple.com/in-app-purchase/)
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [App Store Server API](https://developer.apple.com/documentation/appstoreserverapi/)
- [App Store Server Notifications](https://developer.apple.com/documentation/AppStoreServerNotifications)
- [App Store Receipts](https://developer.apple.com/documentation/AppStoreReceipts)
- [Testing subscriptions and IAP in TestFlight](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testing-subscriptions-and-in-app-purchases-in-testflight)
- [appAccountToken](https://developer.apple.com/documentation/storekit/product/purchaseoption/appaccounttoken%28_%3A%29)

Public app help centers:

- [ChatGPT Restore Purchases](https://help.openai.com/en/articles/8346573-restoring-a-chatgpt-plus-or-chatgpt-pro-subscription-purchased-in-the-apple-app-store)
- [Headspace subscription restore](https://help.headspace.com/hc/en-us/articles/218912777-I-purchased-a-subscription-but-it-is-not-activated-on-my-account)
- [Day One subscription troubleshooting](https://dayoneapp.com/guides/troubleshooting/premium-subscription-troubleshooting/)
- [Strava subscription not showing](https://support.strava.com/en-us/articles/15401789-strava-subscription-not-showing-on-your-account)
