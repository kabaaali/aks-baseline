# BAD DOCKERFILE
# 1. Uses a heavy base image
FROM python:3.9

# 2. Runs as root (default)
# 3. Copies everything (including secrets if they were here)
COPY . /app
WORKDIR /app

# 4. Installs dependencies at runtime (slow, non-deterministic)
RUN pip install flask

# 5. No entrypoint, just cmd
CMD ["python", "app.py"]
