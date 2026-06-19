class SignUpModel {
  final String email;
  final String password;
  final String confirmPassword;
  final String userRole; // <-- added

  SignUpModel({
    required this.email,
    required this.password,
    required this.confirmPassword,
    required this.userRole,
  });
}

