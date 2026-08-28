import 'package:equatable/equatable.dart';

/// Base class for all Use Cases in the application.
///
/// [T] is the return type of the use case.
/// [Params] is the parameters needed to execute the use case.
abstract class UseCase<T, Params> {
  Future<T> call(Params params);
}

/// Used when a Use Case does not require any parameters.
class NoParams extends Equatable {
  @override
  List<Object?> get props => [];
}
