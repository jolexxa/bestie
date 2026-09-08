import 'package:intentions/intentions.dart';

/// Which answer to an ask for write access keyboard focus rests on.
@model
enum WriteAccessChoice {
  /// Say yes.
  allow,

  /// Say no: where focus opens, so a stray Enter grants nothing.
  deny;

  /// The other answer.
  WriteAccessChoice get other => switch (this) {
    allow => deny,
    deny => allow,
  };

  /// Whether this answer says yes.
  bool get allows => this == allow;
}
