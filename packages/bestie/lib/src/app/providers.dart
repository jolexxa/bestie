import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;
import 'package:provider_fireworks/provider_fireworks.dart';
import 'package:provider_openai/provider_openai.dart';
import 'package:provider_openrouter/provider_openrouter.dart';
import 'package:provider_protocol/provider_protocol.dart';

const String openRouterAppTitle = 'Bestie';
const String openRouterAppSite = 'https://hobbyfarm.ai';
const List<String> openRouterAppCategories = ['cli-agent'];

/// Every provider bestie ships, in the order their models are listed: the
/// user's own models first.
List<Provider> bestieProviders({
  required Provider local,
  required http.Client httpClient,
  required Clock clock,
}) => [
  local,
  OpenAiProvider(client: httpClient),
  const OpenRouterProvider(
    appTitle: openRouterAppTitle,
    httpReferer: openRouterAppSite,
    appCategories: openRouterAppCategories,
  ),
  FireworksProvider(client: httpClient, clock: clock),
];
