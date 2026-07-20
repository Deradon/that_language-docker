# syntax=docker/dockerfile:1

# ruby:4.0-slim, not -alpine. Alpine saves ~84 MB of base but is musl, so puma
# and nio4r rebuild their C extensions against a different libc -- a poor trade
# against a wordlist payload that starts at 16 MB and goes up from there.
ARG RUBY_VERSION=4.0

FROM ruby:${RUBY_VERSION}-slim AS builder

# build-essential only. git was needed while the Gemfile carried git sources;
# every gem now resolves from rubygems.
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends build-essential && \
    rm -rf /var/lib/apt/lists/*

ENV BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT=development:test \
    BUNDLE_FROZEN=true \
    BUNDLE_JOBS=4

WORKDIR /app

# Above the COPY of application files on purpose, so editing config.ru does not
# invalidate the bundle.
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf "${BUNDLE_PATH}/cache"


FROM ruby:${RUBY_VERSION}-slim AS runtime

# Which wordlist tier the image ships.
#
#   gem-10k  the 10k/72-language set bundled inside the that_language gem.
#            The default: nothing to fetch, no extra plumbing, 16 MB.
#   <name>   any directory placed at wordlists/<name> in the build context,
#            e.g. wordlists/100000. Those tiers live in a separate, private
#            repository and are not part of this one -- see the README.
ARG WORDLIST_TIER=gem-10k

# APP_ENV=production is load-bearing, not cosmetic. Sinatra 4 added
# Rack::Protection::HostAuthorization, whose development allow-list is
# localhost-only; in development this container answers 403 Host not permitted
# to every request arriving through a proxy or a domain name. The production
# environment applies no allow-list.
ENV BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT=development:test \
    BUNDLE_FROZEN=true \
    APP_ENV=production \
    RACK_ENV=production \
    PORT=4567 \
    THAT_LANGUAGE_WORDLIST_TIER=${WORDLIST_TIER}

COPY --from=builder /usr/local/bundle /usr/local/bundle

WORKDIR /app

# wordlists/ always exists in the build context (it carries a .keep), so this
# COPY is valid whether or not a tier was dropped into it.
COPY wordlists/ /app/wordlists/
COPY Gemfile Gemfile.lock config.ru ./

# Fail the build, not the boot, on a tier that is not actually there -- and drop
# the tiers that were not selected so they do not ride along in the image.
RUN if [ "${WORDLIST_TIER}" = "gem-10k" ]; then \
      rm -rf /app/wordlists; \
    elif [ -d "/app/wordlists/${WORDLIST_TIER}" ]; then \
      find /app/wordlists -mindepth 1 -maxdepth 1 ! -name "${WORDLIST_TIER}" -exec rm -rf {} +; \
    else \
      echo "WORDLIST_TIER=${WORDLIST_TIER} but wordlists/${WORDLIST_TIER} is not in the build context" >&2; \
      exit 1; \
    fi

RUN useradd --create-home --shell /usr/sbin/nologin app && chown -R app:app /app
USER app

EXPOSE 4567

CMD ["sh", "-c", "exec bundle exec puma --bind tcp://0.0.0.0:${PORT} config.ru"]
