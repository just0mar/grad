import 'package:google_sign_in/google_sign_in.dart';

const googleServerClientId =
    '22292251267-5ma5rh3ek1bafc6gdpuvr0emeq1sokoh.apps.googleusercontent.com';

GoogleSignIn createGoogleSignIn() {
  return GoogleSignIn(
    scopes: ['email', 'profile'],
    clientId: googleServerClientId,
    serverClientId: googleServerClientId,
  );
}
