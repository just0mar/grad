import 'package:google_sign_in/google_sign_in.dart';

const googleServerClientId =
    '592688667804-j8si9t2rlu9rmu1ou4cjfbuqapjm9jlb.apps.googleusercontent.com';

GoogleSignIn createGoogleSignIn() {
  return GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: googleServerClientId,
  );
}
