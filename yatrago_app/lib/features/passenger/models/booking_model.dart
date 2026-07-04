class BookingModel {
  final String id;
  final String rideId;
  final String passengerId;
  final int seatsBooked;
  final double totalAmount;
  final String status;
  final String paymentStatus;
  final DateTime bookedAt;
  final DateTime? confirmedAt;
  final Map<String, dynamic>? ride;
  final Map<String, dynamic>? passenger;

  BookingModel({
    required this.id,
    required this.rideId,
    required this.passengerId,
    required this.seatsBooked,
    required this.totalAmount,
    required this.status,
    required this.paymentStatus,
    required this.bookedAt,
    this.confirmedAt,
    this.ride,
    this.passenger,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) => BookingModel(
    id: json['id'] ?? '',
    rideId: json['rideId'] ?? '',
    passengerId: json['passengerId'] ?? '',
    seatsBooked: json['seatsBooked'] ?? 1,
    totalAmount: (json['totalAmount'] ?? 0).toDouble(),
    status: json['status'] ?? 'pending',
    paymentStatus: json['paymentStatus'] ?? 'pending',
    bookedAt: DateTime.parse(
      json['bookedAt'] ?? DateTime.now().toIso8601String(),
    ),
    confirmedAt: json['confirmedAt'] != null
        ? DateTime.parse(json['confirmedAt'])
        : null,
    ride: json['ride'],
    passenger: json['passenger'],
  );
}
