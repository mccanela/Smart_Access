class Document {
  final String id;
  final String name;
  final String path;
  final String? extractedText;
  final DateTime? lastProcessed;
  final bool hasTextLayer;
  final int pageCount;

  Document({
    required this.id,
    required this.name,
    required this.path,
    this.extractedText,
    this.lastProcessed,
    this.hasTextLayer = false,
    this.pageCount = 0,
  });

  Document copyWith({
    String? id,
    String? name,
    String? path,
    String? extractedText,
    DateTime? lastProcessed,
    bool? hasTextLayer,
    int? pageCount,
  }) {
    return Document(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      extractedText: extractedText ?? this.extractedText,
      lastProcessed: lastProcessed ?? this.lastProcessed,
      hasTextLayer: hasTextLayer ?? this.hasTextLayer,
      pageCount: pageCount ?? this.pageCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'extractedText': extractedText,
      'lastProcessed': lastProcessed?.toIso8601String(),
      'hasTextLayer': hasTextLayer,
      'pageCount': pageCount,
    };
  }

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      id: json['id'],
      name: json['name'],
      path: json['path'],
      extractedText: json['extractedText'],
      lastProcessed: json['lastProcessed'] != null
          ? DateTime.parse(json['lastProcessed'])
          : null,
      hasTextLayer: json['hasTextLayer'] ?? false,
      pageCount: json['pageCount'] ?? 0,
    );
  }
}
