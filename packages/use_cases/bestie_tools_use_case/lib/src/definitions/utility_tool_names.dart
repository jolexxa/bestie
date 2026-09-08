/// What each utility tool is called.
///
/// Named once and referenced by both the definition a model is shown and the
/// dispatch that answers the call, so the two cannot drift apart. They have to
/// be constants rather than reads off the definitions: a switch case is a
/// constant pattern, and a field read is not one.
abstract final class UtilityToolNames {
  static const create = 'create';
  static const edit = 'edit';
  static const webSearch = 'web_search';
  static const newsSearch = 'news_search';
  static const webFetch = 'web_fetch';
  static const wikipediaSearch = 'wiki_search';
  static const arxivSearch = 'arxiv_search';
  static const calculator = 'calculator';
  static const dateTime = 'date_time';
}
