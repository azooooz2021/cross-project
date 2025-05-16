FROM python:3.9-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
RUN python3 -m pip install --upgrade pip wheel setuptools && \
    python3 -m pip install --upgrade acryl-datahub

# Set environment variables
ENV PYTHONUNBUFFERED=1

# Create a non-root user to run the application
RUN useradd -m datahub
USER datahub

# Set the entrypoint
ENTRYPOINT ["datahub"]
CMD ["docker", "quickstart"]
