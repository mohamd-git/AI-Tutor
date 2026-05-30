import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../i18n.dart';
import '../models/lesson.dart';
import 'chat_screen.dart';
import 'settings_screen.dart';

class LessonScreen extends StatelessWidget {
  final LessonSet lessonSet;
  const LessonScreen({super.key, required this.lessonSet});

  @override
  Widget build(BuildContext context) {
    final t = stringsFor(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(lessonSet.sourceName),
        actions: [
          IconButton(
            tooltip: t.settingsTooltip,
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ChatScreen(lessonSet: lessonSet)),
        ),
        icon: const Icon(Icons.chat_bubble_outline),
        label: Text(t.askTutor),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: lessonSet.topics.length,
            itemBuilder: (context, index) =>
                _TopicCard(topic: lessonSet.topics[index], number: index + 1),
          ),
        ),
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  final Topic topic;
  final int number;
  const _TopicCard({required this.topic, required this.number});

  Future<void> _openYouTube() async {
    final uri = Uri.parse(
      'https://www.youtube.com/results?search_query=${Uri.encodeQueryComponent(topic.youtubeQuery)}',
    );
    await launchUrl(uri, mode: LaunchMode.platformDefault);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = stringsFor(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: theme.colorScheme.primary,
                  child: Text(
                    '$number',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    topic.title,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (topic.summary.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                topic.summary,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (topic.explanation.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                topic.explanation,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
              ),
            ],
            if (topic.chart != null) ...[
              const SizedBox(height: 16),
              _ChartView(chart: topic.chart!),
            ],
            if (topic.diagram != null) ...[
              const SizedBox(height: 16),
              _DiagramView(diagram: topic.diagram!),
            ],
            if (topic.terms.isNotEmpty) ...[
              const SizedBox(height: 18),
              _SectionLabel(t.keyWords, theme.colorScheme.primary),
              const SizedBox(height: 8),
              ...topic.terms.map((term) => _TermRow(term: term)),
            ],
            if (topic.equations.isNotEmpty) ...[
              const SizedBox(height: 18),
              _SectionLabel(t.formulas, theme.colorScheme.tertiary),
              const SizedBox(height: 8),
              ...topic.equations.map((e) => _EquationBox(eq: e)),
            ],
            if (topic.question != null) ...[
              const SizedBox(height: 18),
              _SectionLabel(t.quickCheck, theme.colorScheme.secondary),
              const SizedBox(height: 8),
              _QuizView(quiz: topic.question!),
            ],
            if (topic.youtubeQuery.isNotEmpty) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _openYouTube,
                icon: const Icon(Icons.play_circle_outline),
                label: Text(t.watchYoutube),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _SectionLabel(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.bold,
        fontSize: 13,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _TermRow extends StatelessWidget {
  final TermDef term;
  const _TermRow({required this.term});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: term.term,
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextSpan(
              text: '  —  ${term.definition}',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _EquationBox extends StatelessWidget {
  final EquationItem eq;
  const _EquationBox({required this.eq});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            eq.formula,
            style: TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onTertiaryContainer,
            ),
          ),
          if (eq.meaning.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              eq.meaning,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

const List<Color> _chartPalette = [
  Color(0xFF4F46E5),
  Color(0xFF06B6D4),
  Color(0xFFF59E0B),
  Color(0xFF10B981),
  Color(0xFFEF4444),
  Color(0xFF8B5CF6),
  Color(0xFFEC4899),
  Color(0xFF14B8A6),
];

class _ChartView extends StatelessWidget {
  final ChartData chart;
  const _ChartView({required this.chart});

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  double get _maxValue {
    var m = 0.0;
    for (final v in chart.values) {
      if (v > m) m = v;
    }
    return m <= 0 ? 1 : m * 1.2;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget body;
    switch (chart.type) {
      case 'pie':
        body = _pie();
        break;
      case 'line':
        body = _line();
        break;
      default:
        body = _bar();
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (chart.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                chart.title,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          SizedBox(height: 190, child: body),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: List.generate(chart.labels.length, (i) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _chartPalette[i % _chartPalette.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${chart.labels[i]} (${_fmt(chart.values[i])})',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _bar() {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: _maxValue,
        barGroups: List.generate(chart.values.length, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: chart.values[i],
                color: _chartPalette[i % _chartPalette.length],
                width: 16,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }),
        titlesData: _titles(),
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  Widget _line() {
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: _maxValue,
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(
              chart.values.length,
              (i) => FlSpot(i.toDouble(), chart.values[i]),
            ),
            isCurved: true,
            color: _chartPalette[0],
            barWidth: 3,
            dotData: FlDotData(show: true),
          ),
        ],
        titlesData: _titles(),
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  Widget _pie() {
    final total = chart.values.fold<double>(0, (a, b) => a + b);
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 28,
        sections: List.generate(chart.values.length, (i) {
          final pct = total > 0 ? chart.values[i] / total * 100 : 0.0;
          return PieChartSectionData(
            value: chart.values[i],
            color: _chartPalette[i % _chartPalette.length],
            title: '${pct.toStringAsFixed(0)}%',
            radius: 64,
            titleStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        }),
      ),
    );
  }

  FlTitlesData _titles() {
    return FlTitlesData(
      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 28,
          getTitlesWidget: (value, meta) {
            final i = value.toInt();
            if (i < 0 || i >= chart.labels.length) {
              return const SizedBox.shrink();
            }
            final label = chart.labels[i];
            final short =
                label.length > 7 ? '${label.substring(0, 7)}…' : label;
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(short, style: const TextStyle(fontSize: 10)),
            );
          },
        ),
      ),
    );
  }
}

// Draws a picture of an IDEA (no numbers): a process (flow/cycle), a tree
// (hierarchy), or a side-by-side comparison. Built from plain widgets so there
// is no fragile graph-layout engine to break.
class _DiagramView extends StatelessWidget {
  final DiagramData diagram;
  const _DiagramView({required this.diagram});

  IconData get _icon {
    switch (diagram.type) {
      case 'comparison':
        return Icons.compare_arrows;
      case 'hierarchy':
        return Icons.account_tree;
      case 'cycle':
        return Icons.autorenew;
      default:
        return Icons.timeline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget body;
    switch (diagram.type) {
      case 'comparison':
        body = _comparison(theme);
        break;
      case 'hierarchy':
        body = _hierarchy(theme);
        break;
      default:
        // 'flow' and 'cycle' both render as a vertical sequence of steps.
        body = _flow(theme);
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (diagram.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(_icon, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      diagram.title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          body,
        ],
      ),
    );
  }

  // One labelled box, with an optional smaller detail line under the label.
  Widget _box(ThemeData theme, DiagramNode node, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            node.label,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (node.detail.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              node.detail,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // A top-to-bottom chain of steps, joined by down-arrows. A 'cycle' adds a
  // loop-back hint to the first step at the end. The steps are flattened
  // depth-first, because the model sometimes lists them flat and sometimes
  // nests each step inside the previous one's children - both should read as
  // one ordered sequence.
  Widget _flow(ThemeData theme) {
    final steps = <DiagramNode>[];
    void collect(DiagramNode n) {
      if (n.hasLabel) steps.add(n);
      for (final c in n.children) {
        collect(c);
      }
    }

    for (final n in diagram.nodes) {
      collect(n);
    }
    final children = <Widget>[];
    for (var i = 0; i < steps.length; i++) {
      final color = _chartPalette[i % _chartPalette.length];
      children.add(_box(theme, steps[i], color));
      if (i < steps.length - 1) {
        children.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Icon(Icons.arrow_downward,
              size: 20, color: theme.colorScheme.onSurfaceVariant),
        ));
      }
    }
    if (diagram.type == 'cycle' && steps.length >= 2) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.autorenew, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                steps.first.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.primary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ));
    }
    return Column(children: children);
  }

  // Side-by-side cards. Each top-level node is a column; its children are the
  // bullet points under that column's heading.
  Widget _comparison(ThemeData theme) {
    final nodes = diagram.nodes.where((n) => n.hasLabel).toList();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(nodes.length, (i) {
        final node = nodes[i];
        final color = _chartPalette[i % _chartPalette.length];
        return Expanded(
          child: Padding(
            padding:
                EdgeInsetsDirectional.only(end: i < nodes.length - 1 ? 8 : 0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    node.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  if (node.detail.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(node.detail, style: theme.textTheme.bodySmall),
                  ],
                  ...node.children.where((c) => c.hasLabel).map(
                        (c) => Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Icon(Icons.circle,
                                    size: 6,
                                    color: theme.colorScheme.onSurfaceVariant),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  c.detail.isNotEmpty
                                      ? '${c.label}: ${c.detail}'
                                      : c.label,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  // An indented tree. Each level steps further from the start edge (which is
  // the left in English and the right in Arabic).
  Widget _hierarchy(ThemeData theme) {
    final rows = <Widget>[];
    void addNode(DiagramNode node, int depth) {
      if (!node.hasLabel) return;
      final color = _chartPalette[depth % _chartPalette.length];
      rows.add(Padding(
        padding: EdgeInsetsDirectional.only(start: depth * 18.0, bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              depth == 0 ? Icons.lan : Icons.subdirectory_arrow_right,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    node.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          depth == 0 ? FontWeight.bold : FontWeight.w600,
                    ),
                  ),
                  if (node.detail.isNotEmpty)
                    Text(
                      node.detail,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ));
      for (final child in node.children) {
        addNode(child, depth + 1);
      }
    }

    for (final node in diagram.nodes) {
      addNode(node, 0);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }
}

class _QuizView extends StatefulWidget {
  final QuizQuestion quiz;
  const _QuizView({required this.quiz});

  @override
  State<_QuizView> createState() => _QuizViewState();
}

class _QuizViewState extends State<_QuizView> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = stringsFor(context);
    final quiz = widget.quiz;
    final answered = _selected != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          quiz.question,
          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        ...List.generate(quiz.options.length, (i) {
          final isCorrect = i == quiz.answerIndex;
          final isPicked = _selected == i;
          var bg = theme.colorScheme.surfaceContainerHighest;
          var border = Colors.transparent;
          IconData? icon;
          var iconColor = theme.colorScheme.onSurfaceVariant;
          if (answered) {
            if (isCorrect) {
              bg = Colors.green.withValues(alpha: 0.15);
              border = Colors.green;
              icon = Icons.check_circle;
              iconColor = Colors.green;
            } else if (isPicked) {
              bg = Colors.red.withValues(alpha: 0.12);
              border = Colors.red;
              icon = Icons.cancel;
              iconColor = Colors.red;
            }
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: answered ? null : () => setState(() => _selected = i),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: border, width: 1.5),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(quiz.options[i])),
                    if (icon != null) Icon(icon, color: iconColor, size: 20),
                  ],
                ),
              ),
            ),
          );
        }),
        if (answered) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _selected == quiz.answerIndex
                      ? Icons.emoji_events
                      : Icons.lightbulb_outline,
                  color: theme.colorScheme.secondary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selected == quiz.answerIndex
                        ? '${t.correctPrefix}${quiz.explanation}'
                        : '${t.notQuitePrefix}${quiz.explanation}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _selected = null),
            child: Text(t.tryAgain),
          ),
        ],
      ],
    );
  }
}
