# Releases

Tagged releases are built by GitHub Actions when a tag matching `v*` is pushed.

Each release publishes:

- A Linux compiler binary named `austral-linux-<arch>`.
- A macOS compiler binary named `austral-macos-<arch>`.
- SHA-256 checksum files for each binary.

The release binaries are compiler binaries only. Generated Austral programs
still require a platform C compiler and the normal generated-C flags documented
in the README.

Docker images are built from the repository `Dockerfile`. The Dockerfile is
intended to be usable both locally and by downstream image publishing workflows.

```bash
docker build -t austral:local .
docker run --rm austral:local --version
```

Release signing is not implemented yet.
