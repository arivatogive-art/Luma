// Pfad: lib/application/remembered_login_account_storage_service.dart

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/luma_user_profile_model.dart';
import '../domain/models/remembered_login_account_model.dart';

class RememberedLoginAccountStorageService {
  const RememberedLoginAccountStorageService();

  static const String _accountsKey = 'luma.auth.rememberedLoginAccounts.v1';
  static const int _maxRememberedAccounts = 5;

  Future<List<RememberedLoginAccountModel>> loadAccounts() async {
    final preferences = await SharedPreferences.getInstance();
    final rawJson = preferences.getString(_accountsKey);

    if (rawJson == null || rawJson.trim().isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! List) return const [];

      final accounts = <RememberedLoginAccountModel>[];

      for (final item in decoded) {
        if (item is! Map) continue;

        try {
          final normalizedMap = Map<String, dynamic>.from(item);
          final account = RememberedLoginAccountModel.fromMap(normalizedMap);

          if (account.userId.trim().isEmpty) continue;
          accounts.add(account);
        } catch (error, stackTrace) {
          debugPrint(
            'REMEMBERED LOGIN ACCOUNTS: skipped invalid account entry: $error',
          );
          debugPrintStack(stackTrace: stackTrace);
        }
      }

      accounts.sort((a, b) => b.lastLoginAt.compareTo(a.lastLoginAt));

      return List<RememberedLoginAccountModel>.unmodifiable(accounts);
    } catch (error, stackTrace) {
      debugPrint('REMEMBERED LOGIN ACCOUNTS: could not read storage: $error');
      debugPrintStack(stackTrace: stackTrace);
      return const [];
    }
  }

  Future<RememberedLoginAccountModel?> loadLatestAccount() async {
    final accounts = await loadAccounts();
    if (accounts.isEmpty) return null;
    return accounts.first;
  }

  Future<void> upsertAccount(RememberedLoginAccountModel account) async {
    final cleanedAccount = _cleanAccount(account);
    if (cleanedAccount == null) return;

    final existingAccounts = await loadAccounts();
    final nextAccounts = <RememberedLoginAccountModel>[
      cleanedAccount,
      ...existingAccounts.where(
        (existingAccount) => existingAccount.userId != cleanedAccount.userId,
      ),
    ];

    await _saveAccounts(nextAccounts.take(_maxRememberedAccounts).toList());
  }

  Future<void> upsertProfile(LumaUserProfileModel profile) async {
    final account = RememberedLoginAccountModel(
      userId: profile.id,
      displayName: profile.displayName,
      email: profile.email,
      phoneNumber: profile.phoneNumber,
      avatarUrl: profile.avatarUrl,
      lastLoginAt: DateTime.now(),
      signInProvider: _providerForProfile(profile),
    );

    await upsertAccount(account);
  }

  Future<void> removeAccountByUserId(String userId) async {
    final cleanedUserId = userId.trim();
    if (cleanedUserId.isEmpty) return;

    final accounts = await loadAccounts();
    final nextAccounts = accounts
        .where((account) => account.userId != cleanedUserId)
        .toList(growable: false);

    await _saveAccounts(nextAccounts);
  }

  Future<void> clearAccounts() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_accountsKey);
  }

  Future<void> _saveAccounts(List<RememberedLoginAccountModel> accounts) async {
    final preferences = await SharedPreferences.getInstance();

    if (accounts.isEmpty) {
      await preferences.remove(_accountsKey);
      return;
    }

    final encoded = jsonEncode(
      accounts.map((account) => account.toMap()).toList(growable: false),
    );

    await preferences.setString(_accountsKey, encoded);
  }

  RememberedLoginAccountModel? _cleanAccount(
    RememberedLoginAccountModel account,
  ) {
    final cleanedUserId = account.userId.trim();
    if (cleanedUserId.isEmpty) return null;

    final cleanedDisplayName = account.displayName.trim();
    final cleanedEmail = _cleanNullable(account.email);
    final cleanedPhoneNumber = _cleanNullable(account.phoneNumber);
    final cleanedAvatarUrl = _cleanNullable(account.avatarUrl);
    final cleanedProvider = _cleanProvider(account.signInProvider);

    final fallbackDisplayName = cleanedEmail == null || cleanedEmail.isEmpty
        ? 'Luma Nutzer'
        : cleanedEmail.split('@').first;

    return RememberedLoginAccountModel(
      userId: cleanedUserId,
      displayName:
          cleanedDisplayName.isEmpty ? fallbackDisplayName : cleanedDisplayName,
      email: cleanedEmail,
      phoneNumber: cleanedPhoneNumber,
      avatarUrl: cleanedAvatarUrl,
      lastLoginAt: account.lastLoginAt,
      signInProvider: cleanedProvider,
    );
  }

  String? _cleanNullable(String? value) {
    final cleaned = value?.trim();
    if (cleaned == null || cleaned.isEmpty) return null;
    return cleaned;
  }

  String _cleanProvider(String value) {
    final cleaned = value.trim().toLowerCase();

    if (cleaned == 'google.com' || cleaned == 'google') {
      return 'google.com';
    }

    if (cleaned == 'phone' || cleaned == 'phone_number') {
      return 'phone';
    }

    return 'password';
  }

  String _providerForProfile(LumaUserProfileModel profile) {
    if ((profile.email ?? '').trim().isNotEmpty) return 'password';
    if ((profile.phoneNumber ?? '').trim().isNotEmpty) return 'phone';
    return 'password';
  }
}

