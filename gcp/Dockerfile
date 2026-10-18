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

# cache-bust: v8 (Option B: baked blobs; Ollama 0.40.5 for gpt-oss tool calls - CANARY-TEST sm_89)
# Install runtime deps: curl for healthcheck/downloads, ca-certs, and gzip for the Ollama release tgz.
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl ca-certificates gnupg gzip zstd \
    && rm -rf /var/lib/apt/lists/*

# Install Ollama Linux.
#
# VERSION HISTORY / RISK, read before changing this number.
#   The pin was originally 0.12.3 because LATER CUDA runners reproduced
#   "device kernel image is invalid" on L4 / sm_89 with gpt-oss. That is a real
#   regression risk and the reason this is not a casual bump.
#   0.12.3 was nevertheless far too old for this product: its harmony tool-call parser
#   could not handle gpt-oss tool calls, so EVERY tool call failed with HTTP 500
#   'error parsing tool call: raw=...<|call|>commentary to=functions.spicy_search
#   <|constrain|>json...'. Both the tuned alias AND the base model failed identically,
#   which ruled out the Modelfile and pointed at the runtime. Plain chat worked fine on
#   0.12.3, which is why the deficiency stayed hidden until a tool was actually called.
#
#   0.40.5 is the current release. It MUST be validated on a --no-traffic canary for BOTH
#   (a) a plain generation and (b) a real tool call, because the sm_89 risk above means an
#   upgrade can plausibly fix tool calling by breaking GPU inference. Do not promote a
#   build of this without checking both.
#
#   Asset naming changed between these versions: newer releases publish
#   ollama-linux-amd64.tar.zst (zstd), not ollama-linux-amd64.tgz. Hence the `zstd`
#   package above and the --zstd extraction below.
ARG OLLAMA_VERSION=0.40.5
RUN curl -fsSL "https://github.com/ollama/ollama/releases/download/v${OLLAMA_VERSION}/ollama-linux-amd64.tar.zst" \
      -o /tmp/ollama.tar.zst \
    && tar -C /usr/local --zstd -xf /tmp/ollama.tar.zst \
    && rm /tmp/ollama.tar.zst \
    && ollama --version

# Environment for Cloud Run:
# - OLLAMA_HOST: listen on 0.0.0.0:11434 (Cloud Run expects $PORT)
# - OLLAMA_KEEP_ALIVE: keep models loaded (default 5m, we want 24h for the test)
# - OLLAMA_MODELS: /models, BAKED INTO THIS IMAGE by the bake step below. It must NOT
#   point at /tmp: Cloud Run's /tmp is memory-backed, so a 15.8 GB store there is
#   wiped on every instance restart (forcing a fresh 15.8 GB pull) and eats half of
#   the 32 GiB memory limit.
# - OLLAMA_NUM_PARALLEL: limit to 1 to avoid dual-load OOM surprise
ENV OLLAMA_HOST=0.0.0.0:11434 \
    OLLAMA_KEEP_ALIVE=24h \
    OLLAMA_MODELS=/models \
    OLLAMA_NUM_PARALLEL=1 \
    OLLAMA_DEBUG=2 \
    PORT=11434

# Add a non-root user to match Cloud Run's default security context
RUN useradd -m -u 1000 -s /bin/bash ollama || true

# Bake the model blobs into an image layer so that an instance restart no longer
# re-downloads ~19 GB (15.8 GB gpt-oss + ~3.3 GB gemma3:4b for JEV vision). Runs as root,
# then hands /models to the ollama user.
# Values mirror the entrypoint.sh defaults so boot-time `ollama create` is a no-op.
ARG STOCK_MODEL=svjack/gpt-oss-20b-heretic
ARG TUNED_MODEL=spicy-heretic:latest
ARG SPICY_TEMPERATURE=0.7
ARG SPICY_TOP_P=0.9
ARG SPICY_REPEAT_PENALTY=1.18
ARG SPICY_NUM_PREDICT=4096
# Multimodal model for spicy-search's JEV lane. It must advertise the `vision` capability
# in `ollama show` (bake_models.sh fails the build otherwise); a text-only model here would
# leave that lane permanently degraded while appearing configured.
ARG VISION_MODEL=gemma3:4b
COPY --chown=ollama:ollama bake_models.sh /home/ollama/bake_models.sh
RUN chmod +x /home/ollama/bake_models.sh \
    && mkdir -p /models \
    && /home/ollama/bake_models.sh \
    && chown -R ollama:ollama /models

USER ollama
WORKDIR /home/ollama

# Startup script:
# 1. Start `ollama serve` in background
# 2. Wait for it to be healthy
# 3. Pull both models (idempotent — a no-op when the blobs are already in /models)
# 4. Tail the ollama logs to keep the container alive
COPY --chown=ollama:ollama entrypoint.sh /home/ollama/entrypoint.sh
RUN chmod +x /home/ollama/entrypoint.sh

CMD ["/home/ollama/entrypoint.sh"]
