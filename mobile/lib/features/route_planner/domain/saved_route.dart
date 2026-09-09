import '../../trail/domain/trail_direction.dart';
import 'route_plan.dart';

class SavedRouteDay {
  const SavedRouteDay({
    required this.dayNumber,
    required this.startStageId,
    required this.startStageName,
    required this.finishStageId,
    required this.finishStageName,
    required this.distanceKm,
    required this.ascentM,
    required this.descentM,
    required this.estimatedWalkingMinutes,
    required this.usesCamping,
    required this.accommodationName,
    this.accommodationId,
    required this.estimatedCostEur,
  });

  final int dayNumber;
  final String startStageId;
  final String startStageName;
  final String finishStageId;
  final String finishStageName;
  final double distanceKm;
  final double ascentM;
  final double descentM;
  final int estimatedWalkingMinutes;
  final bool usesCamping;
  final String? accommodationName;
  final String? accommodationId;
  final double? estimatedCostEur;

  Map<String, Object?> toJson() => {
    'dayNumber': dayNumber,
    'startStageId': startStageId,
    'startStageName': startStageName,
    'finishStageId': finishStageId,
    'finishStageName': finishStageName,
    'distanceKm': distanceKm,
    'ascentM': ascentM,
    'descentM': descentM,
    'estimatedWalkingMinutes': estimatedWalkingMinutes,
    'usesCamping': usesCamping,
    'accommodationName': accommodationName,
    'accommodationId': accommodationId,
    'estimatedCostEur': estimatedCostEur,
  };

  factory SavedRouteDay.fromJson(Map<String, Object?> json) => SavedRouteDay(
    dayNumber: (json['dayNumber'] as num).toInt(),
    startStageId: json['startStageId']! as String,
    startStageName: json['startStageName']! as String,
    finishStageId: json['finishStageId']! as String,
    finishStageName: json['finishStageName']! as String,
    distanceKm: (json['distanceKm'] as num).toDouble(),
    ascentM: (json['ascentM'] as num).toDouble(),
    descentM: (json['descentM'] as num).toDouble(),
    estimatedWalkingMinutes: (json['estimatedWalkingMinutes'] as num).toInt(),
    usesCamping: json['usesCamping']! as bool,
    accommodationName: json['accommodationName'] as String?,
    accommodationId: json['accommodationId'] as String?,
    estimatedCostEur: (json['estimatedCostEur'] as num?)?.toDouble(),
  );
}

class SavedRoute {
  const SavedRoute({
    required this.id,
    required this.createdAt,
    required this.style,
    required this.direction,
    required this.startStageId,
    required this.startStageName,
    required this.finishStageId,
    required this.finishStageName,
    required this.minimumDailyDistanceKm,
    required this.maximumDailyDistanceKm,
    this.maximumDailyWalkingMinutes,
    this.preferredDailyDistanceKm,
    this.constraint = RoutePlanConstraint.fixedDays,
    this.paceUnit = RoutePaceUnit.hours,
    this.paceValue = 6,
    this.includeUnknownAccommodationPrices = true,
    required this.minimumAccommodationPriceEur,
    required this.maximumAccommodationPriceEur,
    required this.overnightPreference,
    this.startDate,
    required this.days,
    required this.estimatedAccommodationCostEur,
    required this.unknownPriceNights,
  });

  final String id;
  final DateTime createdAt;
  final RoutePlanStyle style;
  final TrailDirection direction;
  final String startStageId;
  final String startStageName;
  final String finishStageId;
  final String finishStageName;
  final double minimumDailyDistanceKm;
  final double maximumDailyDistanceKm;
  final int? maximumDailyWalkingMinutes;
  final double? preferredDailyDistanceKm;
  final RoutePlanConstraint constraint;
  final RoutePaceUnit paceUnit;
  final double paceValue;
  final bool includeUnknownAccommodationPrices;
  final double? minimumAccommodationPriceEur;
  final double? maximumAccommodationPriceEur;
  final RouteOvernightPreference overnightPreference;
  final DateTime? startDate;
  final List<SavedRouteDay> days;
  final double estimatedAccommodationCostEur;
  final int unknownPriceNights;

  String get name => '$startStageName → $finishStageName';

  double get totalDistanceKm =>
      days.fold(0, (total, day) => total + day.distanceKm);

  Set<String> get stageIds => {
    if (days.isNotEmpty) days.first.startStageId,
    for (final day in days) day.finishStageId,
  };

  factory SavedRoute.fromPlan({
    required String id,
    required DateTime createdAt,
    required RoutePlanStyle style,
    required TrailDirection direction,
    required RoutePlanRequest request,
    required RoutePlan plan,
  }) => SavedRoute(
    id: id,
    createdAt: createdAt,
    style: style,
    direction: direction,
    startStageId: request.startStageId,
    startStageName: plan.days.first.start.name,
    finishStageId: request.finishStageId,
    finishStageName: plan.days.last.finish.name,
    minimumDailyDistanceKm: request.minimumDailyDistanceKm,
    maximumDailyDistanceKm: request.maximumDailyDistanceKm,
    maximumDailyWalkingMinutes: request.maximumDailyWalkingMinutes,
    preferredDailyDistanceKm: request.preferredDailyDistanceKm,
    constraint: request.constraint,
    paceUnit: request.paceUnit,
    paceValue: request.paceValue,
    includeUnknownAccommodationPrices:
        request.includeUnknownAccommodationPrices,
    minimumAccommodationPriceEur: request.minimumAccommodationPriceEur,
    maximumAccommodationPriceEur: request.maximumAccommodationPriceEur,
    overnightPreference: request.overnightPreference,
    startDate: request.startDate,
    days: [
      for (final day in plan.days)
        SavedRouteDay(
          dayNumber: day.dayNumber,
          startStageId: day.start.id,
          startStageName: day.start.name,
          finishStageId: day.finish.id,
          finishStageName: day.finish.name,
          distanceKm: day.distanceKm,
          ascentM: day.ascentM,
          descentM: day.descentM,
          estimatedWalkingMinutes: day.estimatedWalkingMinutes,
          usesCamping: day.usesCamping,
          accommodationName: day.accommodation?.name,
          accommodationId: day.accommodation?.id,
          estimatedCostEur: day.estimatedCostEur,
        ),
    ],
    estimatedAccommodationCostEur: plan.estimatedAccommodationCostEur,
    unknownPriceNights: plan.unknownPriceNights,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'style': style.name,
    'direction': direction.name,
    'startStageId': startStageId,
    'startStageName': startStageName,
    'finishStageId': finishStageId,
    'finishStageName': finishStageName,
    'minimumDailyDistanceKm': minimumDailyDistanceKm,
    'maximumDailyDistanceKm': maximumDailyDistanceKm,
    'maximumDailyWalkingMinutes': maximumDailyWalkingMinutes,
    'preferredDailyDistanceKm': preferredDailyDistanceKm,
    'constraint': constraint.name,
    'paceUnit': paceUnit.name,
    'paceValue': paceValue,
    'includeUnknownAccommodationPrices': includeUnknownAccommodationPrices,
    'minimumAccommodationPriceEur': minimumAccommodationPriceEur,
    'maximumAccommodationPriceEur': maximumAccommodationPriceEur,
    'overnightPreference': overnightPreference.name,
    'startDate': startDate?.toIso8601String(),
    'days': [for (final day in days) day.toJson()],
    'estimatedAccommodationCostEur': estimatedAccommodationCostEur,
    'unknownPriceNights': unknownPriceNights,
  };

  factory SavedRoute.fromJson(Map<String, Object?> json) => SavedRoute(
    id: json['id']! as String,
    createdAt: DateTime.parse(json['createdAt']! as String),
    style: switch (json['style']! as String) {
      'budget' => RoutePlanStyle.relaxed,
      'comfort' => RoutePlanStyle.adventurous,
      final value => RoutePlanStyle.values.byName(value),
    },
    direction: TrailDirection.values.byName(json['direction']! as String),
    startStageId: json['startStageId']! as String,
    startStageName: json['startStageName']! as String,
    finishStageId: json['finishStageId']! as String,
    finishStageName: json['finishStageName']! as String,
    minimumDailyDistanceKm: (json['minimumDailyDistanceKm'] as num).toDouble(),
    maximumDailyDistanceKm: (json['maximumDailyDistanceKm'] as num).toDouble(),
    maximumDailyWalkingMinutes: (json['maximumDailyWalkingMinutes'] as num?)
        ?.toInt(),
    preferredDailyDistanceKm: (json['preferredDailyDistanceKm'] as num?)
        ?.toDouble(),
    constraint: switch (json['constraint']) {
      final String value => RoutePlanConstraint.values.byName(value),
      _ => RoutePlanConstraint.fixedDays,
    },
    paceUnit: switch (json['paceUnit']) {
      final String value => RoutePaceUnit.values.byName(value),
      _ => RoutePaceUnit.hours,
    },
    paceValue: (json['paceValue'] as num?)?.toDouble() ?? 6,
    includeUnknownAccommodationPrices:
        json['includeUnknownAccommodationPrices'] as bool? ?? true,
    minimumAccommodationPriceEur: (json['minimumAccommodationPriceEur'] as num?)
        ?.toDouble(),
    maximumAccommodationPriceEur: (json['maximumAccommodationPriceEur'] as num?)
        ?.toDouble(),
    overnightPreference: switch (json['overnightPreference']) {
      final String value => RouteOvernightPreference.values.byName(value),
      _ when json['allowCamping'] == true => RouteOvernightPreference.either,
      _ => RouteOvernightPreference.accommodation,
    },
    startDate: switch (json['startDate']) {
      final String value => DateTime.tryParse(value),
      _ => null,
    },
    days: [
      for (final value in json['days']! as List<Object?>)
        SavedRouteDay.fromJson(
          Map<String, Object?>.from(value! as Map<Object?, Object?>),
        ),
    ],
    estimatedAccommodationCostEur:
        (json['estimatedAccommodationCostEur'] as num).toDouble(),
    unknownPriceNights: (json['unknownPriceNights'] as num).toInt(),
  );
}
