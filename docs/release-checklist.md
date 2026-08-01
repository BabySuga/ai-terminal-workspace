# Release Checklist

This checklist defines the steps required to validate, package, and verify a release for AI Terminal Workspace.

## Pre-release

- [ ] `shellcheck`
- [ ] `shfmt`
- [ ] `markdownlint`
- [ ] `aiw doctor`
- [ ] `aiw config test`
- [ ] `aiw benchmark`

## Release

- [ ] update version
- [ ] create git tag
- [ ] push tag
- [ ] create GitHub release

## Post-release

- [ ] verify installation
- [ ] verify README
- [ ] verify screenshots
