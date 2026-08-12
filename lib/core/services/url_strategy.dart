/// Chooses the web URL strategy without pulling web-only libraries into a
/// mobile or desktop build.
library;

export 'url_strategy_stub.dart'
    if (dart.library.js_interop) 'url_strategy_web.dart';
