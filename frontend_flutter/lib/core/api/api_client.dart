import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  final String baseUrl;

  ApiClient({this.baseUrl = 'http://localhost:8000'});

  Future<Map<String, dynamic>> getJson(String path) async {
    final response = await http.get(Uri.parse('$baseUrl$path'));
    if (response.statusCode >= 400) {
      throw Exception('GET $path failed: ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode >= 400) {
      throw Exception('POST $path failed: ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
