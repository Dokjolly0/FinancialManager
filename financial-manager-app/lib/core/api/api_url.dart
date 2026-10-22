/// Turns a route path the backend returns (always "/v1/...", relative to
/// the API root) into an absolute URL for the configured [baseUrl], which
/// ends in "/v1" and may sit under a prefix: production is
/// "https://financialmanager.alexviolatto.dev/api/v1", behind Caddy's
/// /api. Resolving against the origin alone would drop that prefix.
String resolveApiPath(String baseUrl, String path) {
  var root = baseUrl;
  while (root.endsWith('/')) {
    root = root.substring(0, root.length - 1);
  }
  if (root.endsWith('/v1')) root = root.substring(0, root.length - 3);
  return '$root${path.startsWith('/') ? path : '/$path'}';
}
