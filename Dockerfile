# Build stage
FROM hexpm/elixir:1.17.3-erlang-27.1.2-debian-bookworm-20241016-slim AS builder

# Install build dependencies
RUN apt-get update -y && apt-get install -y \
    build-essential \
    git \
    nodejs \
    npm \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set work directory
WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set build ENV
ENV MIX_ENV=prod

# Install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
RUN mkdir config

# Copy compile-time config files before compiling dependencies
COPY config/config.exs config/prod.exs config/runtime.exs config/
RUN mix deps.compile

# Copy source code (needed for Tailwind to scan for classes)
COPY lib lib
COPY priv priv
COPY assets assets

# Compile the project first
RUN mix compile

# Now compile assets (Tailwind can now scan lib/ for classes)
RUN mix assets.deploy

# Copy remaining files
COPY . .

# Build release
RUN mix release

# Verify static assets were generated
RUN ls -la /app/priv/static/assets/

# Runtime stage
FROM debian:bookworm-20241016-slim AS runtime

# Install runtime dependencies
RUN apt-get update -y && apt-get install -y \
    libstdc++6 \
    openssl \
    libncurses5 \
    locales \
    ca-certificates \
    postgresql-client \
    libreoffice \
    libreoffice-writer \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Create app user
RUN useradd -m -u 1000 -s /bin/bash app

# Set work directory
WORKDIR /app

# Copy release from builder
COPY --from=builder --chown=app:app /app/_build/prod/rel/pdf_converter ./

# Copy static assets from builder (this is critical for CSS/JS)
COPY --from=builder --chown=app:app /app/priv/static ./priv/static

# Copy entrypoint script
COPY --chown=app:app entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Create necessary directories
RUN mkdir -p /app/priv/static/uploads /app/priv/static/converted && \
    chown -R app:app /app

# Switch to app user
USER app

# Expose port
EXPOSE 4000

# Set environment variables
ENV MIX_ENV=prod
ENV PHX_SERVER=true

# Start the application with entrypoint
ENTRYPOINT ["/app/entrypoint.sh"]
