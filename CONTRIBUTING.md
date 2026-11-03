# Contributing to Dropdone

Thanks for wanting to help. This is a small project, so the process is simple.

## Setting up

1. Fork the repo and clone your fork.
2. Install the tools: `brew install xcodegen swiftlint swiftformat`
3. Run `xcodegen` to create the Xcode project, then open `Dropdone.xcodeproj`.

You need macOS 26 and a recent Xcode.

## Making a change

1. Make a branch from `main`. Use a short name like `feat/something`, `fix/something` or `docs/something`.
2. Keep the change small and focused on one thing.
3. Add or update tests if you touched `Store.swift` or `Item.swift`.
4. Run the checks before you push:

   ```bash
   swiftformat .
   swiftlint --strict
   xcodebuild test -scheme Dropdone -destination 'platform=macOS'
   ```

5. Open a pull request and fill in the template. CI must pass before it can be merged.

## Commit messages

We use short prefixes so the history is easy to scan:

- `feat:` a new feature
- `fix:` a bug fix
- `docs:` documentation only
- `test:` tests only
- `style:` how it looks
- `ci:` workflows
- `chore:` everything else

Example: `fix: keep the panel open while editing`

## Reporting bugs

Open an issue and use the bug report form. Tell us your macOS version and what you did right before it broke.

## Code of conduct

Be kind. By taking part you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).
