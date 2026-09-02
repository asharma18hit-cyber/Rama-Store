import 'package:flutter/foundation.dart';
import '../network/api_exceptions.dart';

@immutable
sealed class Result<T> {
  const Result();

  factory Result.success(T data) = Success<T>;
  factory Result.failure(ApiException error) = Failure<T>;

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T? get dataOrNull => switch (this) {
        Success<T>(data: final data) => data,
        Failure<T>() => null,
      };

  ApiException? get errorOrNull => switch (this) {
        Success<T>() => null,
        Failure<T>(error: final error) => error,
      };

  R when<R>({
    required R Function(T data) success,
    required R Function(ApiException error) failure,
  }) {
    return switch (this) {
      Success<T>(data: final data) => success(data),
      Failure<T>(error: final error) => failure(error),
    };
  }
}

class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Success<T> && runtimeType == other.runtimeType && data == other.data;

  @override
  int get hashCode => data.hashCode;
}

class Failure<T> extends Result<T> {
  final ApiException error;
  const Failure(this.error);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Failure<T> && runtimeType == other.runtimeType && error == other.error;

  @override
  int get hashCode => error.hashCode;
}
