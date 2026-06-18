class PermissionService {
  static bool canEditStates(String role) {
    return role.trim() == 'Analyst';
  }
}
