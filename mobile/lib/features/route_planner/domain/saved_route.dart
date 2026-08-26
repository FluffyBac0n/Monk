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
    required this.accommodationBudgetEur,
    required this.allowCamping,
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
  final double? accommodationBudgetEur;
  final bool allowCamping;
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
    accommodationBudgetEur: request.accommodationBudgetEur,
    allowCamping: request.allowCamping,
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
    'accommodationBudgetEur': accommodationBudgetEur,
    'allowCamping': allowCamping,
    'days': [for (final day in days) day.toJson()],
    'estimatedAccommodationCostEur': estimatedAccommodationCostEur,
    'unknownPriceNights': unknownPriceNights,
  };

  factory SavedRoute.fromJson(Map<String, Object?> json) => SavedRoute(
    id: json['id']! as String,
    createdAt: DateTime.parse(json['createdAt']! as String),
    style: RoutePlanStyle.values.byName(json['style']! as String),
    direction: TrailDirection.values.byName(json['direction']! as String),
    startStageId: json['startStageId']! as String,
    startStageName: json['startStageName']! as String,
    finishStageId: json['finishStageId']! as String,
    finishStageName: json['finishStageName']! as String,
    minimumDailyDistanceKm: (json['minimumDailyDistanceKm'] as num).toDouble(),
    maximumDailyDistanceKm: (json['maximumDailyDistanceKm'] as num).toDouble(),
    accommodationBudgetEur: (json['accommodationBudgetEur'] as num?)
        ?.toDouble(),
    allowCamping: json['allowCamping']! as bool,
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
