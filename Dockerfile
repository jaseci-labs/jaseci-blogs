FROM python:3.12-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy documentation files
COPY docs/ ./docs/
COPY scripts/ ./scripts/
COPY setup.py .
COPY jac_syntax_highlighter.py .
COPY mkdocs.yml .
COPY README.md .

# Install Python dependencies
RUN pip install --no-cache-dir -e .

# Expose port 8000
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=3s CMD curl -f http://localhost:8000/health || exit 1

# Start the custom mkdocs server
CMD ["python", "scripts/mkdocs_serve.py"]
