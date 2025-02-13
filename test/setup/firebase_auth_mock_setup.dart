import 'package:firebase_auth/firebase_auth.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'firebase_auth_mock_setup.mocks.dart';

@GenerateMocks([
  FirebaseAuth,
  User,
  UserCredential,
])
void setupFirebaseAuthMocks() {}

class MockUser implements GeneratedMockUser {
  String? _displayName;
  final String _email;
  
  MockUser({String? displayName, String email = 'test@example.com'})
      : _displayName = displayName,
        _email = email;
  
  @override
  String? get displayName => _displayName;
  
  @override
  String get email => _email;
  
  @override
  Future<void> updateDisplayName(String? displayName) async {
    _displayName = displayName;
  }
  
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockUserCredential implements GeneratedMockUserCredential {
  final MockUser _user;
  
  MockUserCredential(this._user);
  
  @override
  User? get user => _user;
  
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockFirebaseAuth implements GeneratedMockFirebaseAuth {
  @override
  Future<UserCredential> getRedirectResult() async {
    return Future.value(MockUserCredential(MockUser()));
  }
  
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
} 