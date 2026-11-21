/// The sample surfaces of the gallery, by name.
final Map<String, List<Map<String, Object?>>> gallerySamples = {
  'layout': [
    {
      'id': 'root',
      'component': 'Column',
      'children': ['kv1', 'kv2', 'div', 'box', 'row'],
    },
    {
      'id': 'kv1',
      'component': 'Row',
      'justify': 'spaceBetween',
      'children': ['k1', 'v1'],
    },
    {'id': 'k1', 'component': 'Caption', 'text': 'Subtotal'},
    {
      'id': 'v1',
      'component': 'Text',
      'text': r'$1,240.00',
      'fontWeight': 'medium',
      'tabularNums': true,
    },
    {
      'id': 'kv2',
      'component': 'Row',
      'justify': 'spaceBetween',
      'children': ['k2', 'v2'],
    },
    {'id': 'k2', 'component': 'Caption', 'text': 'Shipping'},
    {'id': 'v2', 'component': 'Text', 'text': 'Free', 'color': 'success'},
    {'id': 'div', 'component': 'Divider'},
    {
      'id': 'box',
      'component': 'Box',
      'border': true,
      'radius': 'lg',
      'padding': 3,
      'gap': 2,
      'children': ['bt', 'bc'],
    },
    {'id': 'bt', 'component': 'Label', 'text': 'Delivery window'},
    {
      'id': 'bc',
      'component': 'Text',
      'text': 'Tuesday, 9:00 to 12:00. We text you an hour before.',
    },
    {
      'id': 'row',
      'component': 'Row',
      'children': ['left', 'sp', 'right'],
    },
    {'id': 'left', 'component': 'Badge', 'label': 'Express'},
    {'id': 'sp', 'component': 'Spacer'},
    {
      'id': 'right',
      'component': 'Caption',
      'text': 'Order #4821',
      'size': 'sm',
    },
  ],
  'card': [
    {
      'id': 'root',
      'component': 'Card',
      'children': ['head', 'body', 'panel', 'div', 'tags'],
    },
    {
      'id': 'head',
      'component': 'Column',
      'gap': 1,
      'children': ['title', 'sub'],
    },
    {'id': 'title', 'component': 'Title', 'text': 'Team plan', 'size': 'lg'},
    {
      'id': 'sub',
      'component': 'Caption',
      'text': 'Billed yearly, **cancel** any time',
    },
    {
      'id': 'body',
      'component': 'Text',
      'text': 'Up to 25 seats, shared workspaces and *priority* support.',
    },
    {
      'id': 'panel',
      'component': 'Card',
      'background': 'surface-secondary',
      'children': ['pk', 'pv'],
    },
    {'id': 'pk', 'component': 'Label', 'text': 'Price'},
    {
      'id': 'pv',
      'component': 'Text',
      'text': r'$29 per seat',
      'size': 'lg',
      'strong': true,
    },
    {'id': 'div', 'component': 'Divider'},
    {
      'id': 'tags',
      'component': 'Row',
      'wrap': 'wrap',
      'children': ['b1', 'b2', 'b3'],
    },
    {
      'id': 'b1',
      'component': 'Badge',
      'label': 'Popular',
      'color': 'discovery',
    },
    {'id': 'b2', 'component': 'Badge', 'label': 'SSO', 'variant': 'outline'},
    {
      'id': 'b3',
      'component': 'Badge',
      'label': 'Save 20%',
      'color': 'success',
      'variant': 'solid',
    },
  ],
  'grid': [
    {
      'id': 'root',
      'component': 'Grid',
      'columns': 2,
      'gap': 3,
      'children': ['c1', 'c2', 'c3', 'wide'],
    },
    for (final (id, label, value) in [
      ('c1', 'Revenue', r'$18.4M'),
      ('c2', 'Customers', '2,940'),
      ('c3', 'Churn', '1.8%'),
    ]) ...[
      {
        'id': id,
        'component': 'Card',
        'size': 'sm',
        'children': ['${id}_l', '${id}_v'],
      },
      {'id': '${id}_l', 'component': 'Caption', 'text': label},
      {'id': '${id}_v', 'component': 'Title', 'text': value, 'size': 'xl'},
    ],
    {
      'id': 'wide',
      'component': 'GridItem',
      'span': 2,
      'children': ['wt'],
    },
    {
      'id': 'wt',
      'component': 'Text',
      'text': 'A GridItem that spans both columns fills the row.',
      'highlight': 'green',
    },
  ],
  'text': [
    {
      'id': 'root',
      'component': 'Column',
      'gap': 2,
      'children': ['t1', 't2', 't3', 't4', 'x1', 'x2', 'x3', 'x4', 'l1'],
    },
    {'id': 't1', 'component': 'Title', 'text': 'Title 2xl', 'size': '2xl'},
    {'id': 't2', 'component': 'Title', 'text': 'Title lg', 'size': 'lg'},
    {'id': 't3', 'component': 'Title', 'text': 'Title sm', 'size': 'sm'},
    {
      'id': 't4',
      'component': 'Title',
      'text': 'A title too long to fit on one line is cut',
      'truncate': true,
    },
    {
      'id': 'x1',
      'component': 'Text',
      'text': 'Body with **bold**, *italic*, ~~old~~, ++new++ and `code`.',
    },
    {'id': 'x2', 'component': 'Text', 'text': 'Small text', 'size': 'sm'},
    {
      'id': 'x3',
      'component': 'Text',
      'text':
          'Two lines at most: this sentence goes on long enough to need '
          'a third line on a narrow surface.',
      'maxLines': 2,
      'color': 'secondary',
    },
    {
      'id': 'x4',
      'component': 'Text',
      'text': 'Plan',
      'children': ['xb'],
    },
    {'id': 'xb', 'component': 'Badge', 'label': 'Pro', 'size': 'sm'},
    {'id': 'l1', 'component': 'Label', 'text': 'Email address'},
  ],
  'badges': [
    {
      'id': 'root',
      'component': 'Column',
      'children': ['soft', 'solid', 'outline'],
    },
    for (final variant in ['soft', 'solid', 'outline']) ...[
      {
        'id': variant,
        'component': 'Row',
        'wrap': 'wrap',
        'children': [
          for (final color in [
            'secondary',
            'success',
            'danger',
            'warning',
            'info',
            'discovery',
          ])
            '${variant}_$color',
        ],
      },
      for (final color in [
        'secondary',
        'success',
        'danger',
        'warning',
        'info',
        'discovery',
      ])
        {
          'id': '${variant}_$color',
          'component': 'Badge',
          'label': color,
          'color': color,
          'variant': variant,
        },
    ],
  ],
  // Phase 1b.
  'form': [
    {
      'id': 'root',
      'component': 'Card',
      'children': ['form'],
    },
    {
      'id': 'form',
      'component': 'Form',
      'label': 'Book a demo',
      'children': ['name', 'plan', 'size', 'terms', 'actions'],
    },
    {
      'id': 'name',
      'component': 'TextField',
      'label': 'Work email',
      'placeholder': 'you@company.com',
      'value': 'ada@',
      'checks': [
        {
          'condition': {
            '@call': 'email',
            'args': {'value': 'ada@'},
          },
        },
      ],
    },
    {
      'id': 'plan',
      'component': 'Select',
      'label': 'Plan',
      'icon': 'credit-card',
      'options': ['Free', 'Team', 'Enterprise'],
      'value': 'Team',
    },
    {
      'id': 'size',
      'component': 'RadioGroup',
      'label': 'Team size',
      'variant': 'pills',
      'options': ['1-10', '11-50', '51+'],
      'value': '11-50',
    },
    {
      'id': 'terms',
      'component': 'CheckBox',
      'label': 'Send me the weekly report',
      'value': true,
    },
    {
      'id': 'actions',
      'component': 'Row',
      'children': ['cancel', 'send'],
    },
    {'id': 'cancel', 'component': 'Button', 'label': 'Cancel'},
    {
      'id': 'send',
      'component': 'Button',
      'label': 'Book',
      'icon': 'send',
      'variant': 'primary',
      'submit': true,
    },
  ],
  'buttons': [
    {
      'id': 'root',
      'component': 'Column',
      'children': ['r1', 'r2', 'r3'],
    },
    {
      'id': 'r1',
      'component': 'Row',
      'wrap': 'wrap',
      'children': ['primary', 'default', 'soft', 'borderless'],
    },
    {
      'id': 'primary',
      'component': 'Button',
      'label': 'Primary',
      'variant': 'primary',
    },
    {'id': 'default', 'component': 'Button', 'label': 'Default'},
    {'id': 'soft', 'component': 'Button', 'label': 'Soft', 'variant': 'soft'},
    {
      'id': 'borderless',
      'component': 'Button',
      'label': 'Borderless',
      'variant': 'borderless',
    },
    {
      'id': 'r2',
      'component': 'Row',
      'wrap': 'wrap',
      'children': ['danger', 'secondary', 'small', 'square'],
    },
    {
      'id': 'danger',
      'component': 'Button',
      'label': 'Delete',
      'color': 'danger',
      'icon': 'trash-2',
    },
    {
      'id': 'secondary',
      'component': 'Button',
      'label': 'Secondary',
      'variant': 'primary',
      'color': 'secondary',
    },
    {
      'id': 'small',
      'component': 'Button',
      'label': 'Small',
      'size': 'sm',
      'pill': false,
    },
    {'id': 'square', 'component': 'Button', 'icon': 'plus', 'uniform': true},
    {
      'id': 'r3',
      'component': 'Button',
      'label': 'Block and disabled',
      'block': true,
      'disabled': true,
    },
  ],
  'lists': [
    {
      'id': 'root',
      'component': 'Column',
      'children': ['specs', 'steps', 'icons', 'link'],
    },
    {
      'id': 'specs',
      'component': 'List',
      'marker': 'none',
      'items': [
        {'label': 'Price', 'value': r'$1,599'},
        {'label': 'Battery', 'value': '18 h', 'description': 'Mixed use'},
      ],
    },
    {
      'id': 'steps',
      'component': 'List',
      'marker': 'number',
      'connector': 'solid',
      'items': ['Sign up', 'Invite your team', 'Ship'],
    },
    {
      'id': 'icons',
      'component': 'Row',
      'children': ['i1', 'i2', 'i3', 'i4'],
    },
    {'id': 'i1', 'component': 'Icon', 'name': 'check', 'color': 'success'},
    {'id': 'i2', 'component': 'Icon', 'name': 'warning', 'color': 'warning'},
    {'id': 'i3', 'component': 'Icon', 'name': 'heart', 'size': 'xl'},
    {
      'id': 'i4',
      'component': 'Icon',
      'name': {'svgPath': 'M12 2 22 22H2z'},
      'color': 'info',
    },
    {
      'id': 'link',
      'component': 'Link',
      'text': 'Read the docs',
      'href': 'https://docs.copilotkit.ai',
    },
  ],
  'markdown': [
    {
      'id': 'root',
      'component': 'Markdown',
      'text':
          '## Release notes\n\nThe **new** planner and a `fix` for '
          'search.\n\n- Faster sync\n- [x] Dark mode\n\n> Ship it.\n\n'
          '| Plan | Seats |\n|---|---|\n| Team | 10 |',
    },
  ],
  'kpis': [
    {
      'id': 'root',
      'component': 'Column',
      'children': ['head', 'row', 'group'],
    },
    {
      'id': 'head',
      'component': 'Heading',
      'eyebrow': 'Sales dashboard',
      'text': 'Q3 sales by region',
      'subtitle': 'Revenue grew 11% on EMEA renewals',
    },
    {
      'id': 'row',
      'component': 'Row',
      'children': ['k1', 'k2'],
    },
    {
      'id': 'k1',
      'component': 'Stat',
      'label': 'Revenue',
      'value': r'$18.4M',
      'delta': '+11.2%',
      'icon': 'trending-up',
      'tone': 'positive',
      'caption': 'vs. Q2',
    },
    {
      'id': 'k2',
      'component': 'Stat',
      'label': 'Churn',
      'value': '2.1%',
      'delta': '-0.4%',
    },
    {
      'id': 'group',
      'component': 'StatGroup',
      'items': [
        {'label': 'Visitors', 'value': '84,210', 'delta': '+8.1%'},
        {'label': 'Signups', 'value': 2318, 'delta': '+14.6%'},
        {
          'label': 'Avg. session',
          'value': '4m 12s',
          'delta': '0.0%',
          'trend': 'flat',
        },
      ],
    },
  ],
  'details': [
    {
      'id': 'root',
      'component': 'Section',
      'eyebrow': 'Order',
      'title': 'Order #A-20481',
      'description': 'Shipped to Lisbon.',
      'children': ['kv', 'alert', 'callout'],
    },
    {
      'id': 'kv',
      'component': 'KeyValueList',
      'title': 'Summary',
      'items': [
        {'label': 'Placed', 'value': 'Oct 14, 2026', 'hint': '9:42 AM PT'},
        {'label': 'Items', 'value': 3},
        {'label': 'Total', 'value': r'$236.40', 'hint': r'Incl. $18.40 tax'},
      ],
    },
    {
      'id': 'alert',
      'component': 'Alert',
      'tone': 'warning',
      'title': 'Usage at 92% of plan',
      'message': 'You will hit the request limit in about 3 days.',
    },
    {
      'id': 'callout',
      'component': 'Callout',
      'title': 'Tip',
      'text': 'Fixed-schema surfaces paint as soon as the data lands.',
      'actionLabel': 'Learn more',
      'onAction': {
        'event': {'name': 'learn_more'},
      },
    },
  ],
  // Phase 2a: the playground's chart samples (samples/charts.ts).
  'charts': [
    {
      'id': 'root',
      'component': 'Column',
      'children': ['line', 'area', 'bar', 'pie', 'scatter', 'spark'],
    },
    {
      'id': 'line',
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
    },
    {
      'id': 'area',
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
    },
    {
      'id': 'bar',
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
    },
    {
      'id': 'pie',
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
    },
    {
      'id': 'scatter',
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
    },
    {
      'id': 'spark',
      'component': 'Sparkline',
      'label': 'Monthly recurring revenue',
      'value': r'$184.2K',
      'delta': '+12.4%',
      'tone': 'positive',
      'values': [
        128, 131, 129, 138, 142, 140, 149, 155, 153, 162, 171, 168, 176, 184, //
      ],
    },
  ],
  // CopilotKit's standard Chart, as recharts draws it.
  'chart': [
    {
      'id': 'root',
      'component': 'Column',
      'children': ['bars', 'cost', 'donut'],
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
    {
      'id': 'cost',
      'component': 'Chart',
      'chartType': 'area',
      'title': 'Monthly cost',
      'xKey': 'month',
      'series': ['cost', 'budget'],
      'stacked': true,
      'format': 'currency',
      'data': [
        {'month': 'Jan', 'cost': 290, 'budget': 120},
        {'month': 'Feb', 'cost': 580, 'budget': 140},
        {'month': 'Mar', 'cost': 410, 'budget': 160},
      ],
    },
    {
      'id': 'donut',
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

/// One row per value of the series [name], x from [xs] (the months).
List<Map<String, Object?>> _series(
  String name,
  List<num> values, [
  List<Object> xs = _months,
]) => [
  for (var i = 0; i < values.length; i++)
    {'x': xs[i], 'y': values[i], 'series': name},
];
