FROM python:3.13-slim-bookworm@sha256:9f0e8d7c6b5a4938271605948372615049382716059483726150493827160594

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
