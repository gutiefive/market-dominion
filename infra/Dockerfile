FROM python:3.12-slim

WORKDIR /app

RUN useradd --uid 10001 --no-create-home --shell /usr/sbin/nologin market \
    && mkdir -p /data \
    && chown 10001:10001 /data

COPY pyproject.toml README.md ./
COPY server ./server
COPY shared ./shared
COPY infra/entrypoint.py /entrypoint.py

RUN --mount=type=secret,id=proxy_ca \
    chmod -R a+rX /app/shared \
    && if [ -f /run/secrets/proxy_ca ]; then export PIP_CERT=/run/secrets/proxy_ca; fi \
    && pip install --no-cache-dir .

ENV MD_HOST=0.0.0.0 \
    MD_PORT=8741 \
    MD_DATABASE_PATH=/data/market.db \
    MD_REPO_ROOT=/app \
    MD_LOG_LEVEL=info \
    MD_ENV=container \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

EXPOSE 8741

HEALTHCHECK --interval=10s --timeout=3s --retries=3 --start-period=8s \
    CMD python -c "import os,urllib.request; urllib.request.urlopen('http://127.0.0.1:%s/ready' % os.environ.get('MD_PORT','8741'))"

ENTRYPOINT ["python", "/entrypoint.py"]
