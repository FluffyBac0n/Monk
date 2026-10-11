import 'package:eurotrex/features/map/presentation/map_screen.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:integration_test/integration_test.dart';

import '../test/route_planner_screen_test.dart' as planner;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MapboxOptions.setAccessToken(mapboxAccessToken);
  // Isolated trail and storage fixtures exercise the real wizard without
  // changing the user's routes or accessing Firebase.
  planner.registerPlannerWorkflowTests();
}
