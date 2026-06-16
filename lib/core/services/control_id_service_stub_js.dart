// Stub for dart:js on non-web platforms
class JsObject {
  dynamic operator [](Object key) => null;
  void operator []=(Object key, dynamic value) {}
  dynamic callMethod(Object method, [List? args]) => null;
  static dynamic jsify(Object object) => null;
}

dynamic get context => _Context();

class _Context {
  dynamic callMethod(Object method, [List? args]) => null;
}

// Stub function for allowInterop (top-level in dart:js)
dynamic allowInterop(Function f) => f;

