FROM python:3.12-slim

WORKDIR /app

# Install Node.js LTS + npx (required for firebase-mcp-server subprocess)
RUN apt-get update && apt-get install -y curl && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install uv for fast dependency resolution
RUN pip install uv

# Copy project files
COPY pyproject.toml .
COPY gozai_agent/ gozai_agent/

# Install dependencies with uv
RUN uv pip install --system .

# Expose port for Cloud Run
ENV PORT=8080
EXPOSE 8080

# Run ADK in API server mode
CMD ["adk", "api_server", "--port", "8080", "gozai_agent"]
