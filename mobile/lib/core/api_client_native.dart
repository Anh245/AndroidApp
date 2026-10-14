import 'package:http/http.dart' as http;
import 'refresh_cookie_client.dart';

http.Client createApiClient(Uri baseUri) => RefreshCookieClient(http.Client(), baseUri);
