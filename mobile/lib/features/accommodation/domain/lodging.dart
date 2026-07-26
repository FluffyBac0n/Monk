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
