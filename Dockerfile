FROM ruby:3.3-slim

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends build-essential libsqlite3-dev curl && \
    rm -rf /var/lib/apt/lists/*

# Non-root user
RUN groupadd -r dol && useradd -r -g dol -m dol

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle config set --local without 'development test' && \
    bundle install --jobs 4

COPY . .

# Data persistence: XLSX cache + SQLite databases
RUN mkdir -p /data && chown dol:dol /data
VOLUME /data
ENV DOL_LOOKUP_CACHE_DIR=/data

USER dol

EXPOSE 9292

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s \
  CMD curl -f http://localhost:9292/ || exit 1

CMD ["bundle", "exec", "puma", "-b", "tcp://0.0.0.0:9292", "-e", "production"]
