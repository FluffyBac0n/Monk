/// Prevents delayed automatic camera work from overriding map gestures.
class MapCameraIntent {
  int _revision = 0;
  bool _hasGesture = false;
  bool _followingLocation = false;

  int get revision => _revision;
  int? get initialRequest =>
      _hasGesture || _followingLocation ? null : _revision;

  void onGesture() {
    _hasGesture = true;
    _followingLocation = false;
    _revision++;
  }

  void startLocation({required bool focus}) {
    _followingLocation = focus;
    _revision++;
  }

  void stopLocation() {
    _followingLocation = false;
    _revision++;
  }

  bool isCurrent(int? request) => request != null && request == _revision;
  bool shouldFollowLocation(int request) =>
      _followingLocation && isCurrent(request);
}
