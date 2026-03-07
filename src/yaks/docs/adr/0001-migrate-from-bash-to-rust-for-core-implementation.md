# 1. Migrate from Bash to Rust for core implementation

Date: 2026-02-02

## Status

accepted

## Context

Yaks started as a ~240 line bash script (bin/yx) with a simple
directory-based storage model. As the project grew, we migrated
to argc (a bash CLI framework) to improve argument parsing and
maintainability (January 2026).

However, several challenges emerged with the bash implementation:

**Performance concerns**: As yak hierarchies grow, bash's process
spawning overhead for operations like finding yaks, parsing state,
and traversing hierarchies becomes noticeable.

**Type safety**: Bash's lack of type checking makes it easy to
introduce subtle bugs, especially around state management (done
files vs state files) and fuzzy matching logic.

**Testing complexity**: While ShellSpec works well, testing bash
requires careful management of subprocesses, environment variables,
and filesystem state. Mocking is difficult.

**Cross-platform compatibility**: Bash behavior varies across
platforms (macOS vs Linux), especially around commands like
`readlink -f`, `stat`, and `realpath`. We hit issues with
symlink resolution that required platform-specific workarounds.

**Build and packaging**: Nix packaging of bash scripts requires
bundling dependencies (argc) and careful path management. The
release process involved multiple bash wrappers and path resolution
logic.

## Decision

Rewrite the core implementation in Rust while preserving the
existing CLI interface and directory-based storage format.

**Migration approach**:
- Port functionality incrementally (list → done → remove → prune →
  etc.)
- Maintain 100% test compatibility with existing ShellSpec tests
- Use Rust's clap crate for CLI parsing (similar to argc's
  annotation approach)
- Implement hexagonal architecture (ports/adapters) to prepare for
  git ref backend
- Keep storage format identical (`.yaks/<name>/` directories with
  `state` files)
- Remove bash implementation entirely once Rust implementation
  passes all tests

**Architecture**:
- **Ports**: Storage, Sync, Log, Output (abstractions)
- **Adapters**: DirectoryStorage, GitRefSync, GitLog, ConsoleOutput
- **Application**: Use cases (AddYak, ListYaks, DoneYak, etc.)
- **Domain**: Core entities (Yak)

This hexagonal architecture makes testing easier and prepares for
future backends without changing use case logic.

## Consequences

### What becomes easier

**Performance**: Rust's compiled nature eliminates process spawning
overhead. Operations on large yak hierarchies are significantly
faster.

**Type safety**: Rust's type system catches bugs at compile time.
State transitions (todo/in-progress/done) are enforced by the type
system. Fuzzy matching logic is safer with proper Result types.

**Testing**: Rust's testing framework is integrated, fast, and
supports mocking/dependency injection naturally through traits.
Unit tests run in milliseconds.

**Cross-platform**: Rust's standard library handles platform
differences. No more conditional logic for macOS vs Linux commands.

**Build process**: Single Rust binary, no path resolution or argc
bundling. Nix build simplified using rustPlatform. Release is just
the compiled binary.

**Maintenance**: Clear module boundaries, explicit dependencies,
and compiler-enforced contracts reduce maintenance burden.

### What becomes more difficult

**Development barrier**: Contributors need Rust experience instead
of bash knowledge. Rust has a steeper learning curve.

**Compile times**: Changes require recompilation (though cargo is
fast for incremental builds). Bash was immediate feedback.

**Binary size**: Rust binary (~1.3MB) is larger than bash script
(~10KB), though still small and includes all dependencies.

**Dogfooding complexity**: Can't read implementation in a text
editor as easily. Need Rust development environment (cargo, rustc).

**ShellSpec tests**: Kept for compatibility but now test the Rust
binary as a black box rather than unit testing bash functions
directly. Some test granularity lost.

### Migration impact

**Completed** (Feb 1-2, 2026):
- ✅ All use cases ported (list, add, done, remove, prune, move,
  context, sync)
- ✅ All 100+ ShellSpec tests passing
- ✅ Bash implementation removed entirely
- ✅ Nix build updated to produce Rust binary
- ✅ Release process simplified
- ✅ Code hygiene tools integrated (clippy, rustfmt)

**No user-facing changes**: CLI interface, storage format, and
behavior identical. Existing yaks repositories work without
migration.