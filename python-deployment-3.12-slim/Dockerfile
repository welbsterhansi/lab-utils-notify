FROM python:3.12-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

COPY requirements.txt .
RUN pip install --require-hashes -r requirements.txt || pip install -r requirements.txt

COPY . .

RUN useradd --uid 1001 --create-home appuser
USER 1001

CMD ["python", "-m", "app"]
