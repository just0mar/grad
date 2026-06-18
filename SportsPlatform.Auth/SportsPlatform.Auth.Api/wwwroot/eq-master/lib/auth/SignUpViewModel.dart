
// import 'SignUpModel.dart';
//
// class SignUpViewModel {
//   SignUpModel? _signUpModel;
//
//   void setCredentials(String email, String password, String confirmPassword, String userRole) {
//     _signUpModel = SignUpModel(
//       email: email,
//       password: password,
//       confirmPassword: confirmPassword,
//       userRole: userRole, // <-- pass role here
//     );
//   }
//
//   bool validateCredentials() {
//     if (_signUpModel == null) return false;
//     return _signUpModel!.email.isNotEmpty &&
//         _signUpModel!.password.isNotEmpty &&
//         _signUpModel!.password == _signUpModel!.confirmPassword;
//   }
//
//   String? get userRole => _signUpModel?.userRole; // <-- expose role
// }


import 'package:flutter/material.dart';
import 'SignUpModel.dart';

class SignUpViewModel extends ChangeNotifier {
  SignUpModel? _signUpModel;

  void setCredentials(String email, String password, String confirmPassword, String userRole) {
    _signUpModel = SignUpModel(
      email: email,
      password: password,
      confirmPassword: confirmPassword,
      userRole: userRole,
    );
    notifyListeners();
  }

  bool validateCredentials() {
    if (_signUpModel == null) return false;
    return _signUpModel!.email.isNotEmpty &&
        _signUpModel!.password.isNotEmpty &&
        _signUpModel!.password == _signUpModel!.confirmPassword;
  }

  String? get userRole => _signUpModel?.userRole;
}
