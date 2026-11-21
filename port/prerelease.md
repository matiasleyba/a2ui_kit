# Before the pub.dev release

Findings held for one pass before publishing (`port/RULEBOOK.md` section 7, "Order and stopping rule"): inputs no
normal use sends, sub-pixel differences, platform branches, and rule proposals not yet adopted. Each line names its
source. Remove a line when it is fixed or decided, in the commit that does it.

## Charts (after the fourth chart batch, e987134c)

- The scroll keys move Flutter's line and page amounts; Chromium's are in `scroll/scrollable_area.cc`, not fetched
  (`TODO(port)` in `lib/src/foundation/chart/plot.dart`). Fetch it, or document the amounts (fourth batch,
  proposal 2).
- macOS: Chromium's `IS_MAC` branches (Alt+Up/Down page; Ctrl+Home/End off) are not ported; the scroll keys follow
  Windows and Linux (fourth batch, departures).
- A scroll key the browser does nothing with (a modified arrow): on the web `ignored`; off the web `handled` only
  where Flutter's default shortcuts act on it. Decide and write the §2 sentence (fourth batch, proposal 1).
- A centred fit-content line can sit up to 0.5px in (Flutter rounds intrinsic widths up): a documented difference
  or a test tolerance? (fourth batch, proposal 6).
- `ChartPlot.rowsKey` stands in for JavaScript row-object identity; exact for the pie, the only playground mark
  whose keys repeat (fourth batch, departures).
- TanStack Charts' `LICENSE` is not in `$A2UI_THIRDPARTY_SRC/tanstack/` (the agent's copy was refused; the fetched
  file waits in a scratch folder): the user's to copy. `NOTICE.md` already carries its text (fourth batch,
  proposal 5).

## Icons (after the phase 1 icons batch, 1d2d6c50)

- Arcs: `path_parsing` turns them into cubics; Chromium's own path builder is not fetched (sub-pixel).
- The A2UI name `constructor`: `A2UI_ICONS` is a plain object, so upstream throws; the port draws nothing.
- SkParagraph places an inline placeholder within about 0.01px of the baseline it reports; the test allows that.
- Zero-length round caps are left to Skia or Impeller.
- INV-006's one remaining difference: CopilotKit loads the `icons` map lazily (`media.tsx:76-103`), ours is compiled
  in. Kept as a documented difference (as the Chart's INV-027), unless the user wants it emulated.
- `generate.dart --check` and `test/generated_sync_test.dart` need the fetched lucide-react packages
  (`$A2UI_THIRDPARTY_SRC`): on a machine or CI without them those tests fail with the fetch instructions. Decide how
  CI gets them (or skips them) before publishing.
- The generated `lucide_icons.g.dart` is 22,335 lines: check pub.dev's package size and pana's score with it.

## The first phase's review (phase 1 fixes and the merge)

- A loose task list draws a bullet and no checkbox (`markdown.dart:198-200`: markdown 7.3.1 puts the checkbox inside
  the first paragraph).
- A ListItem with invalid props has its fallback wrapped as a list item.
- `openSafeUrl` (`links.dart:29`) reads a URL with Dart's `Uri`, where RULEBOOK §2's URL row says `whatwg_url.dart`;
  no ordinary URL was found where they differ. Decide (`onOpenUrl` takes a `Uri`).
- Math: after a stand-in, the space after an unknown command in text mode is kept; a typed U+2212 minus is an ordinary symbol in
  flutter_math_fork (`a − b` loses its spaces); the OS bold-text setting makes formulas bold; when one inline piece
  fails to build the whole source is drawn inside it; `\includegraphics`, `\html*` and `_maxStandIns` have no boundary
  tests; `CD` (commutative diagrams) is not typeset.
- A display formula wider than its line scrolls sideways (INV-103), and that scroll view takes no keyboard focus.
- Text: a Blockquote or Code inside a Text sits on the Text's line instead of taking its own (block-in-inline).
- INV-105's 13/16 Code size assumes the host's font size comes from a keyword; a chat that sets px or rem would get
  Chrome's 13px. CopilotKit's chat CSS is not in the clone: check.
- Before publishing: NOTICE.md's CopilotKit file table lacks rows for `node_guard.dart`, `validation/`,
  `failed_value.dart` and the envelope helper; CHANGELOG doesn't name `A2uiOperationValidator` or the fallbacks;
  README's "When a part can't be shown" doesn't name a function value that fails; `invalidPropsCode` and
  `renderFailedCode` aren't exported.

## The first phase's review (tier 1 data)

- `columnSizing: "equal"`: a word longer than its column breaks by characters; Chromium lets it overflow the cell.
- A lone TableRow, TableSection or TableCell in a Column is 100% wide (`table.dart:764`); the browser's anonymous
  table shrinks to fit.
- An anonymous cell (a non-cell child of a row, `table.dart:415, :464`) is middle-aligned; CSS's initial
  `vertical-align` is `baseline`.
- Flow: React writes `gap` after the longhands (layout.tsx:555, style-helpers.ts:123-129), so `gap` wins upstream;
  `flow.dart:22-23, :44` let `rowGap`/`columnGap` win. Its auto-fit minimum uses the column gap where upstream uses
  `props.gap ?? 4` (layout.tsx:556-559).
- Grid `columns` of Infinity or NaN from a function value throw in `floor()` (`grid.dart:33`).
- `table.dart:624-635`: an accessibility binding added later to an existing cell isn't watched until the node list
  changes.
- Cell padding resolves left to right only (`table.dart:782-787`).
- PERF: `hasRowspanStart` (`html_table.dart:1316`) costs rows × cells per `_compute`; a 1,000-row template table
  runs about 4M checks per pass.
- Svg text: an inherited TextStyle with a `foreground` makes `copyWith(color:)` assert (`svg_drawing.dart:586-591`).
- Svg text grows with the text scale while its shapes don't (`svg.dart:53`), so at 2.0 a label near the edge is
  clipped. Decide what a viewBox drawing does (Chrome on Android's text autosizing is not in the fetched sources).
- Flutter breaks a word longer than its line by characters (a Title "Photosynthesis:" at 320px and text scale 2.0);
  CSS lets it overflow. A documented difference, or follow CSS? (the running review, question 2)
- Decide with the user: in the playground and Material looks (`tableEdges` false), a children-mode table's cells
  have no side padding, as the playground's `display: contents` wrapper makes every cell first and last child
  (catalog.ts:93-110, styles.ts:75-76); neighbouring columns' text touches. An app can set `tableEdges: true`.

## The first phase's fix round (text, 7d79239b)

- A Link or an inline Text inside a Text is still one box; KaTeX's error span inside a Text is a box that wraps
  inside itself.
- Flutter may break after a formula piece where CSS doesn't (before a comma; UAX #14's IS class).
- Math: `\\` inside a group or `\left…\right` is red where KaTeX breaks inside; a `%` comment isn't skipped by the
  source scanner; a display formula with several `\\` lines scrolls each line on its own (CSS overflows the
  block); a `\tag` on such a formula sits on its first line (KaTeX: the last); an environment's tag rows nested in
  other content don't count that content's height.
- INV-320: equation numbers start at (1) in each formula; KaTeX counts over the whole page.
- A Markdown image inside a link loses the image (the link builder draws only text runs); inline `$$` maths in a
  paragraph is laid out as a Wrap of widgets.
- The standard look takes the host's type: in an app that sets none, a surface takes Material's bodyMedium (14px)
  unless the app wraps it in a `DefaultTextStyle` (README). The playground look, the default, sets its own.
- PERF: every new formula gets one off-screen build and layout (LRU 256, cleared when fonts change); each formula
  piece is a scroll view and so a repaint boundary; a Markdown answer rebuilds when a link's focus changes.
- No test puts a px Icon in a Text inside another Text's line, so the product of nested `InlineBoxScale`s is
  untested.

## The first phase's fix round (structure, 81df363d)

- INV-340: a grid span is clamped at 1000 tracks (`cssGridMaxTracks`); Chromium allows 10,000,000 because it keeps
  tracks as ranges (`grid_area.h:45`). §0 asks that a difference be forced by Flutter, and this one is forced by our
  `CssGrid` sizing every track as its own entry: track ranges (`TODO(port)` in `render_css_grid.dart`), or keep the
  clamp as a documented difference. Decide before publishing.
- Envelope: a label bound to data that is itself binding-shaped is read once by `KitEnvelope` (upstream's reading)
  and twice by a2ui_flutter's NodeView, which then names its node; the component keeps a node of its own under it
  (the engine case already queued, `accessibility.test.ts:14`).
- Touch focus: Chromium's 0.05px slop epsilon, each platform's own slop and the doubled slop for a touch with no
  contact size are not ported; a long press focuses at the finger's lift, where Chromium makes no tap of one; a pen
  focuses on pointer down, as a mouse (Chromium's stylus slop path not read).
- The keyboard-focusable scroller: "can scroll" uses Flutter's scroll extents (Chromium's pixel-snapped
  `IsScrollableNode` is in `spatial_navigation.cc`, not fetched); "holds something focusable" is recomputed after
  each build and on scroll-metrics changes, not when an inner element's focusability changes on its own.
- The Table wrapper's baseline is its bottom edge (a scroll container's last baseline, CSS Align 3 §9.1); in a
  first-baseline flex alignment Chromium may take the table's first row (not read).
- Six Chromium files (`grid_area.h`, `gesture_manager.cc`, four `ui/events/gesture_detection` files) were fetched
  with curl at the tag, with no hash to check them against (as the other Chromium files).

## Tier 1 data (after the tier 1 data batch, 97aa391c)

- Table layout uses doubles where Chromium uses LayoutUnit (1/64px): sub-pixel differences.
- Tables are left-to-right only; a fixed table's max intrinsic width is 1e6 (`kTableMaxInlineSize`); column
  percentages in intrinsic sizing; white space at line breaks in cells.
- A cell's inline-level classification covers Badge, Link, a non-block Button, Text, Icon, Bold, Italic, Underline,
  Strikethrough and a non-block Math; anything else is a block.
- The envelope's `wrapped` condition mirrors a2ui_flutter's NodeView and must follow it if NodeView changes.
- Svg: percent widths under 100% at the surface root.
- Flow: its columns template uses `gap` where CSS uses `columnGap`, when the two differ; a FlowItem with `clip` or
  `scrollable` still grows past its ratio.
- Five Chromium files were fetched with curl from chromium.googlesource.com (no hash exists to check them against, as
  for the other Chromium files).

## Components (after the phase 1 components batch, b0d083b4)

- A percentage `border-radius` gives no radius (`TODO(port)` in `css_length.dart`).
- A scroll container's line and page lengths are Flutter's: Chromium's `scrollable_area.cc` is not fetched
  (`TODO(port)` in `browser_scroll.dart`, now the one home of the scroll keys; the same gap as the chart plot's,
  above).
- The Select's `:focus-visible` test checks the ring only after Escape (the menu takes the focus on the press).

## Tier 1 text (after the tier 1 text batch, aab384ce)

- Math: the error tooltip is flutter_math_fork's message, without KaTeX's position context for some errors
  (`\frac{a`: KaTeX adds "at end of input: \frac{a").
- Math: an inline formula sits about 0.23px above the Text's baseline (SkParagraph's placeholder); the line uses only
  KaTeX's strut, so in the playground look its height can be off by under a pixel.
- Math: an untrusted command's arguments are skipped by brace matching, not KaTeX's URL argument lexer; an unknown
  command inside a macro's expansion fails the whole formula.
- Bold, Italic, Underline, Strikethrough: an empty one adds nothing to its line's height (CSS counts an empty
  inline box).
- Code: its text cannot be selected or copied; tab stops count code points, so wide characters can misalign; a
  carriage return is drawn as Flutter draws it; the scrollbar follows Flutter's platform `ScrollBehavior`.

## Functions (after the phase 1 functions batch, 1a63f0dd)

- UTS #46 is not ported (INV-201): on the web path, `openUrl` refuses a non-ASCII or `xn--` host, which the browser
  would open; its queued test is the `例え.jp` case in `test/parity/functions_test.dart`.
- whatwg-url walks the userinfo buffer by UTF-16 unit (`url-state-machine.js:763-765`); the port follows the spec's
  code points. They differ only for a character beyond the BMP in a URL's username or password.
- Malformed UTF-8 or a BOM in a percent-encoded host: Dart's decoder and `TextDecoder` may differ; the host is refused
  either way today.
- `failedFunctionValueOf`: a value that keeps failing with a new message keeps the old message until the props
  change.
- The engine refuses an `@index` offset that isn't a finite number, where CopilotKit treats it as 0 (a2ui_core 0.8.0).

## Validation (after the phase 1 validation batch, 0c57cf17)

- `checks` are left out of the render check (a2ui_core hands back the raw rules, `generic_binder.dart:436`): a check
  condition bound to data of the wrong type shows an alert upstream and none here.
- Data under a bound prop whose keys start with `@` is refused by a2ui_core's nested-call check, so it shows invalid
  props where CopilotKit would not.
- The alert's wording is json_schema_builder's, not Zod's.
- The validator refuses `agentFunctionResponse` (as upstream: not one of CopilotKit's five kinds) and the path
  segments `constructor`, `__proto__` and `prototype`.
- `createSurface.metadata` extension keys are not sanitised.
- a2ui_core still reports `CYCLIC_REFERENCE` for a cycle, which upstream does not (`node_resolver.dart:565-570`).
- Retry's look: Chromium's `html.css` is not fetched, so the browser's own `<button>` look is not drawn (`TODO(port)`
  in `node_guard.dart`).
