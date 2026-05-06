# Service A Dockerfile
FROM python:3.11-slim

WORKDIR /app

# Copy dependencies first for better layer caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy rest of the code
COPY . .

# Don't hardcode secrets — pass via environment variables at runtime
EXPOSE 5000

# Run as non-root user for security
RUN useradd -m appuser
USER appuser

# Use gunicorn for production instead of python app.py
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "app:app"]
