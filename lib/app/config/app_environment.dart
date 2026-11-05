import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_environment.g.dart';

/// Names must match the native flavors (Android productFlavors, iOS schemes).
enum AppEnvironment { dev, prod }

/// Overridden in [bootstrap] with the value chosen by the entry point.
@Riverpod(keepAlive: true)
AppEnvironment appEnvironment(Ref ref) {
  throw UnimplementedError('appEnvironmentProvider must be overridden.');
}
