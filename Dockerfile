# Multi-stage build producing a self-contained OTP release.
# Requires a reachable Postgres at runtime (set DATABASE_URL). Provide BOT_TOKEN
# and DISCORD_GUILD_ID to run the Discord adapter, or DISCORD_ENABLED=false to
# run headless.
ARG ELIXIR_VERSION=1.19.5
ARG ERLANG_VERSION=28.5.0.1
ARG DEBIAN_VERSION=bookworm-20260518-slim
ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${ERLANG_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:bookworm-slim"

FROM ${BUILDER_IMAGE} AS builder

RUN apt-get update -y && apt-get install -y build-essential git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV=prod

COPY mix.exs mix.lock ./
COPY apps/masaryk_ex/mix.exs apps/masaryk_ex/
COPY apps/masaryk_ex_web/mix.exs apps/masaryk_ex_web/
RUN mix deps.get --only prod
RUN mix deps.compile

COPY config config
COPY apps apps

RUN mix compile
RUN mix release

FROM ${RUNNER_IMAGE}

RUN apt-get update -y \
    && apt-get install -y libstdc++6 openssl libncurses6 ca-certificates \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=C.UTF-8

WORKDIR /app
COPY --from=builder /app/_build/prod/rel/masaryk_ex ./

CMD ["/app/bin/masaryk_ex", "start"]
