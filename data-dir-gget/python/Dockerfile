# Use Python 3.11 slim image as base
FROM python:3.11-slim

# Install system dependencies
RUN --mount=type=cache,target=/root/.cache/apt apt-get update \
    && apt-get upgrade -y \
    && apt-get install python3-dev curl -y --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

ENV \
  PYTHONFAULTHANDLER=1 \
  PYTHONUNBUFFERED=1 \
  PYTHONHASHSEED=random \
  PIP_NO_CACHE_DIR=1 \ 
  PIP_DISABLE_PIP_VERSION_CHECK=1 \
  PIP_DEFAULT_TIMEOUT=100

# Install uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.cargo/bin:$PATH"

# Copy project files
COPY pyproject.toml uv.lock ./

# Install dependencies
RUN uv sync --frozen --no-dev

# Copy application code
COPY index.html ./
COPY *.py ./

# Create non-root user
# RUN groupadd -r appuser && useradd -r -g appuser appuser && chown -R appuser:appuser /app
# USER appuser

# Set environment variables
ARG PORT
ENV PORT=${PORT:-8080}
ENV HOST=0.0.0.0

# Expose port
EXPOSE $PORT

COPY docker_run.sh ./docker_run.sh
RUN chmod +x ./docker_run.sh

# Run the application
CMD exec ./docker_run.sh
