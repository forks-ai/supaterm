# Development

## Bootstrap

Run setup from the repo root.

Initialize submodules:

```bash
git submodule update --init --recursive
```

Install pinned tools:

```bash
mise trust mise.toml
mise install
```

Authenticate Tuist before using cache-backed generation or cache warming:

```bash
mise exec -- tuist auth login
mise exec -- tuist auth whoami
```

Generate the macOS workspace:

```bash
make mac-generate
```

Generate without external binary cache:

```bash
make mac-generate-sources
```

Warm the external Tuist cache:

```bash
make mac-warm-cache
```

## macOS App

Build and run the Debug app:

```bash
make mac-build
make mac-run
```

Run checks and tests:

```bash
make mac-check
make mac-test
```

Run one test target or method:

```bash
xcodebuild test -workspace apps/mac/supaterm.xcworkspace -scheme supaterm -destination "platform=macOS" \
  -only-testing:supatermTests/AppFeatureTests \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" -skipMacroValidation
```

Use `$SUPATERM_CLI_PATH` inside Supaterm panes to call the Debug CLI injected by the running app instead of an installed `sp`:

```bash
"$SUPATERM_CLI_PATH" diagnostic
```

Useful diagnostics:

```bash
"$SUPATERM_CLI_PATH" instance ls
"$SUPATERM_CLI_PATH" diagnostic --json
"$SUPATERM_CLI_PATH" config validate
```

## Versioning

Supaterm uses Calendar Versioning for public releases: `YY.release.patch`.

- Use `regular` for the first release of a year and normal feature releases. The first 2026 release after `1.3.7` is `26.0.0`; the next regular 2026 release is `26.1.0`.
- Use `hotfix` for patch-only follow-ups within the current release line. A hotfix after `26.1.0` is `26.1.1`.
- `MARKETING_VERSION` is the public version shown in the app, changelog, tags, GitHub releases, and Sparkle short version.
- `CURRENT_PROJECT_VERSION` is a private monotonic build number. Stable CI publishes `CURRENT_PROJECT_VERSION * 1000`; tip CI publishes `CURRENT_PROJECT_VERSION * 1000 + github.run_number`.

Run stable releases from the repo root:

```bash
make bump-and-release
```

## Isolated App State

`make mac-run` creates disposable state and zmx directories under `apps/mac/.build/run-state` by default. To reuse a specific development state root:

```bash
SUPATERM_RUN_STATE_HOME=/tmp/supaterm-dev make mac-run
```

To reuse a named development instance and make `sp --instance` stable:

```bash
SUPATERM_RUN_INSTANCE_NAME=supaterm-dev SUPATERM_RUN_STATE_HOME=/tmp/supaterm-dev make mac-run
```

`make mac-run` accepts these runtime overrides:

- `SUPATERM_RUN_ID` controls the disposable run directory suffix.
- `SUPATERM_RUN_INSTANCE_NAME` becomes `SUPATERM_INSTANCE_NAME` for the app process.
- `SUPATERM_RUN_STATE_HOME` becomes `SUPATERM_STATE_HOME` for the app process and spawned panes.
- `SUPATERM_RUN_ZMX_DIR` becomes `ZMX_DIR` for the app process.

Panes inherit Supaterm context from the running app:

- `SUPATERM_SOCKET_PATH`
- `SUPATERM_CLI_PATH`
- `SUPATERM_STATE_HOME` when an app state root is configured
- `SUPATERM_SURFACE_ID`
- `SUPATERM_TAB_ID`

The app also prepends the bundled CLI directory to pane `PATH`.

## Website

Install dependencies:

```bash
make web-install
```

Run checks, tests, and production build:

```bash
make web-check
make web-test
make web-build
```

Run the Vite dev server:

```bash
make web-dev
```

Run the Cloudflare Worker locally after building:

```bash
make web-worker-dev
```

Deploy the Worker:

```bash
make web-deploy
```

## Testing

Tests that exercise polling or timeout behavior should inject a clock and advance it instead of waiting on wall clock time.

In tests, use `TestClock` from `Clocks` and call `advance(by:)` rather than sleeping for a real poll interval or timeout.

When parsing Codex, Claude Code, or any coding-agent integration, inspect real JSONL files, transcript files, or hook payloads before designing parser behavior. Do not infer event shapes from UI text, source names, or assumptions.
