FROM python:3.11-slim

# Non-root user
RUN groupadd --system app && useradd --system --gid app --home /home/app app \
    && mkdir -p /app /home/app/transcripts \
    && chown -R app:app /home/app

WORKDIR /app

# Install deps as root, then drop privileges
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY advisor.py /app/advisor.py
RUN chown -R app:app /app

USER app
ENV HOME=/home/app \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Transcripts live on a writable volume; everything else is read-only at runtime.
VOLUME ["/home/app/transcripts"]

ENTRYPOINT ["python", "-I", "/app/advisor.py", "--out-dir", "/home/app/transcripts"]
CMD ["--minutes", "20", "--rounds-min", "12", "--delay", "4"]
