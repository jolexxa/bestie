import 'package:intentions/intentions.dart';

@model
sealed class RouterOutput {
  const RouterOutput();
}

@model
final class RouterStateUpdated extends RouterOutput {
  const RouterStateUpdated();
}
