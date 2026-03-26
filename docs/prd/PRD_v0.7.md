# PRD v0.7 / 首版可运行实现包

本版补齐：

- FastAPI 真实 DB session 与 SQLAlchemy ORM 持久化路径
- Alembic 初始化文件与首版 migration
- Weekly feedback API
- Flutter repository / provider 注入整理
- 本地 demo 流程说明

## 本地运行建议

### Backend

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
alembic upgrade head
uvicorn app.main:app --reload
```

默认数据库：

- `sqlite:///./ai_radar.db`

### Flutter

```bash
cd frontend_flutter
flutter pub get
flutter run -d chrome
```

若 Flutter Web 连接本地 FastAPI，请确认 `ApiClient` 的 `baseUrl` 指向：

- `http://localhost:8000`

## Demo 路径

1. 打开 Onboarding，选择一个重复场景并开始
2. 在 Today 输入：`今天又在整理一样的资料`
3. 系统会创建 raw memory / pattern / friction / opportunity，并可能给出 follow-up
4. 进入 Weekly 查看本周洞察
5. 进入 Opportunity Detail 提交 `想试试`
6. 系统会把该 opportunity 标记为 `testing` 并创建 experiment
