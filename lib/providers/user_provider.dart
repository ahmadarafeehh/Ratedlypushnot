import 'package:flutter/widgets.dart';
import 'package:Ratedly/models/user.dart';
import 'package:Ratedly/resources/auth_methods.dart';

class UserProvider with ChangeNotifier {
  AppUser? _user;
  final AuthMethods _authMethods = AuthMethods();

  AppUser? get user => _user;

  Future<void> refreshUser() async {
    try {
      final user = await _authMethods.getUserDetails();
      if (user.uid.isNotEmpty) {
        // Remove null-check operator
        _user = user;
      } else {
        _user = null;
      }
    } catch (e) {
      _user = null;
    }
    notifyListeners();
  }

// Update safeUID getter
  String? get safeUID => _user?.uid.isNotEmpty == true ? _user!.uid : null;
}
