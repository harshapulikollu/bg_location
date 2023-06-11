part of 'location_cubit.dart';

abstract class LocationState extends Equatable {
  const LocationState();
}

class LocationInitial extends LocationState {
  @override
  List<Object> get props => [];
}

class LocationStarted extends LocationState {
  @override
  List<Object> get props => [];
}

class LocationStopped extends LocationState {
  final String message;
  const LocationStopped({required this.message});
  @override
  List<Object> get props => [message];
}

class LocationError extends LocationState {
  final String message;
  const LocationError({required this.message});
  @override
  List<Object> get props => [message];
}
