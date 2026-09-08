import 'package:command_protocol/src/param.dart';

/// How a choice picker narrows its options as the user types.
sealed class OptionFilter {
  const OptionFilter();
}

/// The palette ranks option labels against what is typed.
final class FuzzyFilter extends OptionFilter {
  const FuzzyFilter();
}

/// Nothing to type; every option is always listed.
final class NoFilter extends OptionFilter {
  const NoFilter();
}

/// The feature answers each query itself, over whatever it knows about its
/// options (full text, say); the palette lists what comes back, in order.
final class SearchFilter<T> extends OptionFilter {
  const SearchFilter(this.search);

  final Stream<List<Option<T>>> Function(String query) search;
}
