# Production image for the Oshudh Reminder API.
#   docker build -t oshudh-api -f backend/Dockerfile .
#   docker run -p 8000:8000 --env-file backend/.env oshudh-api
FROM python:3.12-slim AS base

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy
COPY --from=ghcr.io/astral-sh/uv:0.11 /uv /usr/local/bin/uv

WORKDIR /srv/backend
COPY backend/pyproject.toml backend/uv.lock backend/.python-version ./
RUN uv sync --locked --no-dev --no-install-project

COPY backend/app ./app
COPY database/seed /srv/database/seed

# Run as an unprivileged user
RUN useradd --system --uid 10001 api && chown -R api /srv
USER api

ENV ENVIRONMENT=production DRUGS_CSV_PATH=/srv/database/seed/drugs_seed.csv
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=3s CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health')"
CMD ["/srv/backend/.venv/bin/uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--proxy-headers", "--forwarded-allow-ips=*"]
