import 'package:built_in_server_client/built_in_server_client.dart';
import 'package:clock/clock.dart';
import 'package:fireworks_client/fireworks_client.dart';
import 'package:http/http.dart' as http;
import 'package:intentions/intentions.dart';
import 'package:openai_endpoint_client/openai_endpoint_client.dart';
import 'package:openrouter_client/openrouter_client.dart';
import 'package:provider_protocol/provider_protocol.dart';

const String openRouterAppTitle = 'Bestie';
const String openRouterAppSite = 'https://hobbyfarm.ai';
const List<String> openRouterAppCategories = ['cli-agent'];

/// Every provider bestie ships, as the clients each one's feature
/// configures, in the order their models are listed: the user's own models
/// first.
@model
final class BestieProviderClients {
  BestieProviderClients({
    required this.builtInServer,
    required http.Client httpClient,
    required Clock clock,
  }) : openAiEndpoint = OpenAiEndpointClient(client: httpClient),
       openRouter = OpenRouterClient(
         appTitle: openRouterAppTitle,
         httpReferer: openRouterAppSite,
         appCategories: openRouterAppCategories,
       ),
       fireworks = FireworksClient(client: httpClient, clock: clock);

  final BuiltInServerClient builtInServer;
  final OpenAiEndpointClient openAiEndpoint;
  final OpenRouterClient openRouter;
  final FireworksClient fireworks;

  List<ProviderClient> get all => [
    builtInServer,
    openAiEndpoint,
    openRouter,
    fireworks,
  ];
}
