import 'dart:html' as html;

class CredentialStorage {
  Future<String?> read(String key) async {
    return html.window.localStorage[key];
  }

  Future<void> write(String key, String value) async {
    html.window.localStorage[key] = value;
  }

  Future<void> delete(String key) async {
    html.window.localStorage.remove(key);
  }
}
