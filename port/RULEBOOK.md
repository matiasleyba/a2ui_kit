# Porting rulebook: CopilotKit A2UI catalog (React) → a2ui_kit (Flutter)

> **The meta-rule: if two agents could answer a question differently, the answer goes in this file.**
> Every implementer, reviewer and fixer reads this whole file before touching code. It is read-only inside a loop:
> an agent who finds a missing or wrong rule reports it, and the orchestrator amends this file between batches
> (section 8). The shape follows Anthropic's code-migration kit
> (github.com/anthropics/code-migration-kit-with-claude-code, `templates/RULEBOOK.md`) and the article
> "How Anthropic runs large-scale code migrations with Claude Code".
>
> Rules marked *(from review)* were findings in the phase 1 reviews. They are rules now so that no later component
> repeats them.

## 0. Scope and posture

- **Structure-preserving, per component.** One CopilotKit component (its Zod schema, its React renderer and its CSS)
  becomes one Dart component. You are translating, not improving. A web mechanism Flutter lacks (CSS layout, browser
  form validation, iframes) has exactly one replacement, listed in section 2. Use it, never a second one.
- **Sources of truth, in this order:**
  1. CopilotKit's own tests, ported into `test/parity/` (section 6). A failing parity test is a bug in the port.
  2. The Zod schema and `test/fixtures/copilotkit/catalog.json` for props, defaults, enums and required fields.
  3. The React renderer and its CSS for structure, tokens, interaction order and edge cases.
  4. Where the behaviour lives in a library CopilotKit uses and the clone doesn't hold (recharts, d3, TanStack
     Charts, Streamdown, lucide-react): that library's **published source at the version CopilotKit's lockfile
     pins**, read (never installed or run) from unpkg.com or the library's GitHub tag, and cited by file and line in
     a comment. **Never from memory**, and never "by eye" where the source decides it. Copies live in
     `$A2UI_THIRDPARTY_SRC/<package>@<version>/`: whole published packages from registry.npmjs.org,
     each checked against the sha512 in CopilotKit's `pnpm-lock.yaml`. There are recharts 3.10.1,
     decimal.js-light 2.5.1, es-toolkit 1.43.0, d3-array 3.2.4, d3-scale 4.0.2, d3-shape 3.2.0,
     d3-interpolate 3.0.1, d3-path 3.1.0, d3-format 3.1.0, d3-time 3.1.0, d3-time-format 4.1.0, d3-color 3.1.0
     and internmap 2.0.3 (fetched 2026-11-19), streamdown 1.6.11 (fetched 2026-11-19 by the judge's second fix
     round), whatwg-url 16.0.1, tr46 6.0.0 and punycode 2.3.1 (fetched 2026-11-21 by the phase 1 functions
     batch), lucide-react 0.525.0 (react-core's) and 1.57.0 (the playground's own components'; fetched 2026-11-21
     by the phase 1 icons batch), katex 0.16.27 (re-fetched and checked 2026-11-21 by the tier 1 text batch),
     Chromium 159.0.8154.13 (`chromium@159.0.8154.13\`: the stable tag on 2026-11-19, single files from
     chromium.googlesource.com with its BSD `LICENSE`: `core/input/keyboard_event_manager.{cc,h}`,
     `core/input/scroll_manager.cc`, `core/dom/{node,element,document}.cc`, `core/css/selector_checker.cc`, and
     (the icons batch) `core/css/svg.css`, `core/svg/svg_{rect,circle,ellipse,line,poly,polygon,polyline}_element.cc`,
     (the tier 1 text batch) `core/html/resources/html.css`, `core/css/resolver/{font_builder,style_builder_converter}.cc`,
     `core/css/font_size_functions.cc`, `platform/fonts/font_description.{h,cc}`, (the tier 1 data batch)
     `core/layout/table/` with `layout_table_cell.h` and `table_constants.h`,
     `core/html/html_table_cell_element.{cc,h}`, `core/html/parser/html_parser_idioms.cc`, under
     `third_party/blink/renderer/`; read, never ported as code), plus `tanstack\` (@tanstack/charts 1.1.0, whose `dist/react/` is
     react-charts). The older partial folders (`recharts\`, `d3\`, `tanstack-react\`) are superseded. Fetch a
     new package the same way. A site whose source isn't fetched carries
     `TODO(port): <file> not fetched`, and the batch report lists those files.

     Behaviour the **browser** decides (`:focus-visible`, which keys scroll and what, line breaking, stacking order)
     is read the same way: from a spec's normative text, or from the engine's source (Chromium, at a stated tag),
     fetched to `$A2UI_THIRDPARTY_SRC/chromium@<tag>/<path>` and cited by line. Never from a
     spec's non-normative heuristic, and never from memory *(RC3-5)*. JavaScript behaviour that ECMAScript leaves
     implementation-defined (the order an inconsistent comparator sorts into) is ported from an engine only where
     the port's data can reach it: the argument names the source lines that block the input, a test pins that
     invariant, and otherwise the port uses what the spec does define (a stable sort) and says so in one comment.
     An engine's code, when ported, is a library like the others: named at a version, fetched, cited, in
     `NOTICE.md`, its licence weight to the user (§1). A JavaScript engine may serve as an oracle only for a
     script of one's own, never the clone or a package; the script and the engine's version sit beside the test,
     and §9 logs the run *(RC3-8: a TimSort written from memory for orders no data reaches)*.
  5. The live playground (https://a2ui.open.bot) for the look, where the sources leave it open.

  `PORT_PLAN.md` section 11, earlier briefs and reports are notes, not truth.
- **The clone** at `$COPILOTKIT_SRC` (commit ff6f3b03) is read only and never run: no npm, no
  install, no node. This follows the user's 2026-11-18 choice to convert CopilotKit's samples by hand rather than run
  anything from its repo.
- **The referee is cheap, so it runs inside the loop.** `flutter analyze` and the component's own test files run on
  every unit. The full suite runs once per batch.
- **Faithful first.** A slow but faithful translation is fine: mark it `PERF(port):` with one line on the fast
  version.
- **Where Flutter could go either way, CopilotKit's behaviour wins.** A deliberate difference needs a reason
  Flutter forces (no inset shadow, no native `<select>`), never a preference. The difference states the browser's
  outcome from the cited spec sections (line breaking, intrinsic sizes, `vertical-align`), and "Flutter forces it"
  names the missing API; when other Flutter API reaches the browser's outcome, the difference is not forced
  *(RC3-4: INV-053)*. Decided by this rule (2026-11-19, the
  judge fix batch's questions):
  - `openUrl` takes upstream's page path on the web (relative URLs against the page) and its no-page path
    elsewhere, as CopilotKit does in browsers and React Native;
  - a prop of the wrong type shows the alert and reports, as upstream does;
  - the envelope's name goes only on the components upstream spreads it onto;
  - a cycle shows upstream's "cyclic reference" alert, and a component that throws shows upstream's fallback:
    sized like a block, never Flutter's unbounded `ErrorWidget`, with its siblings usable;
  - a table, the Chart's visually hidden data table included, carries the table, row, cell and column-header roles
    (Flutter's `SemanticsRole` has them), never rows that only read each cell after its column (INV-034, JS4).

## 1. Ecosystem: what we use and what we ban

| Area | Decision | Why |
|---|---|---|
| A2UI engine | `a2ui_core` ^0.8.0 and `a2ui_flutter` ^0.4.0. Never fork or patch them; work around them in our layer (ids: section 2) | upstream engine; apps share it |
| Icons | lucide-react's own icon nodes at the version each renderer's lockfile pins (0.525.0 in react-core, 1.57.0 in the playground), fetched per §0 item 4 and generated into a Dart table (one node table, a name map per version), drawn as lucide-react draws them: stroked paths on the 24 grid, round caps and joins, the stroke width the renderer passes (lucide-react's default 2), so `strokeWeight` is honoured. Not `flutter_lucide` | CopilotKit draws lucide-react's SVG. A font has one stroke width, lacks the icons Lucide 1.0 removed (the brands) and ties names to codepoints nothing keeps stable, so INV-006's differences are not forced and §0 overrules them *(RC5, RC6)* |
| Markdown | `flutter_markdown_plus` + `markdown`, `$$…$$` maths through `flutter_math_fork`, `repairIncompleteMarkdown` for streaming | nearest to Streamdown |
| Number, date, plural formatting | the package's helpers only (`lib/src/functions/formatting.dart`, `formatPlaygroundNumber`); never call `intl`'s `NumberFormat` or `DateFormat` straight from a component | parity with JavaScript `Intl` (section 2) |
| Maths typesetting (the Math component) | `flutter_math_fork` typesets; KaTeX 0.16.27's outcome around it is ported in our layer from KaTeX's source (errors and their colour, unknown and untrusted commands, where an inline formula may break and the glue kept at a break). What the engine itself typesets differently is a documented difference (INV-100) | CopilotKit renders with `katex.renderToString` (text.tsx:401-409); no Dart port of KaTeX exists *(from the tier 1 text batch)* |
| Links | `url_launcher`, safe schemes only (http, https, mailto) | |
| Function schemas | `json_schema_builder`, only to build a2ui_core's `FunctionApi.argumentSchema` (`functions/functions.dart`) | the engine's function API takes these schemas (row added after the fact: the chart review fixes) |
| SVG path data | `path_parsing`, for the Icon's Lucide paths (`foundation/icons/lucide.dart`) and the Svg component's `paths` (one parser, shared); never `flutter_svg` (the Svg component draws primitives, not SVG files) | Lucide icons and Svg's paths are SVG path data (row added after the fact: the chart review fixes; Svg added for tier 1) |
| Charts | `CustomPaint` on the chart foundation (`lib/src/foundation/chart/`: scales, curves, arcs, `ChartPlot`); every chart, phase 2b's included, builds on it. `fl_chart` is **not** a dependency | fl_chart's curve is Catmull-Rom, not the monotone cubic, and it has no band or group padding, pad angle or rounded arcs (port note 2a-1) |
| Maps | `flutter_map`; tile source is an **open question for the user** | PORT_PLAN §10, question 3 |
| Goldens | `alchemist` (CI variant draws text as blocks; colours of custom-painted text can't be checked there) | |
| Platform fakes in tests | `url_launcher_platform_interface` (dev only): a fake `UrlLauncherPlatform.instance` records what a link opens and its target | upstream spies on `window.open` (from the judge fix batch) |
| Lints | `very_good_analysis`; 0 issues, infos included | pub.dev |
| Any other dependency | **none** without a row here. The orchestrator adds the row; anything with licence, network or privacy weight goes to the user first | |
| Banned | `dynamic` leaks, unchecked casts outside the JSON helpers, network access in tests, Material default looks where CopilotKit has a token, hard-coded `Color`s in components. A third-party library's literal colour (recharts' `#ccc`, `#808080`, `#fff`, Tailwind's `bg-black/5`) becomes a theme token named after that library default, whose value is the literal *(from review, 2a)* | |

## 2. Web constructs with no Flutter equivalent: one canonical mapping each

An implementer who invents a second mapping for a listed construct breaks a rule. A reviewer who sees an unlisted
construct flags it for this table.

| Web construct | The one translation | Notes |
|---|---|---|
| CSS flexbox (gap, wrap, grow, shrink, `min-size: auto`) | `CssFlex` / `CssFlexItem` (`foundation/layout/render_css_flex.dart`) | never Flutter `Row`/`Column`/`Flex` for a CSS flex box: they don't shrink or wrap like CSS, and a non-flex child in a `Row` throws on overflow *(from review: List value overflow)*. The rule is about upstream's element: where it is **neither a flex box nor a grid** (SVG, a canvas, block or inline flow, a library's own absolute layout), use the plain Flutter layout that does what that element does, and name the upstream element in a comment beside it *(from phase 2a)* |
| CSS grid | `CssGrid` (`render_css_grid.dart`), also inside a library's markup (TanStack's tooltip grid); tracks sized as CSS Grid L1 §11.4-11.8 do, `auto`, `min-content` and `max-content` included | `rows` is not applied yet: documented difference *(from review, 2a: a tooltip grid built with `Row`)*. Items spanning several tracks are a `TODO(port)` in `render_css_grid.dart` |
| `place-items`, `justify-items`, `align-items` on a grid | CssGrid's item alignment. Until CssGrid has it, a grid of one item in one track maps to `Center` (the same layout), and any other case is a `TODO(port)` | INV-051 *(from review, 2a regen: RR37, the donut centre)* |
| `overflow: auto` / `scrollable` | `scrollArea` (`standard/layout/flex_container.dart`): a scroll view inside a flex item whose min sizes are 0 | a scroll container's automatic minimum size is 0 in CSS *(from review: clipped instead of scrolling)* |
| CSS lengths (`n` × 4px scale, px, em, rem, %) | `A2uiLength` (`foundation/css/css_length.dart`) | a unitless string is invalid, not px; negative values are ignored or clamped as CSS does, never asserted *(from review)* |
| Container query units (`cqi`) | `InlineSizeContainer` | |
| `clamp(min, fit, max)` font sizing | the fit wins over a text-scaled floor, so content never leaves its box at text scale 2.0 | *(from review: KPI overflow)* |
| CSS custom properties and colours | `A2uiKitTheme` tokens, light and dark, playground and standard looks; oklch is clipped to sRGB | |
| Child combinator selectors (`>`) in the standard styles | check the playground's `display: contents` wrappers (`catalog.ts:99-112`): such a rule does not match in the playground look. Gate it with a theme flag (example: `keyValueRows`) | *(from review)* |
| JavaScript truthiness | `truthOf` (= `Boolean(x)`) | `"Ada"` is true *(from review)* |
| `Math.*`, `%` | exact JavaScript semantics (`%` keeps the dividend's sign; `log10` exact for powers of ten) | *(from review)* |
| Loop bounds, comparisons, tolerances, rounding (`<` vs `<=`, `Math.round` vs floor, an epsilon) | copied from the source exactly; a tolerance or rounding the source doesn't have is a finding | *(from review, 2a: a `.99 * step` bound dropped a tick; bar sizes floored where recharts rounds)* |
| `Object.keys`, `for…in`, `Object.entries` over JSON | `jsObjectKeys` (`foundation/`, created by the 2a fix batch): integer-like keys (up to 2^32 − 2) first in ascending order, then the rest in insertion order, as ECMAScript does. Never a Dart map's plain order | *(from review, 2a: year columns `"2023"`, `"2024"` swapped)* |
| Text measured inside a `RenderObject` | mix in `RelayoutWhenSystemFontsChangeMixin` and clear every text cache in `systemFontsDidChange` | a web font that loads late leaves a cached size wrong *(from review, 2a)* |
| JavaScript semantics helpers (`jsMathRound`, `jsLog10`, `jsNumberOf`, `jsObjectKeys`, `JsDecimal`) | exported from one place each (`functions/calc.dart`, `foundation/js_object_keys.dart`, `foundation/chart/js_decimal.dart`) and imported; a private copy is a finding | *(from the 2a fix batch: a private round in the TanStack scale)* |
| A library component's props CopilotKit doesn't pass | the library's own defaults (`legendDefaultProps`, `Tooltip`'s `defaultProps`, `YAxis`'s `width`), read from source and listed in a comment where the component is ported; each default is behaviour, and one not ported is a finding | *(from review, 2a regen: the legend's default `itemSorter: 'value'` sorts by name)* |
| A library's interaction (keys, focus, pointer, hover, transitions) | ported from its handlers and middleware like its geometry: the same keys, wrap or clamp, what focus shows, what Escape hides, the same timing, which nested elements are tab stops (`tabIndex`), and the focus and blur pairs a move between them fires (React's bubbling `onFocus`/`onBlur`). A key or behaviour the source doesn't have is a finding. An element with `tabIndex >= 0` takes focus on pointer down, as the browser gives it, and a press on the element that already has focus fires no blur and focus. **Every key the library doesn't prevent keeps the browser's default**, whether the library left it alone (recharts' Up and Down) or acted on it first (its Left, Right and Enter: `RechartsWrapper.js:274-276` dispatches the key and calls no `preventDefault`). The browser's scroll keys, from Chromium 159.0.8154.13 (`keyboard_event_manager.cc`: `MapKeyCodeForScroll` :67-180, `DefaultSpaceEventHandler` :493-525; Windows and Linux): an arrow scrolls a line with no modifier held (Shift, Ctrl or Meta stops it; Alt is a system key); Home and End scroll to the start or end, with or without Ctrl (Shift or Meta stops them); Page Up and Down scroll a page, unmodified only; Space pages forward and Shift+Space back (Ctrl, Alt or Meta stops it). Each scrolls the nearest ancestor that can scroll that way and passes outward (`BubblingScroll`, `LogicalScroll`), never Flutter's nearest scrollable of any axis. On the web the handler returns `ignored` only for a key whose default Flutter's web shortcuts give exactly (an unmodified arrow, Page Up/Down) and whose nearest scrollable is the one the browser would scroll; it invokes the rest itself (Home, End, Ctrl+Home, Ctrl+End, Shift+Space, Space's scroll) and returns `handled`, and returns `handled` where the browser's default on that element is nothing (Enter on an `<svg>`) *(RC3-6)*. Off the web Flutter's defaults are not a browser's (an arrow moves the focus, Enter activates): the handler invokes the browser's default itself (`ScrollIntent` through `Actions.maybeInvoke` for the scroll keys) and returns `handled`, so the focus stays. Never `skipRemainingHandlers`. Both paths are tested, the web one on the VM through the platform override (§6 item 2) *(RC2)* | *(from review, 2a regen: Up and Down added, the pie wrapped, nothing on focus; the chart review fixes: the pie's `<g>` is a second tab stop)* |
| A library's text layout (recharts' `Text` with `width`, word wrap, `maxLines`) | ported from its source, line breaking included: never one clipped line where the library wraps; and never a word broken where CSS keeps it whole: where the source's `overflow-wrap` is `normal`, the text gets its min-intrinsic width and overflows (Flutter breaks an over-long word by characters) | *(from review, 2a regen: horizontal category labels; RC3-9: a donut total broken into lines of digits)* |
| SVG or canvas text from a library (`<text>` with `dy`, `text-anchor`) | placed by its baseline: `dy` in em plus the font's alphabetic baseline, never by a Flutter line box | *(from the 2a fix batch)* |
| An SVG element's box (`getBBox`, the box an outline or a hit test uses) | the tight box of what it draws (an arc's extremes, not its control points), never `Path.getBounds()` | `Path.getBounds()` includes control points: a 184px pie's group box came out 318×276 *(RR2-2)* |
| `overflow: hidden` (or `auto`, `scroll`, `clip`) on a box with a border or a radius | a clip inside the border: the padding box, each corner's radius less that side's border width (CSS Overflow 3, 3.1; CSS Backgrounds 3, 5.3), applied to every descendant whose containing block lies inside the box; never `clipBehavior` on the decorated box itself | `Container(clipBehavior:)` clips at the border box, so a tooltip leaving the playground's figure painted over its border (the third chart batch's follow-up); `CssFlex` clips at the border box too (phase 1 fix batch) |
| A widget that shows or hides a decoration (a focus ring, a highlight) | keeps one tree shape: a `CustomPaint` with a null painter when hidden, or keyed siblings that keep each child's element, never a wrapper that comes and goes | a wrapper that comes and goes remounts stateful children: a text field lost its editor (INV-032) *(from the 2a fix batch)* |
| A library's default colour (recharts `#ccc`, SVG black) | an `A2uiColorToken` named `<library>-<what>` (`recharts-cursor`, `svg-text`), the same value in every look, documented as not addressable by props | *(from the 2a fix batch)* |
| `Intl.NumberFormat`, `DateTimeFormat`, `PluralRules` | the package's formatting helpers: shortest-decimal rounding, half away from zero; a currency's own digits; the locale's plural category | `1.005` → `"1.01"`, JPY `1234.5` → `¥1,235` *(from review)* |
| React local state over a prop (`useState(prop)`) for user input | owned data: every input write marks its path (`A2uiUserOwnedData`); agent writes at or below an owned path are merged as CopilotKit's `mergeOwnedValues` does | an agent re-send must never wipe what the user typed *(from review)* |
| A native change event | write only when the value changes; re-choosing the chosen option writes nothing | *(from review)* |
| `<a href>`, `<button>`, any clickable | `Activatable` (`standard/inputs/controls.dart`): focusable, Enter and Space activate, a visible focus state | every clickable must work by keyboard *(from review)* |
| The browser's own focus outline: a focusable element (`tabIndex`, a native control) with no focus style of its own, such as recharts' `<svg>` and the pie's `<g>` | `FocusRing` (`controls.dart`) at offset 0, in the outline colour CopilotKit gives every element under `[data-copilotkit]` (`outline-ring/50`, `src/v2/styles/globals.css:143-146`), shown when the focus is visible by `:focus-visible`'s heuristic as Chrome applies it: focus that arrives by keyboard shows it; focus a pointer press gave (mouse, touch or pen) shows nothing until a key is pressed while Ctrl, Alt and Meta are all up, Shift and Escape included (Chromium 159.0.8154.13: `keyboard_event_manager.cc:355-359` calls `Node::UpdateHadKeyboardEvent`, `node.cc:3644-3660`; the match is `selector_checker.cc:3863-3902`: text input, or a last focus not from the mouse, or a keyboard event since; a mouse focus clears that flag, `element.cc:8907-8909`, and a press on the element that already has focus changes nothing) *(RC3-5: the review's recollection, modifiers and Escape not counting, is Chromium's user-activation rule at :250-259, not focus)*; an element that takes text input shows it however it was focused. A mouse or pen press focuses on pointer down; a touch focuses on a tap and never on a drag, a touch that moves more than 15px (Chromium 159.0.8154.13: `gesture_detector.cc:337, :634-673`, `gesture_configuration.h:247`); `FocusVisibility` (`foundation/interaction/focus_visible.dart`) is the one home of these rules, for every focusable element *(from the first phase's fix round: running review B1)*. Flutter's highlight mode is not that rule (a mouse press never changes it, and desktop starts in `traditional`), so an element that focuses on press tracks how its focus came, and its tests press with `PointerDeviceKind.mouse` in `traditional` mode *(RC1)*. `outline: auto` is drawn by the browser, so its exact width and colour are a documented difference | recharts sets no outline and CopilotKit removes none, so the user agent's one shows (§0); drawing none was INV-049 *(from the chart review fixes)* |
| Browser constraint validation (`required`, `type=email/url/number`, implicit submission) | `A2uiFormScope` / `A2uiFormController`: Chrome's English messages under the field, first invalid field focused, fields and the default button in **tree order** | *(from review)* |
| `checks` | `firstFailedCheck` (CopilotKit's port): a missing or null condition passes; the rule's message wins. Never a2ui_core's `validationResults` | *(from review)* |
| An HTML table (`<table>`, `<thead>`/`<tbody>`, `<tr>`, `<td>`/`<th>`, `colspan`, `rowspan`) | `RenderHtmlTable` (`foundation/layout/html_table.dart`), one flat render object porting Chromium 159.0.8154.13's LayoutNG table layout; semantics by row (a table node, a row node per row, column headers and cells); a cell's content in block flow inside an `HtmlTableCellBox` (the cell's baseline: its first line's, else the bottom of its content edge, CSS 2.1 §17.5.3), inline-level items on lines (what is inline in the browser: Badge, Link, a non-block Button, an inline Text or Icon, Bold, Italic, Underline, Strikethrough, a Math without `block`), anything else a block; a TableSection, TableRow or TableCell whose props fail the check (`hasValidProps`) is built as its node, so its own guard shows the fallback in its place; a fallback is content that is not a row group, row or cell (CSS 2.1 §17.2.1), so it gets anonymous boxes | *(from the tier 1 data batch; the inline list widened by its reading review; the cell box, the failing parts and the fallback's place by the first phase's fix round)* |
| A replaced element with no size of its own (an `<svg>` with neither width nor height) | the CSS default object size, 300×150 (CSS Images 3, 4.1), with the viewBox's ratio when it has one | *(from the tier 1 data batch: Svg)* |
| A focusable scroll container (`[data-a2ui-scroll]`, `tabIndex` 0 with `overflow: auto`) | `FocusableScrollBox` (`components/standard/layout/focusable_scroll_box.dart`), the one scroll container (Code, Column, Row, Box, Card, Grid, Flow, the Table's wrapper), its own scroll views marked with `FocusableScrollBox.scrollView`, with the scroll keys of `foundation/interaction/browser_scroll.dart`, the one home of Chromium's scroll-key rules (the chart plot calls `browserKeyDefault`); Enter does nothing on it (CopilotKit's clickable boxes act only when `event.target === currentTarget`, `inputs.tsx:421-426`, `composites.tsx:512-518`). Its keyboard-scroller mode (the Table's wrapper) is Chrome's keyboard-focusable scroller (`element.cc:9132-9269`): a tab stop only while it can scroll and holds nothing focusable, never focused by a press | *(from the tier 1 text batch: Code; one home by the first phase's fix round)* |
| A `RenderBox` of ours | answers `computeDryBaseline` with the baseline its layout has; a box with none answers its bottom edge | a null makes any proxy above it throw in debug (a Svg or Table in a baseline Row or a `WidgetSpan`) *(from the first phase's fix round)* |
| A grid item's `span ${n}` (Flow's `span`/`rowSpan`, GridItem) | `cssGridSpanOf` (`foundation/layout/render_css_grid.dart`): a positive whole number, as CSS reads it (a fraction, a negative, 1e21 and up and Infinity give one track), at most `cssGridMaxTracks` (1000; Chromium's 10,000,000, `grid_area.h:45`, needs track ranges in `CssGrid`: INV-340) | *(from the first phase's fix round: a huge span froze the layout)* |
| Inline children of a Text (Bold, Italic, Underline, Strikethrough, an inline Math) | their runs join the Text's paragraph and break with its line, never one `WidgetSpan` box each; `isInlineInText` is the one test of inline against block. The runs are `InlineRun`s (`foundation/text/inline_element.dart`: words, atoms, breaks; `inlineRunSpans`), given by each component's run builder (`boldRuns`, `mathRuns`, …) through the Text's `_inlineRuns`; a hosted child's props are watched with `ChildPropsBuilder`, and one whose props fail the render check (`nodeProblemOf`) or whose type the app overrides stays one box. A fixed-px box on a Text's line divides its size by `InlineBoxScale`, the line's text scale multiplied through nested lines | CSS 2.1 9.2.2: an inline box's words continue its line (INV-104, INV-108) *(from the tier 1 text batch; the runs by the first phase's fix round)* |
| A third-party render object with no correct intrinsic sizes or dry baseline (flutter_math_fork) | measured off-screen from a fresh tree of its own and cached (`_MeasuredMath`, `math.dart`), never by sharing the drawn tree: the library caches widgets that hold `GlobalKey`s, so a shared tree lets the measurement take the drawn elements. A second user moves it to `foundation/` | a Math in a Row, a cell or a Text's line threw in debug *(from the first phase's fix round)* |
| A block container at a surface's root (Column, Card, Markdown, …) | gives its pieces explicit semantics child nodes in order (`explicitChildNodes`, from `catalog.dart` into `wrapKitRoot`); a Title is a heading node of its own. A reading-order test mounts the surface in a `ListView`, as a chat does: the default harness's scroll view hides merging | a screen reader read a whole answer as one node *(from the first phase's fix round: running review B2)* |
| An operation CopilotKit refuses (`validate-operation.ts`) | `A2uiOperationValidator` (`lib/src/validation/`), the first stage, before the id normaliser, so the operation is checked as the agent sent it; each operation of a batch against the surfaces the earlier ones leave | *(from the phase 1 validation batch: the normaliser hid an empty template id)* |
| A part that can't be shown: invalid props, a component that throws, a cyclic reference, an unknown type | `NodeGuard` and `NodeFallback` (`components/node_guard.dart`), round every node the catalog builds; a container keeps a child by `isDrawnChild`, never `!isPlaceholder`, so the fallbacks for a cycle and an unknown type are drawn | *(from the phase 1 validation batch)* |
| A function value (`formatString`'s `${…}`, a validator's result, `@index`) | CopilotKit's resolver, ported in our layer (`lib/src/functions/`: `format_string.dart`, `validators.dart`'s `validationScope`): its grammar, its error wording, a validator's result kept only as a check's condition and a boolean everywhere else. Never a2ui_core's `ExpressionParser`; what the engine still decides first is a queued test naming the engine's line | *(from the phase 1 functions batch)* |
| `new URL(url, base)`, any URL a browser parses | `whatwg_url.dart` (`foundation/url/`, whatwg-url 16.0.1's state machine). Never Dart's `Uri` for a URL the browser would parse; `Uri` only where the URL is already the parser's output | Dart's `Uri` and the URL Standard disagree on hosts, paths and percent-encoding *(from the phase 1 functions batch)* |
| CSS transitions and keyframes | an `AnimationController` with a start time per animated element; words or items already animating keep their own clock | *(from review: Heading snap)* |
| `prefers-reduced-motion` | `MediaQuery.disableAnimationsOf(context)`: show the final state, no motion | |
| `<img>` | the image loader in `standard/media/image.dart`: natural size from `ImageInfo`, **every `ImageInfo` disposed**; web non-CORS fallback reads the element's natural size; a failed image shows its description | *(from review)* |
| Inline children inside a Text | `WidgetSpan` wrapped in `MediaQuery.withNoTextScaling` + `DefaultTextStyle.merge` with the Text's style | no double scaling *(from review)*. Flutter scales a `WidgetSpan`'s child by the paragraph's text scale, so a library's fixed-px box inside one (a legend's dot and gap) is sized divided by that factor, and tested at text scale 2.0 *(RC3)*. Where no break may follow the inline box (an ancestor's `nowrap`), it is a no-break text run (U+00A0, UAX #14 LB12, led by a U+2060 so SkParagraph doesn't shift a line that starts letter-spaced) given the box's advance (measured without the style's own letter spacing), with the box painted over that run's place, never a `WidgetSpan`: Flutter's line wrapper breaks after a placeholder whatever follows it, a word joiner included (observed by the third chart batch) *(RC3-4)* |
| CSS stacking order (`z-index`) | a box with a positive `z-index` paints after every `z-index: auto` box of its stacking context, whatever the tree order (CSS 2.1 §9.9.1, Appendix E): the port puts it last in the nearest Flutter paint order that holds both (an underlay slot beneath it, or an overlay scoped to the clipping ancestor), never only last in its own subtree | TanStack's tooltip (`z-index: 1`) went under the donut's centre total *(RC3-1)* |
| Component ids CopilotKit allows and a2ui_core rejects (`spacer-l`) | `A2uiIdNormalizer` on the way in, its `outbound*` methods on the way out. Components never touch ids | Table `columns`/`rows` cells included |
| Writable props and event arguments | the generated tables in `lib/src/document/behaviour.g.dart`; never hand-list them | |
| Native `<select>` | a Material menu | documented difference |
| `inset` box-shadow with 0 blur and 0 offset (a spread only, as TanStack's swatch ring) | a border of the spread's width inside the box | the same pixels (INV-052) *(from review, 2a regen: RR24)* |
| any other `inset` box-shadow | not drawable in Flutter | documented difference |
| Iframes (HtmlView, VideoEmbed, McpApp) | phase 3: a delegate, with the web implementation behind conditional imports | to be decided in phase 3; documented difference on other platforms |

**The documented-difference rule.** A deliberate difference from CopilotKit appears in three places, with the same
wording: the component's doc comment, the README "Differences" table, and a row in `port/inventory.tsv`. Missing
from any one is a finding.

**The BUG rule.** When CopilotKit's behaviour is itself wrong (a crash, malformed output), reproduce it and mark the
site `// BUG(port): <repro>`. The parity test asserts CopilotKit's behaviour. A fix ships later as its own flagged
change, after the user agrees.

**The UNKNOWN rule.** When neither this table nor the inventory decides a case, translate to the most conservative
option, mark it `// TODO(port): <the open question>`, and keep moving. UNKNOWN is an answer; a stalled batch is not.

## 3. The escape hatches, used visibly

- A lint suppression (`// ignore:`) carries its reason on the same line, in parentheses after the names:
  `// ignore: name (reason)`. The analyzer reads a word after a comma as one more lint name.
- A cast from JSON goes through the checked prop helpers (`ComponentProps.string`, `number`, `list`…), never a bare
  `as`.
- Deferred decisions carry exactly these greppable markers, in this format: `// TODO(port): …`,
  `// PERF(port): …`, `// BUG(port): …`. They are the queue for later work. Never vary the format.

## 4. Names and paths

Done-ness is read from disk, so these are rules, not style.

- A standard component `X` lives in `lib/src/components/standard/<group>/<x_snake>.dart`; a playground component in
  `lib/src/components/playground/<group>/<x_snake>.dart`. `<group>` is the folder for its catalog category; a new
  category gets a new folder, recorded in `port/manifest.tsv`.
- Shared helpers live in `lib/src/foundation/<area>/` (layout, css, text, format, icons, interaction, chart). Before
  writing a helper, look there. A local copy of a shared helper is a finding.
- Tests:
  - component tests: `test/components/<area>_components_test.dart`;
  - ported CopilotKit tests: `test/parity/<upstream file stem>_test.dart`, each Dart test naming its upstream
    `file:line`. The file's header has one line `// Parity for: <Component>, <Component>` (or `(functions)`,
    `(engine)` for tests of no one component), which `port/port_status.dart` reads;
  - goldens: `test/goldens/`.
- **The queue is read from disk.** `dart run port/port_status.dart` writes `port/manifest.tsv` from PORT_PLAN's
  table, the registry, each component file's trailer and the parity headers (`// Signals for:` lines go in a
  `signals` column apart from parity coverage); `--check` fails when it is stale. Run
  it after every batch and commit the manifest with the batch. Never edit the manifest by hand.
- The repo's root `.gitignore` ignores every `**/media/` folder (it hid `image.dart` and `icon.dart` in phase 1b).
  After adding files, run `git status` and `git check-ignore -v <path>` on each new path.

## 5. The gap inventory

Per-component decisions about Flutter-only problems (overlays, focus, fonts, sizes the web gets from the browser) are
**looked up, not made by implementers**: `port/inventory.tsv`, one row per site. A site that isn't there is an
inventory bug. Flag it, apply the UNKNOWN rule, keep moving.

A behaviour this rulebook decides but the code doesn't have yet is never a "documented" row: its row says
`pending: <rule>`, its site carries a `TODO(port)` (counted in the trailer), and a queued test asserts it *(from the
charts' running review, CR16: INV-034 and INV-049 read as accepted)*.

## 6. Per-component obligations (the certificate)

A component is done only when all of this holds. Each item is checked by a machine except the two reviews.

1. **Props:** every prop in its Appendix A block and `catalog.json` is read, or ignored exactly where React ignores
   it. Defaults, enums and required props match the Zod schema.
2. **Parity:** every portable assertion in CopilotKit's tests for it is ported into `test/parity/` with the **exact**
   expectation. Loosening one (`closeTo` for `toBe`, a weaker matcher) is a finding *(from review: `log10`)*. An
   internal-bound test (DOM nodes, class names, hooks) is listed in the parity file's header with the behaviour it
   guards, and that behaviour is tested another way when Flutter can observe it. A ported assertion our code fails is
   **committed anyway**, with the exact expectation and `skip: 'port-queue: <Component>: <one line>'`: the skips
   are the fix queue (`grep -rn "port-queue:" test`). Making it pass by weakening it is a finding. A `testWidgets`
   takes `skip: portQueue('port-queue: …')` (`test/helpers/parity.dart`), since its `skip` is a bool. The subject
   names where the fix goes in this package (a component, `(surface)`, or a function such as `openUrl`); when the
   cause is the engine (a2ui_core, a2ui_flutter), the line says so, and the fix wraps the engine in our layer.
   - A test about the catalog document (a group's names, descriptions, slots, events) is ported whole: it covers
     every component, built or not.
   - A test that mixes built and later-phase components keeps the later ones in its surface, drawing nothing, so the
     test fails as a signal once they are built. Cutting them out is a finding.
   - When upstream's expectation is a browser API's output (WHATWG URL, `Intl`), the expected value is worked out
     from the cited spec, with its section named next to the test, and the reading reviewer checks every such value.
     Where the spec can't decide it, the test is internal-bound.
   - A parity file may end with one group, `beyond <upstream file> (ours)`, holding our own vectors for the same
     functions. Nothing outside that group is ours.
   - **Not-ours** means CopilotKit's own machinery that this package doesn't provide: the chat transport, the agent
     context, React's host and error boundaries, JavaScript platform values. A test of what reaches the student
     through a surface (bindings, templates, repeated or cyclic ids, envelope accessibility, null props, event
     context, children keeping their state) is ours even when a2ui_core or a2ui_flutter does the work: it is ported
     through our surface, and the engine's failure is a `port-queue` skip *(from review: the judge's JR35, JR45-52)*.
   - Check what the student gets: the drawn text, the semantics tree (roles, labels, states) or the platform call,
     never an intermediate such as a parser's output or a widget's type *(JR6, JR23)*. A platform effect (opening a
     link, its target) is observed through a fake platform interface (`UrlLauncherPlatform.instance`), never called
     untestable *(JR2)*.
   - An assertion that something did **not** happen runs after everything has settled (`await tester.pump()` or
     `pumpEventQueue()`, since a2ui_core reports errors in a microtask), and a check that can't fail is a finding
     *(JR1, JR7)*.
   - When inputs must change in translation (a width, a size), the new ones still separate right from wrong code:
     name the wrong result they rule out *(JR8)*. Test the same object upstream tests: the standard catalog's
     export, not the playground's *(JR42)*.
   - A file's `// Parity for:` line names every component its tests touch, `(engine)` files too *(JR43)*.
   - **The queue check.** `A2UI_RUN_QUEUED=1` un-skips **every** `port-queue` test, `test` and `testWidgets`
     alike (`portQueue(...)` for both). Every batch that adds or touches a skip runs the whole queue that way and
     keeps the log: each queued test must fail, for its stated reason. A queued test that passes is either a fixed
     bug (its skip goes) or a test too weak to fail (a finding) *(from review: the judge's JS2, JS12)*. Where a
     one-line fix is cheap, a probe shows the test can pass. Both runs, normal and queued, write a per-test JSON
     report (`--file-reporter json:<path>`; on Windows from Git Bash a Windows path such as `D:\…`, since a `/d/…`
     path lands in a new `D:\d\…` folder), and
     the normal run's skipped tests must equal the queued run's failures, name for name. When a fix changes why a
     queued test fails, the same commit rewrites its skip line to the new reason *(RC7)*.
   - A queued test asserts the outcome upstream (or §0) gives, so a correct fix passes it. One that asserts
     today's behaviour, or that a correct fix would break, is a finding *(JS5, JS7, JS8)*.
   - Every behaviour §0 decides has a test that a wrong implementation fails, on each platform path it names *(JS1,
     JS6)*. The web path runs on the VM: our layer reads each platform value through one `@visibleForTesting` override
     (as Flutter's `debugDefaultTargetPlatformOverride`): `debugKitIsWebOverride` for whether it is the web,
     `debugKitPageHrefOverride` for the page's URL, both in `foundation/platform.dart`, and the test sets them. Not `flutter test --platform
     chrome`: it starts Chrome without `--disable-gpu` and can't be given flags (flutter_tools `web/chrome.dart:249`,
     `test/flutter_web_platform.dart:696`), which this laptop can't take (§7).
   - One `testWidgets` per brightness or look (MaterialApp animates a theme change, so a second `pumpWidget` in one
     test reads the old theme). A surface wider than 800px sets `tester.view.physicalSize`, since the default
     window clamps it silently.
   - In `port/upstream_tests.tsv`, `internal_bound` counts tests whose every assertion is internal-bound; a test
     with internal-bound parts counts as portable and names those parts in its note. `portable` is `tests` −
     `internal_bound` on every row, whatever the tests' state; the note names the not-ours and later-phase tests.
     An inline style value Flutter draws (a size, gap, colour, alignment, clip) is translated, not internal-bound,
     and so are an intermediate object's values that Flutter draws (a chart config's labels and colours).
     Internal-bound means a DOM or CSS term with nothing a student gets: tag or class names with no semantics
     counterpart, data attributes, stylesheet text, a JavaScript object's keys or identity, hooks *(JS33)*.
   - A queued test's expected value comes from its own context (the host's style, the parent's drawn style),
     never from a token that another queued fix changes: two fixes, each right, must not fail each other's tests
     *(from review: the judge's JT1)*.
   - When §0 overrules a documented difference, every assertion written for the old form is rewritten to the form
     §0 gives, and queued while our code fails it. A passing assertion of the old form is a finding *(JT2)*.
   - A port of an upstream equality over a whole list or an order compares the whole list, never a prefix or a
     partition *(JT3)*.
   - Lists are compared with `equals`, which is deep. `contains(<a List>)` over a list of lists compares by identity
     and never matches: use `contains(equals(...))` or a helper's matcher *(the chart batch: the port of
     dynamic-values.test.tsx:145 can never pass)*.
   - `// Parity for:` names only components whose upstream tests the file ports. A later-phase component kept in a
     surface as a signal goes on a separate `// Signals for:` line, which the manifest doesn't count as coverage,
     and `port/upstream_tests.tsv` names it in `subject` *(JT4, JT11)*.
   - A keyboard or focus test checks the effect the student gets (the right box scrolls, the ring shows only after
     Tab), never where a widget sits in the tree *(JT6, JT7)*.
   - The harness ingests messages and mounts surfaces through one helper that follows the README's "Setup" (the
     processor, `A2uiIdNormalizer`, `A2uiUserOwnedData`, the surface widget). A fix that changes the setup (our own
     surface widget, a processor option) changes the README and that helper together, never the tests *(JT14)*.
   - An operation's validation outcome (refused before anything is applied, or applied) is ours: it decides what
     the student sees. A file that calls outcomes ours lists every outcome test by line, and not-ours is used only
     for the categories above *(JT13, JT41)*.
   - A comment that says a wrong fix fails names that fix and holds an input that tells it apart *(JT15; JR8)*.
3. **Its own tests:** every prop, empty and missing data, very long text, events and their arguments, writable
   props, dark mode, reduced motion, semantics and keyboard. Like parity tests, they check what is painted or in the
   semantics tree, never only the token or the input a painter was given *(from review, 2a regen: a grey label
   tested by its token)*. Flutter's `paints..circle(...)` compares only the next circle drawn, and fails or passes
   on it alone: to find one call among others, use the predicates in `test/helpers/paint_calls.dart`
   (`paints..something(paintedCircle(...))`), and compare colours as ARGB32 *(from the chart review fixes)*.
   flutter_test sets `debugDisableShadows`, so a shadow paints as a solid shape with no blur: a test of a shadow
   sets it to false for that test (and back), or checks the shadow's colour and offset only *(from the judge's
   third fix round)*.
   - A chart's tests feed `Infinity`, `-Infinity`, `"1e999"`, `NaN`, `""`, `null` and missing keys, and data that
     empties or changes while the chart has focus or a tooltip. Each is a value its props schema takes, or the test
     is of the invalid-props alert: a bound value the schema refuses shows that alert, as upstream does, and never
     reaches the chart *(from the phase 1 validation batch)*. The outcome is the library's, read from its source
     (axes and ticks included); a throw is never the answer unless the library throws (then `BUG(port)`). State
     kept across a data change (a focus, an index) is checked against the new data on every path that reads it,
     keyboard and pointer alike *(from the charts' running review: CR1, CR2)*. It is kept the way the library
     keeps it, read from its source (by index and clamped, or by the point's key; a pin goes with its point), with
     a test per kept state (hover, keyboard, pin) as rows shrink and as a row is put first *(RR2-5, RR2-6)*. It is
     restored when the library restores it (on its render: new data, size or fonts), never on every rebuild, and a
     test steps the keys over two points that share one key *(RC3-2: a repeated pie label trapped the arrows)*.
     What the library keeps includes what was empty: a pointer resting on the plot with nothing under it is
     resolved again on that render, so new data that puts a point under it focuses that point (TanStack:
     `dist/renderer.js:159-162`, `trackedPointer`) *(RR3-1)*.
   - The inputs also include finite values whose arithmetic overflows a double (±1e308, a span of 2e308), and the
     tests paint every scene, with no focus and with each focus the library's keys reach, into a recording canvas
     and fail on any non-finite number a Canvas call gets, or the tooltip's box gets from its layout. A painter
     drops such a mark before the Canvas call, as a browser drops an SVG attribute it can't parse, or reproduces
     the library's outcome under `BUG(port)` *(RR2-1)*. Dropping a mark drops only its drawing: the point keeps
     everything else the library gives it. It takes the focus by keys and pointer as the library's own
     comparisons decide, with JavaScript's NaN semantics (`NaN || i` falls through to `i`; `NaN < d` is false),
     and the scene's anchor and tooltip place may be NaN where the library's are. The tooltip's layout applies
     CSSOM: a value that doesn't parse is dropped, property by property, so the box keeps its last value, or,
     never set, its CSS default (an absolute box with `left` or `top` unset sits at its static position, read
     from the library's DOM order) *(the third chart batch: this rule's first wording had the keys skip an
     undrawn point and put a never-placed box at the top left)*.
   - A test's name is a claim: a test named for something that does or doesn't happen has, in its body, the step
     that would make it happen (a test of "a press does not show the ring" presses) *(RR2-3)*.
   - Every tolerance, gap, inset, clamp or corner cap copied from a source gets a test at its boundary, and
     geometry is tested by its control points or corner pixels, not only its bounds *(CR6-CR13: ten surviving
     mutants)*.
   - Line heights and glyph boxes in a test come from the FlutterTest font's metrics, not the look's: compare them
     with the formula the display follows, or within a stated tolerance, never by a widget's flag
     *(from the tier 1 text batch: a `softWrap` check that passed while the lines drawn did not)*. SkParagraph
     rounds a line's height to the pixel, and a paragraph `strutStyle` with a run's height multiplier overshoots
     (30px lines where CSS gives about 24px): a strut is a box round each piece instead *(from the first phase's
     fix round: S3)*. The test font's 1em glyphs make words wider than any real font's: a layout check against
     the window's width uses words short enough to fit there *(the fix round's merge: a two-column table of
     "Formula" and "Second" was 383px wide at text scale 2)*.
   - Every look test mounts the surface in a CopilotKit-chat host (`copilotKitHost` in the harness: 16px in
     CopilotKit's ink); a test of what the surface takes from its host passes a host of its own *(from the first
     phase's fix round: the standard look inherits the host's type)*.
   - Text grows with the text scale; a library's fixed pixel sizes (bar widths, dot radii, gaps, insets) don't,
     as a browser's text-size setting leaves `px` alone.
4. **Fit:** no overflow and no exception at 320px width and at text scale 2.0, in both looks.
5. **Disposal:** every controller, listener, focus node and `ImageInfo` is disposed.
6. **Docs:** a doc comment on every public symbol, and deliberate differences recorded per the documented-difference
   rule. Every third-party source a file ports has a `NOTICE.md` section with its licence text and copyright, and
   `port_status.dart` fails when a file's header names a package `NOTICE.md` lacks *(RC3-7: TanStack Charts,
   decimal.js-light and es-toolkit had none)*.
7. **Gates:** `dart format` clean; `flutter analyze` 0 issues (package and example); `dart run tool/generate.dart
   --check`; the full suite green; the commit compiles on its own. A batch that touches `pubspec.yaml` or a
   generated table also runs analyze and the suite on a scratch copy after `flutter pub upgrade` and after
   `flutter pub downgrade`: a pub.dev user gets any version the constraints allow. A table generated from a
   dependency's names works across its whole allowed range, the newest version included (pana scores
   up-to-date dependencies) *(CR3: flutter_lucide 1.74 renamed 8 icons the table uses)*. Such a table is checked
   exactly at the version it was made from (the lock's) and by equivalence at any other: each name still draws
   what it drew (an icon font's glyph, by the font's cmap) *(the CR3 fix)*. A table keyed to a dependency's
   internals (codepoints, private names) states the invariant it relies on as observed, with the versions checked,
   never as a fact; its aliases come from the artefact itself, not a changelog *(RC5, RC6)*. A table generated from
   fetched sources outside the repo (the Lucide icon nodes) reads them from `$A2UI_THIRDPARTY_SRC`, else
   `third_party_src/` in the package (ignored by git); its check runs only where those sources are, and without them it stops
   with the fetch instructions, never passes unchecked *(from the phase 1 icons batch)*.
8. **Mutation check:** for a sample of behaviours, breaking one line makes a test fail. A surviving mutation is a
   finding. The record names the assertion that failed; a mutant killed only by a crash or another bug's assertion
   is not counted as killed, and is run again once that bug is fixed. Mutations target lines where our layer
   decides; one in a value the engine has already resolved is equivalent and proves nothing. A mutant whose only
   separating input is one §0 turns into an alert is recorded as survived, with that reason, and run again once
   the alert lands (F8). A token or constant copied from a source has a test that pins its value as a literal (a
   colour as ARGB32, in every look and brightness, never by its alpha alone): a test that reads its expectation
   from the token can't see the token change *(N9, RC8)*. A mutant compiles: one that doesn't is withdrawn, not
   counted. A survivor on a line that ports a library guard no data can reach is recorded as unreachable, naming
   every line that blocks the input, and the reviewer checks that claim *(the third chart batch: K3, P3; RC3:
   `nice()` blocks P3's input too)*. Each branch of a kept-state rule (hover, keyboard, pin; pointer and key)
   gets a mutant in the batch's record *(RC3-3: the pointer branch of the restore had none)*. When another fix
   makes a mutant equivalent, the record also runs the combined mutant that brings the original bug back *(the
   fourth chart batch: B1, B1b)*.
9. **Trailer:** the component file ends with
   `// PORT STATUS: confidence=<high|medium|low> todos=<N> upstream=<renderer path>`. A trailer that undercounts its
   `TODO(port)` markers is a finding. Every other Dart file under `lib/` (foundation, theme, functions, validation,
   ids, the catalog, `lib/a2ui_kit.dart`) ends with its own trailer (`upstream=` names the sources it ports, or
   `none`), and `port/port_status.dart` checks those too, so a `TODO(port)` outside a component file is still
   counted *(RC14; widened at the first phase's merge, where `functions/failed_value.dart` held an uncounted
   `TODO(port)`, and to all of `lib/` by the fix round)*. A generated `.g.dart` file carries none: its generator's
   check covers it *(from the phase 1 components batch)*. After the full run, `dart run port/port_status.dart
   --check --skips <normal.json>` (the run's `--file-reporter json:` report) checks each `upstream_tests.tsv` row's
   "Port-queue skips: N" against the run's skipped tests in its parity file; rows that share a parity file are
   summed, and a row with no N claims 0 *(from the phase 1 components batch: two counts were stale at fcc050dd; the
   check by the first phase's fix round)*.
10. **Review:** two adversarial reviewers, each in a fresh context, find nothing blocking (section 7).

## 7. The loop

- **One batch** is 4 to 8 components (`port/manifest.tsv` holds the queue; a component is done when its file, its
  tests and its parity file exist and pass).
- **Order and stopping rule** (the user, 2026-11-19 and 2026-11-21: port by priority, stop after each tier for the
  user to look). The remaining components go by `port/priority.md`'s tiers, not by phase. Each tier gets **one**
  reading and **one** running review. Its fix round fixes the blocking findings and any wrong outcome on ordinary
  data (data an agent would send in normal use); everything else (inputs no normal use sends, such as values near
  ±1e308 or the sort order of NaN, and sub-pixel differences) goes to `port/prerelease.md` with the finding's id,
  for one pass before the pub.dev release. No second review round on a tier unless the user asks. Then the tier
  stops: its components are shown to the user (a picture of each, beside CopilotKit's where one is at hand), and
  the next tier waits for the user's word *(four review rounds on the 7 charts built nothing new for an afternoon)*.
- **Implement → two adversarial reviews → fix.** The two reviewers read the same batch in separate contexts. They
  don't see the implementer's report or each other's. Where they disagree, a third agent decides. On this laptop
  only one of them runs Flutter: the **reading reviewer** runs no `flutter` or `dart` command and checks fidelity
  against the sources of truth (section 0, items 1 to 4); the **running reviewer** runs the tests, the mutations, the
  320px and text-scale checks and the disposal checks. Both read the whole batch, and either may raise any finding.
- **Fix the loop, not the code.** When a reviewer finds a mistake a rule could have prevented, or the same mistake
  twice, the orchestrator adds one sentence to this file (section 8), then every file the rule touches is swept
  against it. Hand-patching one file while the rule stays missing is a deviation.
- **Before a new phase,** a shakedown: two agents translate the same two or three components, one with this
  rulebook and one "as a senior Flutter engineer" without it. A third reads the diff and proposes rules. The
  translated code is thrown away. Proposed rules go to the orchestrator, never self-applied.
- **Models:** implementers, reviewers and rule writers all run on the strongest model for now, given the user's
  quality bar. The guide's cheaper-implementer option is open for the user once the parity judge exists.
- **The laptop** (15 GB RAM, has crashed before): one Flutter agent at a time. Before each `flutter test` or
  `flutter analyze`, read `Win32_OperatingSystem`: at least 3 GB of `FreeVirtualMemory` (commit headroom, what ran
  out in the 2026-11-03 crashes) and 1.5 GB of `FreePhysicalMemory`; under 3 GB physical, run with `-j 1`. Wait
  while either is short, and never stop a process this batch didn't start. Nothing on C:, scratch on D:, no
  `flutter run`, headless Chrome only with `--disable-gpu`. Edit Dart with the Edit and Write tools only, never shell heredocs (they eat backslashes here).
- **Commits:** on `a2ui-catalog/port` only, never pushed, merged or rewritten. Messages end with
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## 8. Amendments

One line per change to this file: date, rule, what triggered it, which files were swept.

| Date | Rule | Trigger | Swept |
|---|---|---|---|
| 2026-11-18 | First version: phase 1's review findings turned into rules (marked *from review*) | adopting Anthropic's migration guide | phase 1 sweep pending (judge step) |
| 2026-11-19 | §0 item 4: third-party libraries from their published source at the pinned version, never from memory | phase 2a wrote recharts, d3 and TanStack Charts geometry from memory (its own report) | phase 2a, by its reading reviewer |
| 2026-11-19 | §1 Charts: `CustomPaint` on the chart foundation; fl_chart is not a dependency | phase 2a found fl_chart can't draw the playground's curves, bands and arcs | phase 2a (already so) |
| 2026-11-19 | §2 CSS flexbox: the rule follows upstream's element; plain Flutter layout where it is not a flex box | phase 2a's tooltip, pie centre and Chart figure, where CopilotKit has no flex box | phase 2a, by its reviewers |
| 2026-11-19 | §4 `// Parity for:` headers and `port/port_status.dart`; §6 item 2 failing assertions committed as `port-queue` skips; §7 reading and running reviewers | building the manifest; the laptop's one-Flutter-agent rule | the two chart parity files got their headers |
| 2026-11-19 | §0 item 4 the folder of fetched sources; §1 library colours as named tokens; §2 CSS grid also inside library markup, loop bounds and rounding copied exactly, `jsObjectKeys`, the fonts mixin | the phase 2a reading review (25 blocking, 30 should, 13 nits; the review record (kept outside the repository), `tanstack.md`) | phase 2a: regenerated by the 2a fix batch; phase 1: by the phase 1 sweep |
| 2026-11-19 | §6 item 2: catalog-document tests whole, later-phase components kept in mixed tests, browser-API expectations from the cited spec, one `beyond … (ours)` group; §7 the memory floor defined (commit headroom and physical) | the judge's proposals; the judge waited 3 hours on an undefined "3 GB free" | the judge's parity files (drafted under these rules already) |
| 2026-11-19 | §6 item 2 the widget-test skip form and the skip's subject for engine causes; §6 item 8 a mutant killed by a crash isn't counted | the judge's report (J15 was killed by the Image lightbox's semantics assertion) | the judge's files (already so); J15 to re-run after the Image fix |
| 2026-11-19 | §6 item 2: what not-ours means, check what the student gets, fake platforms, settle before a negative check, translated inputs must still separate, the same object as upstream, complete `Parity for:` lines | the judge's reading review (21 blocking, 24 should, 16 nits; the review record (kept outside the repository)) | the judge's 22 parity files and `port/upstream_tests.tsv`: by the judge fix batch |
| 2026-11-19 | §0 item 4 whole packages, hash-checked, and `TODO(port): <file> not fetched`; §2 one home for JS helpers, library SVG text by baseline, one tree shape for toggled decoration, library colours as prefixed tokens | the 2a fix batch's proposals and its missing-source list | the 10 `TODO(port)` sites in chart.dart and js_decimal.dart: by the 2a review fixes; FocusRing (already so) |
| 2026-11-19 | §2 a library's defaults, interaction and text layout ported from source; §6 item 3 own tests check what is painted | the 2a regeneration's reading review (3 blocking, 18 should, 20 nits; the review record (kept outside the repository)) | the 7 charts: by the 2a review fix batch |
| 2026-11-19 | §0 CopilotKit's behaviour wins where Flutter could go either way (openUrl paths, invalid props, envelope names, cycle and failure alerts); §1 the url_launcher fake; §6 item 2 run queued tests once, one test per theme, wide surfaces, the tsv's `internal_bound`; §6 item 8 equivalent mutants | the judge fix batch's questions and proposals | the parity files; the four behaviours: by the phase 1 fix batch (correction, 2026-11-19: the parity files did **not** yet test the four behaviours; JS29) |
| 2026-11-19 | §6 item 2: the queue check over every skip, queued tests assert the outcome a correct fix gives, every §0 decision tested on each path | the judge's second reading review (8 blocking, 20 should, 21 nits; the review record (kept outside the repository)) | the parity files and the harness: by the judge's second fix round |
| 2026-11-19 | §1 rows for `json_schema_builder` and `path_parsing`; §2 grid track sizing and `place-items`, a zero-blur inset shadow as a border, the browser's own focus outline drawn, a library's tab stops and focus pairs; §3 the suppression's reason in parentheses; §6 item 3 paint predicates | the chart review fix batch's proposals (d023f6ae); INV-049 decided by §0 from CopilotKit's `globals.css` | `// ignore:` (one site, `chart_colors.dart:181`, fixed here); the focus outline: the 7 charts and phase 1's focusable elements, by the next chart batch and the phase 1 fix batch |
| 2026-11-19 | §6 item 2: the web path tested on the VM through a platform override, never in `flutter test --platform chrome` | checking b9e0c0e2's "browser-only test" before briefing it: flutter_tools gives that Chrome no `--disable-gpu` | none yet (no browser-only test existed); the override and its tests: by the phase 1 fix batch, with openUrl's §0 paths |
| 2026-11-19 | §0 tables carry table roles (INV-034); §0 item 4 streamdown 1.6.11; §6 item 2 the queue run's JSON reports and their diff, the tsv's `portable` and what internal-bound means; §6 item 8 a mutant only an alert would separate | the judge's second fix round (47b0e842..2f864a2d): its proposals, and JS4's question answered by §0 (Flutter has `SemanticsRole.table`) | the tsv: by that round (correction: not so then; JT17, JT18, JT31, JT35, JT41, fixed by deddc931); INV-034 and the Chart's table roles: by the next chart batch |
| 2026-11-19 | §6 item 2: expected values from context, §0 overrules rewrite old-form assertions, whole-list equality, `// Signals for:`, focus tests check effects, the harness through the apps' entry point, operation outcomes are ours, a wrong fix named with its input | the judge's third reading review (1 blocking, 14 should, 28 nits; the review record (kept outside the repository)) | the parity files, the harness and the tsv: by the judge's third fix round |
| 2026-11-19 | §5 decided-but-unbuilt items are pending rows with a `TODO(port)` and a queued test; §2 keys a library leaves alone are ignored, tab stops focus on press; §6 item 3 non-finite and changing data, boundary tests for copied constants, what grows with text scale; §6 item 7 fresh resolves at both ends | the charts' running review (3 blocking, 10 should, 3 nits; the review record (kept outside the repository)) | the 7 charts and `pubspec.yaml`: by the next chart batch; phase 1's keyboard handlers and focusable elements: by the phase 1 fix batch |
| 2026-11-19 | §4 the manifest's `signals` column (`port_status.dart` reads `// Signals for:`); §6 item 2 an intermediate object's drawn values are translated; §6 item 3 `debugDisableShadows`; JT42's amendment row corrected | the judge's third fix round (deddc931) and its proposals | the manifest: regenerated here; shadow tests: by the phase 1 fix batch |
| 2026-11-19 | §2 a key the library handles but never prevents (web `ignored` where the browser's default follows, else `handled`); §6 item 2 lists compared deep; §6 item 7 a generated table exact at its version, equivalent elsewhere; §6 item 8 a copied token pinned by a literal | the chart batch after the running review (3546460a..cabc03db) and its proposals; recharts' `onKeyDown` checked (no `preventDefault`) | the Lucide table (already so); Left, Right and Enter on the web and lucide-react's own names (§0 item 4: 0.525.0 and 1.57.0, not fetched): by the phase 1 fix batch; the identity compare at `dynamic_values_test.dart:250`: by the phase 1 fix batch |
| 2026-11-19 | §1 Icons from lucide-react's own icon nodes, not `flutter_lucide` (INV-006 overruled by §0); §2 the focus outline by `:focus-visible`'s heuristic, not Flutter's highlight mode; §2 every key a library doesn't prevent keeps the browser's default on both paths (09d92eab's row rewritten); §2 a fixed-px box inside a `WidgetSpan`; §6 item 2 a skip line rewritten when its cause changes; §6 item 7 a table keyed to a dependency's internals; §6 item 8 pinned in every look; §6 item 9 trailers on shared files | the chart batch's reading review (1 blocking, 7 should, 6 nits; the review record (kept outside the repository)); the Icon's own comment that `strokeWeight` isn't drawn because of the font | the charts' outline, keys, legend and colour pins: by the next chart batch; the Icon, the lucide-react fetch and the foundation trailers with `port_status.dart`: by the phase 1 fix batch |
| 2026-11-19 | §2 an SVG element's box is its tight box; §6 item 3 state across data kept as the library keeps it, overflowing finite values and paint-level non-finite checks, a test's name is a claim | the chart batch's running review (1 blocking, 8 should, 3 nits; the review record (kept outside the repository)) | the 7 charts, and (moved from the phase 1 fix batch) the identity compare at `dynamic_values_test.dart:250` and Left, Right and Enter on the web: by the next chart batch; phase 1's names and boxes: by the phase 1 fix batch |
| 2026-11-19 | §6 item 3 an undrawn point keeps its focus and its tooltip, and the tooltip's layout applies CSSOM's drop (RR2-1's wording amended: it had the keys skip such a point); §6 item 8 a mutant compiles, and an unreachable guard's survivor names what blocks its input | the third chart batch (640fec78..72aa0dc5) and its departures; TanStack's `compareNavigationPoints` (dist/interaction.js) and `createTooltip`, `moveToContainer` (dist/tooltip.js) read | the 7 charts: by the third chart batch's follow-up |
| 2026-11-19 | §2 `overflow` clips at the padding box with inner radii | the third chart batch's follow-up (ab1d2d92) and its proposal; its finding that `CssFlex` clips at the border box | the playground figure: in ab1d2d92; `CssFlex` and every phase 1 box with a border: by the phase 1 fix batch |
| 2026-11-19 | §0 item 4 browser behaviour from a spec's normative text or Chromium's source at a tag; implementation-defined JS behaviour only where data reaches it, an engine's code as a library, a JS engine as an oracle only for one's own script; §0 a documented difference states the browser's outcome and the missing API; §2 stacking order, an inline box no break may follow, a word CSS keeps whole, the scroll keys, which keys make focus visible, keyed siblings as one tree shape; §6 item 3 state restored on the library's render; §6 item 6 a NOTICE section per ported package; §6 item 8 every blocking line named, a mutant per kept-state branch | the third chart reading review (1 blocking, 8 should, 5 nits; the review record (kept outside the repository)) | the 7 charts (TimSort out, stable sort with its invariant pinned), Chromium's `keyboard_event_manager.cc`, NOTICE sections and the `port_status.dart` check: by the fourth chart batch; `CssFlex`'s clip and hit test: by the phase 1 fix batch |
| 2026-11-19 | §6 item 3 a resting pointer with nothing under it is resolved again on the library's render | the third chart running review (0 blocking, 3 should, 2 nits; the review record (kept outside the repository)); TanStack's `renderer.js:159-162` read | the 7 charts: by the fourth chart batch |
| 2026-11-21 | §7 order and stopping rule (tiers in `port/priority.md`, one review pair per tier, edge findings to `port/prerelease.md`, the user looks after each tier); §1 `path_parsing` for the Svg component; §2 the no-break run led by U+2060; §6 item 8 the combined mutant | the user's direction after the chart rounds; the fourth chart batch (e987134c) and its proposals 3 and 4 (1, 2, 5, 6 to `port/prerelease.md`) | tier 1: from its batch on |
| 2026-11-21 | §0 item 4 whatwg-url, tr46, punycode; §2 function values by CopilotKit's resolver, URLs by `whatwg_url.dart`; §6 item 2 one override per platform value | the phase 1 functions batch (34c8661b..1a63f0dd) and its four proposals | the functions and openUrl: in that batch (already so) |
| 2026-11-21 | §2 the operation validator first, the node guard and `isDrawnChild` for containers; §6 item 3 a chart's edge inputs are values its schema takes | the phase 1 validation batch (9b384693..0c57cf17) and its proposals | the four containers and the chart tests: in that batch; tier 1's containers (Table family, Flow, Blockquote): at their merge |
| 2026-11-21 | §0 item 4 lucide-react 0.525.0 and 1.57.0 fetched; §6 item 7 tables generated from sources outside the repo | the phase 1 icons batch (2f8ad421..1d2d6c50) and its proposals 1, 2 and 5 (3 and 4 to `port/prerelease.md`) | `PORT_PLAN.md`'s later components: Lucide through `lucideImport`, here |
| 2026-11-21 | §0 item 4 katex 0.16.27 and Chromium's html.css and font files; §1 maths typesetting (KaTeX's outcome around flutter_math_fork); §2 the focusable scroll container, inline children of a Text; §6 item 3 metrics from the test font | the tier 1 text batch (59b9cea1..aab384ce) and its four proposals | Code (already so); the chart plot's scroll keys to `browser_scroll.dart` and Text's inline children (INV-104, INV-108): by the first phase's fix round |
| 2026-11-21 | §6 item 9 trailers on every file under `lib/src/` but generated ones, and the tsv's skip counts checked | the phase 1 components batch (e072d33c..b0d083b4) and its proposals 3 and 4; the merge, where `failed_value.dart`'s `TODO(port)` had no trailer to count it | the 15 files under `functions/`, `validation/`, `ids/`, the catalog and `a2ui_kit.dart`, and the `port_status.dart` checks: by the first phase's fix round |
| 2026-11-21 | §2 the runs of a Text's inline children and `InlineBoxScale`, a third-party render object measured off-screen, a block root's explicit semantics nodes; §6 item 3 line heights by strut boxes, the test font's wide words, the CopilotKit-chat host in look tests | the first phase's fix round, text (8a513a74..7d79239b) and its five proposals; the merge with the structure batch (d72eca52), where two tests written while queued failed when first run | the code (already so) |
| 2026-11-21 | §2 the focus outline (a touch focuses on a tap, never a drag), the HTML table (cell box, failing parts, the fallback's place), one focusable scroll container, a dry baseline on every box of ours, grid spans; §6 item 9 trailers on all of `lib/`, the skip counts checked against a run's report | the first phase's fix round, structure (8a513a74..81df363d) and its six proposals; INV-340's clamp kept as a documented difference until track ranges (on the pre-release list: §0 asks for Flutter forcing it, and here our `CssGrid` does) | the code (already so) |
| 2026-11-21 | §0 item 4 Chromium's table sources; §2 HTML tables, the replaced element's default size | the tier 1 data batch (2c521ad2..97aa391c) and its proposals 1-3 (4, one envelope helper, to the fix round; 5 held) | Table and Svg (already so) |

## 9. Deviation log

Every departure from this process, one line each. A deviation nobody logged is one nobody approved.

| ID | Date | Deviation | Sanctioned by |
|---|---|---|---|
| DEV-001 | 2026-11-18 | Phase 1 was built and reviewed **without a judge**: of CopilotKit's 57 test files for this catalog, only `calc.test.ts` and `functions.test.ts` were ported. Remedy: the judge step ports the rest before phase 2b | nobody (found when adopting the guide) |
| DEV-002 | 2026-11-18 | Phase 1 review findings were hand-patched per file instead of rule + sweep. Remedy: those findings are the *(from review)* rules above, and the judge step sweeps phase 1 against them | nobody (found when adopting the guide) |
| DEV-003 | 2026-11-18 | Commits 5204ca2d and 2a938b88 don't compile on their own; every commit before 86998492 lacks `image.dart` and `icon.dart` (the `**/media/` ignore). History stays as is | standing rule: never rewrite history |
| DEV-004 | 2026-11-18 | The judge can't run CopilotKit's tests on the original, since the clone is never run. The expectations are taken from upstream's own assertions at ff6f3b03 instead, and the judge is validated by mutations on our side only | follows the user's no-run choice (section 0) |
| DEV-005 | 2026-11-19 | Phase 2a was briefed before this rulebook existed: recharts, d3 and TanStack Charts code written from memory, and its margins, tick text, crosshair, label thinning, tooltip insides and focus distance "rebuilt by eye"; its differences have no `port/inventory.tsv` rows of its own (the brief kept it out of `port/`). Remedy: the reading reviewer checks them against the published sources (§0 item 4); the orchestrator seeded the inventory | nobody (the brief predated the rule) |
| DEV-006 | 2026-11-19 | The phase 2a implementer started one `flutter test` with about 2.3 GB free, under the 3 GB floor (§7). No crash; every later run waited for 3 GB | nobody (reported by the implementer) |
| DEV-007 | 2026-11-19 | Phase 2a's running review is skipped for the code as built: the reading review's 25 blocking findings share one cause (no sources, DEV-005), so the third-party geometry is regenerated from the sources and both reviewers review that instead | the orchestrator (the guide: regenerate the batch, don't hand-patch) |
| DEV-008 | 2026-11-19 | The 2a fix batch edited Dart with the shell: `sed -i` (`implements`→`extends` in 3 scene files, calc.dart's `_jsRound` rename, one import) and two python heredocs (`tanstack_scale.dart`, `tanstack_guides.dart`). None touched a backslash; the reviewers check those files | nobody (reported by the implementer) |
| DEV-009 | 2026-11-19 | The 2a fix batch ran two Flutter agents (the implementer and a fork), serialised by a lock script that applied the §7 floor, never both at once | nobody (reported by the implementer) |
| DEV-010 | 2026-11-19 | The 2a fix batch changed phase 1 code beyond its brief: `controls.dart` (FocusRing, INV-032) and `render_css_grid.dart` with its test (an auto track, F11). Both are reviewed with the batch | nobody (reported by the implementer) |
| DEV-011 | 2026-11-19 | The judge fix batch added the dev dependency `url_launcher_platform_interface` before §1 had its row (added after, same day). Its commit a6693745 says "30 new port-queue sites", the batch's total; the commit adds 19 | the orchestrator (row added; history stays) |
| DEV-012 | 2026-11-19 | The chart review fix batch had a helper agent write the phase 1 sweep's code (b22197ec: RR28-31, 34, 39, 41) without running Flutter; the implementer ran every gate, and the commit compiles and passes on its own. `json_schema_builder` and `path_parsing` had been dependencies with no §1 row since phase 1 (rows added after the fact) | nobody (reported by the implementer) |
| DEV-013 | 2026-11-19 | The judge's second fix round gave `--file-reporter` a `/d/…` path, which wrote two JSON reports (1.4 MB) into a new `D:\d\…` folder, outside the scratch folder; copies are in the scratch folder. Removing the folder was refused to the agent, so it is the user's to delete. Remedy: §6 item 2 now names a Windows path | nobody (reported by the implementer) |
| DEV-014 | 2026-11-19 | The charts' running reviewer edited one of its own probe tests with `sed -i` (no backslashes) and downgraded `flutter_lucide` in its scratch copy so the suite would compile (CR3). Nothing outside its scratch folder changed | nobody (reported by the reviewer) |
| DEV-015 | 2026-11-19 | The third chart batch's follow-up (ab1d2d92) ran Node 24.17.0 on its own generator (`sortvec.js`, in the batch's scratch folder) as an oracle for a TimSort written from memory; the third running review was allowed to do the same with its own script. Never the clone, no npm, no packages. §0 item 4 now names when an engine may be an oracle; the TimSort goes (RC3-8) | the orchestrator for the review's run; nobody for the batch's (found by the reading review) |
| DEV-016 | 2026-11-19 | The third running reviewer edited its own fit probe with a Python script from a heredoc (no backslashes), in its scratch copy only | nobody (reported by the reviewer) |
