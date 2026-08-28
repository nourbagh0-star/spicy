import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:spicy/features/profile/domain/repositories/profile_repository.dart';
import 'package:spicy/features/profile/presentation/cubit/profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  final ProfileRepository _repository;

  ProfileCubit({required this._repository}) : super(ProfileInitial());

  Future<void> loadProfile() async {
    emit(ProfileLoading());
    try {
      final profile = await _repository.getUserProfile();
      emit(ProfileLoaded(profile));
    } catch (e) {
      emit(ProfileError(e.toString()));
    }
  }
}
