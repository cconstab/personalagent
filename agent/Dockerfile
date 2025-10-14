FROM dart:stable AS build

WORKDIR /app

# Copy pubspec files
COPY pubspec.yaml pubspec.lock ./

# Get dependencies
RUN dart pub get

# Copy source code
COPY . .

# Compile to executable
RUN dart compile exe bin/agent.dart -o bin/agent

# Runtime stage
FROM debian:bullseye-slim

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y ca-certificates curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy compiled binary
COPY --from=build /app/bin/agent /app/bin/agent

# Create directories
RUN mkdir -p /app/keys /app/storage/hive /app/storage/commit

# Run as non-root user
RUN useradd -m -u 1000 agent && \
    chown -R agent:agent /app

USER agent

CMD ["/app/bin/agent"]
