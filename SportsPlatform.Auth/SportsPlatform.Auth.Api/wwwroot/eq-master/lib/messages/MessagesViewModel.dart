import 'package:flutter/material.dart';
import 'MessagesModel.dart';

class MessagesViewModel extends ChangeNotifier {
  final List<TeamMember> _members = [
    TeamMember(name: "Ahmed Ali", role: "Coach", image: "assets/profile.png"),
    TeamMember(name: "Ali Omar", role: "Team manager", image: "assets/profile.png"),
    TeamMember(name: "Sara Ashraf", role: "Doctor", image: "assets/profile.png"),
    TeamMember(name: "Mahmoud Hamed", role: "Performance analyst", image: "assets/profile.png"),
    TeamMember(name: "Loay Barakat", role: "Fitness coach", image: "assets/profile.png"),
    TeamMember(name: "Karim Mohamed", role: "Player", image: "assets/profile.png"),
    TeamMember(name: "Khaled Mostafa", role: "Player", image: "assets/profile.png"),
  ];

  List<TeamMember> get members => List.unmodifiable(_members);

  // Later you can replace this with DB fetch
  void loadMembersFromDatabase() {
    // TODO: implement DB integration
    notifyListeners();
  }
}
