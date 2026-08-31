import 'package:spicy/features/profile/domain/entities/saved_address.dart';
import 'package:spicy/features/profile/domain/entities/user_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseProfileDataSource {
  final SupabaseClient? client;

  const SupabaseProfileDataSource({required this.client});

  Future<UserProfile> getUserProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Please sign in to view your profile.');

    final profile = await _client
        .from('profiles')
        .select('full_name, contact_phone')
        .eq('id', user.id)
        .maybeSingle();
    final addressRows = await _client
        .from('customer_addresses')
        .select(
          'id, label, address_line, apartment, entrance, floor, notes, '
          'latitude, longitude, is_default',
        )
        .eq('customer_id', user.id)
        .order('is_default', ascending: false)
        .order('created_at');
    final orderRows = await _client
        .from('orders')
        .select('id')
        .eq('customer_id', user.id);
    final reviewRows = await _client
        .from('order_reviews')
        .select('id')
        .eq('customer_id', user.id);

    return UserProfile(
      id: user.id,
      name: (profile?['full_name'] as String? ?? '').trim().isEmpty
          ? (user.email?.split('@').first ?? '')
          : (profile?['full_name'] as String).trim(),
      email: user.email ?? '',
      phone: (profile?['contact_phone'] as String? ?? '').trim(),
      savedAddresses: addressRows.map(_toAddress).toList(growable: false),
      totalOrders: orderRows.length,
      totalReviews: reviewRows.length,
    );
  }

  Future<void> updatePersonalDetails({
    required String fullName,
    required String phone,
  }) async {
    final userId = _requireUserId();
    await _client
        .from('profiles')
        .update({'full_name': fullName.trim(), 'contact_phone': phone.trim()})
        .eq('id', userId);
  }

  Future<void> saveAddress(SavedAddress address) async {
    final userId = _requireUserId();
    final values = <String, dynamic>{
      'customer_id': userId,
      'label': address.label.trim(),
      'address_line': address.addressLine.trim(),
      'apartment': _nullable(address.apartment),
      'entrance': _nullable(address.entrance),
      'floor': _nullable(address.floor),
      'notes': _nullable(address.notes),
      'latitude': address.latitude,
      'longitude': address.longitude,
      'is_default': address.isDefault,
    };

    if (address.id.isEmpty) {
      await _client.from('customer_addresses').insert(values);
      return;
    }

    await _client
        .from('customer_addresses')
        .update(values)
        .eq('id', address.id)
        .eq('customer_id', userId);
  }

  Future<void> deleteAddress(String addressId) async {
    final userId = _requireUserId();
    await _client
        .from('customer_addresses')
        .delete()
        .eq('id', addressId)
        .eq('customer_id', userId);
  }

  Future<void> deleteAccount() async {
    await _client.functions.invoke('delete-customer-account');
    await _client.auth.signOut(scope: SignOutScope.local);
  }

  SavedAddress _toAddress(Map<String, dynamic> row) => SavedAddress(
    id: row['id'] as String,
    label: row['label'] as String,
    addressLine: row['address_line'] as String,
    apartment: row['apartment'] as String? ?? '',
    entrance: row['entrance'] as String? ?? '',
    floor: row['floor'] as String? ?? '',
    notes: row['notes'] as String? ?? '',
    latitude: (row['latitude'] as num?)?.toDouble(),
    longitude: (row['longitude'] as num?)?.toDouble(),
    isDefault: row['is_default'] as bool? ?? false,
  );

  String _requireUserId() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Please sign in to manage your profile.');
    }
    return userId;
  }

  String? _nullable(String value) => value.trim().isEmpty ? null : value.trim();

  SupabaseClient get _client =>
      client ?? (throw StateError('This build is not connected to Supabase.'));
}
