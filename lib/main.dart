import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/bootstrap/app_bootstrap.dart';
import 'app.dart';

void main() async {
  await AppBootstrap.init();

  runApp(
    const ProviderScope(
      child: CareMindApp(),
    ),
  );
}
