// Stub for dart:html on non-web platforms
class Element {
  void append(Element element) {}
}

class ScriptElement extends Element {
  String? id;
  String? type;
  String? innerHtml;
}

class Document {
  Element? querySelector(String selectors) => null;
  Element? get head => null;
}

final document = Document();
