import 'package:intentions/intentions.dart';

/// What reading a stored file found.
@model
sealed class StoreReadResult<Value> {
  const StoreReadResult();
}

@model
final class StoreLoaded<Value> extends StoreReadResult<Value> {
  const StoreLoaded(this.value);

  final Value value;
}

/// Nothing has been written yet.
@model
final class StoreAbsent<Value> extends StoreReadResult<Value> {
  const StoreAbsent();
}

/// The file exists but does not hold what it should.
@model
final class StoreCorrupt<Value> extends StoreReadResult<Value> {
  const StoreCorrupt(this.reason);

  final String reason;
}

/// The file exists but could not be read.
@model
final class StoreUnreadable<Value> extends StoreReadResult<Value> {
  const StoreUnreadable(this.reason);

  final String reason;
}

/// What writing a stored file came to.
@model
sealed class StoreWriteResult {
  const StoreWriteResult();
}

@model
final class StoreWritten extends StoreWriteResult {
  const StoreWritten();
}

/// The previous contents are untouched.
@model
final class StoreWriteFailed extends StoreWriteResult {
  const StoreWriteFailed(this.reason);

  final String reason;
}

/// What moving an unusable file out of the way came to.
@model
sealed class StoreSetAsideResult {
  const StoreSetAsideResult();
}

/// The file now sits at [movedTo], and its old path is free.
@model
final class StoreSetAside extends StoreSetAsideResult {
  const StoreSetAside(this.movedTo);

  final String movedTo;
}

/// The file is still where it was.
@model
final class StoreSetAsideFailed extends StoreSetAsideResult {
  const StoreSetAsideFailed(this.reason);

  final String reason;
}

/// Whether this process may change the download ledger.
@model
sealed class LedgerLockResult {
  const LedgerLockResult();
}

/// This process holds the lock until it unlocks or exits.
@model
final class LedgerLockAcquired extends LedgerLockResult {
  const LedgerLockAcquired();
}

/// Another process holds the lock.
@model
final class LedgerLockHeld extends LedgerLockResult {
  const LedgerLockHeld();
}

/// The lock file could not be opened, so nobody can be locked out.
@model
final class LedgerLockFailed extends LedgerLockResult {
  const LedgerLockFailed(this.reason);

  final String reason;
}
