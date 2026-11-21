# Notices

a2ui_kit ports data and behaviour from CopilotKit
(https://github.com/CopilotKit/CopilotKit), commit
`ff6f3b03267159cbbf70f9878d988adf4968d022`, under the MIT License below.

| In a2ui_kit | From CopilotKit | How |
|---|---|---|
| `lib/src/document/catalog_document.g.dart` | `examples/showcases/a2ui-playground/src/a2ui/export/catalog.json` | the document as JSON text, generated |
| `lib/src/document/inference_document.g.dart` | `examples/showcases/a2ui-playground/src/a2ui/export/inference-catalog.json` | the document as JSON text, generated |
| `lib/src/document/props.g.dart` | the same `catalog.json` | names, enums and descriptions, generated |
| `lib/src/theme/tokens.dart`, `playground_tokens.dart` | `packages/shared/src/generative-ui/standard/{tokens,theme}.ts`; the playground's `src/a2ui/catalog/catalog.ts` and `src/app/globals.css` | token values |
| `lib/src/foundation/text/inline_markdown.dart` | `packages/react-core/src/v2/generative-ui/standard/markdown.tsx` (`renderInlineMarkdown`, `safeHref`) | ported |
| `lib/src/components/standard/` | `packages/react-core/src/v2/generative-ui/standard/{layout,text,inputs,data,media,markdown,lightbox}.tsx`, `packages/shared/src/generative-ui/standard/{checks,styles}.ts` | styles and rules ported |
| `lib/src/components/playground/` | the playground's `src/a2ui/catalog/renderers/{layout,content,data,feedback,format}.tsx`, `src/app/globals.css`, `src/styles/motion.css` | styles, rules and timings ported |
| `lib/src/functions/calc.dart`, `validators.dart`, `formatting.dart` | `packages/core/src/generative-ui/{calc,functions}.ts` (`BASIC_FUNCTIONS`, `dateOf`, `formatDatePattern`, `pluralCategory`, `truthOf`) | ported |
| `lib/src/functions/open_url.dart`, `lib/src/foundation/page_href_web.dart` | `packages/core/src/generative-ui/functions.ts` (`openUrlSafely`, `parseUrl`, `pageBase`, `openOnPage` and their helpers) | ported |
| `lib/src/functions/format_string.dart`, `validators.dart` (`validationScope`) | `packages/core/src/generative-ui/resolve.ts` (`walk`, `call`, `formatString`, `matchingBrace`, `ExpressionParser`, `coerce`) | ported |
| `lib/src/foundation/interaction/checks.dart` (`firstFailedCheck`) | `packages/shared/src/generative-ui/standard/checks.ts` | ported |
| `lib/src/data/owned_data.dart` | `packages/core/src/generative-ui/surface-manager.ts` (`setOwnedValue`, `mergeOwnedValues`, `isAtOrBelow`, `normalizePath`) | ported |
| `lib/src/foundation/icons/lucide.dart` | `media.tsx` (`A2UI_ICONS`, `kebabToPascal`, `LucideIcon`, `ICON_STROKE`) | lookup and stroke widths ported |
| `lib/src/theme/a2ui_kit_theme.dart` (`fromColorScheme`) | the playground's `src/design-systems/{themes.ts,design-systems.css}` | the Material mapping |
| `tool/src/generator.dart` (`writableProps`, `eventArguments`) | `packages/shared/src/generative-ui/standard/*.ts`, the playground's `src/a2ui/catalog/definitions/*.ts` | tables from the declarations |
| `test/foundation/inline_markdown_test.dart`, `test/functions/{calc,formatting}_test.dart` and the component tests | `packages/react-core/src/v2/generative-ui/standard/__tests__/*.test.tsx`, `packages/core/src/generative-ui/__tests__/{calc,functions}.test.ts` | test vectors |
| `lib/src/components/playground/charts/`, `lib/src/foundation/chart/curve.dart` (`addMonotonePath`), `lib/src/theme/chart_colors.dart` | the playground's `src/a2ui/catalog/renderers/{charts,chart-kit}.tsx`, `renderers.css`, `src/styles/motion.css` | the chart definitions, the monotone curve, colours and the grow-in ported |
| `lib/src/components/standard/data/chart.dart` | `packages/react-core/src/v2/generative-ui/standard/Chart.tsx`, `packages/shared/src/generative-ui/standard/{chart,chart-config}.ts` | ported |
| `lib/src/foundation/format/chart_format.dart` | the playground's `renderers/format.ts`, `chart-kit.tsx` (`fmtValue`, `tickFormatter`, `shortLabel`); `chart-config.ts` (`makeFormatter`) | ported |
| `test/parity/chart_test.dart`, `chart_scatter_test.dart` | `packages/react-core/src/v2/generative-ui/standard/__tests__/{chart,chart-scatter}.test.tsx`, `packages/shared/src/generative-ui/standard/__tests__/standard-helpers.test.ts` | tests ported |
| `test/goldens/chart_samples.dart`, the chart samples of `example/lib/samples.dart` | the playground's `src/a2ui/catalog/samples/{charts,standard}.ts` | converted to JSON by hand |
| `test/fixtures/copilotkit/` | see `test/fixtures/copilotkit/NOTICE.md` | test data |
| `example/assets/replays/` | the replays of `test/fixtures/copilotkit/replays/` (see its NOTICE) | copies, for the example app |
| `lib/src/components/standard/data/table.dart`, `media/svg.dart`, `layout/flow.dart` | `packages/react-core/src/v2/generative-ui/standard/{data,media,layout}.tsx`, `packages/shared/src/generative-ui/standard/{data,media,layout,styles}.ts` | ported |

Icons: [Lucide](https://lucide.dev)'s, from lucide-react's own icon nodes (see "Lucide" below). The
Tailwind CSS palette colours in `lib/src/theme/tone_colors.dart` are Tailwind's (MIT, © Tailwind Labs).

## d3 (ISC License)

`lib/src/foundation/chart/scale.dart` ports d3-array's `ticks` and `tickIncrement` and d3-scale's linear `nice`,
band and point scales; `curve.dart` ports d3-shape's `curveMonotoneX`; `arc.dart` ports d3-shape's `arc` (pad angle
and rounded corners). The playground's charts (TanStack Charts) use d3-style scales and arcs; recharts draws its
`monotone` curve with d3-shape.

> Copyright 2010-2023 Mike Bostock
>
> Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby
> granted, provided that the above copyright notice and this permission notice appear in all copies.
>
> THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL
> IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
> INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN
> AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
> PERFORMANCE OF THIS SOFTWARE.

## KaTeX (MIT License)

`lib/src/components/standard/text/math.dart` follows KaTeX 0.16.27, which CopilotKit's Math component typesets
with: the formula's size and line height and its display block (`dist/katex.css`), where an inline formula may
break (`src/buildHTML.js`), the error span and colour of `throwOnError: false` (`katex.js`, `src/Settings.js`,
`src/ParseError.js`) and the red name of an unknown or untrusted command (`src/Parser.js`, `src/functions/`). The
formula itself is typeset by flutter_math_fork, a dependency under its own licence.

> Copyright (c) 2013-2020 Khan Academy and other contributors
>
> Permission is hereby granted, free of charge, to any person obtaining a copy
> of this software and associated documentation files (the "Software"), to deal
> in the Software without restriction, including without limitation the rights
> to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
> copies of the Software, and to permit persons to whom the Software is
> furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all
> copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
> AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
> LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
> OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
> SOFTWARE.

## recharts (MIT License)

`lib/src/foundation/chart/scale.dart` ports recharts' nice ticks (`getNiceTickValues`, `getTickValuesFixedDomain`,
from recharts-scale) and its number-axis domain rule; `arc.dart` ports its `Sector` paths (`getSectorPath`,
`getSectorWithCorner`); `lib/src/components/standard/data/chart.dart` follows its bar positions (`getBarPosition`),
pie angles, legend and tooltip. CopilotKit's standard Chart draws with recharts 3.

> Copyright (c) 2015-present recharts
>
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
> documentation files (the "Software"), to deal in the Software without restriction, including without limitation the
> rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
> permit persons to whom the Software is furnished to do so, subject to the following conditions: the above copyright
> notice and this permission notice shall be included in all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
> WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
> COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
> OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## TanStack Charts (MIT License)

`lib/src/foundation/chart/tanstack_interaction.dart` (focus, keyboard, tooltip order and placement, hit testing),
`tanstack_scale.dart` (the linear scale and its ticks), `tanstack_stack.dart` (stacks and the pie layout) and
`tanstack_guides.dart` (axes, grid and margins), with `lib/src/components/playground/charts/cartesian.dart`,
`pie_sparkline.dart` and `chart_kit.dart` (the marks and the structured tooltip), port @tanstack/charts 1.1.0, which
the playground's charts draw with. The licence below is the package's own `LICENSE` (1079 bytes, the sha256 its
published file list gives).

> MIT License
>
> Copyright (c) 2026-present Tanner Linsley
>
> Permission is hereby granted, free of charge, to any person obtaining a copy
> of this software and associated documentation files (the "Software"), to deal
> in the Software without restriction, including without limitation the rights
> to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
> copies of the Software, and to permit persons to whom the Software is
> furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all
> copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
> AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
> LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
> OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
> SOFTWARE.

## decimal.js-light (MIT License)

`lib/src/foundation/chart/js_decimal.dart` ports the part of decimal.js-light 2.5.1 that recharts' tick arithmetic
uses: its 20-digit truncating `plus`, `minus`, `times`, `div` and `mod`. The licence below is the package's own
`LICENCE.md`.

> The MIT Expat Licence.
>
> Copyright (c) 2020 Michael Mclaughlin
>
> Permission is hereby granted, free of charge, to any person obtaining
> a copy of this software and associated documentation files (the
> 'Software'), to deal in the Software without restriction, including
> without limitation the rights to use, copy, modify, merge, publish,
> distribute, sublicense, and/or sell copies of the Software, and to
> permit persons to whom the Software is furnished to do so, subject to
> the following conditions:
>
> The above copyright notice and this permission notice shall be
> included in all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
> EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
> MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
> IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
> CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
> TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
> SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## es-toolkit (MIT License)

`lib/src/foundation/chart/recharts.dart` ports es-toolkit 1.43.0's `compat` `get` (with `toPath` and `isDeepKey`)
and `sortBy`, through which recharts reads a row's value by its data key and sorts its legend and tooltip entries.
The licence below is the package's own `LICENSE`.

> MIT License
>
> Copyright (c) 2024 Viva Republica, Inc
>
> Copyright OpenJS Foundation and other contributors
>
> Parts of the test suite and compatibility layer in `es-toolkit/compat` are derived from Lodash (https://github.com/lodash/lodash) by the OpenJS Foundation (https://openjsf.org/) and Underscore.js by Jeremy Ashkenas, DocumentCloud and Investigative Reporters & Editors (http://underscorejs.org/)
>
> Permission is hereby granted, free of charge, to any person obtaining a copy
> of this software and associated documentation files (the "Software"), to deal
> in the Software without restriction, including without limitation the rights
> to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
> copies of the Software, and to permit persons to whom the Software is
> furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all
> copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
> AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
> LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
> OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
> SOFTWARE.

## whatwg-url (MIT License)

`lib/src/foundation/url/whatwg_url.dart` ports whatwg-url 16.0.1's basic URL parser and URL serializer
(`lib/url-state-machine.js`, with `lib/percent-encoding.js`, `lib/infra.js` and the constructor of
`lib/URL-impl.js`): the URL Standard's reference implementation, which jsdom gives CopilotKit's openUrl tests, and by
which `openUrl` resolves a URL against the page on the web. Its domain-to-ASCII step is followed for ASCII domains
only, as tr46 6.0.0 (MIT, © Sebastian Mayr) gives them; nothing of tr46 is ported. The licence below is the
package's own `LICENSE.txt`.

> The MIT License (MIT)
>
> Copyright (c) Sebastian Mayr
>
> Permission is hereby granted, free of charge, to any person obtaining a copy
> of this software and associated documentation files (the "Software"), to deal
> in the Software without restriction, including without limitation the rights
> to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
> copies of the Software, and to permit persons to whom the Software is
> furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in
> all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
> AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
> LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
> OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
> THE SOFTWARE.

## Lucide (ISC License)

`lib/src/foundation/icons/lucide_icons.g.dart` holds the icon nodes (the SVG elements of each icon), the `icons` map
and the exported names of lucide-react 0.525.0, which CopilotKit's react-core draws with, and lucide-react 1.57.0,
which the A2UI playground draws with, generated by `tool/src/lucide.dart` from each published package (fetched whole
from registry.npmjs.org, its sha512 the one CopilotKit's `pnpm-lock.yaml` holds). `lib/src/foundation/icons/lucide.dart`
strokes them as lucide-react's `<svg>` does. The licences below are each package's own `LICENSE` (880 bytes in
0.525.0, 3208 in 1.57.0).

lucide-react 0.525.0:

> ISC License
>
> Copyright (c) for portions of Lucide are held by Cole Bemis 2013-2022 as part of Feather (MIT). All other copyright (c) for Lucide are held by Lucide Contributors 2022.
>
> Permission to use, copy, modify, and/or distribute this software for any
> purpose with or without fee is hereby granted, provided that the above
> copyright notice and this permission notice appear in all copies.
>
> THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
> WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
> MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
> ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
> WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
> ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
> OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

lucide-react 1.57.0:

> ISC License
>
> Copyright (c) 2026 Lucide Icons and Contributors
>
> Permission to use, copy, modify, and/or distribute this software for any
> purpose with or without fee is hereby granted, provided that the above
> copyright notice and this permission notice appear in all copies.
>
> THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
> WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
> MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
> ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
> WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
> ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
> OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
>
> ---
>
> The following Lucide icons are derived from the Feather project:
>
> airplay, alert-circle, alert-octagon, alert-triangle, aperture, arrow-down-circle, arrow-down-left, arrow-down-right, arrow-down, arrow-left-circle, arrow-left, arrow-right-circle, arrow-right, arrow-up-circle, arrow-up-left, arrow-up-right, arrow-up, at-sign, calendar, cast, check, chevron-down, chevron-left, chevron-right, chevron-up, chevrons-down, chevrons-left, chevrons-right, chevrons-up, circle, clipboard, clock, code, columns, command, compass, corner-down-left, corner-down-right, corner-left-down, corner-left-up, corner-right-down, corner-right-up, corner-up-left, corner-up-right, crosshair, database, divide-circle, divide-square, dollar-sign, download, external-link, feather, frown, hash, headphones, help-circle, info, italic, key, layout, life-buoy, link-2, link, loader, lock, log-in, log-out, maximize, meh, minimize, minimize-2, minus-circle, minus-square, minus, monitor, moon, more-horizontal, more-vertical, move, music, navigation-2, navigation, octagon, pause-circle, percent, plus-circle, plus-square, plus, power, radio, rss, search, server, share, shopping-bag, sidebar, smartphone, smile, square, table-2, tablet, target, terminal, trash-2, trash, triangle, tv, type, upload, x-circle, x-octagon, x-square, x, zoom-in, zoom-out
>
> The MIT License (MIT) (for the icons listed above)
>
> Copyright (c) 2013-present Cole Bemis
>
> Permission is hereby granted, free of charge, to any person obtaining a copy
> of this software and associated documentation files (the "Software"), to deal
> in the Software without restriction, including without limitation the rights
> to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
> copies of the Software, and to permit persons to whom the Software is
> furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all
> copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
> AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
> LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
> OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
> SOFTWARE.

## Chromium (BSD 3-Clause License)

`lib/src/foundation/layout/html_table.dart` ports Chromium 159.0.8154.13's table layout (LayoutNG,
`third_party/blink/renderer/core/layout/table/`: column constraints, the width distribution, colspan and rowspan
distribution, collapsed borders, cell alignment) and its `colspan` and `rowspan` parsing
(`third_party/blink/renderer/core/html/html_table_cell_element.cc`, `html/parser/html_parser_idioms.cc`), read from
chromium.googlesource.com at that tag. The same tag's rules are followed elsewhere: the SVG shapes' paths
(`core/svg/svg_{rect,circle,ellipse,line,poly,polygon,polyline}_element.cc`, `core/css/svg.css`) in
`lib/src/foundation/icons/lucide.dart` and the Svg component; the keys that scroll and the `:focus-visible` rule
(`core/input/keyboard_event_manager.cc`, `core/input/scroll_manager.cc`, `core/dom/node.cc`, `core/dom/element.cc`,
`core/css/selector_checker.cc`), when a touch focuses (`core/input/gesture_manager.cc`, `ui/events/gesture_detection/`)
and the keyboard-focusable scroller (`core/dom/element.cc`) in `lib/src/foundation/interaction/`, the focusable
scroll box and the chart plot; a grid span's clamp (`core/style/grid_area.h`) in
`lib/src/foundation/layout/render_css_grid.dart`; the user agent's styles of
`<strong>`, `<em>`, `<u>`, `<s>` and `<pre>` and its font-size rules (`core/html/resources/html.css`,
`core/css/resolver/`, `platform/fonts/font_description.{h,cc}`) in the inline text components and Code.

> Copyright 2015 The Chromium Authors
>
> Redistribution and use in source and binary forms, with or without modification, are permitted provided that the
> following conditions are met:
>
> * Redistributions of source code must retain the above copyright notice, this list of conditions and the following
>   disclaimer.
> * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the
>   following disclaimer in the documentation and/or other materials provided with the distribution.
> * Neither the name of Google LLC nor the names of its contributors may be used to endorse or promote products
>   derived from this software without specific prior written permission.
>
> THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
> INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
> DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
> SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
> SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
> WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
> OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

## flutter_markdown_plus (BSD 3-Clause License)

`lib/src/components/standard/text/markdown.dart` drives flutter_markdown_plus 1.0.12's `MarkdownBuilder` itself and
adapts its `MarkdownBody` (`lib/src/widget.dart`: the parse, the link recognizers, the code text) and its list layout
(`lib/src/builder.dart`: the marker beside each item, the numbering, the spacing between items). flutter_markdown_plus
is a dependency; its LICENSE:

> Copyright 2013 The Flutter Authors. All rights reserved.
>
> Redistribution and use in source and binary forms, with or without modification,
> are permitted provided that the following conditions are met:
>
>     * Redistributions of source code must retain the above copyright
>       notice, this list of conditions and the following disclaimer.
>     * Redistributions in binary form must reproduce the above
>       copyright notice, this list of conditions and the following
>       disclaimer in the documentation and/or other materials provided
>       with the distribution.
>     * Neither the name of Google Inc. nor the names of its
>       contributors may be used to endorse or promote products derived
>       from this software without specific prior written permission.
>
> THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
> ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
> WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
> DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
> ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
> (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
> LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
> ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
> (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
> SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

## License

The MIT License

Copyright (c) Atai Barkai

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
