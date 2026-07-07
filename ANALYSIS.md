# TableOfSpells — Project Analysis & Roadmap

*A strengths / weaknesses / opportunities analysis written as a handoff document.
Each actionable item includes enough context to be picked up cold, plus a
recommended model tier (Opus / Sonnet / Haiku) for executing it.*

---

## 1. What this project is

TableOfSpells is a **macOS-only SwiftUI demo app** built as the companion code
for two Captain SwiftUI Substack articles ("Displaying Data with Table",
Parts I & II). Its purpose is pedagogical: demonstrate the SwiftUI `Table`
component — columns, row selection, sorting via `KeyPathComparator`, and
per-row context menus — using live data from the community-run
Wizard World API (`https://wizard-world-api.herokuapp.com/Spells`).

### Inventory (everything that matters is 3 files)

| File | Role |
|---|---|
| `TableOfSpells/TableOfSpellsApp.swift` | `@main` entry point; single `WindowGroup` hosting `ContentView`. |
| `TableOfSpells/ContentView.swift` | The entire UI: a `Table` of spells with 6 columns, selection state, sort state, a loading placeholder (`ContentUnavailableView`), and the fetch kicked off in `.task`. |
| `TableOfSpells/WizardWorldAPICaller.swift` | The `Spell` model (`Codable`, `Identifiable`, `Hashable`), a `Spells` typealias, a static-method API caller, and two small `URLResponse`/`HTTPURLResponse` conveniences. |

### Build configuration facts

- Deployment target: **macOS 14.3**; SDK `macosx`; Swift language version setting **5.0** (i.e., no strict concurrency checking).
- App Sandbox **enabled**, Hardened Runtime **enabled**, automatic code signing.
- Entitlements: `app-sandbox`, `files.user-selected.read-only`, `network.client`, **and `network.server`** (the last one is unused — see Weaknesses).
- No third-party dependencies, no SPM packages, no test targets, no CI, no `.gitignore`.
- Git history is essentially two commits ("Initial Commit" + README update).

### Data flow (the whole app in one paragraph)

`ContentView` holds `@State var spells: Spells?` (nil = loading). `.task`
awaits `WizardWorldAPICaller.fetchSpells()`, which does a plain
`URLSession.shared.data(for:)` against the hardcoded URL, decodes
`[Spell]` on 2xx, and returns an **empty array on non-2xx** (it does not
throw for HTTP errors). On failure the catch block does `print("Error")`
and the UI stays on the loading placeholder forever. Sorting is done by
mutating the array in place from `.onChange(of: sortOrder, initial: true)`.
Selection (`Set<Spell.ID>`) is captured but never used for anything.

### Sample `Spell` shape (as decoded)

```swift
struct Spell: Codable, Identifiable, Hashable {
    let id, name, effect, type, light: String
    let canBeVerbal: Bool?
    let incantation, creator: String?   // creator is decoded but never displayed
}
```

---

## 2. Strengths

These are worth preserving in any follow-up work — don't refactor them away.

1. **Genuinely modern SwiftUI usage.** The code demonstrates the current-era
   APIs it sets out to teach: `Table(of:selection:sortOrder:)`,
   `TableColumn(_:value:)` for sortable columns, `KeyPathComparator`,
   `ContentUnavailableView`, structured concurrency via `.task` +
   `async/await`, and the two-parameter `onChange(of:initial:)` form. As
   tutorial code, it is on-message.
2. **Small and legible.** ~150 lines of Swift total. A reader can hold the
   entire app in their head, which is exactly right for article companion
   code. Any improvement below should keep this property — resist the urge
   to add architecture the articles don't discuss.
3. **Zero dependencies.** No SPM/CocoaPods; clones and builds with nothing
   but Xcode. Keep it that way unless a feature truly demands otherwise.
4. **Nice teaching touches.** Optional-handling is demonstrated honestly in
   the UI (the `incantation`/`canBeVerbal` columns render "-" for nil), the
   `canBeVerbal` column shows custom cell content (SF Symbols with color),
   and the per-row `contextMenu` with `NSPasteboard` shows a real
   macOS-native interaction.
5. **Sandboxed & hardened.** App Sandbox and Hardened Runtime are on —
   many demo apps skip this entirely.

---

## 3. Weaknesses

Ordered roughly by severity. File/line references are to the current `main`.

### W1. The app's only data source is a Heroku-hosted community API — existential risk
`WizardWorldAPICaller.swift:22` hardcodes
`https://wizard-world-api.herokuapp.com/Spells`. Heroku eliminated free
dynos in November 2022; community APIs on herokuapp.com have a high
mortality/cold-start rate. **Liveness could not be verified from the
analysis sandbox** (the egress proxy blocked the host), so the first thing
a follow-up session with open network access should do is
`curl -i https://wizard-world-api.herokuapp.com/Spells`. If it's dead or
slow-cold-starting, the demo is broken for every reader who clones it.
Mitigation is O2 below (bundled JSON fallback).

### W2. Failure is invisible — the app can hang on the loading screen forever
Two compounding problems:
- `ContentView.swift:64-66` — the `catch` block is `print("Error")`; the
  error object isn't even printed, and `spells` stays `nil`, so the user
  sees "Casting the Fetch Spell!" indefinitely with no retry affordance.
- `WizardWorldAPICaller.swift:26-30` — a non-2xx response doesn't throw; it
  silently returns `[]`, which renders as an *empty table* — indistinguishable
  from "the API has no spells." Errors and empty-success are conflated.

### W3. Force-unwrapped URL
`WizardWorldAPICaller.swift:23-24` — `URLRequest(url: url!)`. Safe today
because the literal is valid, but it's the canonical anti-pattern and a bad
look in teaching code. Trivial fix (make the URL a `static let` built from
a non-failing construction, or guard-throw).

### W4. Untestable networking, and no tests at all
`WizardWorldAPICaller` is a `class` with one static method, hardwired to
`URLSession.shared`. There is no seam for injecting a mock, and the project
has **no test target whatsoever** (nothing in the pbxproj). Any regression
in decoding (e.g., the API changes a field) ships silently.

### W5. Repo hygiene: user state is committed, no .gitignore
`TableOfSpells.xcodeproj/xcuserdata/dbolella.xcuserdatad/**` — including
`UserInterfaceState.xcuserstate` and a breakpoints file — is checked in.
`.xcuserstate` changes on every Xcode launch and will pollute every future
diff. There is no `.gitignore` at all.

### W6. Over-broad entitlements
`TableOfSpells.entitlements` requests `com.apple.security.network.server`
and `files.user-selected.read-only`. The app is a pure HTTP *client* that
never opens a listener or a file picker. Only `network.client` (plus
`app-sandbox`) is needed. Harmless for a demo, but it teaches readers to
over-entitle.

### W7. View owns all logic; state modeling is stringly loose
Everything — fetch, error handling (such as it is), sorting — lives in
`ContentView`. For a Part I/II tutorial that's arguably intentional, but:
- The loading/loaded/empty/failed lifecycle is modeled as `Spells?`, which
  cannot represent "failed" or distinguish "empty" from "error" (see W2).
- In-place `spells?.sort(using:)` inside `onChange` re-sorts the master
  array rather than sorting a derived value; fine at 100 rows, but it's the
  pattern readers will copy into bigger apps.
- `selectedSpell` is bound but drives nothing (no detail pane, no
  toolbar actions), and `creator` is decoded but never shown — both are
  loose threads that read like unfinished features.

### W8. Swift 6 / strict concurrency debt
`SWIFT_VERSION = 5.0` with no concurrency checking flags.
`WizardWorldAPICaller` being a non-`Sendable` class is currently benign
(only a static method), but flipping the project to Swift 6 mode will
surface warnings/errors (`@MainActor` on the view's mutation path, making
the caller an `enum` or `struct`, etc.). Not urgent; cheap now, more
expensive later.

### W9. Minor polish issues
- Accessibility: the Verbal column communicates via SF Symbol + green/red
  color with no `accessibilityLabel`; VoiceOver will read symbol names
  ("checkmark circle fill") instead of "Yes"/"No".
- Trailing whitespace (e.g., `ContentView.swift:45`), inconsistent brace
  spacing (`TableColumn("Incantation"){`), `spell.incantation{`.
- No app icon assets filled in; `AccentColor` empty.
- README doesn't state build requirements (Xcode ≥ 15.3 / macOS 14.3+).

---

## 4. Opportunities

Ranked by leverage. Each item states scope, concrete approach, effort, and
the recommended executing model. General rule used for recommendations:

- **Opus** — ambiguous or architectural work: API/design decisions with
  trade-offs, multi-file refactors where the shape of the answer isn't
  predetermined, migrations with cascading effects.
- **Sonnet** — well-specified implementation: the "what" is written down
  here, the work is executing it cleanly across 1–5 files with tests.
- **Haiku** — mechanical, low-risk chores with an unambiguous done-state.

### O1. Resilient load lifecycle: error + empty + retry states — **Sonnet**
Replace `@State var spells: Spells?` with an explicit phase enum:

```swift
enum LoadPhase { case loading, loaded(Spells), empty, failed(Error) }
```

Render `ContentUnavailableView` variants for `.empty` and `.failed` (the
failed one with a "Try Again" button that re-runs the fetch). Make
`fetchSpells()` **throw** on non-2xx (fixes W2's silent `[]`) and surface
`error.localizedDescription`. This is the single highest-value change for
anyone actually running the demo, and it's fully specified — Sonnet
executes it well. ~1 file + the API caller, small diff. *(Could also seed a
"Part III" article: error handling for Table-driven apps.)*

### O2. Bundled JSON fallback for the dead-API scenario — **Sonnet**
De-risk W1: capture one real `/Spells` response into
`TableOfSpells/Resources/spells.json`, and on network failure fall back to
decoding the bundled file (clearly marked in UI, e.g., a footnote "showing
cached sample data"). Keeps the demo alive forever regardless of Heroku.
Prerequisite: someone with unproxied network must fetch the JSON once. If
the API turns out to be permanently dead, promote the fallback to primary
and demote the network call to opportunistic refresh.

### O3. Testable networking + first test target — **Opus to design, or Sonnet with this spec**
Introduce a minimal seam without bloating the demo:

```swift
protocol SpellFetching { func fetchSpells() async throws -> Spells }
struct WizardWorldAPI: SpellFetching { /* current logic, URL injected */ }
```

Add a unit-test target with: (a) decoding tests against a fixture JSON
(nulls in `incantation`/`canBeVerbal`/`creator` covered), (b) non-2xx →
throws, using `URLProtocol` stubbing or an injected closure. The judgment
call — how much architecture is too much for tutorial code — is the Opus
part; if the maintainer agrees with exactly the shape above, Sonnet can
implement it directly. Convert `class WizardWorldAPICaller` to a
`struct`/`enum` while here (also helps W8).

### O4. Repo hygiene: .gitignore + purge xcuserdata — **Haiku**
Add a standard Xcode/Swift `.gitignore` (xcuserdata, *.xcuserstate, DS_Store,
build/, DerivedData). `git rm -r --cached` the committed
`xcuserdata` directories. Two-command chore, zero ambiguity.

### O5. Trim entitlements — **Haiku**
Delete `network.server` and `files.user-selected.read-only` from
`TableOfSpells.entitlements`, leaving sandbox + `network.client`. Verify
the app still fetches. One-file mechanical edit.

### O6. CI: build + test on GitHub Actions — **Sonnet**
`macos-14` (or newer) runner, `xcodebuild -project TableOfSpells.xcodeproj
-scheme TableOfSpells -destination 'platform=macOS' build test
CODE_SIGNING_ALLOWED=NO`. Blocked on O3 for the `test` half but `build` is
immediately useful (this repo currently has nothing verifying it compiles).
Note for the executing agent: the remote-session Linux container **cannot
build this project** — CI on a macOS runner is the only automated
verification path, which raises this item's priority.

### O7. Feature depth that showcases more of Table — **Sonnet (features), Opus (if redesigning layout)**
Natural Part III/IV article material, each incremental:
- `.searchable` filtering over name/incantation/effect.
- A detail **inspector pane** driven by the currently-unused `selectedSpell`
  (finally displaying the decoded-but-hidden `creator` field — closes two
  loose threads at once).
- Multi-select + toolbar action (e.g., "Copy N spell names"), showing why
  selection is a `Set`.
- Column visibility/customization via `TableColumnCustomization`.
Individually these are well-scoped Sonnet tasks; a full layout rework
(NavigationSplitView + inspector) has enough design surface to justify Opus.

### O8. Cross-platform (iPadOS/iOS) adaptation — **Opus**
`Table` runs on iPadOS but degrades to a single-column list on compact
width; a real adaptation needs a `horizontalSizeClass`-driven alternate
`List` layout, pasteboard abstraction (`NSPasteboard` → `UIPasteboard`),
and project/target changes. Real design trade-offs and Apple-platform
nuance → Opus. Only worth it if the maintainer wants an article out of it;
otherwise skip.

### O9. Swift 6 strict-concurrency migration — **Opus**
Flip `SWIFT_VERSION` to 6 (or add `-strict-concurrency=complete` first),
fix what surfaces: likely `@MainActor` annotations on state mutation,
`Sendable` conformance on `Spell` (already value-typed, fine), and
converting the API caller away from `class`. Small codebase makes this a
cheap migration *now*; the reasoning about actor isolation warnings is
where Opus earns its keep. Pairs naturally with O3.

### O10. Accessibility + polish pass — **Haiku/Sonnet**
`accessibilityLabel` on the Verbal column cells ("Verbal"/"Non-verbal"/
"Unknown"), whitespace/brace-style cleanup, README build-requirements note,
print the actual `error` in any remaining debug paths. Mechanical (Haiku)
except the VoiceOver verification, which needs judgment and a Mac (Sonnet
if bundled with O1).

### Suggested sequencing

1. **O4 + O5** (hygiene, minutes) → 2. **O1** (error states) → 3. **O2**
(offline fallback, pending API liveness check) → 4. **O3** (tests) →
5. **O6** (CI) → 6. **O9** (Swift 6) → 7. **O7/O8** as article-driven
features, if desired.

---

## 5. Handoff notes for the next agent/session

- **You cannot build or run this on the Linux remote container.** It's an
  Xcode project (macOS SDK). Verification options: GitHub Actions macOS
  runner (see O6), or hand off to the maintainer's machine. Don't claim
  "builds/tests pass" without one of those.
- **First action with open network:** verify
  `https://wizard-world-api.herokuapp.com/Spells` responds; the analysis
  sandbox's proxy returned 403 CONNECT, so liveness is unknown. The answer
  decides whether O2 is a fallback or the primary data path.
- **Respect the project's identity.** This is article companion code — the
  maintainer writes SwiftUI tutorials. Every change should either fix a
  real defect (W1–W6) or be plausible future-article material (O7–O9).
  Do not introduce heavyweight architecture (no full MVVM scaffolding,
  no dependency-injection frameworks, no third-party packages).
- **Small diffs, one concern per commit.** The whole app is ~150 lines;
  keep it reviewable at a glance.
- Working branch for this analysis: `claude/fable-analysis-models-45g09g`.
