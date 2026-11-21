# CopilotKit fixtures

The files in this folder come from CopilotKit (https://github.com/CopilotKit/CopilotKit), commit
`ff6f3b03267159cbbf70f9878d988adf4968d022` (2026-11-17), and are used under the MIT License below.
They are test data and the schema source for code generation; none of them is executed.

| File here | Source in the CopilotKit repository | Changes |
|---|---|---|
| `catalog.json` | `examples/showcases/a2ui-playground/src/a2ui/export/catalog.json` | none |
| `inference-catalog.json` | `examples/showcases/a2ui-playground/src/a2ui/export/inference-catalog.json` | none |
| `standard-all.json` | `packages/react-core/src/v2/generative-ui/standard/__tests__/fixtures/standard-all.json` | none |
| `examples.json` | the `<a2ui-json>` block of `examples/showcases/a2ui-playground/skills/generated/json/a2ui-playground/SKILL.md` | extracted and pretty-printed |
| `replays/sales-dashboard.json` | `examples/showcases/a2ui-playground/src/data/replay.json` | renamed |
| `replays/tokyo-trip.json` | `examples/showcases/a2ui-playground/src/data/replay-tokyo.json` | renamed |
| `replays/lisbon-weather.json` | `examples/showcases/a2ui-playground/src/data/replay-weather.json` | renamed |
| `samples_ts/*.ts` | `examples/showcases/a2ui-playground/src/a2ui/catalog/samples/*.ts` | none (reference only; to be converted to JSON) |
| `samples_ts/macro-samples.ts` | `examples/showcases/a2ui-playground/src/a2ui/macros/samples.ts` | renamed (reference only) |

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
