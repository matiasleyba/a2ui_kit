# Contributing to a2ui_kit

Thanks for helping. a2ui_kit draws CopilotKit's A2UI Playground catalog in Flutter (see the
[README](README.md)). This page says how to set up, what to run before a pull request, and how a pull request goes
from draft to merged.

## Before you start

- **A small fix** (a typo, a wrong colour, a crash with a clear cause): open a pull request directly.
- **Anything bigger** (a new component, a change of behaviour): open an issue first, or comment on an existing one,
  and say what you plan. It saves you work that might not fit.
- **Porting a component:** the port follows [`port/RULEBOOK.md`](port/RULEBOOK.md). Its section 6 lists what a
  component needs before it counts as done. Read it before you start; reviews check against it.

## Set up

1. Install Flutter 3.47.4 or a newer stable release (CI uses 3.47.4 on macOS, as the golden images were made).
2. Fork the repository on GitHub, clone your fork, and add this repository as `upstream`:
   ```bash
   git clone https://github.com/<you>/a2ui_kit.git
   cd a2ui_kit
   git remote add upstream https://github.com/vritravaibhav/a2ui_kit.git
   flutter pub get
   (cd example && flutter pub get)
   ```
3. Optional: `tool/fetch_third_party.sh` (needs npm) fetches the lucide-react packages into `third_party_src/`.
   Without them, three generator tests skip and say so. CI always runs them.

## Make the change

- Work on a branch, never on `main`: `git checkout -b agenda-colours`.
- One topic per pull request. Two unrelated fixes are two pull requests.
- Before you start a new piece of work, bring your fork up to date: `git fetch upstream`, then
  `git merge upstream/main` (or **Sync fork** on GitHub).

**Adding or changing a component:**
- register it in `lib/src/components/registry.dart` (`kitBuilders`) and in the list in `test/catalog_test.dart`;
- end its Dart file with the `// PORT STATUS: …` line (RULEBOOK section 4);
- add tests in `test/components/` and its parity tests in `test/parity/`, whose header names it in a
  `// Parity for:` line;
- regenerate the port's queue: `dart run port/port_status.dart`;
- for ported third-party code, add a section to `NOTICE.md`.

## Check it: the same as CI

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze && (cd example && flutter analyze)
dart run port/port_status.dart --check
flutter test && (cd example && flutter test)
```

**Golden images** (`test/goldens/`):
- They are alchemist's CI goldens (text drawn as blocks), made on **macOS (Apple Silicon)**, where CI runs them.
  Up to 0.1% of the pixels may differ, for anti-aliasing; a bigger difference or a new size fails.
- On Linux or Windows a few of them fail even with no change (`details.png` comes out a different height, because
  some text falls back to that system's font). Trust CI's run for those, or check on a Mac.
- When a test fails, its expected, actual and difference images are in `test/goldens/failures/`.
- Update the images only when the change of look is intended:
  `flutter test --update-goldens --plain-name "<test name>" test/goldens`. Say so in the pull request, with a
  before-and-after picture.

## Open the pull request

1. Push your branch to your fork and open a pull request against `main`. GitHub offers a button after the push.
2. Fill in the template: what changed and why, screenshots for anything visual, and how you tested it.
3. **Not finished?** Open it as a **draft**. When it is ready, press **Ready for review** yourself: that is the
   author's signal that the work is done.
4. CI runs on every push. A first-time contributor's run waits until a maintainer approves it (GitHub's rule for
   forks).
5. Answer review comments by pushing more commits to the same branch; the pull request updates by itself.
   Maintainers may push small fixes to your branch ("Allow edits by maintainers" is ticked by default).
6. A maintainer merges once CI is green and the review is done.

## Commit messages

The first line says what the commit does, in under about 72 characters ("Add Agenda's day headers"). Then a blank
line and, when it helps, why: the problem, and anything a reviewer should know.

## Licence

a2ui_kit is under the [MIT licence](LICENSE). By opening a pull request you agree that your contribution is under
it too. Code ported from another project keeps that project's notice in `NOTICE.md`.
