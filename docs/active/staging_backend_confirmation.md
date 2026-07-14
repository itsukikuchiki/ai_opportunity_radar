# 后端迁移与 Railway Staging 确认

状态：**已确认**
确认日期：2026-07-14（Asia/Tokyo）

## 环境

| 项目 | 已确认值 |
| --- | --- |
| Railway project | `ai_opportunity_radar` (`115c20f0-de57-4fc7-9733-48e1d48e498d`) |
| Environment | `staging` (`948c515c-1c52-4bdb-a73c-1642664295c7`) |
| API service | `ai_opportunity_radar` (`c1f399e8-69a7-429a-9cff-d645907e56dd`) |
| PostgreSQL service | `Postgres` (`44d5e2c3-cccb-48af-833e-03353735d9f8`) |
| API URL | `https://aiopportunityradar-staging.up.railway.app` |
| 最终成功部署 | `ae69286e-a1d5-49dc-b3ad-715e0766a596` |

staging 使用独立的 Railway PostgreSQL；API 的 `DATABASE_URL` 只在
`staging` 指向该数据库。没有修改 production 的变量、数据库或部署。

## 迁移结论

- Alembic 是唯一可执行的 schema 迁移来源。
- `backend/migrations/006–019` 只作为不可变的旧库测试 fixture 保留，部署时不得执行。
- 应用启动时不再调用 `Base.metadata.create_all()`；旧库补列、索引和约束只由 Alembic 负责。
- 当前唯一 head 为 `0008_postgres_canonical`。
- `0007_schema_reconcile` 负责收编 Alembic + SQL 混合旧库；`0008_postgres_canonical`
  负责把 PostgreSQL 物理 schema 收敛为精确合约：`JSONB`、无界 `TEXT`、
  命名约束、`DESC` 索引以及 Signal `client_id` partial unique index。
- `0003–0008` 收编链只允许向前升级；回滚使用已验证的数据库备份和兼容代码，
  不执行可能误删旧 SQL 对象的 downgrade。

## 真实旧 PostgreSQL 契约

测试会在唯一命名的临时 PostgreSQL schema 中执行，并在 `finally` 中
`DROP SCHEMA ... CASCADE`。两条路径均在最终 staging 容器内通过：

1. Alembic `0002` → 原样执行 SQL `006–019` → Alembic current head。
2. 已部署的 `0007_schema_reconcile` → `0008_postgres_canonical`。

两条路径都验证：

- revision 到达 head；
- 旧 capture、memory、weekly、SignalCard、observation、candidate 和 telemetry 数据保留；
- usage 重复计数正确合并；
- sensitive 与 tombstone Signal 的 processing/policy 回填正确；
- 与 ORM metadata 严格 `compare_metadata == []`，不过滤 JSON/JSONB、TEXT/VARCHAR、
  索引排序或 partial 条件差异。

本地 SQLite 契约另覆盖 fresh、`0002`、`0006`、raw `006` 和 raw `006–019`
混合库，用于快速回归；它不再被当作 PostgreSQL 物理 schema 的替代证据。

## Railway 部署安全门

`backend/railway.toml` 已配置：

```toml
[deploy]
preDeployCommand = ["python -m alembic -c alembic.ini upgrade head"]
healthcheckPath = "/health"
healthcheckTimeout = 300
```

- 迁移失败会阻止新版本进入服务阶段。
- Railway 环境缺少持久化 `DATABASE_URL`，或误配为 SQLite 时，应用会 fail fast。
- `/health` 会实际执行 `SELECT 1`；数据库不可用时返回脱敏的 `503`，
  而不是虚假的应用存活。
- Railway 给出的无 driver `postgres://` / `postgresql://` 会规范化为
  `postgresql+psycopg://`。Alembic 也正确处理 URL 中 percent-encoded 查询参数。

Railway 行为参考：

- <https://docs.railway.com/deployments/pre-deploy-command>
- <https://docs.railway.com/config-as-code/reference>

## 最终 Staging PostgreSQL 实测

最终部署 `ae69286e-a1d5-49dc-b3ad-715e0766a596` 的 pre-deploy 日志确认：

```text
Running upgrade 0007_schema_reconcile -> 0008_postgres_canonical
```

在正在运行的 staging 容器中执行：

```text
python -m alembic -c alembic.ini current
0008_postgres_canonical (head)

python -m alembic -c alembic.ini check
No new upgrade operations detected.

POSTGRES_MIGRATION_TEST_USE_DATABASE_URL=true \
  python -m pytest tests/test_postgres_alembic_schema_contract.py -q
2 passed in 6.93s
```

## HTTP Smoke

可重复脚本：

```text
python scripts/staging_backend_smoke.py \
  --base-url https://aiopportunityradar-staging.up.railway.app
```

最终部署后执行 20 个真实 HTTP 检查，全部通过：

1. `/health` 同时确认 API 版本与数据库 readiness。
2. 创建一次性测试账户，并绑定唯一的本地 user。
3. 文字、语音、状态三种 capture 均得到 acknowledgement 并生成 SignalCard。
4. 相同 `client_id` 重放返回同一 SignalCard，没有重复记录。
5. recent 列表准确返回 3 条。
6. SignalCard 的确认和用户修正文案持久化。
7. 软删除生成 tombstone，并从 recent 排除。
8. restore 清除删除状态。
9. 3 条同日信号生成 `light_ready` Weekly，周期为用户本地时间的周一至周日。
10. 正式 `/api/v1/ai/reflect-weekly` 响应契约完整。
11. 兼容 `/api/v1/ai/deep-weekly` 正常响应并走 legacy telemetry。
12. usage summary 返回 free entitlement 和 quota 数组。
13. `finally` 中调用账户删除接口，确认临时账户与用户数据已清理。

临时 session 不输出；失败路径同样会尝试账户清理。
最终部署及 smoke 时段的 Railway HTTP 日志中无 `5xx`。

## 自动测试证据

```text
本地后端全量：83 passed, 2 skipped, 44 warnings
最终 staging PostgreSQL 迁移契约：2 passed
python compileall：passed
git diff --check：passed
CI test manifest：covers every Flutter and backend test file
Alembic heads：0008_postgres_canonical (head)
```

本地跳过的 2 项就是需要显式 PostgreSQL URL 的真实迁移契约；它们已在
staging PostgreSQL 和 CI PostgreSQL 16 service 中设为必跑。

44 条 warning 均为既有 `datetime.utcnow()` deprecation，不影响本次迁移或 smoke
结果，但应在后续维护中改为 timezone-aware UTC。

## 本次发现并修复的问题

1. Railway 提供的默认 PostgreSQL URL 未指定 psycopg driver。
2. SignalCard 与 processing state / analysis policy 的 PostgreSQL 外键插入顺序不稳定。
3. 仅用 SQLite 比较会掩盖 JSONB、TEXT、`DESC` 与 partial index 差异。
4. 已部署的 `0007` 需要新的 forward-only `0008` 来收敛物理 schema。
5. Alembic URL 中的 percent-encoded 参数会触发 configparser 插值错误。
6. 过长 revision ID 会超出 Alembic `version_num VARCHAR(32)`；现已有长度门禁。
7. recent 读取路径会覆写已存在的 processing/policy 状态；现只补建缺失行。
8. `0007` 旧数据回填需正确区分 sensitive、不参与分析和 tombstone Signal。
9. `/health` 原先不证明数据库可用，Railway 缺少持久化 DB 时也不会 fail fast。

## Production 不变确认

操作前后 production 的部署基线一致：

- 最新记录 `2cc3cfda-9c47-4efe-8529-77a5bfb23290`：`FAILED`（2026-06-04）。
- 正在运行 `12f99aeb-49cb-42d9-901a-edff717a202d`：`SUCCESS`（2026-06-03）。

本次没有对 production 执行部署、迁移、变量修改或数据库创建。
