// The "shape" of the data our app works with.

class TermDef {
  final String term;
  final String definition;
  const TermDef({required this.term, required this.definition});

  factory TermDef.fromJson(Map<String, dynamic> json) => TermDef(
        term: (json['term'] ?? '').toString(),
        definition: (json['definition'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {'term': term, 'definition': definition};
}

class EquationItem {
  final String formula;
  final String meaning;
  const EquationItem({required this.formula, required this.meaning});

  factory EquationItem.fromJson(Map<String, dynamic> json) => EquationItem(
        formula: (json['formula'] ?? '').toString(),
        meaning: (json['meaning'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {'formula': formula, 'meaning': meaning};
}

class QuizQuestion {
  final String question;
  final List<String> options;
  final int answerIndex;
  final String explanation;

  const QuizQuestion({
    required this.question,
    required this.options,
    required this.answerIndex,
    required this.explanation,
  });

  bool get isValid =>
      question.isNotEmpty &&
      options.length >= 2 &&
      answerIndex >= 0 &&
      answerIndex < options.length;

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    final opts = (json['options'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList();
    final rawIndex = json['answerIndex'];
    final idx = rawIndex is int ? rawIndex : int.tryParse('$rawIndex') ?? 0;
    return QuizQuestion(
      question: (json['question'] ?? '').toString(),
      options: opts,
      answerIndex: idx,
      explanation: (json['explanation'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'question': question,
        'options': options,
        'answerIndex': answerIndex,
        'explanation': explanation,
      };
}

class ChartData {
  final String type; // 'bar', 'pie', or 'line'
  final String title;
  final List<String> labels;
  final List<double> values;

  const ChartData({
    required this.type,
    required this.title,
    required this.labels,
    required this.values,
  });

  // Only show a chart if the data is sensible.
  bool get isValid =>
      labels.length == values.length && values.length >= 2 && values.length <= 12;

  factory ChartData.fromJson(Map<String, dynamic> json) {
    final labels = (json['labels'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList();
    final values = (json['values'] as List<dynamic>? ?? const []).map((e) {
      if (e is num) return e.toDouble();
      return double.tryParse('$e') ?? 0.0;
    }).toList();
    return ChartData(
      type: (json['type'] ?? 'bar').toString().toLowerCase(),
      title: (json['title'] ?? '').toString(),
      labels: labels,
      values: values,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'title': title,
        'labels': labels,
        'values': values,
      };
}

// A small helper: return the first field whose value is a JSON list.
List<dynamic> _firstList(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final v = json[key];
    if (v is List) return v;
  }
  return const [];
}

// One box/item in a diagram. It can hold child items (for trees, and for the
// columns of a comparison), so this same little shape covers every diagram kind.
class DiagramNode {
  final String label;
  final String detail;
  final List<DiagramNode> children;

  const DiagramNode({
    required this.label,
    this.detail = '',
    this.children = const [],
  });

  bool get hasLabel => label.trim().isNotEmpty;

  factory DiagramNode.fromJson(Map<String, dynamic> json) => DiagramNode(
        label:
            (json['label'] ?? json['text'] ?? json['title'] ?? '').toString(),
        detail: (json['detail'] ?? json['description'] ?? '').toString(),
        children: _firstList(json, ['children', 'items', 'nodes'])
            .whereType<Map<String, dynamic>>()
            .map(DiagramNode.fromJson)
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'label': label,
        if (detail.isNotEmpty) 'detail': detail,
        if (children.isNotEmpty)
          'children': children.map((c) => c.toJson()).toList(),
      };
}

// A picture of an IDEA (not numbers): a process ("flow"/"cycle"), a tree
// ("hierarchy"), or a side-by-side "comparison". This is what gives concept
// lessons - like database normalization or an algorithm's steps - a visual.
class DiagramData {
  final String type; // 'flow', 'cycle', 'hierarchy', or 'comparison'
  final String title;
  final List<DiagramNode> nodes;

  const DiagramData({
    required this.type,
    required this.title,
    required this.nodes,
  });

  // Only show a diagram if there are at least two real boxes to draw, and it is
  // not absurdly large. Counts nodes at EVERY depth, because the model often
  // nests a flow's steps inside one another instead of listing them flat.
  bool get isValid {
    var total = 0;
    var labeled = 0;
    void walk(List<DiagramNode> list) {
      for (final n in list) {
        total++;
        if (n.hasLabel) labeled++;
        walk(n.children);
      }
    }

    walk(nodes);
    return labeled >= 2 && total <= 30;
  }

  factory DiagramData.fromJson(Map<String, dynamic> json) {
    final nodes = _firstList(json, ['nodes', 'steps', 'items'])
        .whereType<Map<String, dynamic>>()
        .map(DiagramNode.fromJson)
        .toList();
    var type = (json['type'] ?? 'flow').toString().toLowerCase().trim();
    const known = {'flow', 'cycle', 'hierarchy', 'comparison'};
    if (!known.contains(type)) {
      // Map common synonyms the model might use onto our four kinds.
      if (type.contains('compar')) {
        type = 'comparison';
      } else if (type.contains('tree') || type.contains('hier')) {
        type = 'hierarchy';
      } else if (type.contains('loop') || type.contains('cycle')) {
        type = 'cycle';
      } else {
        type = 'flow';
      }
    }
    return DiagramData(
      type: type,
      title: (json['title'] ?? '').toString(),
      nodes: nodes,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'title': title,
        'nodes': nodes.map((n) => n.toJson()).toList(),
      };
}

class Topic {
  final String title;
  final String summary;
  final String explanation;
  final List<TermDef> terms;
  final List<EquationItem> equations;
  final QuizQuestion? question;
  final String youtubeQuery;
  final ChartData? chart;
  final DiagramData? diagram;

  const Topic({
    required this.title,
    required this.summary,
    required this.explanation,
    this.terms = const [],
    this.equations = const [],
    this.question,
    this.youtubeQuery = '',
    this.chart,
    this.diagram,
  });

  factory Topic.fromJson(Map<String, dynamic> json) {
    QuizQuestion? q;
    final rawQ = json['question'];
    if (rawQ is Map<String, dynamic>) {
      final parsed = QuizQuestion.fromJson(rawQ);
      if (parsed.isValid) q = parsed;
    }
    ChartData? c;
    final rawChart = json['chart'];
    if (rawChart is Map<String, dynamic>) {
      final parsed = ChartData.fromJson(rawChart);
      if (parsed.isValid) c = parsed;
    }
    DiagramData? d;
    final rawDiagram = json['diagram'];
    if (rawDiagram is Map<String, dynamic>) {
      final parsed = DiagramData.fromJson(rawDiagram);
      if (parsed.isValid) d = parsed;
    }
    return Topic(
      title: (json['title'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      explanation: (json['explanation'] ?? json['lesson'] ?? '').toString(),
      terms: (json['terms'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(TermDef.fromJson)
          .toList(),
      equations: (json['equations'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(EquationItem.fromJson)
          .toList(),
      question: q,
      youtubeQuery: (json['youtubeQuery'] ?? json['title'] ?? '').toString(),
      chart: c,
      diagram: d,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'summary': summary,
        'explanation': explanation,
        'terms': terms.map((t) => t.toJson()).toList(),
        'equations': equations.map((e) => e.toJson()).toList(),
        'question': question?.toJson(),
        'youtubeQuery': youtubeQuery,
        'chart': chart?.toJson(),
        'diagram': diagram?.toJson(),
      };
}

class LessonSet {
  final String sourceName;
  final List<Topic> topics;

  const LessonSet({
    required this.sourceName,
    required this.topics,
  });

  factory LessonSet.fromJson(Map<String, dynamic> json) {
    final rawTopics = json['topics'] as List<dynamic>? ?? const [];
    return LessonSet(
      sourceName: (json['sourceName'] ?? 'Your lesson').toString(),
      topics: rawTopics
          .whereType<Map<String, dynamic>>()
          .map(Topic.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'sourceName': sourceName,
        'topics': topics.map((t) => t.toJson()).toList(),
      };
}
