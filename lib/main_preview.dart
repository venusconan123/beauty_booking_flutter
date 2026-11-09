import 'package:flutter/material.dart';

import 'workspace/workspace_app.dart';
import 'workspace/workspace_store.dart';

/// Full interactive UI review. Deliberately runs without Firebase.initializeApp.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(WorkspaceApp(store: WorkspaceStore()));
}
