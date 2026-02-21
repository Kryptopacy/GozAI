FROM python:3.12-slim

WORKDIR /app

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
