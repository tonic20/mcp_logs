# AGENTS.md

Rules for AI agents working on the `mcp_logs` Ruby gem (a mountable Rails engine).

## What this gem is

It records every Model Context Protocol request a Rails app serves, and renders that app's
MCP tool contract as documentation. Capture hangs off the `mcp` gem's public
`around_request` hook — one row per JSON-RPC request, inserted `running` before the handler
and completed after, so a long tool call is visible while it runs.

## Project layout

- `lib/mcp_logs/` — gem code (engine, configuration, `Context`, `Payload`).
- `lib/mcp_logs/version.rb` — single source of truth for the gem version.
- `app/` — engine controllers, models, views, helpers, jobs (all namespaced under `McpLogs::`).
- `app/models/mcp_logs/recorder.rb` — the `around_request` lambda's behaviour. The hot path.
- `app/models/mcp_logs/docs.rb` — turns a live server into renderable documentation sections.
- `app/assets/stylesheets/mcp_logs.css` — all styling. Plain CSS, no build step.
- `db/migrate/` — engine migrations, copied into host apps by the install generator.
- `lib/generators/mcp_logs/` — install generator and its initializer template.
- `spec/` — RSpec, with a `spec/dummy` host Rails app.
- `CHANGELOG.md` — human-edited, Keep a Changelog format.

## Golden rules

1. **Logging must never break a tool call.** Every database touch in the capture path runs
   inside `Recorder#guarded`, which reports to `Rails.error` and swallows. The savepoint in
   there is load-bearing, not decoration: without it a failed statement leaves PostgreSQL's
   connection in an aborted transaction and the *host's own* subsequent queries fail. There
   are specs that provoke a real `SELECT 1/0` to prove it. Do not "simplify" them into stubs.
2. **Bump the version at the end of every feature or bugfix.** Edit `lib/mcp_logs/version.rb`
   and add a matching `CHANGELOG.md` entry before the work is done. Easy to forget; treat it
   as part of the definition of done.
3. **Never ship without `bundle exec rspec` green.**
4. **Keep everything under `McpLogs::`.** No top-level constants.
5. **Don't break host apps.** Migrations, routes and assets must stay additive and idempotent.

## Invariants that are easy to break by accident

Each of these has cost someone real debugging. Read before changing the code they describe.

- **`mcp` is a development dependency.** It may be required from `spec/`, never from `lib/`
  or `app/`. The engine must install and render in an app that serves no MCP at all.
  `Docs` duck-types the server object (`server.tools`, `.name`, `.version`, `.instructions`)
  and must never name an `MCP::` constant.
- **The column is `rpc_method`, not `method`.** An ActiveRecord attribute called `method`
  shadows `Object#method` on every record. The query parameter stays `?method=`.
- **`Recorder#finish` writes with `update_columns`, deliberately.** `update!` sends only
  attributes dirty relative to the in-memory object, and `error_type`/`error_message` are
  `nil` there — so a row the sweep settled as `abandoned` would keep that verdict after the
  call completed. If you change this, the spec named
  "clears an abandoned verdict when a swept call finishes after all" is the one that fails.
- **`tool_name` is raw client input.** `mcp` reads it from `params.name` and hands it to the
  hook *before* looking the tool up, so an unknown tool records whatever the client sent.
  It, and every request-header-derived string, is capped in the recorder. Keep them capped.
- **A host MUST build a fresh `MCP::Server` per request.** `mcp` 1.0.0 keeps its
  instrumentation data in an instance variable on the server object, so two concurrent
  requests through one shared server cross-contaminate tool name, arguments and error. This
  is upstream behaviour the recorder cannot defend against — it is documented on
  `Recorder.around_request` and in the README, and both should stay accurate.
- **`base_controller_class` fails closed.** It defaults to `nil` and `McpLogs.base_controller`
  raises. That is the whole reason a stranger following the README cannot end up serving
  their MCP audit log to the internet. Do not give it a working default "for convenience".
- **Styling is plain CSS with an `mcpl-` prefix.** A host's Tailwind build scans its own root
  and never a gem's files, so utility classes would render unstyled. No build step, no CDN,
  no external request of any kind from the layout.
- **Payload capping order is fixed:** Rails' `filter_parameters`, then the host's
  `payload_filter`, then the byte cap. Truncation is recorded per payload
  (`arguments_truncated`, `response_truncated`, `error_message_truncated`) because one
  combined flag cannot tell the detail page which payload was actually cut.

## Versioning

- Follow SemVer.
  - Patch (`0.1.0 → 0.1.1`): bugfixes, internal refactors, doc-only changes.
  - Minor (`0.1.0 → 0.2.0`): new features, new configuration options, new public APIs
    (pre-1.0 may include breaking changes here — call them out loudly).
  - Major: breaking changes once stable.
- Every bump needs a `## [x.y.z] — YYYY-MM-DD` section in `CHANGELOG.md`.
- After a release commit lands on `main`, tag it and push:
  `git tag -a vX.Y.Z -m "vX.Y.Z" && git push origin vX.Y.Z`.
- Do **not** run `gem push` yourself — it requires the maintainer's RubyGems MFA. Build with
  `gem build mcp_logs.gemspec` and hand the `.gem` off.

## Feature workflow

1. Understand the request; brainstorm first if it is non-trivial.
2. Write or update specs first — request specs for controllers and views, model specs for
   scopes and behaviour.
3. Implement using existing patterns; mirror neighbouring files.
4. Run `bundle exec rspec`.
5. **Bump `lib/mcp_logs/version.rb`.**
6. **Add a `CHANGELOG.md` entry** dated today, written from a user's perspective.
7. Commit with a short imperative subject (see `git log` for tone).

## Rails / Ruby conventions

- Ruby `>= 3.3`, Rails `~> 8.0`, PostgreSQL. `Fiber[]` storage is used by `Context` and needs 3.2+.
- Runtime dependencies are `rails` and `pagy` only. Pagination uses pagy's plain readers, not
  its nav helpers, which ship markup and a stylesheet that do not match this layout.
- Push non-trivial logic into `app/models/mcp_logs/` rather than controllers or views.
- Everything rendered — tool names, actors, user agents, both JSON payloads — arrives from
  outside the application. Normal Rails escaping only: no `raw`, no `html_safe`.
- Migrations must be reversible and namespaced (`mcp_logs_` table prefix).

## Testing

- RSpec against the dummy app in `spec/dummy`. Request specs in `spec/requests/mcp_logs/`.
- Tests run against PostgreSQL (see `spec/spec_helper.rb` and the GitHub Actions workflow).
  Don't assume SQLite.
- `spec/support/fake_tools.rb` builds a **real** `MCP::Server` from real `MCP::Tool`
  subclasses. Prefer it over stubbing the hook: the integration spec driving a real server is
  the strongest evidence in the suite, and it is what catches upstream contract changes.
- `spec/spec_helper.rb` resets configuration before every example, so a spec that changes a
  setting cannot leak it into the next file.

## Things NOT to do

- Do not edit `Gemfile.lock` by hand; run `bundle install`.
- Do not introduce host-app-specific assumptions. Configuration takes strings, lambdas and
  tool **name** strings — the gem must never reference a host's constants.
- Do not add a runtime dependency without a `~>` constraint in the gemspec and a real need.
  This engine is meant to drop into existing apps with minimal surface.
- Do not leave `binding.pry`, `byebug` or `puts` debugging in committed code.
- Do not rename public APIs, tables or routes without the matching version bump and a
  migration path.

## Before declaring done

- [ ] Specs pass: `bundle exec rspec`
- [ ] `lib/mcp_logs/version.rb` bumped
- [ ] `CHANGELOG.md` updated with today's date and a user-facing summary
- [ ] No stray debug output, commented-out code, or TODOs introduced
- [ ] When a release is cut, the matching `vX.Y.Z` tag exists and has been pushed
