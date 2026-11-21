// The chart samples of CopilotKit's playground (samples/charts.ts and the
// standard Chart preview in samples/standard.ts, MIT, (c) Atai Barkai),
// converted to JSON by hand.

const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// charts.ts's `series`: one row per value, x from [xs] (the months).
List<Map<String, Object?>> _series(
  String name,
  List<num> values, [
  List<Object> xs = _months,
]) => [
  for (var i = 0; i < values.length; i++)
    {'x': xs[i], 'y': values[i], 'series': name},
];

/// The surface of one [component].
List<Map<String, Object?>> _root(Map<String, Object?> component) => [
  {'id': 'root', ...component},
];

/// The chart samples, by name.
final Map<String, List<Map<String, Object?>>> chartSamples = {
  'line_chart': _root({
    'component': 'LineChart',
    'title': 'Weekly active users',
    'subtitle': 'Web vs mobile, last 12 months',
    'format': 'compact',
    'data': [
      ..._series('Web', [
        18200, 19400, 21100, 20800, 23900, 26400, //
        25800, 28900, 31200, 33800, 35100, 38400,
      ]),
      ..._series('Mobile', [
        9800, 10900, 12600, 14100, 15900, 17200, //
        19800, 21400, 24100, 26900, 29300, 32600,
      ]),
    ],
  }),
  'area_chart': _root({
    'component': 'AreaChart',
    'title': 'Inference spend by workload',
    'subtitle': 'Stacked monthly cost, USD',
    'format': 'currency',
    'stacked': true,
    'data': [
      ..._series('Chat', [
        4200, 4800, 5600, 6100, 7300, 8100, //
        8900, 9400, 10800, 11600, 12900, 14100,
      ]),
      ..._series('Agents', [
        2100, 2600, 3300, 3900, 4400, 5200, //
        6100, 6900, 7400, 8300, 9100, 9800,
      ]),
      ..._series('Embeddings', [
        900, 950, 1100, 1180, 1260, 1400, //
        1520, 1610, 1700, 1820, 1950, 2080,
      ]),
    ],
  }),
  'bar_chart': _root({
    'component': 'BarChart',
    'title': 'Revenue by region',
    'subtitle': 'Quarterly, USD',
    'format': 'currency',
    'data': [
      ..._series(
        '2025',
        [412000, 298000, 186000, 94000],
        ['NA', 'EMEA', 'APAC', 'LATAM'],
      ),
      ..._series(
        '2026',
        [538000, 371000, 262000, 131000],
        ['NA', 'EMEA', 'APAC', 'LATAM'],
      ),
    ],
  }),
  'pie_chart': _root({
    'component': 'PieChart',
    'title': 'Traffic sources',
    'subtitle': 'Sessions, last 30 days',
    'donut': true,
    'centerLabel': 'sessions',
    'format': 'compact',
    'data': [
      {'label': 'Organic search', 'value': 48200},
      {'label': 'Direct', 'value': 27100},
      {'label': 'Referral', 'value': 14600},
      {'label': 'Social', 'value': 9800},
      {'label': 'Email', 'value': 5300},
    ],
  }),
  'scatter_chart': _root({
    'component': 'ScatterChart',
    'title': 'Latency vs throughput',
    'subtitle': 'Per deployment, bubble size is replica count',
    'xLabel': 'Requests / s',
    'yLabel': 'p95 latency',
    'unit': 'ms',
    'data': [
      for (final (x, y, size, series, label) in const [
        (120, 84, 2, 'us-east', 'api-gateway'),
        (340, 112, 4, 'us-east', 'search'),
        (610, 168, 8, 'us-east', 'checkout'),
        (880, 241, 12, 'us-east', 'catalog'),
        (210, 64, 3, 'eu-west', 'auth'),
        (450, 98, 5, 'eu-west', 'search'),
        (720, 132, 9, 'eu-west', 'checkout'),
        (960, 188, 14, 'eu-west', 'catalog'),
        (300, 142, 2, 'ap-south', 'search'),
        (520, 205, 6, 'ap-south', 'checkout'),
        (690, 262, 7, 'ap-south', 'catalog'),
      ])
        {'x': x, 'y': y, 'size': size, 'series': series, 'label': label},
    ],
  }),
  'sparkline': _root({
    'component': 'Sparkline',
    'label': 'Monthly recurring revenue',
    'value': r'$184.2K',
    'delta': '+12.4%',
    'tone': 'positive',
    'values': [
      128, 131, 129, 138, 142, 140, 149, 155, 153, 162, 171, 168, 176, 184, //
    ],
  }),
  'chart': [
    {
      'id': 'root',
      'component': 'Column',
      'children': ['bars', 'cost', 'pie'],
    },
    {
      'id': 'bars',
      'component': 'Chart',
      'chartType': 'bar',
      'title': 'Signups by week',
      'xKey': 'week',
      'series': [
        {'key': 'signups', 'label': 'Signups'},
      ],
      'data': [
        {'week': 'W1', 'signups': 120},
        {'week': 'W2', 'signups': 164},
        {'week': 'W3', 'signups': 151},
        {'week': 'W4', 'signups': 208},
      ],
    },
    // standard-all.json's chart.
    {
      'id': 'cost',
      'component': 'Chart',
      'chartType': 'line',
      'title': 'Monthly cost',
      'xKey': 'month',
      'series': ['cost'],
      'showDots': true,
      'data': [
        {'month': 'Jan', 'cost': 290},
        {'month': 'Feb', 'cost': 580},
        {'month': 'Mar', 'cost': 410},
      ],
      'height': 160,
      'format': 'currency',
    },
    {
      'id': 'pie',
      'component': 'Chart',
      'chartType': 'donut',
      'xKey': 'name',
      'series': ['amount'],
      'format': 'percent',
      'showValueLabels': true,
      'data': [
        {'name': 'First', 'amount': 0.4},
        {'name': 'Second', 'amount': 0.35},
        {'name': 'Third', 'amount': 0.25},
      ],
    },
  ],
};
