# Ollama + Heretic-friendly base for spicy_llm GCP test
# Image: us-central1-docker.pkg.dev/worldarchitecture-ai/cloud-run-source-deploy/spicy-llm-ollama:gpu-l4
#
# Why this base:
# - nvidia/cuda:12.4.0-base-ubuntu22.04: small (~170MB), has the CUDA userspace
#   libraries that Cloud Run's L4 GPU needs. Base does NOT include the driver
#   (Cloud Run's runtime injects that).

FROM nvidia/cuda:12.4.0-base-ubuntu22.04

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# cache-bust: v4 (zstd fix + direct tar.zst binary install)
# Install runtime deps: curl (for healthcheck), ca-certs, zstd (needed to extract ollama .tar.zst)
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl ca-certificates gnupg zstd \
    && rm -rf /var/lib/apt/lists/*

# Install Ollama Linux — download .tar.zst directly (avoids install.sh issues with sudo/zstd)
# Latest stable v0.30.5 supports gpt-oss:20b (>=0.6.x required)
ARG OLLAMA_VERSION=0.30.5
RUN curl -fsSL "https://github.com/ollama/ollama/releases/download/v${OLLAMA_VERSION}/ollama-linux-amd64.tar.zst" \
      -o /tmp/ollama.tar.zst \
    && zstd -d /tmp/ollama.tar.zst -o /tmp/ollama.tar \
    && tar -C /usr/local -xf /tmp/ollama.tar \
    && rm /tmp/ollama.tar.zst /tmp/ollama.tar \
    && ollama --version

# Environment for Cloud Run:
# - OLLAMA_HOST: listen on 0.0.0.0:11434 (Cloud Run expects $PORT)
# - OLLAMA_KEEP_ALIVE: keep models loaded (default 5m, we want 24h for the test)
# - OLLAMA_MODELS: store model blobs in /tmp/ollama (writable in Cloud Run)
# - OLLAMA_NUM_PARALLEL: limit to 1 to avoid dual-load OOM surprise
ENV OLLAMA_HOST=0.0.0.0:11434 \
    OLLAMA_KEEP_ALIVE=24h \
    OLLAMA_MODELS=/tmp/ollama \
    OLLAMA_NUM_PARALLEL=1 \
    PORT=11434

# Add a non-root user to match Cloud Run's default security context
RUN useradd -m -u 1000 -s /bin/bash ollama || true
RUN mkdir -p /tmp/ollama && chown -R ollama:ollama /tmp/ollama
USER ollama
WORKDIR /home/ollama

# Startup script:
# 1. Start `ollama serve` in background
# 2. Wait for it to be healthy
# 3. Pull both models (idempotent — skips if already present in /tmp/ollama)
# 4. Tail the ollama logs to keep the container alive
COPY --chown=ollama:ollama entrypoint.sh /home/ollama/entrypoint.sh
RUN chmod +x /home/ollama/entrypoint.sh

CMD ["/home/ollama/entrypoint.sh"]
