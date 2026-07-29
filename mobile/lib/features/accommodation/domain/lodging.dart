class LodgingLocation {
  const LodgingLocation({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

class Lodging {
  const Lodging({
    required this.id,
    this.stageId,
    this.stageSequence,
    this.stageName,
    this.name,
    this.type,
    this.village,
    this.minPriceText,
    this.priceMinEur,
    this.priceMaxEur,
    this.distanceFromTrailKm,
    this.location,
    this.address,
    this.phone,
    this.whatsapp,
    this.email,
    this.website,
    this.googleMapsUrl,
    this.openingTime,
    this.closingTime,
    this.monthsOpen,
    this.capacityPeople,
    this.checkInTime,
    this.checkOutTime,
  });

  final String id;
  final String? stageId;
  final int? stageSequence;
  final String? stageName;
  final String? name;
  final String? type;
  final String? village;
  final String? minPriceText;
  final double? priceMinEur;
  final double? priceMaxEur;
  final double? distanceFromTrailKm;
  final LodgingLocation? location;
  final String? address;
  final String? phone;
  final String? whatsapp;
  final String? email;
  final String? website;
  final String? googleMapsUrl;
  final String? openingTime;
  final String? closingTime;
  final String? monthsOpen;
  final int? capacityPeople;
  final String? checkInTime;
  final String? checkOutTime;

  Uri? get bookingUri => _httpUri(website);

  Uri? get mapsUri => _httpUri(googleMapsUrl);

  String? get dialingPhoneNumber => normalizePhoneForDialing(phone);

  Uri? get phoneUri {
    final number = dialingPhoneNumber;
    return number == null ? null : Uri(scheme: 'tel', path: number);
  }

  Uri? get emailUri => _emailUri(email);

  factory Lodging.fromFirestore(String id, Map<String, dynamic> json) {
    final contact = json['contact'];
    return Lodging(
      id: id,
      stageId: _stringOrNull(json['stageId']),
      stageSequence: _intOrNull(json['stageSequence']),
      stageName: _stringOrNull(json['stageName']),
      name: _stringOrNull(json['name']),
      type: _stringOrNull(json['type']),
      village: _stringOrNull(json['village']),
      minPriceText: _stringOrNull(json['minPriceText']),
      priceMinEur: _doubleOrNull(json['priceMinEur']),
      priceMaxEur: _doubleOrNull(json['priceMaxEur']),
      distanceFromTrailKm: _doubleOrNull(json['distanceFromTrailKm']),
      location: _locationOrNull(json['location']),
      address: _stringOrNull(json['address']),
      phone: _contactString(contact, 'phone'),
      whatsapp: _contactString(contact, 'whatsapp'),
      email: _contactString(contact, 'email'),
      website: _contactString(contact, 'website'),
      googleMapsUrl: _contactString(contact, 'googleMapsUrl'),
      openingTime: _stringOrNull(json['openingTime']),
      closingTime: _stringOrNull(json['closingTime']),
      monthsOpen: _stringOrNull(json['monthsOpen']),
      capacityPeople: _intOrNull(json['capacityPeople']),
      checkInTime: _stringOrNull(json['checkInTime']),
      checkOutTime: _stringOrNull(json['checkOutTime']),
    );
  }
}

LodgingLocation? _locationOrNull(Object? value) {
  if (value is! Map) return null;
  final latitude = _doubleOrNull(value['latitude']);
  final longitude = _doubleOrNull(value['longitude']);
  if (latitude == null ||
      longitude == null ||
      latitude < -90 ||
      latitude > 90 ||
      longitude < -180 ||
      longitude > 180) {
    return null;
  }
  return LodgingLocation(latitude: latitude, longitude: longitude);
}

String? _contactString(Object? contact, String key) {
  if (contact is! Map) return null;
  return _stringOrNull(contact[key]);
}

String? _stringOrNull(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

double? _doubleOrNull(Object? value) {
  final parsed = switch (value) {
    num() => value.toDouble(),
    String() => double.tryParse(value.trim()),
    _ => null,
  };
  return parsed?.isFinite == true ? parsed : null;
}

int? _intOrNull(Object? value) {
  if (value is num) {
    if (!value.toDouble().isFinite) return null;
    return value.toInt();
  }
  if (value is String) return int.tryParse(value.trim());
  return null;
}

Uri? _httpUri(String? value) {
  if (value == null) return null;
  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasAuthority || uri.host.isEmpty) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  return uri;
}

String? normalizePhoneForDialing(String? value) {
  if (value == null) return null;
  var raw = value.trim();
  if (raw.toLowerCase().startsWith('tel:')) {
    raw = raw.substring(4).trim();
  }
  if (raw.isEmpty || raw.contains(RegExp(r'[\r\n]'))) return null;

  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  if (raw.startsWith('+')) return '+$digits';
  if (digits.startsWith('00') && digits.length > 2) {
    return '+${digits.substring(2)}';
  }
  if (digits.startsWith('357') && digits.length > 3) return '+$digits';

  final nationalNumber = digits.startsWith('0') && digits.length > 1
      ? digits.substring(1)
      : digits;
  return nationalNumber.isEmpty ? null : '+357$nationalNumber';
}

Uri? _emailUri(String? value) {
  final email = value?.trim();
  if (email == null ||
      email.isEmpty ||
      email.contains(RegExp(r'[\s\r\n]')) ||
      email.indexOf('@') <= 0 ||
      email.lastIndexOf('@') != email.indexOf('@') ||
      email.endsWith('@')) {
    return null;
  }
  return Uri(scheme: 'mailto', path: email);
}
