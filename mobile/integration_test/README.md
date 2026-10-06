Run POI directions checks from `mobile/`, with the local environment file:

```sh
flutter test integration_test/poi_directions_test.dart -d <simulator-id> --dart-define-from-file=env.local.json
```

Use a disposable simulator: Flutter integration tests uninstall their test app
when finished. Install the test APK/app and grant foreground location permission
before running; installing an update preserves that permission. Seed GPS near
Pano Platres (latitude 34.8900, longitude 32.8700). Android may need repeated GPS
fixes while the test runs; iOS's static simulated location stays active.

The test uses native Geolocator and Mapbox maps, plus live Directions API calls
for walking and driving on both stage and accommodation cards. Trail and accommodation fixtures keep it independent
of Firebase data. It checks rendered native route features, route clearing,
distance/ETA/instructions, and controlled offline and permission-denied states.
It also drags stage/accommodation cards and checks that they retain their chosen
height. Centering is checked against the real native camera after delivering the
SDK's gesture callback and moving the camera away from the trail; WidgetTester
pointer events cannot pan the native iOS map view.
For the centering/card regressions without simulator GPS or a Directions API
request, add `--plain-name 'Map controls'` to the test command. These cases use a
fixed location and a controlled offline response while exercising the real map
camera and Flutter sheet gestures.
The unit tests cover stage destinations in both trail directions, expanded stage information, no-route responses, malformed data and cancellation races.

To restore the normal app afterward, run it from `mobile/` with:

```sh
flutter run -d <simulator-id> --dart-define-from-file=env.local.json
```

Never print or commit `env.local.json` or expose the token in test output.
