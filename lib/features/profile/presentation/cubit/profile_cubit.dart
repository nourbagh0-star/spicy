import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:spicy/features/profile/domain/entities/saved_address.dart';
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

  Future<void> updatePersonalDetails({
    required String fullName,
    required String phone,
  }) async {
    try {
      await _repository.updatePersonalDetails(fullName: fullName, phone: phone);
      await loadProfile();
    } catch (error) {
      emit(ProfileError(error.toString()));
    }
  }

  Future<bool> saveAddress(SavedAddress address) async {
    try {
      await _repository.saveAddress(address);
      await loadProfile();
      return state is ProfileLoaded;
    } catch (error) {
      emit(ProfileError(error.toString()));
      return false;
    }
  }

  Future<void> deleteAddress(String addressId) async {
    try {
      await _repository.deleteAddress(addressId);
      await loadProfile();
    } catch (error) {
      emit(ProfileError(error.toString()));
    }
  }

  Future<void> deleteAccount() async {
    try {
      await _repository.deleteAccount();
    } catch (error) {
      emit(ProfileError(error.toString()));
    }
  }
}
