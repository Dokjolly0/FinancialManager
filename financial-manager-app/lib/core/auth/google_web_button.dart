// Google's own sign-in button, rendered by its script: on the web it is
// the only way to start a Google sign-in (google_sign_in has no
// authenticate() there). Elsewhere it renders nothing.
export 'google_web_button_stub.dart'
    if (dart.library.js_interop) 'google_web_button_web.dart';
