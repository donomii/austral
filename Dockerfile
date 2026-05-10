FROM ocaml/opam:debian-12-ocaml-5.2 AS build

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        libgmp-dev \
        m4 \
        pkg-config \
        python3 \
    && rm -rf /var/lib/apt/lists/*

USER opam
WORKDIR /home/opam/austral
COPY --chown=opam:opam . .
RUN opam update \
    && opam install --deps-only --with-test -y . \
    && eval $(opam env) \
    && make \
    && make test \
    && make -C standard \
    && ./standard/test_bin

FROM debian:12-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        libgmp-dev \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /home/opam/austral/austral /usr/local/bin/austral
COPY --from=build /home/opam/austral/standard /usr/local/share/austral/standard
COPY --from=build /home/opam/austral/examples /usr/local/share/austral/examples

WORKDIR /workspace
ENTRYPOINT ["austral"]
CMD ["--help"]
