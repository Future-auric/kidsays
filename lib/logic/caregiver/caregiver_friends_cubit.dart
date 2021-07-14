import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fokus_auth/fokus_auth.dart';
import 'package:formz/formz.dart';
import 'package:mongo_dart/mongo_dart.dart';

import '../../model/db/user/caregiver.dart';
import '../../model/db/user/user_role.dart';
import '../../model/ui/auth/user_code.dart';
import '../../utils/definitions.dart';
import '../common/auth_bloc/authentication_bloc.dart';
import '../common/formz_state.dart';
import '../common/user_code_verifier.dart';

class CaregiverFriendsCubit extends Cubit<CaregiverFriendsState> with UserCodeVerifier<CaregiverFriendsState> {
	final ActiveUserFunction _activeUser;
	final AuthenticationBloc _authBloc;

  CaregiverFriendsCubit(this._activeUser, this._authBloc) : super(CaregiverFriendsState());

  Future addNewFriend() async {
	  if (this.state.status != FormzStatus.pure)
		  return;
	  var state = await _validateFields();
	  if (!state.status.isValidated) {
		  emit(state);
		  return;
	  }
	  emit(state.copyWith(status: FormzStatus.submissionInProgress));
	  var user = _activeUser() as Caregiver;
  	var caregiverId = getIdFromCode(state.caregiverCode.value);
		var caregiverFriends = user.friends != null ? List.of(user.friends!) : <ObjectId>[];
		
		if(caregiverFriends.contains(caregiverId)) {
			emit(state.copyWith(status: FormzStatus.submissionFailure, error: 'caregiverAlreadyBefriendedError'));
		} else if(user.id == caregiverId) {
			emit(state.copyWith(status: FormzStatus.submissionFailure, error: 'enteredOwnCaregiverCodeError'));
		} else {
			var friends = caregiverFriends..add(caregiverId);
			await dataRepository.updateUser(user.id!, friends: friends);
			_authBloc.add(AuthenticationActiveUserUpdated(Caregiver.copyFrom(user, friends: friends)));
			emit(state.copyWith(status: FormzStatus.submissionSuccess));
		}
  }

	Future clearCode() async {
	  var state = this.state;
		emit(state.copyWith(caregiverCode: UserCode.pure('')));
	}

  Future<CaregiverFriendsState> _validateFields() async {
	  var state = this.state;
	  var caregiverField = UserCode.dirty(state.caregiverCode.value.trim());
	  if (caregiverField.valid && !(await verifyUserCode(state.caregiverCode.value.trim(), UserRole.caregiver)))
		  caregiverField = UserCode.dirty(state.caregiverCode.value.trim(), false);
	  state = state.copyWith(caregiverCode: caregiverField);
	  return state.copyWith(status: Formz.validate([state.caregiverCode]));
  }

	void caregiverCodeChanged(String value) => emit(state.copyWith(caregiverCode: UserCode.pure(value), status: FormzStatus.pure));
	
	void removeFriend(ObjectId friendID) async {
    var user = _activeUser() as Caregiver;
		var caregiverFriends = user.friends ?? [];
		await dataRepository.updateUser(user.id!, friends: caregiverFriends..remove(friendID));
	}
}

class CaregiverFriendsState extends FormzState {
	final UserCode caregiverCode;
	final String? error;

  CaregiverFriendsState({
	  this.caregiverCode = const UserCode.pure(),
		this.error,
    FormzStatus status = FormzStatus.pure
  }) : super(status);

  CaregiverFriendsState copyWith({UserCode? caregiverCode, String? error, FormzStatus? status}) {
	  return CaregiverFriendsState(
		  caregiverCode: caregiverCode ?? this.caregiverCode,
			error: error ?? this.error,
		  status: status ?? this.status,
	  );
  }

	@override
	List<Object?> get props => [caregiverCode, error, status];
}
