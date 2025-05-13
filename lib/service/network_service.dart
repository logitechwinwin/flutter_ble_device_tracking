import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../model/common/user_model.dart';
import '../settings/locator.dart';
import '../utils/string_utils.dart';
import '../utils/widget_utils.dart';
import 'shared_service.dart';

class NetworkService {
  Future<User?> signInUsingEmailPassword({
    required String email,
    required String password,
  }) async {
    showLoading();
    FirebaseAuth auth = FirebaseAuth.instance;
    User? user;

    try {
      UserCredential userCredential = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      user = userCredential.user;

      hideLoading();
      showMessage(StringUtils.txtLoginSuccess, null);
    } on FirebaseAuthException catch (e) {
      hideLoading();
      await Future.delayed(Duration(milliseconds: 100));
      if (e.code == 'user-not-found') {
        showMessage(StringUtils.txtNoUserFound, null);
      } else if (e.code == 'wrong-password') {
        showMessage(StringUtils.txtWrongPassword, null);
      } else {
        showMessage(e.message ?? StringUtils.txtNoUserFound, null);
      }
    }

    return user;
  }

  Future<User?> registerUsingEmailPassword({
    required String name,
    required String email,
    required String password,
  }) async {
    showLoading();
    FirebaseAuth auth = FirebaseAuth.instance;
    User? user;

    try {
      UserCredential userCredential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      user = userCredential.user;
      await user!.updateDisplayName(name);
      await user.reload();
      user = auth.currentUser;

      hideLoading();
      showMessage(StringUtils.txtSignUpSuccess, null);
    } on FirebaseAuthException catch (e) {
      hideLoading();

      if (e.code == 'weak-password') {
        showMessage(StringUtils.txtPasswordWeak, null);
      } else if (e.code == 'email-already-in-use') {
        showMessage(StringUtils.txtAccountAlreadyUse, null);
      }
    } catch (e) {
      hideLoading();

      showMessage(e.toString(), null);
    }

    return user;
  }

  Future<User?> updateEmailAndPassword({
    required String newName,
    required String newEmail,
    required String newPassword,
  }) async {
    showLoading();

    FirebaseAuth auth = FirebaseAuth.instance;
    final user = auth.currentUser;

    try {
      if (user == null) {
        throw FirebaseAuthException(
          code: 'no-user',
          message: 'No user is currently signed in.',
        );
      }
      await user.updateDisplayName(newName);
      await user.reload();
      // Send a verification email
      await user.sendEmailVerification();
      await user.verifyBeforeUpdateEmail(
        newEmail,
      ); // After the user verifies the email, you can update the email address
      await user.updatePassword(newPassword);

      hideLoading();
      showMessage(StringUtils.txtSaveSuccess, null);
    } on FirebaseAuthException {
      hideLoading();
      showMessage(StringUtils.txtFirebaseError, null);
      // if (e.code == 'weak-password') {
      //   showMessage(StringUtils.txtPasswordWeak, null);
      // } else if (e.code == 'email-already-in-use') {
      //   showMessage(StringUtils.txtAccountAlreadyUse, null);
      // }
    } catch (e) {
      hideLoading();

      showMessage(e.toString(), null);
    }
    // return null;
    return user;
  }

  Future<User?> refreshUser(User user) async {
    showLoading();
    FirebaseAuth auth = FirebaseAuth.instance;

    await user.reload();
    User? refreshedUser = auth.currentUser;
    hideLoading();
    return refreshedUser;
  }

  Future<bool> createOrUpdateUserData(UserModel? userModel) async {
    bool status = true;
    User? user = FirebaseAuth.instance.currentUser;
    CollectionReference users = FirebaseFirestore.instance.collection('Users');
    var sharedService = locator<SharedService>();

    await users
        .doc(user!.uid)
        .set(userModel!.toJson(), SetOptions(merge: true))
        .then(
          (value) => {
            sharedService.saveUser(userModel),
            status = true,
            debugPrint("User set success!"),
          },
        )
        .catchError((error) => {debugPrint(error), status = false});

    return status;
  }

  Future<UserModel?> getUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    CollectionReference users = FirebaseFirestore.instance.collection('Users');
    UserModel? userModel;
    var sharedService = locator<SharedService>();

    await users
        .doc(user!.uid)
        .get()
        .then(
          (value) async => {
            userModel = UserModel.fromJson(
              value.data() as Map<String, dynamic>,
            ),
            sharedService.saveUser(userModel),
            debugPrint("User get success!"),
          },
        )
        .catchError((error) => {debugPrint(error), userModel = null});
    return userModel;
  }

  Future<List<UserModel>> getAllUsers() async {
    CollectionReference users = FirebaseFirestore.instance.collection('Users');
    List<UserModel> list = [];
    await users
        .get()
        .then((value) {
          for (int i = 0; i < value.docs.length; i++) {
            list.add(
              UserModel.fromJson(value.docs[i].data() as Map<String, dynamic>),
            );
          }
        })
        .catchError((onError) {
          list = [];
        });
    return list;
  }

  Future<String?> getUserToken(String userId) async {
    CollectionReference users = FirebaseFirestore.instance.collection('Users');
    UserModel? userModel;
    String? token;
    await users
        .doc(userId)
        .get()
        .then(
          (value) => {
            userModel = UserModel.fromJson(
              value.data() as Map<String, dynamic>,
            ),
            token = userModel!.token!,
          },
        )
        .catchError((error) => {token = ''});
    return token;
  }
}
