[![CI](https://github.com/Deradon/that_language-docker/actions/workflows/ci.yml/badge.svg)](https://github.com/Deradon/that_language-docker/actions/workflows/ci.yml)

# that_language-docker

Container packaging for [`that_language-service`][service] — the HTTP API in
front of the [`that_language`][core] language-detection library.

The image runs Ruby 4.0 on `puma`, warms the wordlist cache before it accepts
its first request, and takes the wordlist tier as a build argument.

[service]: https://github.com/Deradon/that_language-service
[core]: https://github.com/Deradon/that_language

## Build and run

```sh
docker build -t that_language-service .
docker run --rm -p 4567:4567 that_language-service
```

Then:

```sh
curl 'localhost:4567/language?text=Guten+Tag+mein+Freund'
# {"language":"German"}
```

Every endpoint answers over both GET and POST, and takes a single `text`
parameter (except `/available*` and `/version`, which take none):

`/language` · `/language_code` · `/detect` · `/details` · `/available` ·
`/available_languages` · `/available_language_codes` · `/version`

## Wordlist tiers

`WORDLIST_TIER` decides which set of wordlists is baked into the image. It is
the one build input that materially changes the result — image size, memory
footprint and the number of languages recognised all follow from it.

```sh
docker build --build-arg WORDLIST_TIER=100000 -t that_language-service:100k .
```

| `WORDLIST_TIER` | Source | Languages | Image size | Resident memory |
|---|---|---|---|---|
| `gem-10k` *(default)* | ships inside the `that_language` gem | 72 | 199 MB | ~130 MB |
| `10000` | separate wordlist repository | 308 | 629 MB | — |
| `100000` | separate wordlist repository | 308 | 897 MB | ~1.8 GB |

The default needs nothing extra: the 10k set is part of the gem, so the image
builds from a clean checkout with no other inputs.

Any other value names a directory you place at `wordlists/<tier>` in the build
context before building. Those tiers live in a separate repository and are not
part of this one; `wordlists/` is gitignored apart from its `.keep`. A tier that
is not present fails the build rather than the boot.

Two things to know before reaching for a larger tier. The memory jump is steep —
the 100000 set costs roughly fourteen times the default's resident footprint, all
of it held for the process's lifetime. And the loader treats *every* file in the
tier directory as a language with no extension filter, so a stray file becomes a
phantom language; the 72-file set shipped in the gem is clean, the wider archive
has not been audited.

## Configuration

| Variable | Default | Notes |
|---|---|---|
| `PORT` | `4567` | Puma's bind port. |
| `APP_ENV` / `RACK_ENV` | `production` | Leave these alone — see below. |
| `THAT_LANGUAGE_WORDLIST_TIER` | set from `WORDLIST_TIER` | Baked in at build time. |

**Do not run this image with `APP_ENV=development`.** Sinatra 4 added
`Rack::Protection::HostAuthorization`, whose development allow-list is
localhost-only. Behind a proxy or a domain name, a development container answers
`403 Host not permitted` to every request. The production environment applies no
allow-list, which is why the image pins it.

CORS is enabled for all origins in `config.ru`. The API is public,
unauthenticated and read-only, and browsers on other origins are the intended
callers.

## The git-source caveat

The `Gemfile` pulls both `that_language` and `that_language-service` from git
rather than from rubygems.org, and both lines are required.

A Gemfile is not transitive. If only the service were declared, Bundler would
resolve its dependency on `that_language` from the service's *gemspec*
(`that_language ~> 0.1`) and land on the published 0.1.2 — which predates the
Ruby 3+ fixes and raises on `File.exists?` the first time a wordlist is loaded.
The image would build cleanly and fail on the first request.

Both published gems are therefore too old to use here: `that_language` 0.1.2
does not run on Ruby 3 or later, and `that_language-service` 0.1.3 is the
Sinatra 1.4 / Rack 1 stack, which cannot even load on Ruby 4.0. Once
`that_language` 0.1.3 is released, the first git line can go.

Git sources do not make the build float. `Gemfile.lock` records a revision for
each, and the image sets `BUNDLE_FROZEN=true`, so a build installs those exact
commits and a push to either upstream repository does not change what this image
contains. Moving to newer upstream code means regenerating the lock, which is a
commit here — the trade is reproducibility for having to bump deliberately, and
nothing warns you when upstream has moved ahead.

## Layout

- `Dockerfile` — multi-stage; the build toolchain stays in the builder stage.
- `Gemfile` / `Gemfile.lock` — both git sources plus `puma`. The service gem
  declares no web server on purpose, so the deployment picks one.
- `config.ru` — tier selection, CORS, and the cache warm-up before `run`.
- `wordlists/` — empty; where you stage a non-default tier.
