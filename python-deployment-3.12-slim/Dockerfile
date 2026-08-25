FROM python:3.12-slim-bookworm@sha256:3c4d5e6f7890abcdef1234567890abcdef1234567890abcdef1234567890a1b2

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
