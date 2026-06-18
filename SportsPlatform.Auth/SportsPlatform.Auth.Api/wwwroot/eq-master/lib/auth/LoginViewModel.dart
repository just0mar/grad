import 'LoginModel.dart';

class LoginViewModel {
  LoginModel? _loginModel;

  void setCredentials(String email, String password) {
    _loginModel = LoginModel(email: email, password: password);
  }

  bool validateCredentials() {
    if (_loginModel == null) return false;
    return _loginModel!.email.isNotEmpty && _loginModel!.password.isNotEmpty;
  }
}
