# Austral TODO

This is a working checklist for pushing Austral from "coherent research
compiler" toward a language that can run small real services in production.

Sources reviewed:

- Upstream README: https://github.com/austral/austral
- Upstream roadmap: https://github.com/austral/austral/blob/master/ROADMAP.md
- Compiler walkthrough: https://github.com/austral/austral/blob/master/docs/walkthrough.md
- Open upstream issues: https://github.com/austral/austral/issues
- Language specification: https://austral-lang.org/spec/spec.html
- Original introduction/future work: https://borretti.me/article/introducing-austral

## Immediate Correctness

- [ ] Fix typeclass checking soundness.
  - [ ] Reject instances that omit required typeclass methods.
  - [ ] Reject instance methods whose signatures do not match the typeclass.
  - [ ] Add compile-fail tests for both cases.
  - Related upstream issues: #600, #582.

- [ ] Fix generic/region monomorphization bugs.
  - [ ] Reproduce and reduce region-recursion failure.
  - [ ] Reproduce incompatible generated C types for region-parametric values.
  - [ ] Decide whether region parameters belong in monomorph identity or should
        erase to compatible runtime C types.
  - [ ] Add regression tests that compile generated C, not just typecheck.
  - Related upstream issues: #603, #598, #583.

- [ ] Fix generated C for function-pointer calls.
  - [ ] Reproduce nested function-pointer call used as another call argument.
  - [ ] Remove the spurious semicolon in expression rendering.
  - [ ] Add a codegen regression test.
  - Related upstream issue: #618.

- [ ] Fix typeclass return-type polymorphism internal error.
  - [ ] Reduce failure case.
  - [ ] Identify where monomorphic type universe queries happen.
  - [ ] Return a user-facing error if the pattern is intentionally unsupported,
        or implement it if it is part of the intended typeclass model.
  - Related upstream issue: #564.

- [ ] Improve parser edge cases and diagnostics.
  - [ ] Empty borrow body should either parse or produce a clear diagnostic.
  - [ ] Reserved names like `Region` should produce a clear diagnostic.
  - [ ] Add parser error tests with source spans.
  - Related upstream issues: #585, #584.

## Capability Security

- [ ] Verify whether imported opaque/capability types are forgeable.
  - [ ] Try constructing `TerminalCapability()` outside its defining module.
  - [ ] Try constructing a custom exported opaque linear capability outside its
        defining module.
  - [ ] Compare actual compiler behavior to the spec and tutorial.
  - Related upstream issue: #601.

- [ ] Make capabilities unforgeable if they are currently forgeable.
  - [ ] Separate "type is importable" from "constructor is importable".
  - [ ] Ensure opaque record constructors are private outside the defining
        module.
  - [ ] Add compile-fail tests for forged filesystem, terminal, environment,
        network, and clock capabilities.

- [ ] Define a small capability hierarchy for production services.
  - [ ] Root capability.
  - [ ] Environment/config capability.
  - [ ] Terminal/logging capability.
  - [ ] Filesystem capability with read/write subcapabilities.
  - [ ] Network capability with host/socket subcapabilities.
  - [ ] Clock/timer capability.

## Runtime And Generated C

- [ ] Make the C prelude portable.
  - [ ] Use normal C headers instead of hand-declared libc symbols where
        possible.
  - [ ] Fix OpenBSD stdio/linking behavior.
  - [ ] Audit `memcpy`, `memmove`, allocation, stdio, math, and process exit
        declarations.
  - Related upstream issue: #563.

- [ ] Add generated-C verification to CI.
  - [ ] Compile representative programs with Clang and GCC.
  - [ ] Run generated binaries on Linux and macOS.
  - [ ] Add sanitizer runs for generated C where possible.
  - [ ] Treat C compiler warnings in the prelude as bugs.

- [ ] Stabilize memory primitives.
  - [ ] Clarify `resizeArray`/`realloc` semantics in docs.
  - [ ] Add tests for buffer growth, move, copy, and deallocation paths.
  - [ ] Audit uses of raw pointer casts and `@embed`.

## Installation And Releases

- [ ] Fix opam/dependency installation.
  - [ ] Resolve missing `ppxlib = 0.25.0` report.
  - [ ] Fill missing opam metadata: maintainer, authors, license.
  - [ ] Test install on a fresh non-Nix Linux environment.
  - Related upstream issue: #616.

- [ ] Produce usable release artifacts.
  - [ ] Build Linux binaries that do not depend on Nix store paths.
  - [ ] Add macOS release binaries.
  - [ ] Document supported platforms.
  - [ ] Add checksum/signature publishing.
  - Related upstream issue: #565.

- [ ] Decide Windows support level.
  - [ ] Document unsupported/experimental/supported status.
  - [ ] If supported, define the C compiler/runtime story.
  - Related upstream issue: #560.

- [ ] Add a Docker image for the compiler.
  - [ ] Include compiler, C compiler, standard library, and examples.
  - [ ] Use it in CI and quick-start docs.

## Standard Library

- [ ] Finish primitive equality and ordering.
  - [ ] Add equality/order instances for primitive integer and boolean types.
  - [ ] Add tests for every primitive instance.
  - [ ] Add useful comparison helpers.
  - Related upstream issue: #619.

- [ ] Harden core containers.
  - [ ] Buffer.
  - [ ] String and byte string.
  - [ ] Map and set.
  - [ ] Queue/deque.
  - [ ] Result-like error type, if not already sufficient in pervasive/builtin
        modules.

- [ ] Improve terminal and basic IO.
  - [ ] Make `readLine` distinguish EOF from an empty line.
  - [ ] Audit all functions for capability requirements and error returns.
  - Related upstream issue: #597.

- [ ] Add service-oriented modules.
  - [ ] Environment/config.
  - [ ] Filesystem.
  - [ ] Time/clock.
  - [ ] TCP sockets.
  - [ ] TLS story, either native or via extension bridge.
  - [ ] HTTP client/server.
  - [ ] JSON.
  - [ ] Logging.

- [ ] Add FFI support patterns for existing ecosystems.
  - [ ] Document C shims.
  - [ ] Bind enough C ABI to call extensionengine.
  - [ ] Prototype ClickHouse access through extensionengine.
  - [ ] Prototype AWS access through extensionengine.
  - [ ] Decide whether native gRPC is realistic or should be bridged first.

## Concurrency

- [ ] Integrate a first-class threading module.
  - [ ] Move owned linear values into threads.
  - [ ] Join threads exactly once.
  - [ ] Return owned results from joins.
  - [ ] Add compile-fail tests for forgotten joins, double joins, and using a
        moved value after spawn.

- [ ] Add basic synchronization primitives.
  - [ ] Mutex.
  - [ ] Condition variable.
  - [ ] One-shot channel.
  - [ ] Bounded multi-producer/multi-consumer queue.

- [ ] Build a real worker-pool abstraction.
  - [ ] Workers start first and block on a shared queue.
  - [ ] Parent submits jobs dynamically.
  - [ ] Results are collected through a result queue or joined result handle.
  - [ ] Shutdown is explicit and linear.
  - [ ] Add stress tests with hundreds/thousands of jobs.

- [ ] Define portability policy.
  - [ ] pthreads for Unix-like systems.
  - [ ] Windows threading backend only if Windows becomes a supported target.

## Build Tooling And Packages

- [ ] Add a basic `austral build` workflow.
  - [ ] Discover modules from a project file.
  - [ ] Track interface/body pairs.
  - [ ] Invoke the C compiler consistently.
  - [ ] Support executable and library outputs.

- [ ] Add `austral test`.
  - [ ] Compile and run test modules.
  - [ ] Support compile-fail tests.
  - [ ] Support generated-C compile tests.

- [ ] Add package/dependency metadata.
  - [ ] Package name/version.
  - [ ] Module roots.
  - [ ] Dependencies.
  - [ ] Capability declarations or audit metadata, if useful.

- [ ] Plan separate compilation.
  - [ ] Decide intermediate artifact format.
  - [ ] Cache typed interfaces and monomorphized instantiations.
  - [ ] Preserve whole-program checks where required for safety.
  - [ ] Keep this behind correctness and build-tooling work.

## Documentation And Examples

- [ ] Write a larger example program.
  - [ ] Multiple modules.
  - [ ] Imports across files.
  - [ ] Linear resources.
  - [ ] Capabilities.
  - [ ] Error handling.
  - Related upstream issue: #609.

- [ ] Document module imports clearly.
  - [ ] Explain module names versus filesystem paths.
  - [ ] Show interface/body pairs.
  - [ ] Show the command line for multi-module builds.
  - Related upstream issue: #592.

- [ ] Refresh capability tutorial after fixing opacity semantics.
  - [ ] Ensure examples cannot forge capabilities.
  - [ ] Show hierarchical acquisition and release.
  - [ ] Show how capabilities affect library APIs.

- [ ] Expand tutorial coverage.
  - [ ] Generic containers.
  - [ ] Linked list.
  - [ ] Heap buffer.
  - [ ] FFI.
  - [ ] Service tutorial.

- [ ] Add grammar docs.
  - [ ] Generate railroad diagrams from the parser grammar.
  - [ ] Keep grammar docs checked against parser tests.
  - Related upstream issue: #567.

## Editor And Developer Tools

- [ ] Provide first-class editor support.
  - [ ] Decide whether to split Vim mode into its own repository.
  - [ ] Add VS Code syntax highlighting.
  - [ ] Add basic language server diagnostics.
  - [ ] Add compiler-error parsing for editor integrations.
  - Related upstream issues: #587, #574.

- [ ] Add formatter.
  - [ ] Define stable style.
  - [ ] Format module interfaces and bodies.
  - [ ] Use it in examples and tests.

- [ ] Improve diagnostics.
  - [ ] Better module/import errors.
  - [ ] Better parse errors.
  - [ ] Better generic/typeclass errors.
  - [ ] Better generated-C failure reporting with reduced context.

## Production Service Milestone

Goal: one Austral service running in Kubernetes, doing limited but real work.

- [ ] Build a container image containing an Austral executable.
- [ ] Read configuration from environment variables through a capability.
- [ ] Emit structured logs.
- [ ] Expose an HTTP health endpoint.
- [ ] Handle one useful request path.
- [ ] Call one external dependency through extensionengine.
- [ ] Return structured errors without exceptions.
- [ ] Shut down cleanly.
- [ ] Include unit tests and one integration test.
- [ ] Document the build/run/deploy path.

## Strategic Questions

- [ ] Keep compiling to C, or add a second backend?
  - C is closest to the current compiler.
  - Rust or Go could unlock ecosystems, but would require mapping Austral's
    semantics carefully and may not preserve the language's simplicity.

- [ ] How much effect tracking belongs in the language?
  - Capabilities already expose some effects in function signatures.
  - Decide whether that is enough for environment, filesystem, network, clock,
    and threading, or whether a formal effect system is worth the complexity.
  - Related upstream issue: #615.

- [ ] What does "supported platform" mean?
  - Compiler host platforms.
  - Generated program target platforms.
  - Runtime/threading platforms.
  - Release artifact platforms.
