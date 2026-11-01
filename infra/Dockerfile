FROM python:3.12-slim

WORKDIR /app

COPY pyproject.toml README.md ./
COPY server ./server
COPY shared ./shared

RUN pip install --no-cache-dir .

ENV MD_HOST=0.0.0.0
ENV MD_PORT=8741
ENV MD_DATABASE_PATH=/data/market.db

EXPOSE 8741

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8741"]
