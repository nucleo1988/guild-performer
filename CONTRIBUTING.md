# Contributing

Thanks for contributing to Guild Performer.

## Ground rules

- Do not copy proprietary code or assets from other addons (including Class Performer).
- Do not commit secrets, tokens, or local WoW SavedVariables.
- Keep the shared format (`GPv1`) backwards compatible or bump `FORMAT_VERSION` deliberately.
- Prefer small, focused PRs.

## Setup

1. Fork and clone the repository.
2. Copy or symlink `addon/` to `Interface/AddOns/GuildPerformer`.
3. Run `./scripts/validate-release.sh` before opening a PR.

## Pull requests

- Describe the user-facing change.
- Update `CHANGELOG.md` under `[Unreleased]`.
- Add or update locales (`enUS` + `itIT`) for new UI strings.
