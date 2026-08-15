import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// A saved recipient entry.
class AddressBookEntry {
  final String name;
  final String address;

  const AddressBookEntry({required this.name, required this.address});

  Map<String, dynamic> toJson() => {'name': name, 'address': address};

  factory AddressBookEntry.fromJson(Map<String, dynamic> json) {
    return AddressBookEntry(
      name: json['name'] as String,
      address: json['address'] as String,
    );
  }
}

class AddressBookNotifier extends AsyncNotifier<List<AddressBookEntry>> {
  static const _storageKey = 'address_book';

  @override
  Future<List<AddressBookEntry>> build() async {
    return _load();
  }

  Future<List<AddressBookEntry>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return [];
    final list = json.decode(raw) as List;
    return list
        .map((e) => AddressBookEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _save(List<AddressBookEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      json.encode(entries.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> add(AddressBookEntry entry) async {
    final current = state.value ?? [];
    final updated = [...current, entry];
    await _save(updated);
    state = AsyncData(updated);
  }

  Future<void> remove(int index) async {
    final current = state.value ?? [];
    final updated = List<AddressBookEntry>.from(current)..removeAt(index);
    await _save(updated);
    state = AsyncData(updated);
  }

  Future<void> updateEntry(int index, AddressBookEntry entry) async {
    final current = state.value ?? [];
    final updated = List<AddressBookEntry>.from(current)..[index] = entry;
    await _save(updated);
    state = AsyncData(updated);
  }
}

final addressBookProvider =
    AsyncNotifierProvider<AddressBookNotifier, List<AddressBookEntry>>(
  AddressBookNotifier.new,
);
