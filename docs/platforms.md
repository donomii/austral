# Supported Platforms

Austral currently has one production compiler implementation: the OCaml
compiler that emits C.

## Compiler Hosts

The supported compiler hosts are:

- Linux on x86_64 and aarch64.
- macOS on x86_64 and aarch64.

The supported OCaml range for building the compiler is 4.14.x through 5.3.x.
Use opam to install the compiler dependencies, or use the Nix shell/flake.

Windows is not currently supported as a compiler host.

## Generated Programs

Generated C is supported on Unix-like systems with:

- GCC or Clang.
- A C standard library with normal POSIX-like process behavior.
- `-fwrapv` and `-lm` when compiling generated C outside the `austral` command.

Linux and macOS are the supported generated-program targets. Windows generated
programs are unsupported until the runtime and C compiler story are designed and
tested.

## Docker

The Docker image is a Linux compiler image. It includes:

- `austral` in `/usr/local/bin`.
- A C toolchain for compiling generated C.
- Standard library sources in `/usr/local/share/austral/standard`.
- Example programs in `/usr/local/share/austral/examples`.

Build locally:

```bash
docker build -t austral:local .
```

Run:

```bash
docker run --rm austral:local --version
```

Build the bundled hello-world project from the image:

```bash
docker run --rm \
  -v "$PWD":/workspace \
  -w /workspace/examples/hello-world \
  austral:local \
  build
```
