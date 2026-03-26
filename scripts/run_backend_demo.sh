#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../backend"
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
alembic upgrade head
uvicorn app.main:app --reload
