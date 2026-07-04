class RideStop {
  final String locationName;
  final double lat;
  final double lng;
  final int stopOrder;
  final int? minutesFromStart;

  RideStop({
    required this.locationName,
    required this.lat,
    required this.lng,
    required this.stopOrder,
    this.minutesFromStart,
  });

  factory RideStop.fromJson(Map<String, dynamic> json) => RideStop(
    locationName: json['locationName'] ?? '',
    lat: (json['lat'] ?? 0).toDouble(),
    lng: (json['lng'] ?? 0).toDouble(),
    stopOrder: json['stopOrder'] ?? 0,
    minutesFromStart: json['minutesFromStart'],
  );
}

class RideDriver {
  final String id;
  final String? fullName;
  final String? profilePhotoUrl;
  final double averageRating;
  final int totalTrips;

  RideDriver({
    required this.id,
    this.fullName,
    this.profilePhotoUrl,
    required this.averageRating,
    required this.totalTrips,
  });

  factory RideDriver.fromJson(Map<String, dynamic> json) => RideDriver(
    id: json['id'] ?? '',
    fullName: json['fullName'],
    profilePhotoUrl: json['profilePhotoUrl'],
    averageRating: (json['averageRating'] ?? 0).toDouble(),
    totalTrips: json['totalTrips'] ?? 0,
  );
}

class RideVehicle {
  final String make;
  final String model;
  final String? color;
  final String vehicleType;

  RideVehicle({
    required this.make,
    required this.model,
    this.color,
    required this.vehicleType,
  });

  factory RideVehicle.fromJson(Map<String, dynamic> json) => RideVehicle(
    make: json['make'] ?? '',
    model: json['model'] ?? '',
    color: json['color'],
    vehicleType: json['vehicleType'] ?? 'car',
  );
}

class RideModel {
  final String id;
  final String originName;
  final double originLat;
  final double originLng;
  final String destName;
  final double destLat;
  final double destLng;
  final DateTime departureAt;
  final int availableSeats;
  final int totalSeats;
  final double pricePerSeat;
  final bool womenOnly;
  final String smokingPref;
  final String luggagePref;
  final String? notes;
  final RideDriver driver;
  final RideVehicle vehicle;
  final List<RideStop> stops;
  final String matchType;

  RideModel({
    required this.id,
    required this.originName,
    required this.originLat,
    required this.originLng,
    required this.destName,
    required this.destLat,
    required this.destLng,
    required this.departureAt,
    required this.availableSeats,
    required this.totalSeats,
    required this.pricePerSeat,
    required this.womenOnly,
    required this.smokingPref,
    required this.luggagePref,
    this.notes,
    required this.driver,
    required this.vehicle,
    required this.stops,
    this.matchType = 'nearby',
  });

  factory RideModel.fromJson(Map<String, dynamic> json) => RideModel(
    id: json['id'] ?? '',
    originName: json['originName'] ?? '',
    originLat: (json['originLat'] ?? 0).toDouble(),
    originLng: (json['originLng'] ?? 0).toDouble(),
    destName: json['destName'] ?? '',
    destLat: (json['destLat'] ?? 0).toDouble(),
    destLng: (json['destLng'] ?? 0).toDouble(),
    departureAt: DateTime.parse(json['departureAt']),
    availableSeats: json['availableSeats'] ?? 0,
    totalSeats: json['totalSeats'] ?? 0,
    pricePerSeat: (json['pricePerSeat'] ?? 0).toDouble(),
    womenOnly: json['womenOnly'] ?? false,
    smokingPref: json['smokingPref'] ?? 'no_smoking',
    luggagePref: json['luggagePref'] ?? 'any',
    notes: json['notes'],
    driver: RideDriver.fromJson(json['driver'] ?? {}),
    vehicle: RideVehicle.fromJson(json['vehicle'] ?? {}),
    stops: (json['stops'] as List<dynamic>? ?? [])
        .map((s) => RideStop.fromJson(s))
        .toList(),
    matchType: json['matchType'] ?? 'nearby',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'originName': originName,
    'originLat': originLat,
    'originLng': originLng,
    'destName': destName,
    'destLat': destLat,
    'destLng': destLng,
    'departureAt': departureAt.toIso8601String(),
    'availableSeats': availableSeats,
    'totalSeats': totalSeats,
    'pricePerSeat': pricePerSeat,
    'womenOnly': womenOnly,
    'smokingPref': smokingPref,
    'luggagePref': luggagePref,
    'notes': notes,
    'driver': {
      'id': driver.id,
      'fullName': driver.fullName,
      'profilePhotoUrl': driver.profilePhotoUrl,
      'averageRating': driver.averageRating,
      'totalTrips': driver.totalTrips,
    },
    'vehicle': {
      'make': vehicle.make,
      'model': vehicle.model,
      'color': vehicle.color,
      'vehicleType': vehicle.vehicleType,
    },
    'stops': stops
        .map((s) => {'locationName': s.locationName, 'stopOrder': s.stopOrder})
        .toList(),
  };
}
