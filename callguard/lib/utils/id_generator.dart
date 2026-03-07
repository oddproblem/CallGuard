import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

String generateCallGuardId() {
  final rand = Random();
  return (100000 + rand.nextInt(900000)).toString();
}

Future<String> getUserId() async {
  final prefs = await SharedPreferences.getInstance();
  String? id = prefs.getString("user_id");

  if (id == null) {
    id = generateCallGuardId();
    await prefs.setString("user_id", id);
  }

  return id;
}
