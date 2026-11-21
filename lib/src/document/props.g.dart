// GENERATED CODE. Do not edit by hand: run `dart run tool/generate.dart`.
// Source: CopilotKit (MIT, (c) Atai Barkai), commit ff6f3b03, the A2UI
// Playground export. See NOTICE.md.
// ignore_for_file: comment_references, constant_identifier_names, lines_longer_than_80_chars, unintended_html_in_doc_comment (names and docs from CopilotKit's catalog)

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';

/// The values of `SegmentedControl.variant`.
enum A2uiActionVariant {
  /// `"solid"`.
  solid('solid'),

  /// `"soft"`.
  soft('soft'),

  /// `"outline"`.
  outline('outline'),

  /// `"ghost"`.
  ghost('ghost');

  const A2uiActionVariant(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static A2uiActionVariant? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `Box.align`, `Column.align`, `Row.align`, `Grid.align`,
/// `GridItem.align`, `Card.align`, `Flow.align`, `FlowItem.align`,
/// `Carousel.align`, `CarouselItem.align`, `CarouselMediaItem.align`,
/// `Pressable.align`, `Form.align`.
enum A2uiAlign {
  /// `"start"`.
  start('start'),

  /// `"center"`.
  center('center'),

  /// `"end"`.
  end('end'),

  /// `"baseline"`.
  baseline('baseline'),

  /// `"stretch"`.
  stretch('stretch');

  const A2uiAlign(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static A2uiAlign? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `Badge.color`.
enum A2uiBadgeColor {
  /// `"secondary"`.
  secondary('secondary'),

  /// `"success"`.
  success('success'),

  /// `"danger"`.
  danger('danger'),

  /// `"warning"`.
  warning('warning'),

  /// `"info"`.
  info('info'),

  /// `"discovery"`.
  discovery('discovery');

  const A2uiBadgeColor(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static A2uiBadgeColor? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `Box.borderColor`, `Column.borderColor`,
/// `Row.borderColor`, `Grid.borderColor`, `GridItem.borderColor`,
/// `Card.borderColor`, `Flow.borderColor`, `FlowItem.borderColor`,
/// `Carousel.borderColor`, `CarouselItem.borderColor`,
/// `CarouselMediaItem.borderColor`, `Divider.color`,
/// `Pressable.borderColor`, `Form.borderColor`.
enum A2uiBorderColor {
  /// `"default"`.
  default_('default'),

  /// `"subtle"`.
  subtle('subtle'),

  /// `"strong"`.
  strong('strong'),

  /// `"info"`.
  info('info'),

  /// `"warning"`.
  warning('warning'),

  /// `"caution"`.
  caution('caution'),

  /// `"success"`.
  success('success'),

  /// `"danger"`.
  danger('danger'),

  /// `"discovery"`.
  discovery('discovery');

  const A2uiBorderColor(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static A2uiBorderColor? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `Button.checks[].condition.severity`,
/// `TextField.checks[].condition.severity`,
/// `TextArea.checks[].condition.severity`,
/// `Select.checks[].condition.severity`,
/// `CheckBox.checks[].condition.severity`,
/// `RadioGroup.checks[].condition.severity`,
/// `Slider.checks[].condition.severity`,
/// `SegmentedControl.checks[].condition.severity`,
/// `ChoicePicker.checks[].condition.severity`,
/// `DateTimeInput.checks[].condition.severity`.
enum A2uiCheckSeverity {
  /// `"error"`.
  error('error'),

  /// `"warning"`.
  warning('warning'),

  /// `"info"`.
  info('info');

  const A2uiCheckSeverity(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static A2uiCheckSeverity? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `TextField.size`, `TextArea.size`, `Select.size`,
/// `SegmentedControl.size`.
enum A2uiControlSize {
  /// `"sm"`.
  sm('sm'),

  /// `"md"`.
  md('md'),

  /// `"lg"`.
  lg('lg'),

  /// `"xl"`.
  xl('xl');

  const A2uiControlSize(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static A2uiControlSize? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `Title.fontWeight`, `Text.fontWeight`,
/// `Caption.fontWeight`, `Label.fontWeight`, `Bold.fontWeight`,
/// `Badge.fontWeight`, `ShimmerText.fontWeight`, `Icon.strokeWeight`.
enum A2uiFontWeight {
  /// `"normal"`.
  normal('normal'),

  /// `"medium"`.
  medium('medium'),

  /// `"semibold"`.
  semibold('semibold'),

  /// `"bold"`.
  bold('bold');

  const A2uiFontWeight(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static A2uiFontWeight? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `Box.justify`, `Column.justify`, `Row.justify`,
/// `Grid.justify`, `GridItem.justify`, `Card.justify`, `Flow.justify`,
/// `FlowItem.justify`, `Carousel.justify`, `CarouselItem.justify`,
/// `CarouselMediaItem.justify`, `Pressable.justify`, `Form.justify`.
enum A2uiJustify {
  /// `"start"`.
  start('start'),

  /// `"center"`.
  center('center'),

  /// `"end"`.
  end('end'),

  /// `"spaceBetween"`.
  spaceBetween('spaceBetween'),

  /// `"spaceAround"`.
  spaceAround('spaceAround'),

  /// `"spaceEvenly"`.
  spaceEvenly('spaceEvenly'),

  /// `"stretch"`.
  stretch('stretch');

  const A2uiJustify(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static A2uiJustify? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `List.direction`, `Chart.layout`, `EntityCard.layout`.
enum A2uiOrientation {
  /// `"vertical"`.
  vertical('vertical'),

  /// `"horizontal"`.
  horizontal('horizontal');

  const A2uiOrientation(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static A2uiOrientation? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `Box.radius`, `Column.radius`, `Row.radius`,
/// `Grid.radius`, `GridItem.radius`, `Card.radius`, `Flow.radius`,
/// `FlowItem.radius`, `Carousel.radius`, `CarouselItem.radius`,
/// `CarouselMediaItem.radius`, `Pressable.radius`, `Form.radius`,
/// `Image.radius`.
enum A2uiRadius {
  /// `"2xs"`.
  twoXs('2xs'),

  /// `"xs"`.
  xs('xs'),

  /// `"sm"`.
  sm('sm'),

  /// `"md"`.
  md('md'),

  /// `"lg"`.
  lg('lg'),

  /// `"xl"`.
  xl('xl'),

  /// `"2xl"`.
  twoXl('2xl'),

  /// `"3xl"`.
  threeXl('3xl'),

  /// `"4xl"`.
  fourXl('4xl'),

  /// `"full"`.
  full('full');

  const A2uiRadius(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static A2uiRadius? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `Card.size`, `CarouselMediaItem.size`, `Caption.size`,
/// `Badge.size`, `Button.size`, `Avatar.size`.
enum A2uiSize {
  /// `"sm"`.
  sm('sm'),

  /// `"md"`.
  md('md'),

  /// `"lg"`.
  lg('lg');

  const A2uiSize(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static A2uiSize? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `Carousel.snapAlign`, `Title.textAlign`, `Text.textAlign`,
/// `Caption.textAlign`, `Label.textAlign`, `ShimmerText.textAlign`,
/// `PopoverContent.align`, `TableCell.vAlign`, `TableCell.align`.
enum A2uiTextAlign {
  /// `"start"`.
  start('start'),

  /// `"center"`.
  center('center'),

  /// `"end"`.
  end('end');

  const A2uiTextAlign(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static A2uiTextAlign? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `Text.size`, `Label.size`, `ShimmerText.size`.
enum A2uiTextSize {
  /// `"3xs"`.
  threeXs('3xs'),

  /// `"2xs"`.
  twoXs('2xs'),

  /// `"xs"`.
  xs('xs'),

  /// `"sm"`.
  sm('sm'),

  /// `"md"`.
  md('md'),

  /// `"lg"`.
  lg('lg');

  const A2uiTextSize(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static A2uiTextSize? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `Stat.tone`, `Progress.tone`, `RadialProgress.tone`,
/// `TagList.tone`.
enum A2uiTone {
  /// `"default"`.
  default_('default'),

  /// `"positive"`.
  positive('positive'),

  /// `"negative"`.
  negative('negative'),

  /// `"warning"`.
  warning('warning'),

  /// `"info"`.
  info('info'),

  /// `"accent"`.
  accent('accent');

  const A2uiTone(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static A2uiTone? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `Stat.trend`.
enum A2uiTrend {
  /// `"up"`.
  up('up'),

  /// `"down"`.
  down('down'),

  /// `"flat"`.
  flat('flat');

  const A2uiTrend(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static A2uiTrend? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `LineChart.format`, `AreaChart.format`, `BarChart.format`,
/// `PieChart.format`, `ScatterChart.format`, `Heatmap.format`,
/// `RadarChart.format`, `CandlestickChart.format`, `Treemap.format`,
/// `SankeyChart.format`, `Gauge.format`.
enum A2uiValueFormat {
  /// `"number"`.
  number('number'),

  /// `"currency"`.
  currency('currency'),

  /// `"percent"`.
  percent('percent'),

  /// `"compact"`.
  compact('compact');

  const A2uiValueFormat(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static A2uiValueFormat? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `Box.wrap`, `Column.wrap`, `Row.wrap`, `Grid.wrap`,
/// `GridItem.wrap`, `Card.wrap`, `Flow.wrap`, `FlowItem.wrap`,
/// `Carousel.wrap`, `CarouselItem.wrap`, `CarouselMediaItem.wrap`,
/// `Pressable.wrap`, `Form.wrap`.
enum A2uiWrap {
  /// `"nowrap"`.
  nowrap('nowrap'),

  /// `"wrap"`.
  wrap('wrap'),

  /// `"wrap-reverse"`.
  wrapReverse('wrap-reverse');

  const A2uiWrap(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static A2uiWrap? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `Alert.tone`.
enum AlertTone {
  /// `"info"`.
  info('info'),

  /// `"success"`.
  success('success'),

  /// `"warning"`.
  warning('warning'),

  /// `"error"`.
  error('error');

  const AlertTone(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static AlertTone? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `Avatar.status`.
enum AvatarStatus {
  /// `"online"`.
  online('online'),

  /// `"away"`.
  away('away'),

  /// `"offline"`.
  offline('offline');

  const AvatarStatus(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static AvatarStatus? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `Badge.variant`.
enum BadgeVariant {
  /// `"soft"`.
  soft('soft'),

  /// `"solid"`.
  solid('solid'),

  /// `"outline"`.
  outline('outline');

  const BadgeVariant(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static BadgeVariant? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `Box.direction`.
enum BoxDirection {
  /// `"col"`.
  col('col'),

  /// `"row"`.
  row('row');

  const BoxDirection(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static BoxDirection? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `Button.color`.
enum ButtonColor {
  /// `"primary"`.
  primary('primary'),

  /// `"secondary"`.
  secondary('secondary'),

  /// `"danger"`.
  danger('danger');

  const ButtonColor(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static ButtonColor? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `Button.variant`.
enum ButtonVariant {
  /// `"default"`.
  default_('default'),

  /// `"primary"`.
  primary('primary'),

  /// `"soft"`.
  soft('soft'),

  /// `"borderless"`.
  borderless('borderless');

  const ButtonVariant(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static ButtonVariant? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `Card.shadowStyle`.
enum CardShadowStyle {
  /// `"none"`.
  none('none'),

  /// `"sm"`.
  sm('sm'),

  /// `"md"`.
  md('md');

  const CardShadowStyle(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static CardShadowStyle? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `Card.variant`.
enum CardVariant {
  /// `"default"`.
  default_('default'),

  /// `"outline"`.
  outline('outline'),

  /// `"section"`.
  section('section'),

  /// `"soft"`.
  soft('soft'),

  /// `"elevated"`.
  elevated('elevated'),

  /// `"transparent"`.
  transparent('transparent');

  const CardVariant(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static CardVariant? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `Carousel.snap`.
enum CarouselSnap {
  /// `"none"`.
  none('none'),

  /// `"proximity"`.
  proximity('proximity'),

  /// `"mandatory"`.
  mandatory('mandatory');

  const CarouselSnap(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static CarouselSnap? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `Chart.format`.
enum ChartFormat {
  /// `"number"`.
  number('number'),

  /// `"currency"`.
  currency('currency'),

  /// `"percent"`.
  percent('percent');

  const ChartFormat(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static ChartFormat? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `Chart.chartType`.
enum ChartType {
  /// `"bar"`.
  bar('bar'),

  /// `"line"`.
  line('line'),

  /// `"area"`.
  area('area'),

  /// `"scatter"`.
  scatter('scatter'),

  /// `"pie"`.
  pie('pie'),

  /// `"donut"`.
  donut('donut');

  const ChartType(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static ChartType? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `CheckBox.shape`.
enum CheckBoxShape {
  /// `"round"`.
  round('round'),

  /// `"square"`.
  square('square');

  const CheckBoxShape(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static CheckBoxShape? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `ChoicePicker.displayStyle`.
enum ChoicePickerDisplayStyle {
  /// `"checkbox"`.
  checkbox('checkbox'),

  /// `"chips"`.
  chips('chips');

  const ChoicePickerDisplayStyle(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static ChoicePickerDisplayStyle? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `ChoicePicker.variant`.
enum ChoicePickerVariant {
  /// `"multipleSelection"`.
  multipleSelection('multipleSelection'),

  /// `"mutuallyExclusive"`.
  mutuallyExclusive('mutuallyExclusive');

  const ChoicePickerVariant(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static ChoicePickerVariant? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `Divider.axis`.
enum DividerAxis {
  /// `"horizontal"`.
  horizontal('horizontal'),

  /// `"vertical"`.
  vertical('vertical');

  const DividerAxis(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static DividerAxis? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `FlowItem.aspectMode`.
enum FlowItemAspectMode {
  /// `"soft"`.
  soft('soft'),

  /// `"fixed"`.
  fixed('fixed');

  const FlowItemAspectMode(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static FlowItemAspectMode? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `Flow.layout`.
enum FlowLayout {
  /// `"pack"`.
  pack('pack'),

  /// `"fixed"`.
  fixed('fixed');

  const FlowLayout(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static FlowLayout? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `Heading.level`.
enum HeadingLevel {
  /// `"1"`.
  one('1'),

  /// `"2"`.
  two('2'),

  /// `"3"`.
  three('3');

  const HeadingLevel(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static HeadingLevel? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `Image.fit`.
enum ImageFit {
  /// `"cover"`.
  cover('cover'),

  /// `"contain"`.
  contain('contain'),

  /// `"fill"`.
  fill('fill'),

  /// `"none"`.
  none('none'),

  /// `"scaleDown"`.
  scaleDown('scaleDown');

  const ImageFit(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static ImageFit? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `ImageGrid.layout`.
enum ImageGridLayout {
  /// `"grid"`.
  grid('grid'),

  /// `"bento"`.
  bento('bento');

  const ImageGridLayout(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static ImageGridLayout? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `Image.variant`.
enum ImageVariant {
  /// `"icon"`.
  icon('icon'),

  /// `"avatar"`.
  avatar('avatar'),

  /// `"smallFeature"`.
  smallFeature('smallFeature'),

  /// `"mediumFeature"`.
  mediumFeature('mediumFeature'),

  /// `"largeFeature"`.
  largeFeature('largeFeature'),

  /// `"header"`.
  header('header');

  const ImageVariant(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static ImageVariant? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `List.align`.
enum ListAlign {
  /// `"start"`.
  start('start'),

  /// `"center"`.
  center('center'),

  /// `"end"`.
  end('end'),

  /// `"stretch"`.
  stretch('stretch');

  const ListAlign(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static ListAlign? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `List.connector`.
enum ListConnector {
  /// `"none"`.
  none('none'),

  /// `"solid"`.
  solid('solid');

  const ListConnector(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static ListConnector? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `List.marker`.
enum ListMarker {
  /// `"bullet"`.
  bullet('bullet'),

  /// `"number"`.
  number('number'),

  /// `"rich"`.
  rich('rich'),

  /// `"none"`.
  none('none');

  const ListMarker(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static ListMarker? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `PlaceList.basemap`.
enum PlaceListBasemap {
  /// `"dark"`.
  dark('dark'),

  /// `"streets"`.
  streets('streets'),

  /// `"liberty"`.
  liberty('liberty');

  const PlaceListBasemap(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static PlaceListBasemap? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `PopoverContent.side`.
enum PopoverContentSide {
  /// `"top"`.
  top('top'),

  /// `"bottom"`.
  bottom('bottom'),

  /// `"left"`.
  left('left'),

  /// `"right"`.
  right('right');

  const PopoverContentSide(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static PopoverContentSide? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `RadioGroup.direction`.
enum RadioGroupDirection {
  /// `"row"`.
  row('row'),

  /// `"col"`.
  col('col');

  const RadioGroupDirection(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static RadioGroupDirection? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `RadioGroup.variant`.
enum RadioGroupVariant {
  /// `"list"`.
  list('list'),

  /// `"pills"`.
  pills('pills'),

  /// `"cards"`.
  cards('cards');

  const RadioGroupVariant(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static RadioGroupVariant? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `Skeleton.variant`.
enum SkeletonVariant {
  /// `"text"`.
  text('text'),

  /// `"card"`.
  card('card'),

  /// `"chart"`.
  chart('chart');

  const SkeletonVariant(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static SkeletonVariant? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `Slider.sliderStyle`.
enum SliderStyle {
  /// `"continuous"`.
  continuous('continuous'),

  /// `"discrete"`.
  discrete('discrete');

  const SliderStyle(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static SliderStyle? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `Sparkline.tone`.
enum SparklineTone {
  /// `"positive"`.
  positive('positive'),

  /// `"negative"`.
  negative('negative'),

  /// `"default"`.
  default_('default');

  const SparklineTone(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static SparklineTone? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `Svg.strokeLinecap`.
enum SvgStrokeLinecap {
  /// `"butt"`.
  butt('butt'),

  /// `"round"`.
  round('round'),

  /// `"square"`.
  square('square');

  const SvgStrokeLinecap(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static SvgStrokeLinecap? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `Svg.strokeLinejoin`.
enum SvgStrokeLinejoin {
  /// `"miter"`.
  miter('miter'),

  /// `"round"`.
  round('round'),

  /// `"bevel"`.
  bevel('bevel');

  const SvgStrokeLinejoin(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static SvgStrokeLinejoin? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `Table.columnSizing`.
enum TableColumnSizing {
  /// `"auto"`.
  auto('auto'),

  /// `"equal"`.
  equal('equal');

  const TableColumnSizing(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static TableColumnSizing? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `TextField.variant`.
enum TextFieldVariant {
  /// `"shortText"`.
  shortText('shortText'),

  /// `"longText"`.
  longText('longText'),

  /// `"number"`.
  number('number'),

  /// `"obscured"`.
  obscured('obscured'),

  /// `"email"`.
  email('email'),

  /// `"url"`.
  url('url'),

  /// `"tel"`.
  tel('tel');

  const TextFieldVariant(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static TextFieldVariant? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `Title.size`.
enum TitleSize {
  /// `"sm"`.
  sm('sm'),

  /// `"md"`.
  md('md'),

  /// `"lg"`.
  lg('lg'),

  /// `"xl"`.
  xl('xl'),

  /// `"2xl"`.
  twoXl('2xl'),

  /// `"3xl"`.
  threeXl('3xl'),

  /// `"4xl"`.
  fourXl('4xl'),

  /// `"5xl"`.
  fiveXl('5xl');

  const TitleSize(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static TitleSize? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of `WeatherCard.unit`.
enum WeatherCardUnit {
  /// `"C"`.
  c('C'),

  /// `"F"`.
  f('F');

  const WeatherCardUnit(this.wire);

  /// The value as A2UI writes it.
  final String wire;

  /// The value whose [wire] is [value], or null when [value] is none of them.
  static WeatherCardUnit? fromWire(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// The values of every enum above, for tests that check each
/// value is handled.
const List<List<Enum>> propEnumValues = [
  A2uiActionVariant.values,
  A2uiAlign.values,
  A2uiBadgeColor.values,
  A2uiBorderColor.values,
  A2uiCheckSeverity.values,
  A2uiControlSize.values,
  A2uiFontWeight.values,
  A2uiJustify.values,
  A2uiOrientation.values,
  A2uiRadius.values,
  A2uiSize.values,
  A2uiTextAlign.values,
  A2uiTextSize.values,
  A2uiTone.values,
  A2uiTrend.values,
  A2uiValueFormat.values,
  A2uiWrap.values,
  AlertTone.values,
  AvatarStatus.values,
  BadgeVariant.values,
  BoxDirection.values,
  ButtonColor.values,
  ButtonVariant.values,
  CardShadowStyle.values,
  CardVariant.values,
  CarouselSnap.values,
  ChartFormat.values,
  ChartType.values,
  CheckBoxShape.values,
  ChoicePickerDisplayStyle.values,
  ChoicePickerVariant.values,
  DividerAxis.values,
  FlowItemAspectMode.values,
  FlowLayout.values,
  HeadingLevel.values,
  ImageFit.values,
  ImageGridLayout.values,
  ImageVariant.values,
  ListAlign.values,
  ListConnector.values,
  ListMarker.values,
  PlaceListBasemap.values,
  PopoverContentSide.values,
  RadioGroupDirection.values,
  RadioGroupVariant.values,
  SkeletonVariant.values,
  SliderStyle.values,
  SparklineTone.values,
  SvgStrokeLinecap.values,
  SvgStrokeLinejoin.values,
  TableColumnSizing.values,
  TextFieldVariant.values,
  TitleSize.values,
  WeatherCardUnit.values,
];

/// The props of a `Box` node, typed.
///
/// A flex container. It stacks its children in a column (direction "row"
/// puts them in a row). Use it to group children with gap, padding, border,
/// radius or background.
extension type const BoxProps(ComponentProps raw) {
  /// `children`: the child nodes, in order.
  List<ComponentNode<ComponentImplementation>> get children =>
      raw.children('children');

  /// `direction`: Default "col".
  BoxDirection get direction =>
      BoxDirection.fromWire(raw.value('direction')) ?? BoxDirection.col;

  /// `onVisible`: Sent once, the first time the container scrolls into view.
  /// Use it to load more content lazily.
  NodeAction? get onVisible => raw.action('onVisible');

  /// `align`.
  A2uiAlign? get align => A2uiAlign.fromWire(raw.value('align'));

  /// `justify`.
  A2uiJustify? get justify => A2uiJustify.fromWire(raw.value('justify'));

  /// `wrap`.
  A2uiWrap? get wrap => A2uiWrap.fromWire(raw.value('wrap'));

  /// `gap`: 4px steps when a number.
  Object? get gap => raw.value('gap');

  /// `rowGap`.
  Object? get rowGap => raw.value('rowGap');

  /// `columnGap`.
  Object? get columnGap => raw.value('columnGap');

  /// `padding`: 4px steps when a number.
  Object? get padding => raw.value('padding');

  /// `background`: Leave it unset. A surface token such as surface,
  /// surface-secondary, info, success, warning, danger, discovery, or one
  /// with -solid, or a CSS color. Only one summary panel in a Card uses
  /// "surface-secondary".
  String? get background => raw.string('background');

  /// `border`.
  bool? get border => raw.boolean('border');

  /// `borderColor`.
  A2uiBorderColor? get borderColor =>
      A2uiBorderColor.fromWire(raw.value('borderColor'));

  /// `radius`.
  Object? get radius => raw.value('radius');

  /// `width`.
  Object? get width => raw.value('width');

  /// `height`.
  Object? get height => raw.value('height');

  /// `minWidth`.
  Object? get minWidth => raw.value('minWidth');

  /// `maxWidth`.
  Object? get maxWidth => raw.value('maxWidth');

  /// `minHeight`.
  Object? get minHeight => raw.value('minHeight');

  /// `maxHeight`.
  Object? get maxHeight => raw.value('maxHeight');

  /// `flex`.
  double? get flex => raw.number('flex');

  /// `weight`: flex-grow in a Row or Column.
  double? get weight => raw.number('weight');

  /// `aspectRatio`.
  String? get aspectRatio => raw.string('aspectRatio');

  /// `scrollable`.
  bool? get scrollable => raw.boolean('scrollable');

  /// `clip`.
  bool? get clip => raw.boolean('clip');

  /// `shadow`.
  bool? get shadow => raw.boolean('shadow');

  /// `inline`.
  bool? get inline => raw.boolean('inline');

  /// `role`: ARIA role.
  String? get role => raw.string('role');

  /// `flush`: No padding.
  bool? get flush => raw.boolean('flush');

  /// `minSize`: Minimum width and height.
  Object? get minSize => raw.value('minSize');

  /// `maxSize`: Maximum width and height.
  Object? get maxSize => raw.value('maxSize');

  /// `disableAutoSpacing`: No default gap between children.
  bool? get disableAutoSpacing => raw.boolean('disableAutoSpacing');
}

/// The props of a `Column` node, typed.
///
/// A vertical flex container. Its default gap already separates sections,
/// so do not add padding, background or a Spacer for space.
extension type const ColumnProps(ComponentProps raw) {
  /// `children`: the child nodes, in order.
  List<ComponentNode<ComponentImplementation>> get children =>
      raw.children('children');

  /// `onVisible`: Sent once, the first time the container scrolls into view.
  /// Use it to load more content lazily.
  NodeAction? get onVisible => raw.action('onVisible');

  /// `align`.
  A2uiAlign? get align => A2uiAlign.fromWire(raw.value('align'));

  /// `justify`.
  A2uiJustify? get justify => A2uiJustify.fromWire(raw.value('justify'));

  /// `wrap`.
  A2uiWrap? get wrap => A2uiWrap.fromWire(raw.value('wrap'));

  /// `gap`: 4px steps when a number.
  Object? get gap => raw.value('gap');

  /// `rowGap`.
  Object? get rowGap => raw.value('rowGap');

  /// `columnGap`.
  Object? get columnGap => raw.value('columnGap');

  /// `padding`: 4px steps when a number.
  Object? get padding => raw.value('padding');

  /// `background`: Leave it unset. A surface token such as surface,
  /// surface-secondary, info, success, warning, danger, discovery, or one
  /// with -solid, or a CSS color. Only one summary panel in a Card uses
  /// "surface-secondary".
  String? get background => raw.string('background');

  /// `border`.
  bool? get border => raw.boolean('border');

  /// `borderColor`.
  A2uiBorderColor? get borderColor =>
      A2uiBorderColor.fromWire(raw.value('borderColor'));

  /// `radius`.
  Object? get radius => raw.value('radius');

  /// `width`.
  Object? get width => raw.value('width');

  /// `height`.
  Object? get height => raw.value('height');

  /// `minWidth`.
  Object? get minWidth => raw.value('minWidth');

  /// `maxWidth`.
  Object? get maxWidth => raw.value('maxWidth');

  /// `minHeight`.
  Object? get minHeight => raw.value('minHeight');

  /// `maxHeight`.
  Object? get maxHeight => raw.value('maxHeight');

  /// `flex`.
  double? get flex => raw.number('flex');

  /// `weight`: flex-grow in a Row or Column.
  double? get weight => raw.number('weight');

  /// `aspectRatio`.
  String? get aspectRatio => raw.string('aspectRatio');

  /// `scrollable`.
  bool? get scrollable => raw.boolean('scrollable');

  /// `clip`.
  bool? get clip => raw.boolean('clip');

  /// `shadow`.
  bool? get shadow => raw.boolean('shadow');

  /// `inline`.
  bool? get inline => raw.boolean('inline');

  /// `role`: ARIA role.
  String? get role => raw.string('role');

  /// `flush`: No padding.
  bool? get flush => raw.boolean('flush');

  /// `minSize`: Minimum width and height.
  Object? get minSize => raw.value('minSize');

  /// `maxSize`: Maximum width and height.
  Object? get maxSize => raw.value('maxSize');

  /// `disableAutoSpacing`: No default gap between children.
  bool? get disableAutoSpacing => raw.boolean('disableAutoSpacing');
}

/// The props of a `Row` node, typed.
///
/// A horizontal flex container. Label and value pair: justify
/// "spaceBetween", a Caption left and a Text with fontWeight "medium"
/// right. Buttons go in a Row at the bottom of a Card: one variant
/// "primary", the others default or "borderless".
extension type const RowProps(ComponentProps raw) {
  /// `children`: the child nodes, in order.
  List<ComponentNode<ComponentImplementation>> get children =>
      raw.children('children');

  /// `onVisible`: Sent once, the first time the container scrolls into view.
  /// Use it to load more content lazily.
  NodeAction? get onVisible => raw.action('onVisible');

  /// `align`.
  A2uiAlign? get align => A2uiAlign.fromWire(raw.value('align'));

  /// `justify`.
  A2uiJustify? get justify => A2uiJustify.fromWire(raw.value('justify'));

  /// `wrap`.
  A2uiWrap? get wrap => A2uiWrap.fromWire(raw.value('wrap'));

  /// `gap`: 4px steps when a number.
  Object? get gap => raw.value('gap');

  /// `rowGap`.
  Object? get rowGap => raw.value('rowGap');

  /// `columnGap`.
  Object? get columnGap => raw.value('columnGap');

  /// `padding`: 4px steps when a number.
  Object? get padding => raw.value('padding');

  /// `background`: Leave it unset. A surface token such as surface,
  /// surface-secondary, info, success, warning, danger, discovery, or one
  /// with -solid, or a CSS color. Only one summary panel in a Card uses
  /// "surface-secondary".
  String? get background => raw.string('background');

  /// `border`.
  bool? get border => raw.boolean('border');

  /// `borderColor`.
  A2uiBorderColor? get borderColor =>
      A2uiBorderColor.fromWire(raw.value('borderColor'));

  /// `radius`.
  Object? get radius => raw.value('radius');

  /// `width`.
  Object? get width => raw.value('width');

  /// `height`.
  Object? get height => raw.value('height');

  /// `minWidth`.
  Object? get minWidth => raw.value('minWidth');

  /// `maxWidth`.
  Object? get maxWidth => raw.value('maxWidth');

  /// `minHeight`.
  Object? get minHeight => raw.value('minHeight');

  /// `maxHeight`.
  Object? get maxHeight => raw.value('maxHeight');

  /// `flex`.
  double? get flex => raw.number('flex');

  /// `weight`: flex-grow in a Row or Column.
  double? get weight => raw.number('weight');

  /// `aspectRatio`.
  String? get aspectRatio => raw.string('aspectRatio');

  /// `scrollable`.
  bool? get scrollable => raw.boolean('scrollable');

  /// `clip`.
  bool? get clip => raw.boolean('clip');

  /// `shadow`.
  bool? get shadow => raw.boolean('shadow');

  /// `inline`.
  bool? get inline => raw.boolean('inline');

  /// `role`: ARIA role.
  String? get role => raw.string('role');

  /// `flush`: No padding.
  bool? get flush => raw.boolean('flush');

  /// `minSize`: Minimum width and height.
  Object? get minSize => raw.value('minSize');

  /// `maxSize`: Maximum width and height.
  Object? get maxSize => raw.value('maxSize');

  /// `disableAutoSpacing`: No default gap between children.
  bool? get disableAutoSpacing => raw.boolean('disableAutoSpacing');
}

/// The props of a `Grid` node, typed.
///
/// A CSS grid container. On a narrow screen, its columns collapse towards
/// one column.
extension type const GridProps(ComponentProps raw) {
  /// `children`: the child nodes, in order.
  List<ComponentNode<ComponentImplementation>> get children =>
      raw.children('children');

  /// `columns`: Column count or CSS template. Default 2.
  Object? get columns => raw.value('columns');

  /// `minChildWidth`.
  Object? get minChildWidth => raw.value('minChildWidth');

  /// `rows`.
  Object? get rows => raw.value('rows');

  /// `onVisible`: Sent once, the first time the container scrolls into view.
  /// Use it to load more content lazily.
  NodeAction? get onVisible => raw.action('onVisible');

  /// `align`.
  A2uiAlign? get align => A2uiAlign.fromWire(raw.value('align'));

  /// `justify`.
  A2uiJustify? get justify => A2uiJustify.fromWire(raw.value('justify'));

  /// `wrap`.
  A2uiWrap? get wrap => A2uiWrap.fromWire(raw.value('wrap'));

  /// `gap`: 4px steps when a number.
  Object? get gap => raw.value('gap');

  /// `rowGap`.
  Object? get rowGap => raw.value('rowGap');

  /// `columnGap`.
  Object? get columnGap => raw.value('columnGap');

  /// `padding`: 4px steps when a number.
  Object? get padding => raw.value('padding');

  /// `background`: Leave it unset. A surface token such as surface,
  /// surface-secondary, info, success, warning, danger, discovery, or one
  /// with -solid, or a CSS color. Only one summary panel in a Card uses
  /// "surface-secondary".
  String? get background => raw.string('background');

  /// `border`.
  bool? get border => raw.boolean('border');

  /// `borderColor`.
  A2uiBorderColor? get borderColor =>
      A2uiBorderColor.fromWire(raw.value('borderColor'));

  /// `radius`.
  Object? get radius => raw.value('radius');

  /// `width`.
  Object? get width => raw.value('width');

  /// `height`.
  Object? get height => raw.value('height');

  /// `minWidth`.
  Object? get minWidth => raw.value('minWidth');

  /// `maxWidth`.
  Object? get maxWidth => raw.value('maxWidth');

  /// `minHeight`.
  Object? get minHeight => raw.value('minHeight');

  /// `maxHeight`.
  Object? get maxHeight => raw.value('maxHeight');

  /// `flex`.
  double? get flex => raw.number('flex');

  /// `weight`: flex-grow in a Row or Column.
  double? get weight => raw.number('weight');

  /// `aspectRatio`.
  String? get aspectRatio => raw.string('aspectRatio');

  /// `scrollable`.
  bool? get scrollable => raw.boolean('scrollable');

  /// `clip`.
  bool? get clip => raw.boolean('clip');

  /// `shadow`.
  bool? get shadow => raw.boolean('shadow');

  /// `inline`.
  bool? get inline => raw.boolean('inline');

  /// `role`: ARIA role.
  String? get role => raw.string('role');

  /// `flush`: No padding.
  bool? get flush => raw.boolean('flush');

  /// `minSize`: Minimum width and height.
  Object? get minSize => raw.value('minSize');

  /// `maxSize`: Maximum width and height.
  Object? get maxSize => raw.value('maxSize');

  /// `disableAutoSpacing`: No default gap between children.
  bool? get disableAutoSpacing => raw.boolean('disableAutoSpacing');
}

/// The props of a `GridItem` node, typed.
///
/// A cell of a Grid, with an optional span. A span that covers all rendered
/// columns fills the row.
extension type const GridItemProps(ComponentProps raw) {
  /// `children`: the child nodes, in order.
  List<ComponentNode<ComponentImplementation>> get children =>
      raw.children('children');

  /// `span`.
  double? get span => raw.number('span');

  /// `rowSpan`.
  double? get rowSpan => raw.number('rowSpan');

  /// `onVisible`: Sent once, the first time the container scrolls into view.
  /// Use it to load more content lazily.
  NodeAction? get onVisible => raw.action('onVisible');

  /// `align`.
  A2uiAlign? get align => A2uiAlign.fromWire(raw.value('align'));

  /// `justify`.
  A2uiJustify? get justify => A2uiJustify.fromWire(raw.value('justify'));

  /// `wrap`.
  A2uiWrap? get wrap => A2uiWrap.fromWire(raw.value('wrap'));

  /// `gap`: 4px steps when a number.
  Object? get gap => raw.value('gap');

  /// `rowGap`.
  Object? get rowGap => raw.value('rowGap');

  /// `columnGap`.
  Object? get columnGap => raw.value('columnGap');

  /// `padding`: 4px steps when a number.
  Object? get padding => raw.value('padding');

  /// `background`: Leave it unset. A surface token such as surface,
  /// surface-secondary, info, success, warning, danger, discovery, or one
  /// with -solid, or a CSS color. Only one summary panel in a Card uses
  /// "surface-secondary".
  String? get background => raw.string('background');

  /// `border`.
  bool? get border => raw.boolean('border');

  /// `borderColor`.
  A2uiBorderColor? get borderColor =>
      A2uiBorderColor.fromWire(raw.value('borderColor'));

  /// `radius`.
  Object? get radius => raw.value('radius');

  /// `width`.
  Object? get width => raw.value('width');

  /// `height`.
  Object? get height => raw.value('height');

  /// `minWidth`.
  Object? get minWidth => raw.value('minWidth');

  /// `maxWidth`.
  Object? get maxWidth => raw.value('maxWidth');

  /// `minHeight`.
  Object? get minHeight => raw.value('minHeight');

  /// `maxHeight`.
  Object? get maxHeight => raw.value('maxHeight');

  /// `flex`.
  double? get flex => raw.number('flex');

  /// `weight`: flex-grow in a Row or Column.
  double? get weight => raw.number('weight');

  /// `aspectRatio`.
  String? get aspectRatio => raw.string('aspectRatio');

  /// `scrollable`.
  bool? get scrollable => raw.boolean('scrollable');

  /// `clip`.
  bool? get clip => raw.boolean('clip');

  /// `shadow`.
  bool? get shadow => raw.boolean('shadow');

  /// `inline`.
  bool? get inline => raw.boolean('inline');

  /// `role`: ARIA role.
  String? get role => raw.string('role');

  /// `flush`: No padding.
  bool? get flush => raw.boolean('flush');

  /// `minSize`: Minimum width and height.
  Object? get minSize => raw.value('minSize');

  /// `maxSize`: Maximum width and height.
  Object? get maxSize => raw.value('maxSize');

  /// `disableAutoSpacing`: No default gap between children.
  bool? get disableAutoSpacing => raw.boolean('disableAutoSpacing');
}

/// The props of a `Card` node, typed.
///
/// A bordered panel, only for an interactive panel (controls, a form, a
/// configurator); tables, charts and text need none. Give it a Title and a
/// Caption. Separate groups with a Divider or the gap, never a nested Card
/// or bordered Box. Variant "section": no box; "outline": always a box. In
/// markdown mode, without controls it renders as "section" unless variant
/// or border is set.
extension type const CardProps(ComponentProps raw) {
  /// `children`: the child nodes, in order.
  List<ComponentNode<ComponentImplementation>> get children =>
      raw.children('children');

  /// `child`: the child node.
  ComponentNode<ComponentImplementation>? get child => raw.child('child');

  /// `variant`.
  CardVariant? get variant => CardVariant.fromWire(raw.value('variant'));

  /// `onVisible`: Sent once, the first time the container scrolls into view.
  /// Use it to load more content lazily.
  NodeAction? get onVisible => raw.action('onVisible');

  /// `align`.
  A2uiAlign? get align => A2uiAlign.fromWire(raw.value('align'));

  /// `justify`.
  A2uiJustify? get justify => A2uiJustify.fromWire(raw.value('justify'));

  /// `wrap`.
  A2uiWrap? get wrap => A2uiWrap.fromWire(raw.value('wrap'));

  /// `gap`: 4px steps when a number.
  Object? get gap => raw.value('gap');

  /// `rowGap`.
  Object? get rowGap => raw.value('rowGap');

  /// `columnGap`.
  Object? get columnGap => raw.value('columnGap');

  /// `padding`: 4px steps when a number.
  Object? get padding => raw.value('padding');

  /// `background`: Leave it unset. A surface token such as surface,
  /// surface-secondary, info, success, warning, danger, discovery, or one
  /// with -solid, or a CSS color. Only one summary panel in a Card uses
  /// "surface-secondary".
  String? get background => raw.string('background');

  /// `border`.
  bool? get border => raw.boolean('border');

  /// `borderColor`.
  A2uiBorderColor? get borderColor =>
      A2uiBorderColor.fromWire(raw.value('borderColor'));

  /// `radius`.
  Object? get radius => raw.value('radius');

  /// `width`.
  Object? get width => raw.value('width');

  /// `height`.
  Object? get height => raw.value('height');

  /// `minWidth`.
  Object? get minWidth => raw.value('minWidth');

  /// `maxWidth`.
  Object? get maxWidth => raw.value('maxWidth');

  /// `minHeight`.
  Object? get minHeight => raw.value('minHeight');

  /// `maxHeight`.
  Object? get maxHeight => raw.value('maxHeight');

  /// `flex`.
  double? get flex => raw.number('flex');

  /// `weight`: flex-grow in a Row or Column.
  double? get weight => raw.number('weight');

  /// `aspectRatio`.
  String? get aspectRatio => raw.string('aspectRatio');

  /// `scrollable`.
  bool? get scrollable => raw.boolean('scrollable');

  /// `clip`.
  bool? get clip => raw.boolean('clip');

  /// `shadow`.
  bool? get shadow => raw.boolean('shadow');

  /// `inline`.
  bool? get inline => raw.boolean('inline');

  /// `role`: ARIA role.
  String? get role => raw.string('role');

  /// `flush`: No padding.
  bool? get flush => raw.boolean('flush');

  /// `minSize`: Minimum width and height.
  Object? get minSize => raw.value('minSize');

  /// `maxSize`: Maximum width and height.
  Object? get maxSize => raw.value('maxSize');

  /// `disableAutoSpacing`: No default gap between children.
  bool? get disableAutoSpacing => raw.boolean('disableAutoSpacing');

  /// `shadowStyle`: Overrides the shadow of the variant.
  CardShadowStyle? get shadowStyle =>
      CardShadowStyle.fromWire(raw.value('shadowStyle'));

  /// `size`: The padding preset: 8, 16 or 24px. Default "md".
  A2uiSize get size => A2uiSize.fromWire(raw.value('size')) ?? A2uiSize.md;
}

/// The props of a `Flow` node, typed.
///
/// A masonry-like grid that packs cells of different sizes. Put FlowItem
/// children in it.
extension type const FlowProps(ComponentProps raw) {
  /// `children`: the child nodes, in order.
  List<ComponentNode<ComponentImplementation>> get children =>
      raw.children('children');

  /// `columns`.
  double? get columns => raw.number('columns');

  /// `rows`.
  double? get rows => raw.number('rows');

  /// `layout`: Default "pack".
  FlowLayout get layout =>
      FlowLayout.fromWire(raw.value('layout')) ?? FlowLayout.pack;

  /// `onVisible`: Sent once, the first time the container scrolls into view.
  /// Use it to load more content lazily.
  NodeAction? get onVisible => raw.action('onVisible');

  /// `align`.
  A2uiAlign? get align => A2uiAlign.fromWire(raw.value('align'));

  /// `justify`.
  A2uiJustify? get justify => A2uiJustify.fromWire(raw.value('justify'));

  /// `wrap`.
  A2uiWrap? get wrap => A2uiWrap.fromWire(raw.value('wrap'));

  /// `gap`: 4px steps when a number.
  Object? get gap => raw.value('gap');

  /// `rowGap`.
  Object? get rowGap => raw.value('rowGap');

  /// `columnGap`.
  Object? get columnGap => raw.value('columnGap');

  /// `padding`: 4px steps when a number.
  Object? get padding => raw.value('padding');

  /// `background`: Leave it unset. A surface token such as surface,
  /// surface-secondary, info, success, warning, danger, discovery, or one
  /// with -solid, or a CSS color. Only one summary panel in a Card uses
  /// "surface-secondary".
  String? get background => raw.string('background');

  /// `border`.
  bool? get border => raw.boolean('border');

  /// `borderColor`.
  A2uiBorderColor? get borderColor =>
      A2uiBorderColor.fromWire(raw.value('borderColor'));

  /// `radius`.
  Object? get radius => raw.value('radius');

  /// `width`.
  Object? get width => raw.value('width');

  /// `height`.
  Object? get height => raw.value('height');

  /// `minWidth`.
  Object? get minWidth => raw.value('minWidth');

  /// `maxWidth`.
  Object? get maxWidth => raw.value('maxWidth');

  /// `minHeight`.
  Object? get minHeight => raw.value('minHeight');

  /// `maxHeight`.
  Object? get maxHeight => raw.value('maxHeight');

  /// `flex`.
  double? get flex => raw.number('flex');

  /// `weight`: flex-grow in a Row or Column.
  double? get weight => raw.number('weight');

  /// `aspectRatio`.
  String? get aspectRatio => raw.string('aspectRatio');

  /// `scrollable`.
  bool? get scrollable => raw.boolean('scrollable');

  /// `clip`.
  bool? get clip => raw.boolean('clip');

  /// `shadow`.
  bool? get shadow => raw.boolean('shadow');

  /// `inline`.
  bool? get inline => raw.boolean('inline');

  /// `role`: ARIA role.
  String? get role => raw.string('role');

  /// `flush`: No padding.
  bool? get flush => raw.boolean('flush');

  /// `minSize`: Minimum width and height.
  Object? get minSize => raw.value('minSize');

  /// `maxSize`: Maximum width and height.
  Object? get maxSize => raw.value('maxSize');

  /// `disableAutoSpacing`: No default gap between children.
  bool? get disableAutoSpacing => raw.boolean('disableAutoSpacing');
}

/// The props of a `FlowItem` node, typed.
///
/// A cell of a Flow, with an optional span.
extension type const FlowItemProps(ComponentProps raw) {
  /// `children`: the child nodes, in order.
  List<ComponentNode<ComponentImplementation>> get children =>
      raw.children('children');

  /// `span`.
  double? get span => raw.number('span');

  /// `rowSpan`.
  double? get rowSpan => raw.number('rowSpan');

  /// `aspectMode`.
  FlowItemAspectMode? get aspectMode =>
      FlowItemAspectMode.fromWire(raw.value('aspectMode'));

  /// `onVisible`: Sent once, the first time the container scrolls into view.
  /// Use it to load more content lazily.
  NodeAction? get onVisible => raw.action('onVisible');

  /// `align`.
  A2uiAlign? get align => A2uiAlign.fromWire(raw.value('align'));

  /// `justify`.
  A2uiJustify? get justify => A2uiJustify.fromWire(raw.value('justify'));

  /// `wrap`.
  A2uiWrap? get wrap => A2uiWrap.fromWire(raw.value('wrap'));

  /// `gap`: 4px steps when a number.
  Object? get gap => raw.value('gap');

  /// `rowGap`.
  Object? get rowGap => raw.value('rowGap');

  /// `columnGap`.
  Object? get columnGap => raw.value('columnGap');

  /// `padding`: 4px steps when a number.
  Object? get padding => raw.value('padding');

  /// `background`: Leave it unset. A surface token such as surface,
  /// surface-secondary, info, success, warning, danger, discovery, or one
  /// with -solid, or a CSS color. Only one summary panel in a Card uses
  /// "surface-secondary".
  String? get background => raw.string('background');

  /// `border`.
  bool? get border => raw.boolean('border');

  /// `borderColor`.
  A2uiBorderColor? get borderColor =>
      A2uiBorderColor.fromWire(raw.value('borderColor'));

  /// `radius`.
  Object? get radius => raw.value('radius');

  /// `width`.
  Object? get width => raw.value('width');

  /// `height`.
  Object? get height => raw.value('height');

  /// `minWidth`.
  Object? get minWidth => raw.value('minWidth');

  /// `maxWidth`.
  Object? get maxWidth => raw.value('maxWidth');

  /// `minHeight`.
  Object? get minHeight => raw.value('minHeight');

  /// `maxHeight`.
  Object? get maxHeight => raw.value('maxHeight');

  /// `flex`.
  double? get flex => raw.number('flex');

  /// `weight`: flex-grow in a Row or Column.
  double? get weight => raw.number('weight');

  /// `aspectRatio`: Default "1 / 1".
  String get aspectRatio => raw.string('aspectRatio') ?? '1 / 1';

  /// `scrollable`.
  bool? get scrollable => raw.boolean('scrollable');

  /// `clip`.
  bool? get clip => raw.boolean('clip');

  /// `shadow`.
  bool? get shadow => raw.boolean('shadow');

  /// `inline`.
  bool? get inline => raw.boolean('inline');

  /// `role`: ARIA role.
  String? get role => raw.string('role');

  /// `flush`: No padding.
  bool? get flush => raw.boolean('flush');

  /// `minSize`: Minimum width and height.
  Object? get minSize => raw.value('minSize');

  /// `maxSize`: Maximum width and height.
  Object? get maxSize => raw.value('maxSize');

  /// `disableAutoSpacing`: No default gap between children.
  bool? get disableAutoSpacing => raw.boolean('disableAutoSpacing');
}

/// The props of a `Carousel` node, typed.
///
/// A horizontally scrolling row that snaps to its CarouselItem or
/// CarouselMediaItem children, with arrows. Bind activeIndex to read or set
/// the slide in view.
extension type const CarouselProps(ComponentProps raw) {
  /// `children`: the child nodes, in order.
  List<ComponentNode<ComponentImplementation>> get children =>
      raw.children('children');

  /// `activeIndex`: The index of the slide in view. Bind it with { "@path":
  /// "/x" } to read or set it.
  double? get activeIndex => raw.number('activeIndex');

  /// `label`: A short name of the carousel for screen readers.
  String? get label => raw.string('label');

  /// `visibleItems`.
  double? get visibleItems => raw.number('visibleItems');

  /// `showArrows`: Default true.
  bool get showArrows => raw.boolean('showArrows') ?? true;

  /// `previousLabel`: Default "Previous".
  String get previousLabel => raw.string('previousLabel') ?? 'Previous';

  /// `nextLabel`: Default "Next".
  String get nextLabel => raw.string('nextLabel') ?? 'Next';

  /// `snap`.
  CarouselSnap? get snap => CarouselSnap.fromWire(raw.value('snap'));

  /// `snapAlign`.
  A2uiTextAlign? get snapAlign =>
      A2uiTextAlign.fromWire(raw.value('snapAlign'));

  /// `onVisible`: Sent once, the first time the container scrolls into view.
  /// Use it to load more content lazily.
  NodeAction? get onVisible => raw.action('onVisible');

  /// `align`.
  A2uiAlign? get align => A2uiAlign.fromWire(raw.value('align'));

  /// `justify`.
  A2uiJustify? get justify => A2uiJustify.fromWire(raw.value('justify'));

  /// `wrap`.
  A2uiWrap? get wrap => A2uiWrap.fromWire(raw.value('wrap'));

  /// `gap`: 4px steps when a number.
  Object? get gap => raw.value('gap');

  /// `rowGap`.
  Object? get rowGap => raw.value('rowGap');

  /// `columnGap`.
  Object? get columnGap => raw.value('columnGap');

  /// `padding`: 4px steps when a number.
  Object? get padding => raw.value('padding');

  /// `background`: Leave it unset. A surface token such as surface,
  /// surface-secondary, info, success, warning, danger, discovery, or one
  /// with -solid, or a CSS color. Only one summary panel in a Card uses
  /// "surface-secondary".
  String? get background => raw.string('background');

  /// `border`.
  bool? get border => raw.boolean('border');

  /// `borderColor`.
  A2uiBorderColor? get borderColor =>
      A2uiBorderColor.fromWire(raw.value('borderColor'));

  /// `radius`.
  Object? get radius => raw.value('radius');

  /// `width`.
  Object? get width => raw.value('width');

  /// `height`.
  Object? get height => raw.value('height');

  /// `minWidth`.
  Object? get minWidth => raw.value('minWidth');

  /// `maxWidth`.
  Object? get maxWidth => raw.value('maxWidth');

  /// `minHeight`.
  Object? get minHeight => raw.value('minHeight');

  /// `maxHeight`.
  Object? get maxHeight => raw.value('maxHeight');

  /// `flex`.
  double? get flex => raw.number('flex');

  /// `weight`: flex-grow in a Row or Column.
  double? get weight => raw.number('weight');

  /// `aspectRatio`.
  String? get aspectRatio => raw.string('aspectRatio');

  /// `scrollable`.
  bool? get scrollable => raw.boolean('scrollable');

  /// `clip`.
  bool? get clip => raw.boolean('clip');

  /// `shadow`.
  bool? get shadow => raw.boolean('shadow');

  /// `inline`.
  bool? get inline => raw.boolean('inline');

  /// `role`: ARIA role.
  String? get role => raw.string('role');

  /// `flush`: No padding.
  bool? get flush => raw.boolean('flush');

  /// `minSize`: Minimum width and height.
  Object? get minSize => raw.value('minSize');

  /// `maxSize`: Maximum width and height.
  Object? get maxSize => raw.value('maxSize');

  /// `disableAutoSpacing`: No default gap between children.
  bool? get disableAutoSpacing => raw.boolean('disableAutoSpacing');
}

/// The props of a `CarouselItem` node, typed.
///
/// A slide of a Carousel.
extension type const CarouselItemProps(ComponentProps raw) {
  /// `children`: the child nodes, in order.
  List<ComponentNode<ComponentImplementation>> get children =>
      raw.children('children');

  /// `onVisible`: Sent once, the first time the container scrolls into view.
  /// Use it to load more content lazily.
  NodeAction? get onVisible => raw.action('onVisible');

  /// `align`.
  A2uiAlign? get align => A2uiAlign.fromWire(raw.value('align'));

  /// `justify`.
  A2uiJustify? get justify => A2uiJustify.fromWire(raw.value('justify'));

  /// `wrap`.
  A2uiWrap? get wrap => A2uiWrap.fromWire(raw.value('wrap'));

  /// `gap`: 4px steps when a number.
  Object? get gap => raw.value('gap');

  /// `rowGap`.
  Object? get rowGap => raw.value('rowGap');

  /// `columnGap`.
  Object? get columnGap => raw.value('columnGap');

  /// `padding`: 4px steps when a number.
  Object? get padding => raw.value('padding');

  /// `background`: Leave it unset. A surface token such as surface,
  /// surface-secondary, info, success, warning, danger, discovery, or one
  /// with -solid, or a CSS color. Only one summary panel in a Card uses
  /// "surface-secondary".
  String? get background => raw.string('background');

  /// `border`.
  bool? get border => raw.boolean('border');

  /// `borderColor`.
  A2uiBorderColor? get borderColor =>
      A2uiBorderColor.fromWire(raw.value('borderColor'));

  /// `radius`.
  Object? get radius => raw.value('radius');

  /// `width`.
  Object? get width => raw.value('width');

  /// `height`.
  Object? get height => raw.value('height');

  /// `minWidth`.
  Object? get minWidth => raw.value('minWidth');

  /// `maxWidth`.
  Object? get maxWidth => raw.value('maxWidth');

  /// `minHeight`.
  Object? get minHeight => raw.value('minHeight');

  /// `maxHeight`.
  Object? get maxHeight => raw.value('maxHeight');

  /// `flex`.
  double? get flex => raw.number('flex');

  /// `weight`: flex-grow in a Row or Column.
  double? get weight => raw.number('weight');

  /// `aspectRatio`.
  String? get aspectRatio => raw.string('aspectRatio');

  /// `scrollable`.
  bool? get scrollable => raw.boolean('scrollable');

  /// `clip`.
  bool? get clip => raw.boolean('clip');

  /// `shadow`.
  bool? get shadow => raw.boolean('shadow');

  /// `inline`.
  bool? get inline => raw.boolean('inline');

  /// `role`: ARIA role.
  String? get role => raw.string('role');

  /// `flush`: No padding.
  bool? get flush => raw.boolean('flush');

  /// `minSize`: Minimum width and height.
  Object? get minSize => raw.value('minSize');

  /// `maxSize`: Maximum width and height.
  Object? get maxSize => raw.value('maxSize');

  /// `disableAutoSpacing`: No default gap between children.
  bool? get disableAutoSpacing => raw.boolean('disableAutoSpacing');
}

/// The props of a `CarouselMediaItem` node, typed.
///
/// A Carousel slide: an image with its children (a Caption, a Text) under
/// it. size "sm" 160px, "md" 240px (default), "lg" 320px wide. A click
/// opens all slides full-screen, unless href or onClick is set.
extension type const CarouselMediaItemProps(ComponentProps raw) {
  /// `url` (required): Image URL.
  String? get url => raw.string('url');

  /// `children`: the child nodes, in order.
  List<ComponentNode<ComponentImplementation>> get children =>
      raw.children('children');

  /// `onClick`: Sent when the user clicks the image. It replaces the
  /// full-screen view.
  NodeAction? get onClick => raw.action('onClick');

  /// `description`: What the image shows, for screen readers.
  String? get description => raw.string('description');

  /// `href`: Opens this URL in a new tab.
  String? get href => raw.string('href');

  /// `lightbox`: Default true: a click opens all slides full-screen.
  bool get lightbox => raw.boolean('lightbox') ?? true;

  /// `onVisible`: Sent once, the first time the container scrolls into view.
  /// Use it to load more content lazily.
  NodeAction? get onVisible => raw.action('onVisible');

  /// `align`.
  A2uiAlign? get align => A2uiAlign.fromWire(raw.value('align'));

  /// `justify`.
  A2uiJustify? get justify => A2uiJustify.fromWire(raw.value('justify'));

  /// `wrap`.
  A2uiWrap? get wrap => A2uiWrap.fromWire(raw.value('wrap'));

  /// `gap`: 4px steps when a number.
  Object? get gap => raw.value('gap');

  /// `rowGap`.
  Object? get rowGap => raw.value('rowGap');

  /// `columnGap`.
  Object? get columnGap => raw.value('columnGap');

  /// `padding`: 4px steps when a number.
  Object? get padding => raw.value('padding');

  /// `background`: Leave it unset. A surface token such as surface,
  /// surface-secondary, info, success, warning, danger, discovery, or one
  /// with -solid, or a CSS color. Only one summary panel in a Card uses
  /// "surface-secondary".
  String? get background => raw.string('background');

  /// `border`.
  bool? get border => raw.boolean('border');

  /// `borderColor`.
  A2uiBorderColor? get borderColor =>
      A2uiBorderColor.fromWire(raw.value('borderColor'));

  /// `radius`.
  Object? get radius => raw.value('radius');

  /// `width`.
  Object? get width => raw.value('width');

  /// `height`.
  Object? get height => raw.value('height');

  /// `minWidth`.
  Object? get minWidth => raw.value('minWidth');

  /// `maxWidth`.
  Object? get maxWidth => raw.value('maxWidth');

  /// `minHeight`.
  Object? get minHeight => raw.value('minHeight');

  /// `maxHeight`.
  Object? get maxHeight => raw.value('maxHeight');

  /// `flex`.
  double? get flex => raw.number('flex');

  /// `weight`: flex-grow in a Row or Column.
  double? get weight => raw.number('weight');

  /// `aspectRatio`: Default "4 / 3".
  String get aspectRatio => raw.string('aspectRatio') ?? '4 / 3';

  /// `scrollable`.
  bool? get scrollable => raw.boolean('scrollable');

  /// `clip`.
  bool? get clip => raw.boolean('clip');

  /// `shadow`.
  bool? get shadow => raw.boolean('shadow');

  /// `inline`.
  bool? get inline => raw.boolean('inline');

  /// `role`: ARIA role.
  String? get role => raw.string('role');

  /// `flush`: No padding.
  bool? get flush => raw.boolean('flush');

  /// `minSize`: Minimum width and height.
  Object? get minSize => raw.value('minSize');

  /// `maxSize`: Maximum width and height.
  Object? get maxSize => raw.value('maxSize');

  /// `disableAutoSpacing`: No default gap between children.
  bool? get disableAutoSpacing => raw.boolean('disableAutoSpacing');

  /// `size`: The width: "sm" 160px, "md" 240px, "lg" 320px. Default "md".
  A2uiSize get size => A2uiSize.fromWire(raw.value('size')) ?? A2uiSize.md;
}

/// The props of a `Spacer` node, typed.
///
/// Flexible empty space. You almost never need it: use the default gap.
extension type const SpacerProps(ComponentProps raw) {
  /// `minSize`.
  Object? get minSize => raw.value('minSize');
}

/// The props of a `Divider` node, typed.
///
/// A line between two groups: horizontal, or vertical with axis "vertical"
/// in a Row.
extension type const DividerProps(ComponentProps raw) {
  /// `axis`: Default "horizontal".
  DividerAxis get axis =>
      DividerAxis.fromWire(raw.value('axis')) ?? DividerAxis.horizontal;

  /// `spacing`.
  Object? get spacing => raw.value('spacing');

  /// `weight`: flex-grow in a Row or Column.
  double? get weight => raw.number('weight');

  /// `color`.
  A2uiBorderColor? get color => A2uiBorderColor.fromWire(raw.value('color'));

  /// `size`.
  double? get size => raw.number('size');

  /// `flush`.
  bool? get flush => raw.boolean('flush');
}

/// The props of a `Tabs` node, typed.
///
/// Tabs that show one panel at a time. Each tab has a title and the id of
/// its panel component: "tabs":\[{"title":"Specs","child":"specs"}\].
extension type const TabsProps(ComponentProps raw) {
  /// `tabs` (required): One entry per tab.
  List<Object?> get tabs => raw.list('tabs');

  /// `selectedIndex`: The open tab. Default 0. Bind it with { "@path": "/x" }
  /// to read it.
  double get selectedIndex => raw.number('selectedIndex') ?? 0.0;

  /// `weight`: flex-grow in a Row or Column.
  double? get weight => raw.number('weight');
}

/// The props of a `Title` node, typed.
///
/// A heading in a Card or next to another component; a heading alone is
/// markdown. Size "2xl" at most once per surface, "lg" for sections. "sm"
/// is an h4, "md"/"lg" an h3 (default "md"), "xl" and up an h2. Bold unless
/// strong is false.
extension type const TitleProps(ComponentProps raw) {
  /// `text` (required): Heading text.
  String? get text => raw.string('text');

  /// `color`: One of
  /// default|prose|primary|emphasis|secondary|tertiary|success|info|warning|caution|danger|discovery
  /// or a CSS color.
  String? get color => raw.string('color');

  /// `fontWeight`.
  A2uiFontWeight? get fontWeight =>
      A2uiFontWeight.fromWire(raw.value('fontWeight'));

  /// `textAlign`.
  A2uiTextAlign? get textAlign =>
      A2uiTextAlign.fromWire(raw.value('textAlign'));

  /// `italic`.
  bool? get italic => raw.boolean('italic');

  /// `truncate`.
  bool? get truncate => raw.boolean('truncate');

  /// `maxLines`.
  double? get maxLines => raw.number('maxLines');

  /// `tabularNums`.
  bool? get tabularNums => raw.boolean('tabularNums');

  /// `width`.
  Object? get width => raw.value('width');

  /// `size`: Default "md".
  TitleSize get size => TitleSize.fromWire(raw.value('size')) ?? TitleSize.md;

  /// `strong`: Default true.
  bool get strong => raw.boolean('strong') ?? true;
}

/// The props of a `Text` node, typed.
///
/// Body text in a Card or next to another component; a paragraph alone is
/// markdown outside the fence. Color "default" or "secondary". `text` takes
/// inline markdown (**bold**, *italic*, ~~strike~~, ++underline++, `code`,
/// \[link\](url)). `children` ids render inline after it, e.g. a Badge.
extension type const TextProps(ComponentProps raw) {
  /// `text`: Text with inline markdown. A bound number shows as text.
  String? get text => raw.string('text');

  /// `children`: the child nodes, in order.
  List<ComponentNode<ComponentImplementation>> get children =>
      raw.children('children');

  /// `color`: One of
  /// default|prose|primary|emphasis|secondary|tertiary|success|info|warning|caution|danger|discovery
  /// or a CSS color.
  String? get color => raw.string('color');

  /// `fontWeight`.
  A2uiFontWeight? get fontWeight =>
      A2uiFontWeight.fromWire(raw.value('fontWeight'));

  /// `textAlign`.
  A2uiTextAlign? get textAlign =>
      A2uiTextAlign.fromWire(raw.value('textAlign'));

  /// `italic`.
  bool? get italic => raw.boolean('italic');

  /// `truncate`.
  bool? get truncate => raw.boolean('truncate');

  /// `maxLines`.
  double? get maxLines => raw.number('maxLines');

  /// `tabularNums`.
  bool? get tabularNums => raw.boolean('tabularNums');

  /// `width`.
  Object? get width => raw.value('width');

  /// `weight`: flex-grow in a Row or Column.
  double? get weight => raw.number('weight');

  /// `size`: Default "md".
  A2uiTextSize get size =>
      A2uiTextSize.fromWire(raw.value('size')) ?? A2uiTextSize.md;

  /// `fontSize`: Pixels when a number. Wins over size.
  Object? get fontSize => raw.value('fontSize');

  /// `lineHeight`: A unitless ratio, or CSS.
  Object? get lineHeight => raw.value('lineHeight');

  /// `minLines`: Reserves the height of this many lines.
  double? get minLines => raw.number('minLines');

  /// `strong`: Default false.
  bool get strong => raw.boolean('strong') ?? false;

  /// `underline`.
  bool? get underline => raw.boolean('underline');

  /// `lineThrough`.
  bool? get lineThrough => raw.boolean('lineThrough');

  /// `inline`.
  bool? get inline => raw.boolean('inline');

  /// `preserveWhitespace`.
  bool? get preserveWhitespace => raw.boolean('preserveWhitespace');

  /// `highlight`.
  Object? get highlight => raw.value('highlight');
}

/// The props of a `Caption` node, typed.
///
/// Small secondary text: a hint under a control, or a label in a Row.
/// `text` can have inline markdown.
extension type const CaptionProps(ComponentProps raw) {
  /// `text` (required): Caption text.
  String? get text => raw.string('text');

  /// `color`: One of
  /// default|prose|primary|emphasis|secondary|tertiary|success|info|warning|caution|danger|discovery
  /// or a CSS color.
  String? get color => raw.string('color');

  /// `size`: Default "lg".
  A2uiSize get size => A2uiSize.fromWire(raw.value('size')) ?? A2uiSize.lg;

  /// `fontWeight`: Default "normal".
  A2uiFontWeight get fontWeight =>
      A2uiFontWeight.fromWire(raw.value('fontWeight')) ?? A2uiFontWeight.normal;

  /// `textAlign`.
  A2uiTextAlign? get textAlign =>
      A2uiTextAlign.fromWire(raw.value('textAlign'));

  /// `truncate`.
  bool? get truncate => raw.boolean('truncate');

  /// `maxLines`.
  double? get maxLines => raw.number('maxLines');
}

/// The props of a `Label` node, typed.
///
/// The label of a form field.
extension type const LabelProps(ComponentProps raw) {
  /// `text` (required): Label text.
  String? get text => raw.string('text');

  /// `htmlFor`.
  String? get htmlFor => raw.string('htmlFor');

  /// `color`: One of
  /// default|prose|primary|emphasis|secondary|tertiary|success|info|warning|caution|danger|discovery
  /// or a CSS color.
  String? get color => raw.string('color');

  /// `size`: Default "sm".
  A2uiTextSize get size =>
      A2uiTextSize.fromWire(raw.value('size')) ?? A2uiTextSize.sm;

  /// `fontWeight`: Default "medium".
  A2uiFontWeight get fontWeight =>
      A2uiFontWeight.fromWire(raw.value('fontWeight')) ?? A2uiFontWeight.medium;

  /// `textAlign`.
  A2uiTextAlign? get textAlign =>
      A2uiTextAlign.fromWire(raw.value('textAlign'));

  /// `truncate`.
  bool? get truncate => raw.boolean('truncate');

  /// `width`.
  Object? get width => raw.value('width');
}

/// The props of a `Bold` node, typed.
///
/// Bold inline text.
extension type const BoldProps(ComponentProps raw) {
  /// `text` (required).
  String? get text => raw.string('text');

  /// `fontWeight`.
  A2uiFontWeight? get fontWeight =>
      A2uiFontWeight.fromWire(raw.value('fontWeight'));
}

/// The props of a `Italic` node, typed.
///
/// Italic inline text.
extension type const ItalicProps(ComponentProps raw) {
  /// `text` (required).
  String? get text => raw.string('text');
}

/// The props of a `Underline` node, typed.
///
/// Underlined inline text.
extension type const UnderlineProps(ComponentProps raw) {
  /// `text` (required).
  String? get text => raw.string('text');
}

/// The props of a `Strikethrough` node, typed.
///
/// Struck-through inline text.
extension type const StrikethroughProps(ComponentProps raw) {
  /// `text` (required).
  String? get text => raw.string('text');
}

/// The props of a `Badge` node, typed.
///
/// A small status pill. Use the colors success, danger and warning only to
/// show a status, not for decoration.
extension type const BadgeProps(ComponentProps raw) {
  /// `label` (required): Badge text.
  String? get label => raw.string('label');

  /// `variant`: Default "soft".
  BadgeVariant get variant =>
      BadgeVariant.fromWire(raw.value('variant')) ?? BadgeVariant.soft;

  /// `color`: Default "secondary".
  A2uiBadgeColor get color =>
      A2uiBadgeColor.fromWire(raw.value('color')) ?? A2uiBadgeColor.secondary;

  /// `size`: Default "md".
  A2uiSize get size => A2uiSize.fromWire(raw.value('size')) ?? A2uiSize.md;

  /// `pill`: Default true.
  bool get pill => raw.boolean('pill') ?? true;

  /// `fontWeight`: Default "medium".
  A2uiFontWeight get fontWeight =>
      A2uiFontWeight.fromWire(raw.value('fontWeight')) ?? A2uiFontWeight.medium;

  /// `maxWidth`.
  Object? get maxWidth => raw.value('maxWidth');

  /// `padding`.
  Object? get padding => raw.value('padding');
}

/// The props of a `Blockquote` node, typed.
///
/// A block quotation with a line on the left. `text` can have inline
/// markdown.
extension type const BlockquoteProps(ComponentProps raw) {
  /// `text` (required): The quoted text, with inline markdown.
  String? get text => raw.string('text');
}

/// The props of a `Code` node, typed.
///
/// A block of code in a monospace font.
extension type const CodeProps(ComponentProps raw) {
  /// `text` (required): Source code.
  String? get text => raw.string('text');

  /// `language`.
  String? get language => raw.string('language');
}

/// The props of a `Markdown` node, typed.
///
/// A block of GitHub-flavored markdown. Use it only next to other
/// components, for example in a table cell or next to a chart. Markdown
/// alone goes outside the fence.
extension type const MarkdownProps(ComponentProps raw) {
  /// `text` (required): Markdown source.
  String? get text => raw.string('text');

  /// `streaming`: Default false.
  bool get streaming => raw.boolean('streaming') ?? false;
}

/// The props of a `Math` node, typed.
///
/// A TeX math formula, typeset with KaTeX. Set block to true for a centered
/// formula on its own line.
extension type const MathProps(ComponentProps raw) {
  /// `value` (required): TeX source.
  String? get value => raw.string('value');

  /// `block`: Default false.
  bool get block => raw.boolean('block') ?? false;
}

/// The props of a `ShimmerText` node, typed.
///
/// Text with a moving shimmer. It shows that something is loading or
/// pending.
extension type const ShimmerTextProps(ComponentProps raw) {
  /// `text` (required).
  String? get text => raw.string('text');

  /// `color`: One of
  /// default|prose|primary|emphasis|secondary|tertiary|success|info|warning|caution|danger|discovery
  /// or a CSS color.
  String? get color => raw.string('color');

  /// `fontWeight`.
  A2uiFontWeight? get fontWeight =>
      A2uiFontWeight.fromWire(raw.value('fontWeight'));

  /// `textAlign`.
  A2uiTextAlign? get textAlign =>
      A2uiTextAlign.fromWire(raw.value('textAlign'));

  /// `italic`.
  bool? get italic => raw.boolean('italic');

  /// `truncate`.
  bool? get truncate => raw.boolean('truncate');

  /// `maxLines`.
  double? get maxLines => raw.number('maxLines');

  /// `tabularNums`.
  bool? get tabularNums => raw.boolean('tabularNums');

  /// `width`.
  Object? get width => raw.value('width');

  /// `size`: Default "md".
  A2uiTextSize get size =>
      A2uiTextSize.fromWire(raw.value('size')) ?? A2uiTextSize.md;

  /// `lineThrough`.
  bool? get lineThrough => raw.boolean('lineThrough');
}

/// The props of a `Link` node, typed.
///
/// A link. Only http, https and mailto URLs work. It opens in a new tab.
extension type const LinkProps(ComponentProps raw) {
  /// `text` (required): Link text.
  String? get text => raw.string('text');

  /// `href` (required): URL.
  String? get href => raw.string('href');

  /// `title`.
  String? get title => raw.string('title');
}

/// The props of a `Tooltip` node, typed.
///
/// Shows `content` when the user points at or focuses `trigger`. `trigger`:
/// one child id, a Text, Icon or Badge (not a Button or Link). `content`:
/// one child id of short text, no links or buttons.
extension type const TooltipProps(ComponentProps raw) {
  /// `trigger`: the child node.
  ComponentNode<ComponentImplementation>? get trigger => raw.child('trigger');

  /// `content`: the child node.
  ComponentNode<ComponentImplementation>? get content => raw.child('content');
}

/// The props of a `Button` node, typed.
///
/// Sends its onClick event; with href it opens the URL, with copy it copies
/// the text. Variant "primary" for the one main Button in a Row. submit
/// true submits the Form around it. Its children render instead of the
/// label. With checks it is disabled while a check fails.
extension type const ButtonProps(ComponentProps raw) {
  /// `label`: The button text.
  String? get label => raw.string('label');

  /// `onClick`: Sent when the user clicks the button.
  NodeAction? get onClick => raw.action('onClick');

  /// `checks`: Validation rules. The control shows the first failed one.
  List<Object?> get checks => raw.list('checks');

  /// `text`: Same as label. Used when label is not set.
  String? get text => raw.string('text');

  /// `variant`: Default "default": outlined. "primary" is filled, for the one
  /// main action. "borderless" has no box, like a link.
  ButtonVariant get variant =>
      ButtonVariant.fromWire(raw.value('variant')) ?? ButtonVariant.default_;

  /// `block`: Full width.
  bool? get block => raw.boolean('block');

  /// `disabled`.
  bool? get disabled => raw.boolean('disabled');

  /// `loading`.
  bool? get loading => raw.boolean('loading');

  /// `submit`: Submits the Form around it. The Form sends its onSubmit event.
  bool? get submit => raw.boolean('submit');

  /// `icon`: Lucide icon name.
  String? get icon => raw.string('icon');

  /// `uniform`: A square button, for an icon.
  bool? get uniform => raw.boolean('uniform');

  /// `href`: Opens this URL in a new tab on click, instead of onClick.
  String? get href => raw.string('href');

  /// `copy`: Copies this text to the clipboard on click and shows a check
  /// mark, instead of onClick.
  String? get copy => raw.string('copy');

  /// `child`: the child node.
  ComponentNode<ComponentImplementation>? get child => raw.child('child');

  /// `children`: the child nodes, in order.
  List<ComponentNode<ComponentImplementation>> get children =>
      raw.children('children');

  /// `color`: Default "primary".
  ButtonColor get color =>
      ButtonColor.fromWire(raw.value('color')) ?? ButtonColor.primary;

  /// `size`: Default "lg".
  A2uiSize get size => A2uiSize.fromWire(raw.value('size')) ?? A2uiSize.lg;

  /// `weight`: flex-grow in a Row or Column.
  double? get weight => raw.number('weight');

  /// `pill`: Default true.
  bool get pill => raw.boolean('pill') ?? true;
}

/// The props of a `Pressable` node, typed.
///
/// A layout container that the user can click or press with Enter or Space.
/// It sends its onClick event, or opens href. A control inside it sends
/// only its own event.
extension type const PressableProps(ComponentProps raw) {
  /// `children`: the child nodes, in order.
  List<ComponentNode<ComponentImplementation>> get children =>
      raw.children('children');

  /// `onClick`: Sent when the user clicks or presses the container.
  NodeAction? get onClick => raw.action('onClick');

  /// `href`: Opens this URL in a new tab on click, instead of onClick.
  String? get href => raw.string('href');

  /// `disabled`.
  bool? get disabled => raw.boolean('disabled');

  /// `tooltip`: Shown on hover.
  String? get tooltip => raw.string('tooltip');

  /// `ariaPressed`: For a toggle.
  bool? get ariaPressed => raw.boolean('ariaPressed');

  /// `onVisible`: Sent once, the first time the container scrolls into view.
  /// Use it to load more content lazily.
  NodeAction? get onVisible => raw.action('onVisible');

  /// `align`.
  A2uiAlign? get align => A2uiAlign.fromWire(raw.value('align'));

  /// `justify`.
  A2uiJustify? get justify => A2uiJustify.fromWire(raw.value('justify'));

  /// `wrap`.
  A2uiWrap? get wrap => A2uiWrap.fromWire(raw.value('wrap'));

  /// `gap`: 4px steps when a number.
  Object? get gap => raw.value('gap');

  /// `rowGap`.
  Object? get rowGap => raw.value('rowGap');

  /// `columnGap`.
  Object? get columnGap => raw.value('columnGap');

  /// `padding`: 4px steps when a number.
  Object? get padding => raw.value('padding');

  /// `background`: Leave it unset. A surface token such as surface,
  /// surface-secondary, info, success, warning, danger, discovery, or one
  /// with -solid, or a CSS color. Only one summary panel in a Card uses
  /// "surface-secondary".
  String? get background => raw.string('background');

  /// `border`.
  bool? get border => raw.boolean('border');

  /// `borderColor`.
  A2uiBorderColor? get borderColor =>
      A2uiBorderColor.fromWire(raw.value('borderColor'));

  /// `radius`.
  Object? get radius => raw.value('radius');

  /// `width`.
  Object? get width => raw.value('width');

  /// `height`.
  Object? get height => raw.value('height');

  /// `minWidth`.
  Object? get minWidth => raw.value('minWidth');

  /// `maxWidth`.
  Object? get maxWidth => raw.value('maxWidth');

  /// `minHeight`.
  Object? get minHeight => raw.value('minHeight');

  /// `maxHeight`.
  Object? get maxHeight => raw.value('maxHeight');

  /// `flex`.
  double? get flex => raw.number('flex');

  /// `weight`: flex-grow in a Row or Column.
  double? get weight => raw.number('weight');

  /// `aspectRatio`.
  String? get aspectRatio => raw.string('aspectRatio');

  /// `scrollable`.
  bool? get scrollable => raw.boolean('scrollable');

  /// `clip`.
  bool? get clip => raw.boolean('clip');

  /// `shadow`.
  bool? get shadow => raw.boolean('shadow');

  /// `inline`.
  bool? get inline => raw.boolean('inline');

  /// `role`: ARIA role.
  String? get role => raw.string('role');

  /// `flush`: No padding.
  bool? get flush => raw.boolean('flush');

  /// `minSize`: Minimum width and height.
  Object? get minSize => raw.value('minSize');

  /// `maxSize`: Maximum width and height.
  Object? get maxSize => raw.value('maxSize');

  /// `disableAutoSpacing`: No default gap between children.
  bool? get disableAutoSpacing => raw.boolean('disableAutoSpacing');

  /// `hoverBackground`.
  String? get hoverBackground => raw.string('hoverBackground');

  /// `insetBorder`: A 1px border inside the box.
  bool? get insetBorder => raw.boolean('insetBorder');
}

/// The props of a `Form` node, typed.
///
/// A layout container that is a form. It sends onSubmit when the user
/// submits (a Button with submit true, or Enter in a field). Put its field
/// values in the event context with { "@path": "/x" }.
extension type const FormProps(ComponentProps raw) {
  /// `children`: the child nodes, in order.
  List<ComponentNode<ComponentImplementation>> get children =>
      raw.children('children');

  /// `onSubmit`: Sent when the user submits the form.
  NodeAction? get onSubmit => raw.action('onSubmit');

  /// `label`: A short name of the form for screen readers.
  String? get label => raw.string('label');

  /// `align`.
  A2uiAlign? get align => A2uiAlign.fromWire(raw.value('align'));

  /// `justify`.
  A2uiJustify? get justify => A2uiJustify.fromWire(raw.value('justify'));

  /// `wrap`.
  A2uiWrap? get wrap => A2uiWrap.fromWire(raw.value('wrap'));

  /// `gap`: 4px steps when a number.
  Object? get gap => raw.value('gap');

  /// `rowGap`.
  Object? get rowGap => raw.value('rowGap');

  /// `columnGap`.
  Object? get columnGap => raw.value('columnGap');

  /// `padding`: 4px steps when a number.
  Object? get padding => raw.value('padding');

  /// `background`: Leave it unset. A surface token such as surface,
  /// surface-secondary, info, success, warning, danger, discovery, or one
  /// with -solid, or a CSS color. Only one summary panel in a Card uses
  /// "surface-secondary".
  String? get background => raw.string('background');

  /// `border`.
  bool? get border => raw.boolean('border');

  /// `borderColor`.
  A2uiBorderColor? get borderColor =>
      A2uiBorderColor.fromWire(raw.value('borderColor'));

  /// `radius`.
  Object? get radius => raw.value('radius');

  /// `width`.
  Object? get width => raw.value('width');

  /// `height`.
  Object? get height => raw.value('height');

  /// `minWidth`.
  Object? get minWidth => raw.value('minWidth');

  /// `maxWidth`.
  Object? get maxWidth => raw.value('maxWidth');

  /// `minHeight`.
  Object? get minHeight => raw.value('minHeight');

  /// `maxHeight`.
  Object? get maxHeight => raw.value('maxHeight');

  /// `flex`.
  double? get flex => raw.number('flex');

  /// `weight`: flex-grow in a Row or Column.
  double? get weight => raw.number('weight');

  /// `aspectRatio`.
  String? get aspectRatio => raw.string('aspectRatio');

  /// `scrollable`.
  bool? get scrollable => raw.boolean('scrollable');

  /// `clip`.
  bool? get clip => raw.boolean('clip');

  /// `shadow`.
  bool? get shadow => raw.boolean('shadow');

  /// `inline`.
  bool? get inline => raw.boolean('inline');

  /// `role`: ARIA role.
  String? get role => raw.string('role');

  /// `flush`: No padding.
  bool? get flush => raw.boolean('flush');

  /// `minSize`: Minimum width and height.
  Object? get minSize => raw.value('minSize');

  /// `maxSize`: Maximum width and height.
  Object? get maxSize => raw.value('maxSize');

  /// `disableAutoSpacing`: No default gap between children.
  bool? get disableAutoSpacing => raw.boolean('disableAutoSpacing');
}

/// The props of a `TextField` node, typed.
///
/// A text input, single-line unless variant is "longText". Bind value with
/// { "@path": "/x" } to read what the user typed. Give it a label.
extension type const TextFieldProps(ComponentProps raw) {
  /// `label`: The visible label of the field. Always set it.
  String? get label => raw.string('label');

  /// `value`: Bind it with { "@path": "/x" } to read what the user typed.
  String? get value => raw.string('value');

  /// `checks`: Validation rules. The control shows the first failed one.
  List<Object?> get checks => raw.list('checks');

  /// `placeholder`.
  String? get placeholder => raw.string('placeholder');

  /// `variant`: Default "shortText". "longText" is a multi-line field,
  /// "obscured" a password.
  TextFieldVariant get variant =>
      TextFieldVariant.fromWire(raw.value('variant')) ??
      TextFieldVariant.shortText;

  /// `name`.
  String? get name => raw.string('name');

  /// `required`.
  bool? get required => raw.boolean('required');

  /// `disabled`.
  bool? get disabled => raw.boolean('disabled');

  /// `invalid`.
  bool? get invalid => raw.boolean('invalid');

  /// `autoSelect`.
  bool? get autoSelect => raw.boolean('autoSelect');

  /// `mask`.
  String? get mask => raw.string('mask');

  /// `weight`: flex-grow in a Row or Column.
  double? get weight => raw.number('weight');

  /// `size`: Default "xl".
  A2uiControlSize get size =>
      A2uiControlSize.fromWire(raw.value('size')) ?? A2uiControlSize.xl;

  /// `pill`: Default true.
  bool get pill => raw.boolean('pill') ?? true;
}

/// The props of a `TextArea` node, typed.
///
/// A multi-line text input. Bind value with { "@path": "/x" } to read what
/// the user typed. Give it a label.
extension type const TextAreaProps(ComponentProps raw) {
  /// `label`: The visible label of the field. Always set it.
  String? get label => raw.string('label');

  /// `value`: Bind it with { "@path": "/x" } to read what the user entered.
  String? get value => raw.string('value');

  /// `checks`: Validation rules. The control shows the first failed one.
  List<Object?> get checks => raw.list('checks');

  /// `placeholder`.
  String? get placeholder => raw.string('placeholder');

  /// `rows`: Default 3.
  double get rows => raw.number('rows') ?? 3.0;

  /// `maxRows`.
  double? get maxRows => raw.number('maxRows');

  /// `autoResize`.
  bool? get autoResize => raw.boolean('autoResize');

  /// `name`.
  String? get name => raw.string('name');

  /// `required`.
  bool? get required => raw.boolean('required');

  /// `disabled`.
  bool? get disabled => raw.boolean('disabled');

  /// `invalid`.
  bool? get invalid => raw.boolean('invalid');

  /// `weight`: flex-grow in a Row or Column.
  double? get weight => raw.number('weight');

  /// `size`: Default "xl".
  A2uiControlSize get size =>
      A2uiControlSize.fromWire(raw.value('size')) ?? A2uiControlSize.xl;
}

/// The props of a `Select` node, typed.
///
/// A dropdown list of options. Bind value with { "@path": "/x" } to read
/// the chosen option. Give it a label.
extension type const SelectProps(ComponentProps raw) {
  /// `label`: The visible label of the field. Always set it.
  String? get label => raw.string('label');

  /// `options`.
  List<Object?> get options => raw.list('options');

  /// `value`: Bind it with { "@path": "/x" } to read what the user entered.
  String? get value => raw.string('value');

  /// `checks`: Validation rules. The control shows the first failed one.
  List<Object?> get checks => raw.list('checks');

  /// `placeholder`.
  String? get placeholder => raw.string('placeholder');

  /// `name`.
  String? get name => raw.string('name');

  /// `required`.
  bool? get required => raw.boolean('required');

  /// `disabled`.
  bool? get disabled => raw.boolean('disabled');

  /// `clearable`.
  bool? get clearable => raw.boolean('clearable');

  /// `clearLabel`: The label of the empty option.
  String? get clearLabel => raw.string('clearLabel');

  /// `searchable`.
  bool? get searchable => raw.boolean('searchable');

  /// `icon`: Lucide icon shown before the value.
  String? get icon => raw.string('icon');

  /// `block`: Full width.
  bool? get block => raw.boolean('block');

  /// `size`: Default "xl".
  A2uiControlSize get size =>
      A2uiControlSize.fromWire(raw.value('size')) ?? A2uiControlSize.xl;

  /// `pill`: Default true.
  bool get pill => raw.boolean('pill') ?? true;
}

/// The props of a `CheckBox` node, typed.
///
/// A checkbox with a label. Bind value with { "@path": "/x" } to read its
/// state, true or false.
extension type const CheckBoxProps(ComponentProps raw) {
  /// `label`: The label text. Always set it.
  String? get label => raw.string('label');

  /// `value`: True when checked. Bind it with { "@path": "/x" } to read the
  /// state of the box.
  bool? get value => raw.boolean('value');

  /// `checks`: Validation rules. The control shows the first failed one.
  List<Object?> get checks => raw.list('checks');

  /// `name`.
  String? get name => raw.string('name');

  /// `disabled`.
  bool? get disabled => raw.boolean('disabled');

  /// `required`.
  bool? get required => raw.boolean('required');

  /// `shape`: Default "round".
  CheckBoxShape get shape =>
      CheckBoxShape.fromWire(raw.value('shape')) ?? CheckBoxShape.round;

  /// `weight`: flex-grow in a Row or Column.
  double? get weight => raw.number('weight');

  /// `lineThrough`: Default false. Strikes the label when the box is checked.
  bool get lineThrough => raw.boolean('lineThrough') ?? false;
}

/// The props of a `Radio` node, typed.
///
/// One radio button. Use RadioGroup instead, because it keeps the chosen
/// value.
extension type const RadioProps(ComponentProps raw) {
  /// `label`.
  String? get label => raw.string('label');

  /// `value`.
  String? get value => raw.string('value');

  /// `disabled`.
  bool? get disabled => raw.boolean('disabled');

  /// `required`.
  bool? get required => raw.boolean('required');
}

/// The props of a `RadioGroup` node, typed.
///
/// A group of radio buttons. The user chooses one option. Bind value with {
/// "@path": "/x" } to read it. Give it a label.
extension type const RadioGroupProps(ComponentProps raw) {
  /// `label`: The visible label of the field. Always set it.
  String? get label => raw.string('label');

  /// `options`.
  List<Object?> get options => raw.list('options');

  /// `value`: Bind it with { "@path": "/x" } to read what the user entered.
  String? get value => raw.string('value');

  /// `checks`: Validation rules. The control shows the first failed one.
  List<Object?> get checks => raw.list('checks');

  /// `name`.
  String? get name => raw.string('name');

  /// `direction`: Default "row".
  RadioGroupDirection get direction =>
      RadioGroupDirection.fromWire(raw.value('direction')) ??
      RadioGroupDirection.row;

  /// `variant`.
  RadioGroupVariant? get variant =>
      RadioGroupVariant.fromWire(raw.value('variant'));

  /// `disabled`.
  bool? get disabled => raw.boolean('disabled');

  /// `required`.
  bool? get required => raw.boolean('required');
}

/// The props of a `Slider` node, typed.
///
/// A range slider for a number between min and max. Bind value with {
/// "@path": "/x" } to read the number. Give it a label.
extension type const SliderProps(ComponentProps raw) {
  /// `label`: The visible label of the field. Always set it.
  String? get label => raw.string('label');

  /// `value`: Bind it with { "@path": "/x" } to read the number.
  double? get value => raw.number('value');

  /// `min`: Default 0.
  double get min => raw.number('min') ?? 0.0;

  /// `max`: Default 100.
  double get max => raw.number('max') ?? 100.0;

  /// `checks`: Validation rules. The control shows the first failed one.
  List<Object?> get checks => raw.list('checks');

  /// `step`: Default 1.
  double get step => raw.number('step') ?? 1.0;

  /// `steps`: The number of equal divisions between min and max, instead of
  /// step.
  double? get steps => raw.number('steps');

  /// `unit`: Unit after the value, for example "%".
  String? get unit => raw.string('unit');

  /// `marks`.
  List<Object?> get marks => raw.list('marks');

  /// `sliderStyle`: Default "continuous".
  SliderStyle get sliderStyle =>
      SliderStyle.fromWire(raw.value('sliderStyle')) ?? SliderStyle.continuous;

  /// `disabled`.
  bool? get disabled => raw.boolean('disabled');

  /// `name`.
  String? get name => raw.string('name');

  /// `weight`: flex-grow in a Row or Column.
  double? get weight => raw.number('weight');
}

/// The props of a `SegmentedControl` node, typed.
///
/// A row of segments. The user chooses one option. Use it for 2 to 5 short
/// options. Bind value with { "@path": "/x" } to read it.
extension type const SegmentedControlProps(ComponentProps raw) {
  /// `label`: The visible label of the field. Always set it.
  String? get label => raw.string('label');

  /// `options`.
  List<Object?> get options => raw.list('options');

  /// `value`: Bind it with { "@path": "/x" } to read what the user entered.
  String? get value => raw.string('value');

  /// `checks`: Validation rules. The control shows the first failed one.
  List<Object?> get checks => raw.list('checks');

  /// `block`: Full width.
  bool? get block => raw.boolean('block');

  /// `variant`: Default "ghost".
  A2uiActionVariant get variant =>
      A2uiActionVariant.fromWire(raw.value('variant')) ??
      A2uiActionVariant.ghost;

  /// `disabled`.
  bool? get disabled => raw.boolean('disabled');

  /// `size`: Default "lg".
  A2uiControlSize get size =>
      A2uiControlSize.fromWire(raw.value('size')) ?? A2uiControlSize.lg;

  /// `pill`: Default true.
  bool get pill => raw.boolean('pill') ?? true;
}

/// The props of a `ChoicePicker` node, typed.
///
/// Options as checkboxes or chips: pick one, or several with variant
/// "multipleSelection". Its value is the list of chosen values. Give it a
/// label.
extension type const ChoicePickerProps(ComponentProps raw) {
  /// `label`: The visible label of the field. Always set it.
  String? get label => raw.string('label');

  /// `options`.
  List<Object?> get options => raw.list('options');

  /// `value`: The chosen option values. Bind it with { "@path": "/x" } to a
  /// string list.
  List<Object?> get value => raw.list('value');

  /// `checks`: Validation rules. The control shows the first failed one.
  List<Object?> get checks => raw.list('checks');

  /// `variant`: Default "mutuallyExclusive": the user picks one option.
  ChoicePickerVariant get variant =>
      ChoicePickerVariant.fromWire(raw.value('variant')) ??
      ChoicePickerVariant.mutuallyExclusive;

  /// `displayStyle`: Default "checkbox". "chips" shows the options as pills.
  ChoicePickerDisplayStyle get displayStyle =>
      ChoicePickerDisplayStyle.fromWire(raw.value('displayStyle')) ??
      ChoicePickerDisplayStyle.checkbox;

  /// `filterable`: Default false. Shows a field that filters the options.
  bool get filterable => raw.boolean('filterable') ?? false;

  /// `disabled`.
  bool? get disabled => raw.boolean('disabled');

  /// `required`.
  bool? get required => raw.boolean('required');

  /// `weight`: flex-grow in a Row or Column.
  double? get weight => raw.number('weight');
}

/// The props of a `DateTimeInput` node, typed.
///
/// A date picker, a time picker with enableTime, or both. timeStep
/// (minutes) offers fixed times, e.g. 30 for a booking. The value is ISO
/// 8601. Give it a label.
extension type const DateTimeInputProps(ComponentProps raw) {
  /// `label`: The visible label of the field. Always set it.
  String? get label => raw.string('label');

  /// `value`: ISO 8601: "YYYY-MM-DD", "HH:MM" or "YYYY-MM-DDTHH:MM". Bind it
  /// with { "@path": "/x" }.
  String? get value => raw.string('value');

  /// `checks`: Validation rules. The control shows the first failed one.
  List<Object?> get checks => raw.list('checks');

  /// `enableDate`: The user picks a date. Default true unless only enableTime
  /// is set.
  bool get enableDate => raw.boolean('enableDate') ?? true;

  /// `enableTime`: The user picks a time.
  bool? get enableTime => raw.boolean('enableTime');

  /// `timeStep`: Minutes between the times the user can pick, e.g. 15 or 30.
  /// Shows the time as a list.
  double? get timeStep => raw.number('timeStep');

  /// `min`: The earliest value, ISO 8601.
  String? get min => raw.string('min');

  /// `max`: The latest value, ISO 8601.
  String? get max => raw.string('max');

  /// `placeholder`.
  String? get placeholder => raw.string('placeholder');

  /// `disabled`.
  bool? get disabled => raw.boolean('disabled');

  /// `required`.
  bool? get required => raw.boolean('required');

  /// `clearable`.
  bool? get clearable => raw.boolean('clearable');

  /// `block`: Full width.
  bool? get block => raw.boolean('block');

  /// `weight`: flex-grow in a Row or Column.
  double? get weight => raw.number('weight');
}

/// The props of a `PulseIndicator` node, typed.
///
/// A small dot that pulses, for example next to the text "Live". Set label
/// when no text next to the dot says what it means.
extension type const PulseIndicatorProps(ComponentProps raw) {
  /// `label`: What the dot means, for screen readers. Leave it unset when
  /// text next to the dot says the same.
  String? get label => raw.string('label');

  /// `pulseColor`.
  String? get pulseColor => raw.string('pulseColor');

  /// `duration`: Milliseconds. Default 1500.
  double get duration => raw.number('duration') ?? 1500.0;

  /// `endScale`: Default 2.4.
  double get endScale => raw.number('endScale') ?? 2.4;

  /// `startOpacity`: Default 0.6.
  double get startOpacity => raw.number('startOpacity') ?? 0.6;

  /// `color`: Text color token. Default "success".
  String get color => raw.string('color') ?? 'success';

  /// `size`: Pixels. Default 12.
  double get size => raw.number('size') ?? 12.0;
}

/// The props of a `FlashcardFlip` node, typed.
///
/// A card that shows the front text. A click or the Enter key flips it to
/// the back text, and again to the front.
extension type const FlashcardFlipProps(ComponentProps raw) {
  /// `front`: The text on the front.
  String? get front => raw.string('front');

  /// `back`: The text on the back.
  String? get back => raw.string('back');

  /// `hint`: A small line under the front, for example "Click to flip".
  String? get hint => raw.string('hint');
}

/// The props of a `Popover` node, typed.
///
/// A small overlay: exactly two children, one PopoverTrigger then one
/// PopoverContent. A click on the trigger toggles it; Escape or a click
/// outside closes it.
extension type const PopoverProps(ComponentProps raw) {
  /// `children`: the child nodes, in order.
  List<ComponentNode<ComponentImplementation>> get children =>
      raw.children('children');

  /// `open`: Default false.
  bool get open => raw.boolean('open') ?? false;

  /// `showOnHover`.
  bool? get showOnHover => raw.boolean('showOnHover');

  /// `hoverOpenDelay`: Milliseconds before a hover opens it. Default 0.
  double get hoverOpenDelay => raw.number('hoverOpenDelay') ?? 0.0;
}

/// The props of a `PopoverTrigger` node, typed.
///
/// The trigger of a Popover. Its children are the label of the trigger: a
/// Text or an Icon. Do not put a Button in it, because the trigger is
/// already a button.
extension type const PopoverTriggerProps(ComponentProps raw) {
  /// `children`: the child nodes, in order.
  List<ComponentNode<ComponentImplementation>> get children =>
      raw.children('children');

  /// `block`: Full width.
  bool? get block => raw.boolean('block');
}

/// The props of a `PopoverContent` node, typed.
///
/// The body of a Popover. It shows only when the Popover is open.
extension type const PopoverContentProps(ComponentProps raw) {
  /// `children`: the child nodes, in order.
  List<ComponentNode<ComponentImplementation>> get children =>
      raw.children('children');

  /// `side`: Default "bottom".
  PopoverContentSide get side =>
      PopoverContentSide.fromWire(raw.value('side')) ??
      PopoverContentSide.bottom;

  /// `sideOffset`: Pixels between the trigger and the content. Default 6.
  double get sideOffset => raw.number('sideOffset') ?? 6.0;

  /// `align`: Default "center".
  A2uiTextAlign get align =>
      A2uiTextAlign.fromWire(raw.value('align')) ?? A2uiTextAlign.center;

  /// `width`: 4px steps when a number.
  Object? get width => raw.value('width');
}

/// The props of a `Modal` node, typed.
///
/// A dialog over the page. A click on the trigger (a Button or a Text)
/// opens the content in the dialog. Escape, the close button or a click on
/// the backdrop closes it.
extension type const ModalProps(ComponentProps raw) {
  /// `trigger`: the child node.
  ComponentNode<ComponentImplementation>? get trigger => raw.child('trigger');

  /// `content`: the child node.
  ComponentNode<ComponentImplementation>? get content => raw.child('content');

  /// `title`: The heading of the dialog.
  String? get title => raw.string('title');

  /// `open`: Default false. Bind it with { "@path": "/x" } to read it.
  bool get open => raw.boolean('open') ?? false;

  /// `maxWidth`: Default 480.
  Object? get maxWidth => raw.value('maxWidth');

  /// `weight`: flex-grow in a Row or Column.
  double? get weight => raw.number('weight');
}

/// The props of a `Table` node, typed.
///
/// A data table, in a plain Column, not a Card. Give "columns" and "rows",
/// or "children": TableSection or TableRow ids, or a template {
/// "componentId", "path" } repeating a TableRow per item. A component in a
/// cell or header (Badge, Button, Icon, Text): { "componentId": "<id>" },
/// with the id in "cellComponents".
extension type const TableProps(ComponentProps raw) {
  /// `columns`: Default \[\].
  List<Object?> get columns => raw.list('columns');

  /// `rows`: A list of row lists. A cell is a string, a number, or {
  /// "componentId": "<id>" } to show a component. Default \[\].
  List<Object?> get rows => raw.list('rows');

  /// `children`: the child nodes, in order.
  List<ComponentNode<ComponentImplementation>> get children =>
      raw.children('children');

  /// `caption`: A short name of the table for screen readers. It is not
  /// shown.
  String? get caption => raw.string('caption');

  /// `columnSizing`: Default "auto".
  TableColumnSizing get columnSizing =>
      TableColumnSizing.fromWire(raw.value('columnSizing')) ??
      TableColumnSizing.auto;

  /// `dividers`: Default true.
  bool get dividers => raw.boolean('dividers') ?? true;

  /// `stickyHeader`: Default false.
  bool get stickyHeader => raw.boolean('stickyHeader') ?? false;

  /// `emptyLabel`: Default "No rows".
  String get emptyLabel => raw.string('emptyLabel') ?? 'No rows';

  /// `cellComponents`: the child nodes, in order.
  List<ComponentNode<ComponentImplementation>> get cellComponents =>
      raw.children('cellComponents');
}

/// The props of a `TableSection` node, typed.
///
/// A group of TableRow children in a Table. With header true, it is the
/// header of the table.
extension type const TableSectionProps(ComponentProps raw) {
  /// `children`: the child nodes, in order.
  List<ComponentNode<ComponentImplementation>> get children =>
      raw.children('children');

  /// `header`: Renders the rows as the header.
  bool? get header => raw.boolean('header');

  /// `rowDivider`.
  bool? get rowDivider => raw.boolean('rowDivider');
}

/// The props of a `TableRow` node, typed.
///
/// A row of a Table. Its children are TableCell ids, or a template. With
/// label, a header cell with that text starts the row.
extension type const TableRowProps(ComponentProps raw) {
  /// `children`: the child nodes, in order.
  List<ComponentNode<ComponentImplementation>> get children =>
      raw.children('children');

  /// `label`: The text of a header cell at the start of the row.
  String? get label => raw.string('label');

  /// `header`.
  bool? get header => raw.boolean('header');

  /// `labelColSpan`: Columns the label cell spans.
  double? get labelColSpan => raw.number('labelColSpan');
}

/// The props of a `TableCell` node, typed.
///
/// A cell of a TableRow. It shows "text", or its children. With header
/// true, it is a header cell.
extension type const TableCellProps(ComponentProps raw) {
  /// `text`.
  String? get text => raw.string('text');

  /// `children`: the child nodes, in order.
  List<ComponentNode<ComponentImplementation>> get children =>
      raw.children('children');

  /// `header`.
  bool? get header => raw.boolean('header');

  /// `vAlign`: Default "start".
  A2uiTextAlign get vAlign =>
      A2uiTextAlign.fromWire(raw.value('vAlign')) ?? A2uiTextAlign.start;

  /// `colSpan`.
  double? get colSpan => raw.number('colSpan');

  /// `rowSpan`.
  double? get rowSpan => raw.number('rowSpan');

  /// `align`.
  A2uiTextAlign? get align => A2uiTextAlign.fromWire(raw.value('align'));

  /// `width`.
  Object? get width => raw.value('width');

  /// `padding`.
  Object? get padding => raw.value('padding');
}

/// The props of a `List` node, typed.
///
/// A list in a Card or next to another component; a plain list of text is
/// markdown. Give "items": an item with a value and no action is a
/// key-value row (Price: $1,599). Or give "children": ListItem ids or a
/// template. With "action" the user picks an item; the event context gets
/// its index, label and value.
extension type const ListProps(ComponentProps raw) {
  /// `items`.
  List<Object?> get items => raw.list('items');

  /// `children`: the child nodes, in order.
  List<ComponentNode<ComponentImplementation>> get children =>
      raw.children('children');

  /// `action`: Runs when the user picks an item. The args are the index,
  /// label and value of the item.
  NodeAction? get action => raw.action('action');

  /// `direction`: Default "vertical". "horizontal" scrolls sideways.
  A2uiOrientation get direction =>
      A2uiOrientation.fromWire(raw.value('direction')) ??
      A2uiOrientation.vertical;

  /// `marker`: Default "bullet".
  ListMarker get marker =>
      ListMarker.fromWire(raw.value('marker')) ?? ListMarker.bullet;

  /// `connector`: Default "none".
  ListConnector get connector =>
      ListConnector.fromWire(raw.value('connector')) ?? ListConnector.none;

  /// `start`: The first number of marker "number".
  double? get start => raw.number('start');

  /// `maxMarkerSize`: The width of the marker column in pixels.
  double? get maxMarkerSize => raw.number('maxMarkerSize');

  /// `align`.
  ListAlign? get align => ListAlign.fromWire(raw.value('align'));

  /// `weight`: flex-grow in a Row or Column.
  double? get weight => raw.number('weight');

  /// `gap`.
  Object? get gap => raw.value('gap');
}

/// The props of a `ListItem` node, typed.
///
/// An item of a List, with a label, a value on the right, a description, an
/// icon and children. With an "action", the user can pick it.
extension type const ListItemProps(ComponentProps raw) {
  /// `label`.
  String? get label => raw.string('label');

  /// `value`: Without an action: shown on the right of the label, for a key
  /// and value fact.
  String? get value => raw.string('value');

  /// `action`: Runs when the user picks the item.
  NodeAction? get action => raw.action('action');

  /// `children`: the child nodes, in order.
  List<ComponentNode<ComponentImplementation>> get children =>
      raw.children('children');

  /// `description`.
  String? get description => raw.string('description');

  /// `icon`: Lucide icon name.
  String? get icon => raw.string('icon');

  /// `marker`: Shows this text as the marker.
  String? get marker => raw.string('marker');

  /// `markerSize`: The width of the marker column in pixels.
  double? get markerSize => raw.number('markerSize');

  /// `disabled`: Greys the item out and ignores its action.
  bool? get disabled => raw.boolean('disabled');
}

/// The props of a `Chart` node, typed.
///
/// A bar, line, area, scatter, pie or donut chart. "data" is a list of
/// objects. "xKey" is the field of the category. "series" are the value
/// fields.
extension type const ChartProps(ComponentProps raw) {
  /// `data`.
  List<Object?> get data => raw.list('data');

  /// `xKey`: The field of the category axis.
  String? get xKey => raw.string('xKey');

  /// `series`: Default: every number field except xKey.
  List<Object?> get series => raw.list('series');

  /// `chartType`: Default "bar".
  ChartType get chartType =>
      ChartType.fromWire(raw.value('chartType')) ?? ChartType.bar;

  /// `stacked`.
  bool? get stacked => raw.boolean('stacked');

  /// `layout`: "horizontal" draws the bars from left to right. Default
  /// "vertical".
  A2uiOrientation get layout =>
      A2uiOrientation.fromWire(raw.value('layout')) ?? A2uiOrientation.vertical;

  /// `yAxis`: Example: {label: "Revenue (USD)", min: 0, max: 100}. In a
  /// horizontal chart it is the horizontal axis, and width sets the category
  /// axis width.
  Map<String, Object?>? get yAxis => switch (raw.value('yAxis')) {
    final Map<Object?, Object?> m => m.cast<String, Object?>(),
    _ => null,
  };

  /// `showDots`: Point markers on a line or area.
  bool? get showDots => raw.boolean('showDots');

  /// `barRadius`: The corner radius of a bar, in pixels.
  double? get barRadius => raw.number('barRadius');

  /// `innerRadius`: Pie and donut.
  Object? get innerRadius => raw.value('innerRadius');

  /// `outerRadius`: Pie and donut.
  Object? get outerRadius => raw.value('outerRadius');

  /// `startAngle`: Pie and donut. Default 90.
  double get startAngle => raw.number('startAngle') ?? 90.0;

  /// `endAngle`: Pie and donut. Default -270.
  double get endAngle => raw.number('endAngle') ?? -270.0;

  /// `cornerRadius`: The corners of a slice.
  double? get cornerRadius => raw.number('cornerRadius');

  /// `paddingAngle`: The gap between slices.
  double? get paddingAngle => raw.number('paddingAngle');

  /// `showLabelLines`: Leader lines of the slice labels. Default true.
  bool get showLabelLines => raw.boolean('showLabelLines') ?? true;

  /// `showLegend`: Default true.
  bool get showLegend => raw.boolean('showLegend') ?? true;

  /// `showGrid`: Default true.
  bool get showGrid => raw.boolean('showGrid') ?? true;

  /// `showTooltip`: Default true.
  bool get showTooltip => raw.boolean('showTooltip') ?? true;

  /// `showValueLabels`.
  bool? get showValueLabels => raw.boolean('showValueLabels');

  /// `format`: With "percent", data values and axis min/max are fractions:
  /// 0.4 shows as 40%; for 0% to 10%, use min: 0 and max: 0.1.
  ChartFormat? get format => ChartFormat.fromWire(raw.value('format'));

  /// `currency`: ISO code. Default "USD".
  String get currency => raw.string('currency') ?? 'USD';

  /// `title`.
  String? get title => raw.string('title');

  /// `height`: Pixels. Default 240.
  double get height => raw.number('height') ?? 240.0;
}

/// The props of a `Map` node, typed.
///
/// A map with markers; with "route" a line connects them in order. Bind
/// "selected" to get the label of the marker the user picks. Without maps
/// it shows a list of the places.
extension type const MapProps(ComponentProps raw) {
  /// `markers`.
  List<Object?> get markers => raw.list('markers');

  /// `selected`: The label of the selected marker. Bind it with { "@path":
  /// "/x" } to read the choice of the user.
  String? get selected => raw.string('selected');

  /// `route`: Draws a line through the markers in order.
  bool? get route => raw.boolean('route');

  /// `zoom`: With two or more markers, only the highest zoom of the fit.
  double? get zoom => raw.number('zoom');

  /// `center`.
  Map<String, Object?>? get center => switch (raw.value('center')) {
    final Map<Object?, Object?> m => m.cast<String, Object?>(),
    _ => null,
  };

  /// `height`: Pixels. Default 240.
  double get height => raw.number('height') ?? 240.0;
}

/// The props of a `Image` node, typed.
///
/// An image from a URL. A click opens it full-screen. Set description to
/// say what the image shows, unless it is only decoration.
extension type const ImageProps(ComponentProps raw) {
  /// `url` (required): Image URL.
  String? get url => raw.string('url');

  /// `description`: What the image shows, for screen readers. Leave it unset
  /// only for a decorative image.
  String? get description => raw.string('description');

  /// `onOverlayClick`: Sent when the user clicks the actionOverlay button and
  /// it has no href.
  NodeAction? get onOverlayClick => raw.action('onOverlayClick');

  /// `variant`: The size: "icon" 24px, "avatar" 40px round, "smallFeature"
  /// 160px wide, "largeFeature" and "header" full width. Default
  /// "mediumFeature": the natural size.
  ImageVariant get variant =>
      ImageVariant.fromWire(raw.value('variant')) ?? ImageVariant.mediumFeature;

  /// `fit`: CSS object-fit. Default "cover".
  ImageFit get fit => ImageFit.fromWire(raw.value('fit')) ?? ImageFit.cover;

  /// `frame`.
  bool? get frame => raw.boolean('frame');

  /// `position`: CSS object-position, for example "top" or "50% 20%".
  String? get position => raw.string('position');

  /// `hideOnFailure`: Default false.
  bool get hideOnFailure => raw.boolean('hideOnFailure') ?? false;

  /// `fallback`: Text shown in place of the image when it does not load.
  String? get fallback => raw.string('fallback');

  /// `hoverZoom`: A slight zoom on hover.
  bool? get hoverZoom => raw.boolean('hoverZoom');

  /// `lightbox`: Default true: a click opens the image full-screen.
  bool get lightbox => raw.boolean('lightbox') ?? true;

  /// `actionOverlay`: A button over the bottom-right corner of the image.
  /// Without href, it sends onOverlayClick.
  Map<String, Object?>? get actionOverlay =>
      switch (raw.value('actionOverlay')) {
        final Map<Object?, Object?> m => m.cast<String, Object?>(),
        _ => null,
      };

  /// `weight`: flex-grow in a Row or Column.
  double? get weight => raw.number('weight');

  /// `aspectRatio`.
  String? get aspectRatio => raw.string('aspectRatio');

  /// `radius`.
  Object? get radius => raw.value('radius');

  /// `width`.
  Object? get width => raw.value('width');

  /// `height`.
  Object? get height => raw.value('height');

  /// `maxWidth`.
  Object? get maxWidth => raw.value('maxWidth');

  /// `maxHeight`.
  Object? get maxHeight => raw.value('maxHeight');

  /// `minWidth`.
  Object? get minWidth => raw.value('minWidth');

  /// `minHeight`.
  Object? get minHeight => raw.value('minHeight');

  /// `background`.
  String? get background => raw.string('background');
}

/// The props of a `Icon` node, typed.
///
/// A Lucide icon by kebab-case name (for example "arrow-right"), or an A2UI
/// icon name (for example "arrowBack"). Set label when no text next to the
/// icon says what it means.
extension type const IconProps(ComponentProps raw) {
  /// `name` (required): A Lucide icon name in kebab-case ("arrow-right"), an
  /// A2UI icon name ("arrowBack"), or { "svgPath" } on a 24px grid.
  Object? get name => raw.value('name');

  /// `label`: What the icon means, for screen readers. Leave it unset when
  /// text next to the icon says the same.
  String? get label => raw.string('label');

  /// `size`: Default "md".
  Object? get size => raw.value('size');

  /// `color`.
  String? get color => raw.string('color');

  /// `inline`: Default false.
  bool get inline => raw.boolean('inline') ?? false;

  /// `strokeWeight`: The stroke width.
  A2uiFontWeight? get strokeWeight =>
      A2uiFontWeight.fromWire(raw.value('strokeWeight'));

  /// `weight`: flex-grow in a Row or Column.
  double? get weight => raw.number('weight');
}

/// The props of a `Favicon` node, typed.
///
/// The favicon of the site at a URL.
extension type const FaviconProps(ComponentProps raw) {
  /// `url` (required).
  String? get url => raw.string('url');

  /// `alt`.
  String? get alt => raw.string('alt');

  /// `frame`: Default false.
  bool get frame => raw.boolean('frame') ?? false;

  /// `size`: Pixels. Default 16.
  double get size => raw.number('size') ?? 16.0;

  /// `inline`: Default false.
  bool get inline => raw.boolean('inline') ?? false;
}

/// The props of a `Svg` node, typed.
///
/// A vector drawing from primitive shapes (paths, circles, rects, lines,
/// texts). Colors take text color tokens or CSS colors.
extension type const SvgProps(ComponentProps raw) {
  /// `paths`.
  List<Object?> get paths => raw.list('paths');

  /// `viewBox`.
  String? get viewBox => raw.string('viewBox');

  /// `label`: What the drawing shows, for screen readers. Leave it unset for
  /// a decorative drawing.
  String? get label => raw.string('label');

  /// `fill`: Default "currentColor".
  String get fill => raw.string('fill') ?? 'currentColor';

  /// `stroke`.
  String? get stroke => raw.string('stroke');

  /// `strokeWidth`.
  double? get strokeWidth => raw.number('strokeWidth');

  /// `strokeLinecap`.
  SvgStrokeLinecap? get strokeLinecap =>
      SvgStrokeLinecap.fromWire(raw.value('strokeLinecap'));

  /// `strokeLinejoin`.
  SvgStrokeLinejoin? get strokeLinejoin =>
      SvgStrokeLinejoin.fromWire(raw.value('strokeLinejoin'));

  /// `preserveAspectRatio`.
  String? get preserveAspectRatio => raw.string('preserveAspectRatio');

  /// `circles`.
  List<Object?> get circles => raw.list('circles');

  /// `rects`.
  List<Object?> get rects => raw.list('rects');

  /// `lines`.
  List<Object?> get lines => raw.list('lines');

  /// `texts`.
  List<Object?> get texts => raw.list('texts');

  /// `width`.
  Object? get width => raw.value('width');

  /// `height`.
  Object? get height => raw.value('height');

  /// `size`.
  Object? get size => raw.value('size');

  /// `color`: Default "prose".
  String get color => raw.string('color') ?? 'prose';
}

/// The props of a `Video` node, typed.
///
/// A video file URL (optional captions) or a YouTube link,
/// privacy-enhanced: the poster shows until play. Other video sites show as
/// a link. Set title.
extension type const VideoProps(ComponentProps raw) {
  /// `url` (required): The URL of a video file, or of a YouTube video or
  /// short. A page on another video site shows as a link.
  String? get url => raw.string('url');

  /// `title`: Names the video for screen readers.
  String? get title => raw.string('title');

  /// `captions`: Caption tracks of a video file.
  List<Object?> get captions => raw.list('captions');

  /// `posterUrl`: The image shown before the video plays.
  String? get posterUrl => raw.string('posterUrl');

  /// `aspectRatio`: Default "16 / 9".
  String get aspectRatio => raw.string('aspectRatio') ?? '16 / 9';

  /// `width`: Default "100%".
  Object? get width => raw.value('width');

  /// `maxWidth`: Default "100%".
  Object? get maxWidth => raw.value('maxWidth');

  /// `weight`: flex-grow in a Row or Column.
  double? get weight => raw.number('weight');
}

/// The props of a `AudioPlayer` node, typed.
///
/// An audio player for an audio file URL, with the description above it.
extension type const AudioPlayerProps(ComponentProps raw) {
  /// `url` (required): The URL of the audio file.
  String? get url => raw.string('url');

  /// `description`: A title or summary of the audio, shown above the player.
  String? get description => raw.string('description');

  /// `weight`: flex-grow in a Row or Column.
  double? get weight => raw.number('weight');
}

/// The props of a `HtmlView` node, typed.
///
/// Raw HTML in a fully sandboxed iframe: no scripts, no same-origin access.
/// Set title to name the content.
extension type const HtmlViewProps(ComponentProps raw) {
  /// `html` (required).
  String? get html => raw.string('html');

  /// `title`.
  String? get title => raw.string('title');

  /// `height`: Pixels when a number. Default 360.
  Object? get height => raw.value('height');

  /// `width`: Default "100%".
  Object? get width => raw.value('width');
}

/// The props of a `LinkCard` node, typed.
///
/// A preview of a URL: favicon and domain, title, description, thumbnail. A
/// click opens it in a new tab, or sends onClick when bound. For sources,
/// articles and products with a page.
extension type const LinkCardProps(ComponentProps raw) {
  /// `href` (required): The URL (http, https).
  String? get href => raw.string('href');

  /// `title` (required): The page title.
  String? get title => raw.string('title');

  /// `onClick`: Sent when the user clicks the card, instead of the link.
  NodeAction? get onClick => raw.action('onClick');

  /// `description`: One or two lines.
  String? get description => raw.string('description');

  /// `image`: A thumbnail URL.
  String? get image => raw.string('image');

  /// `domain`: Shown next to the favicon. Default: the host of href.
  String? get domain => raw.string('domain');

  /// `favicon`: Default true.
  bool get favicon => raw.boolean('favicon') ?? true;
}

/// The props of a `Citation` node, typed.
///
/// An inline source marker (\[1\]) showing title, snippet and link on hover
/// or click. Put it right after the sentence it supports, as a child of a
/// Text or in a Row.
extension type const CitationProps(ComponentProps raw) {
  /// `index`: The marker number. Default 1.
  double get index => raw.number('index') ?? 1.0;

  /// `title`: The source title.
  String? get title => raw.string('title');

  /// `url`: The source URL (http, https).
  String? get url => raw.string('url');

  /// `label`: Marker text instead of the number, for example a domain.
  String? get label => raw.string('label');

  /// `snippet`: The quoted passage, one or two lines.
  String? get snippet => raw.string('snippet');

  /// `source`: The publisher or domain. Default: the host of url.
  String? get source => raw.string('source');
}

/// The props of a `FollowUp` node, typed.
///
/// Suggested next prompts as pills; a click sends the pill's message as the
/// user's next turn, no event needed. At the end of a surface, two to four
/// short items.
extension type const FollowUpProps(ComponentProps raw) {
  /// `items`.
  List<Object?> get items => raw.list('items');

  /// `onFollowUp`: Sent when the user clicks a pill. The args carry the
  /// message of the pill.
  NodeAction? get onFollowUp => raw.action('onFollowUp');

  /// `title`: A caption above the pills.
  String? get title => raw.string('title');
}

/// The props of a `EntityCard` node, typed.
///
/// A card for one product, place, person or listing: image, title,
/// subtitle, description, a price or meta line, badge, rating and up to
/// three buttons. href opens a page; onClick is sent when bound. Use a Grid
/// of them for several things.
extension type const EntityCardProps(ComponentProps raw) {
  /// `title` (required): The name.
  String? get title => raw.string('title');

  /// `actions`: Up to three buttons. A button without href sends onAction
  /// with its label.
  List<Object?> get actions => raw.list('actions');

  /// `onAction`: Sent when the user clicks a button without href. The args
  /// carry the label of the button.
  NodeAction? get onAction => raw.action('onAction');

  /// `onClick`: Sent when the user clicks the card and it has no href.
  NodeAction? get onClick => raw.action('onClick');

  /// `subtitle`: A second line, for example the brand or category.
  String? get subtitle => raw.string('subtitle');

  /// `description`: Up to three lines.
  String? get description => raw.string('description');

  /// `image`: An image URL.
  String? get image => raw.string('image');

  /// `imageAspectRatio`: Default "4 / 3".
  String get imageAspectRatio => raw.string('imageAspectRatio') ?? '4 / 3';

  /// `meta`: A short fact line, for example "$29 / month" or "Open until
  /// 22:00".
  String? get meta => raw.string('meta');

  /// `badge`.
  Map<String, Object?>? get badge => switch (raw.value('badge')) {
    final Map<Object?, Object?> m => m.cast<String, Object?>(),
    _ => null,
  };

  /// `rating`: 0 to 5, shown as stars.
  double? get rating => raw.number('rating');

  /// `ratingCount`: The number of ratings.
  double? get ratingCount => raw.number('ratingCount');

  /// `href`: Opens this URL in a new tab when the user clicks the card.
  String? get href => raw.string('href');

  /// `layout`: Default "vertical". "horizontal" puts the image on the left.
  A2uiOrientation get layout =>
      A2uiOrientation.fromWire(raw.value('layout')) ?? A2uiOrientation.vertical;

  /// `width`.
  Object? get width => raw.value('width');
}

/// The props of a `ImageGrid` node, typed.
///
/// A gallery of images in a grid. A click opens the image full-screen, with
/// arrows to the other images. layout "bento" makes the first image twice
/// as large.
extension type const ImageGridProps(ComponentProps raw) {
  /// `images`.
  List<Object?> get images => raw.list('images');

  /// `columns`: Default 3.
  double get columns => raw.number('columns') ?? 3.0;

  /// `layout`: Default "grid". "bento" makes the first image twice as large.
  ImageGridLayout get layout =>
      ImageGridLayout.fromWire(raw.value('layout')) ?? ImageGridLayout.grid;

  /// `aspectRatio`: Default "1 / 1".
  String get aspectRatio => raw.string('aspectRatio') ?? '1 / 1';

  /// `gap`: Default 2.
  Object? get gap => raw.value('gap');
}

/// The props of a `Section` node, typed.
///
/// Titled group with eyebrow, title, description, and children.
extension type const SectionProps(ComponentProps raw) {
  /// `eyebrow`.
  String? get eyebrow => raw.string('eyebrow');

  /// `title` (required).
  String? get title => raw.string('title');

  /// `description`.
  String? get description => raw.string('description');

  /// `children` (required): the child nodes, in order.
  List<ComponentNode<ComponentImplementation>> get children =>
      raw.children('children');
}

/// The props of a `Accordion` node, typed.
///
/// Collapsible items (FAQs, details, per-file notes); each has a title and
/// either text or a child id.
extension type const AccordionProps(ComponentProps raw) {
  /// `items` (required).
  List<Object?> get items => raw.list('items');

  /// `multiple`.
  bool? get multiple => raw.boolean('multiple');
}

/// The props of a `Heading` node, typed.
///
/// Surface title with optional eyebrow and subtitle. Start most surfaces
/// with one.
extension type const HeadingProps(ComponentProps raw) {
  /// `text` (required).
  String? get text => raw.string('text');

  /// `eyebrow`.
  String? get eyebrow => raw.string('eyebrow');

  /// `subtitle`.
  String? get subtitle => raw.string('subtitle');

  /// `level`.
  HeadingLevel? get level => HeadingLevel.fromWire(raw.value('level'));
}

/// The props of a `CodeBlock` node, typed.
///
/// Syntax-colored code with language label and copy button. Use for any
/// code, config, command or diff snippet.
extension type const CodeBlockProps(ComponentProps raw) {
  /// `code` (required).
  String? get code => raw.string('code');

  /// `language`.
  String? get language => raw.string('language');

  /// `filename`.
  String? get filename => raw.string('filename');
}

/// The props of a `Quote` node, typed.
///
/// Pull quote with attribution: testimonial, review, reviewer comment.
extension type const QuoteProps(ComponentProps raw) {
  /// `text` (required).
  String? get text => raw.string('text');

  /// `author`.
  String? get author => raw.string('author');

  /// `role`.
  String? get role => raw.string('role');
}

/// The props of a `ImageGallery` node, typed.
///
/// Grid of images with captions.
extension type const ImageGalleryProps(ComponentProps raw) {
  /// `images` (required).
  List<Object?> get images => raw.list('images');

  /// `columns`.
  double? get columns => raw.number('columns');
}

/// The props of a `VideoEmbed` node, typed.
///
/// Embedded YouTube/Vimeo video by URL.
extension type const VideoEmbedProps(ComponentProps raw) {
  /// `url` (required).
  String? get url => raw.string('url');

  /// `title`.
  String? get title => raw.string('title');
}

/// The props of a `Kbd` node, typed.
///
/// Keyboard shortcut chips, e.g. keys \['Cmd','K'\] with a label. Use for
/// shortcuts and how-to steps.
extension type const KbdProps(ComponentProps raw) {
  /// `keys` (required).
  List<Object?> get keys => raw.list('keys');

  /// `label`.
  String? get label => raw.string('label');
}

/// The props of a `Stat` node, typed.
///
/// One numeric KPI: label, short value (number or <10 chars like '$84k'),
/// optional delta (e.g. '+4.2%'), caption. Not for sentences.
extension type const StatProps(ComponentProps raw) {
  /// `label` (required).
  String? get label => raw.string('label');

  /// `value` (required).
  String? get value => raw.string('value');

  /// `delta`.
  String? get delta => raw.string('delta');

  /// `trend`.
  A2uiTrend? get trend => A2uiTrend.fromWire(raw.value('trend'));

  /// `caption`.
  String? get caption => raw.string('caption');

  /// `tone`.
  A2uiTone? get tone => A2uiTone.fromWire(raw.value('tone'));

  /// `icon`.
  String? get icon => raw.string('icon');
}

/// The props of a `StatGroup` node, typed.
///
/// Compact strip of several KPIs in one card.
extension type const StatGroupProps(ComponentProps raw) {
  /// `items` (required).
  List<Object?> get items => raw.list('items');
}

/// The props of a `Avatar` node, typed.
///
/// Person avatar (initials if no image) with name and subtitle: authors,
/// owners, reviewers.
extension type const AvatarProps(ComponentProps raw) {
  /// `name` (required).
  String? get name => raw.string('name');

  /// `image`.
  String? get image => raw.string('image');

  /// `subtitle`.
  String? get subtitle => raw.string('subtitle');

  /// `size`.
  A2uiSize? get size => A2uiSize.fromWire(raw.value('size'));

  /// `status`.
  AvatarStatus? get status => AvatarStatus.fromWire(raw.value('status'));
}

/// The props of a `AvatarGroup` node, typed.
///
/// Overlapping avatar stack with +N overflow: attendees, team members,
/// reviewers.
extension type const AvatarGroupProps(ComponentProps raw) {
  /// `people` (required).
  List<Object?> get people => raw.list('people');

  /// `max`.
  double? get max => raw.number('max');

  /// `label`.
  String? get label => raw.string('label');
}

/// The props of a `DataTable` node, typed.
///
/// Sortable, filterable table (TanStack Table). columns
/// \[{key,label,format?}\], rows are objects keyed by column key.
extension type const DataTableProps(ComponentProps raw) {
  /// `title`.
  String? get title => raw.string('title');

  /// `columns` (required).
  List<Object?> get columns => raw.list('columns');

  /// `rows` (required).
  List<Object?> get rows => raw.list('rows');

  /// `searchable`.
  bool? get searchable => raw.boolean('searchable');

  /// `pageSize`.
  double? get pageSize => raw.number('pageSize');
}

/// The props of a `KeyValueList` node, typed.
///
/// Label/value rows, e.g. specs or order details.
extension type const KeyValueListProps(ComponentProps raw) {
  /// `title`.
  String? get title => raw.string('title');

  /// `items` (required).
  List<Object?> get items => raw.list('items');

  /// `columns`.
  double? get columns => raw.number('columns');
}

/// The props of a `Timeline` node, typed.
///
/// Vertical timeline of dated events or steps with status.
extension type const TimelineProps(ComponentProps raw) {
  /// `items` (required).
  List<Object?> get items => raw.list('items');
}

/// The props of a `Progress` node, typed.
///
/// Labelled progress bar, value 0-100: goals, budgets used, completion,
/// coverage.
extension type const ProgressProps(ComponentProps raw) {
  /// `label`.
  String? get label => raw.string('label');

  /// `value` (required).
  double? get value => raw.number('value');

  /// `caption`.
  String? get caption => raw.string('caption');

  /// `tone`.
  A2uiTone? get tone => A2uiTone.fromWire(raw.value('tone'));
}

/// The props of a `RadialProgress` node, typed.
///
/// Ring with centered value, value 0-100: a single score or percent
/// complete.
extension type const RadialProgressProps(ComponentProps raw) {
  /// `label`.
  String? get label => raw.string('label');

  /// `value` (required).
  double? get value => raw.number('value');

  /// `display`.
  String? get display => raw.string('display');

  /// `tone`.
  A2uiTone? get tone => A2uiTone.fromWire(raw.value('tone'));
}

/// The props of a `Rating` node, typed.
///
/// Star rating (0-5) with optional review count: products, places, reviews.
extension type const RatingProps(ComponentProps raw) {
  /// `value` (required).
  double? get value => raw.number('value');

  /// `count`.
  double? get count => raw.number('count');

  /// `label`.
  String? get label => raw.string('label');
}

/// The props of a `TagList` node, typed.
///
/// Wrapping list of tags/chips.
extension type const TagListProps(ComponentProps raw) {
  /// `tags` (required).
  List<Object?> get tags => raw.list('tags');

  /// `tone`.
  A2uiTone? get tone => A2uiTone.fromWire(raw.value('tone'));
}

/// The props of a `Agenda` node, typed.
///
/// Calendar agenda: days with timed events (conference, week plan,
/// schedule). Prefer over Timeline for clock times.
extension type const AgendaProps(ComponentProps raw) {
  /// `title`.
  String? get title => raw.string('title');

  /// `days` (required).
  List<Object?> get days => raw.list('days');
}

/// The props of a `ComparisonTable` node, typed.
///
/// Feature matrix comparing options side by side. options are the option
/// names as strings; rows \[{feature, values}\] with one value per option,
/// in the same order, each true/false/text; highlight is the recommended
/// option's index in options (0 is the first).
extension type const ComparisonTableProps(ComponentProps raw) {
  /// `title`.
  String? get title => raw.string('title');

  /// `options` (required).
  List<Object?> get options => raw.list('options');

  /// `rows` (required).
  List<Object?> get rows => raw.list('rows');

  /// `highlight`.
  double? get highlight => raw.number('highlight');
}

/// The props of a `LineChart` node, typed.
///
/// Trend over ordered x. data \[{x,y,series?}\]; one line per series.
extension type const LineChartProps(ComponentProps raw) {
  /// `title`.
  String? get title => raw.string('title');

  /// `subtitle`.
  String? get subtitle => raw.string('subtitle');

  /// `height`.
  double? get height => raw.number('height');

  /// `format`.
  A2uiValueFormat? get format => A2uiValueFormat.fromWire(raw.value('format'));

  /// `unit`.
  String? get unit => raw.string('unit');

  /// `data` (required).
  List<Object?> get data => raw.list('data');

  /// `curve`.
  bool? get curve => raw.boolean('curve');

  /// `highlight`.
  String? get highlight => raw.string('highlight');
}

/// The props of a `AreaChart` node, typed.
///
/// Filled trend for volumes or cumulative totals (traffic, signups); series
/// stack. data \[{x,y,series?}\].
extension type const AreaChartProps(ComponentProps raw) {
  /// `title`.
  String? get title => raw.string('title');

  /// `subtitle`.
  String? get subtitle => raw.string('subtitle');

  /// `height`.
  double? get height => raw.number('height');

  /// `format`.
  A2uiValueFormat? get format => A2uiValueFormat.fromWire(raw.value('format'));

  /// `unit`.
  String? get unit => raw.string('unit');

  /// `data` (required).
  List<Object?> get data => raw.list('data');

  /// `stacked`.
  bool? get stacked => raw.boolean('stacked');

  /// `highlight`.
  String? get highlight => raw.string('highlight');
}

/// The props of a `BarChart` node, typed.
///
/// Compare categories. data \[{x,y,series?}\]; series grouped side by side,
/// or stacked:true. horizontal for long labels.
extension type const BarChartProps(ComponentProps raw) {
  /// `title`.
  String? get title => raw.string('title');

  /// `subtitle`.
  String? get subtitle => raw.string('subtitle');

  /// `height`.
  double? get height => raw.number('height');

  /// `format`.
  A2uiValueFormat? get format => A2uiValueFormat.fromWire(raw.value('format'));

  /// `unit`.
  String? get unit => raw.string('unit');

  /// `data` (required).
  List<Object?> get data => raw.list('data');

  /// `stacked`.
  bool? get stacked => raw.boolean('stacked');

  /// `horizontal`.
  bool? get horizontal => raw.boolean('horizontal');

  /// `highlight`.
  String? get highlight => raw.string('highlight');
}

/// The props of a `PieChart` node, typed.
///
/// Part-to-whole. data \[{label,value}\]; donut:true for a ring with center
/// total.
extension type const PieChartProps(ComponentProps raw) {
  /// `title`.
  String? get title => raw.string('title');

  /// `subtitle`.
  String? get subtitle => raw.string('subtitle');

  /// `height`.
  double? get height => raw.number('height');

  /// `format`.
  A2uiValueFormat? get format => A2uiValueFormat.fromWire(raw.value('format'));

  /// `unit`.
  String? get unit => raw.string('unit');

  /// `data` (required).
  List<Object?> get data => raw.list('data');

  /// `donut`.
  bool? get donut => raw.boolean('donut');

  /// `centerLabel`.
  String? get centerLabel => raw.string('centerLabel');
}

/// The props of a `ScatterChart` node, typed.
///
/// Relationship between two numbers (price vs rating, effort vs impact).
/// data \[{x,y,label?,size?,series?}\].
extension type const ScatterChartProps(ComponentProps raw) {
  /// `title`.
  String? get title => raw.string('title');

  /// `subtitle`.
  String? get subtitle => raw.string('subtitle');

  /// `height`.
  double? get height => raw.number('height');

  /// `format`.
  A2uiValueFormat? get format => A2uiValueFormat.fromWire(raw.value('format'));

  /// `unit`.
  String? get unit => raw.string('unit');

  /// `data` (required).
  List<Object?> get data => raw.list('data');

  /// `xLabel`.
  String? get xLabel => raw.string('xLabel');

  /// `yLabel`.
  String? get yLabel => raw.string('yLabel');
}

/// The props of a `Heatmap` node, typed.
///
/// Matrix of values, e.g. day x hour. data \[{x,y,value}\] with x,y
/// categories.
extension type const HeatmapProps(ComponentProps raw) {
  /// `title`.
  String? get title => raw.string('title');

  /// `subtitle`.
  String? get subtitle => raw.string('subtitle');

  /// `height`.
  double? get height => raw.number('height');

  /// `format`.
  A2uiValueFormat? get format => A2uiValueFormat.fromWire(raw.value('format'));

  /// `unit`.
  String? get unit => raw.string('unit');

  /// `data` (required).
  List<Object?> get data => raw.list('data');
}

/// The props of a `Sparkline` node, typed.
///
/// Tiny trend with label and latest value; a compact KPI with history, fits
/// in a Grid instead of Stat. values: numbers.
extension type const SparklineProps(ComponentProps raw) {
  /// `label`.
  String? get label => raw.string('label');

  /// `values` (required).
  List<Object?> get values => raw.list('values');

  /// `value`.
  String? get value => raw.string('value');

  /// `delta`.
  String? get delta => raw.string('delta');

  /// `tone`.
  SparklineTone? get tone => SparklineTone.fromWire(raw.value('tone'));
}

/// The props of a `RadarChart` node, typed.
///
/// Multi-axis profile (scores per criterion for 2-3 options or people).
/// data \[{axis,value,series?}\], values on a shared scale.
extension type const RadarChartProps(ComponentProps raw) {
  /// `title`.
  String? get title => raw.string('title');

  /// `subtitle`.
  String? get subtitle => raw.string('subtitle');

  /// `height`.
  double? get height => raw.number('height');

  /// `format`.
  A2uiValueFormat? get format => A2uiValueFormat.fromWire(raw.value('format'));

  /// `unit`.
  String? get unit => raw.string('unit');

  /// `data` (required).
  List<Object?> get data => raw.list('data');

  /// `max`.
  double? get max => raw.number('max');
}

/// The props of a `CandlestickChart` node, typed.
///
/// OHLC price candles. data \[{date,open,high,low,close}\].
extension type const CandlestickChartProps(ComponentProps raw) {
  /// `title`.
  String? get title => raw.string('title');

  /// `subtitle`.
  String? get subtitle => raw.string('subtitle');

  /// `height`.
  double? get height => raw.number('height');

  /// `format`.
  A2uiValueFormat? get format => A2uiValueFormat.fromWire(raw.value('format'));

  /// `unit`.
  String? get unit => raw.string('unit');

  /// `data` (required).
  List<Object?> get data => raw.list('data');
}

/// The props of a `Treemap` node, typed.
///
/// Nested part-to-whole as rectangles. data \[{name,value,group?}\].
extension type const TreemapProps(ComponentProps raw) {
  /// `title`.
  String? get title => raw.string('title');

  /// `subtitle`.
  String? get subtitle => raw.string('subtitle');

  /// `height`.
  double? get height => raw.number('height');

  /// `format`.
  A2uiValueFormat? get format => A2uiValueFormat.fromWire(raw.value('format'));

  /// `unit`.
  String? get unit => raw.string('unit');

  /// `data` (required).
  List<Object?> get data => raw.list('data');
}

/// The props of a `SankeyChart` node, typed.
///
/// Flows between stages, e.g. budget or funnel paths. links
/// \[{source,target,value}\].
extension type const SankeyChartProps(ComponentProps raw) {
  /// `title`.
  String? get title => raw.string('title');

  /// `subtitle`.
  String? get subtitle => raw.string('subtitle');

  /// `height`.
  double? get height => raw.number('height');

  /// `format`.
  A2uiValueFormat? get format => A2uiValueFormat.fromWire(raw.value('format'));

  /// `unit`.
  String? get unit => raw.string('unit');

  /// `links` (required).
  List<Object?> get links => raw.list('links');
}

/// The props of a `Gauge` node, typed.
///
/// Half-ring gauge for a single value within min..max (score, utilization).
extension type const GaugeProps(ComponentProps raw) {
  /// `title`.
  String? get title => raw.string('title');

  /// `value` (required).
  double? get value => raw.number('value');

  /// `min`.
  double? get min => raw.number('min');

  /// `max`.
  double? get max => raw.number('max');

  /// `label`.
  String? get label => raw.string('label');

  /// `format`.
  A2uiValueFormat? get format => A2uiValueFormat.fromWire(raw.value('format'));
}

/// The props of a `MapView` node, typed.
///
/// Interactive map (MapLibre) with numbered markers; fits all markers.
/// markers \[{name,lat,lon,description?}\].
extension type const MapViewProps(ComponentProps raw) {
  /// `title`.
  String? get title => raw.string('title');

  /// `markers` (required).
  List<Object?> get markers => raw.list('markers');

  /// `height`.
  double? get height => raw.number('height');

  /// `zoom`.
  double? get zoom => raw.number('zoom');
}

/// The props of a `RouteMap` node, typed.
///
/// Map with a route line through coordinates \[\[lon,lat\],...\] plus
/// start/end pins and distance/duration.
extension type const RouteMapProps(ComponentProps raw) {
  /// `title`.
  String? get title => raw.string('title');

  /// `from` (required).
  String? get from => raw.string('from');

  /// `to` (required).
  String? get to => raw.string('to');

  /// `coordinates` (required).
  List<Object?> get coordinates => raw.list('coordinates');

  /// `distance`.
  String? get distance => raw.string('distance');

  /// `duration`.
  String? get duration => raw.string('duration');

  /// `height`.
  double? get height => raw.number('height');
}

/// The props of a `LocationCard` node, typed.
///
/// Single place (venue, hotel, office): mini map, name, address, category,
/// rating, actions. Use instead of MapView for one place.
extension type const LocationCardProps(ComponentProps raw) {
  /// `name` (required).
  String? get name => raw.string('name');

  /// `address`.
  String? get address => raw.string('address');

  /// `lat` (required).
  double? get lat => raw.number('lat');

  /// `lon` (required).
  double? get lon => raw.number('lon');

  /// `category`.
  String? get category => raw.string('category');

  /// `rating`.
  double? get rating => raw.number('rating');

  /// `hours`.
  String? get hours => raw.string('hours');
}

/// The props of a `PlaceList` node, typed.
///
/// Split view: ranked list of places linked to a map; hovering/clicking a
/// row highlights its marker. selected (row index) starts with that row
/// highlighted.
extension type const PlaceListProps(ComponentProps raw) {
  /// `title`.
  String? get title => raw.string('title');

  /// `places` (required).
  List<Object?> get places => raw.list('places');

  /// `source`.
  String? get source => raw.string('source');

  /// `selected`.
  double? get selected => raw.number('selected');

  /// `height`.
  double? get height => raw.number('height');

  /// `basemap`.
  PlaceListBasemap? get basemap =>
      PlaceListBasemap.fromWire(raw.value('basemap'));
}

/// The props of a `Combobox` node, typed.
///
/// Searchable dropdown for long option lists (countries, cities,
/// timezones).
extension type const ComboboxProps(ComponentProps raw) {
  /// `label`.
  String? get label => raw.string('label');

  /// `value`.
  String? get value => raw.string('value');

  /// `options` (required).
  List<Object?> get options => raw.list('options');

  /// `placeholder`.
  String? get placeholder => raw.string('placeholder');
}

/// The props of a `Switch` node, typed.
///
/// On/off toggle with label and description.
extension type const SwitchProps(ComponentProps raw) {
  /// `label` (required).
  String? get label => raw.string('label');

  /// `value`.
  bool? get value => raw.boolean('value');

  /// `description`.
  String? get description => raw.string('description');
}

/// The props of a `DatePicker` node, typed.
///
/// Date picker with calendar popover; value ISO date bound to a path.
extension type const DatePickerProps(ComponentProps raw) {
  /// `label`.
  String? get label => raw.string('label');

  /// `value`.
  String? get value => raw.string('value');

  /// `placeholder`.
  String? get placeholder => raw.string('placeholder');
}

/// The props of a `ButtonGroup` node, typed.
///
/// Segmented single-choice control; value bound to a path.
extension type const ButtonGroupProps(ComponentProps raw) {
  /// `label`.
  String? get label => raw.string('label');

  /// `value`.
  String? get value => raw.string('value');

  /// `options` (required).
  List<Object?> get options => raw.list('options');
}

/// The props of a `ChipSelect` node, typed.
///
/// Multi-select chips bound to a string-list path: extras, interests,
/// dietary needs.
extension type const ChipSelectProps(ComponentProps raw) {
  /// `label`.
  String? get label => raw.string('label');

  /// `value`.
  List<Object?> get value => raw.list('value');

  /// `options` (required).
  List<Object?> get options => raw.list('options');
}

/// The props of a `Alert` node, typed.
///
/// Inline alert with icon, title and message.
extension type const AlertProps(ComponentProps raw) {
  /// `title` (required).
  String? get title => raw.string('title');

  /// `message`.
  String? get message => raw.string('message');

  /// `tone`.
  AlertTone? get tone => AlertTone.fromWire(raw.value('tone'));
}

/// The props of a `Callout` node, typed.
///
/// Highlighted tip or note with optional emoji/icon and a call to action.
extension type const CalloutProps(ComponentProps raw) {
  /// `title`.
  String? get title => raw.string('title');

  /// `text` (required).
  String? get text => raw.string('text');

  /// `icon`.
  String? get icon => raw.string('icon');

  /// `actionLabel`.
  String? get actionLabel => raw.string('actionLabel');

  /// `onAction`: Fires when the call-to-action button is clicked.
  NodeAction? get onAction => raw.action('onAction');
}

/// The props of a `Skeleton` node, typed.
///
/// Loading placeholder lines/blocks.
extension type const SkeletonProps(ComponentProps raw) {
  /// `lines`.
  double? get lines => raw.number('lines');

  /// `variant`.
  SkeletonVariant? get variant =>
      SkeletonVariant.fromWire(raw.value('variant'));
}

/// The props of a `EmptyState` node, typed.
///
/// Empty or zero-results state with icon, title, hint and optional action:
/// no matches, nothing scheduled, inbox zero.
extension type const EmptyStateProps(ComponentProps raw) {
  /// `title` (required).
  String? get title => raw.string('title');

  /// `description`.
  String? get description => raw.string('description');

  /// `icon`.
  String? get icon => raw.string('icon');

  /// `actionLabel`.
  String? get actionLabel => raw.string('actionLabel');

  /// `onAction`: Fires when the action button is clicked.
  NodeAction? get onAction => raw.action('onAction');
}

/// The props of a `WeatherCard` node, typed.
///
/// Current weather hero with condition icon, temp, high/low, details, an
/// hourly strip and daily forecast. icon:
/// sun|cloud-sun|cloud|fog|drizzle|rain|snow|storm.
extension type const WeatherCardProps(ComponentProps raw) {
  /// `location` (required).
  String? get location => raw.string('location');

  /// `temp` (required).
  double? get temp => raw.number('temp');

  /// `condition` (required).
  String? get condition => raw.string('condition');

  /// `icon`.
  String? get icon => raw.string('icon');

  /// `high`.
  double? get high => raw.number('high');

  /// `low`.
  double? get low => raw.number('low');

  /// `feels`.
  double? get feels => raw.number('feels');

  /// `humidity`.
  double? get humidity => raw.number('humidity');

  /// `wind`.
  double? get wind => raw.number('wind');

  /// `unit`.
  WeatherCardUnit? get unit => WeatherCardUnit.fromWire(raw.value('unit'));

  /// `hourly`.
  List<Object?> get hourly => raw.list('hourly');

  /// `daily`.
  List<Object?> get daily => raw.list('daily');
}

/// The props of a `ProfileCard` node, typed.
///
/// Person card: avatar, name, role, company, location, bio, contacts, tags,
/// stats. Use for team members, speakers, candidates.
extension type const ProfileCardProps(ComponentProps raw) {
  /// `name` (required).
  String? get name => raw.string('name');

  /// `role`.
  String? get role => raw.string('role');

  /// `company`.
  String? get company => raw.string('company');

  /// `avatar`.
  String? get avatar => raw.string('avatar');

  /// `location`.
  String? get location => raw.string('location');

  /// `bio`.
  String? get bio => raw.string('bio');

  /// `email`.
  String? get email => raw.string('email');

  /// `phone`.
  String? get phone => raw.string('phone');

  /// `website`.
  String? get website => raw.string('website');

  /// `tags`.
  List<Object?> get tags => raw.list('tags');

  /// `stats`.
  List<Object?> get stats => raw.list('stats');
}

/// The props of a `ReceiptCard` node, typed.
///
/// Order receipt: merchant, order id, date, line items with qty and price,
/// subtotal/tax/total, status.
extension type const ReceiptCardProps(ComponentProps raw) {
  /// `merchant` (required).
  String? get merchant => raw.string('merchant');

  /// `orderId`.
  String? get orderId => raw.string('orderId');

  /// `date`.
  String? get date => raw.string('date');

  /// `status`.
  String? get status => raw.string('status');

  /// `items` (required).
  List<Object?> get items => raw.list('items');

  /// `currency`.
  String? get currency => raw.string('currency');

  /// `tax`.
  double? get tax => raw.number('tax');

  /// `shipping`.
  double? get shipping => raw.number('shipping');

  /// `discount`.
  double? get discount => raw.number('discount');

  /// `payment`.
  String? get payment => raw.string('payment');
}

/// The props of a `EventCard` node, typed.
///
/// Event: date block, title, time, venue, host, attendees count, tags, RSVP
/// action. Lead an event or conference with it.
extension type const EventCardProps(ComponentProps raw) {
  /// `title` (required).
  String? get title => raw.string('title');

  /// `date` (required).
  String? get date => raw.string('date');

  /// `time`.
  String? get time => raw.string('time');

  /// `venue`.
  String? get venue => raw.string('venue');

  /// `host`.
  String? get host => raw.string('host');

  /// `description`.
  String? get description => raw.string('description');

  /// `attendees`.
  double? get attendees => raw.number('attendees');

  /// `image`.
  String? get image => raw.string('image');

  /// `tags`.
  List<Object?> get tags => raw.list('tags');

  /// `actionLabel`.
  String? get actionLabel => raw.string('actionLabel');

  /// `onAction`: Fires when the RSVP button is clicked.
  NodeAction? get onAction => raw.action('onAction');
}

/// The props of a `StockTicker` node, typed.
///
/// Stock quote header: symbol, name, price, change and % change, sparkline,
/// key stats. sample:true labels illustrative data.
extension type const StockTickerProps(ComponentProps raw) {
  /// `symbol` (required).
  String? get symbol => raw.string('symbol');

  /// `name`.
  String? get name => raw.string('name');

  /// `price` (required).
  double? get price => raw.number('price');

  /// `change`.
  double? get change => raw.number('change');

  /// `changePct`.
  double? get changePct => raw.number('changePct');

  /// `currency`.
  String? get currency => raw.string('currency');

  /// `series`.
  List<Object?> get series => raw.list('series');

  /// `stats`.
  List<Object?> get stats => raw.list('stats');

  /// `sample`.
  bool? get sample => raw.boolean('sample');
}

/// The props of a `RecipeCard` node, typed.
///
/// Recipe: title, time/servings/difficulty, ingredient checklist and
/// numbered steps. Use for any recipe or cooking how-to.
extension type const RecipeCardProps(ComponentProps raw) {
  /// `title` (required).
  String? get title => raw.string('title');

  /// `image`.
  String? get image => raw.string('image');

  /// `time`.
  String? get time => raw.string('time');

  /// `servings`.
  double? get servings => raw.number('servings');

  /// `difficulty`.
  String? get difficulty => raw.string('difficulty');

  /// `ingredients` (required).
  List<Object?> get ingredients => raw.list('ingredients');

  /// `steps` (required).
  List<Object?> get steps => raw.list('steps');

  /// `tags`.
  List<Object?> get tags => raw.list('tags');
}
