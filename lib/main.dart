import 'package:flutter/material.dart';

import 'app.dart';
import 'services/shared_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedService.instance.initialize();
  runApp(const DracApp());
}
