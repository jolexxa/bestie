sealed class Validation {
  const Validation();
}

final class Valid extends Validation {
  const Valid();
}

final class Invalid extends Validation {
  const Invalid(this.message);

  final String message;
}
