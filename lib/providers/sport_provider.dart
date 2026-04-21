import 'package:flutter/material.dart';
import '../models/sport_model.dart';
import '../services/sport_service.dart';

class SportProvider with ChangeNotifier {
  final SportService _sportService;
  
  SportProvider({SportService? sportService})
    : _sportService = sportService ?? SportService();

  List<SportModel> _sports = [];
  bool _isLoading = false;

  int _currentPage = 1;
  int _currentLimit = 100;
  String _currentSortBy = 'date';
  String _currentSortOrder = 'desc';

  List<SportModel> get sports => _sports;
  bool get isLoading => _isLoading;

  Future<void> fetchSports({
    int? page,
    int? limit,
    String? sortBy,
    String? sortOrder,
    bool forceRefresh = false,
  }) async {
    if (page == 1 || page == null) _isLoading = true;
    if (forceRefresh) notifyListeners();

    if (page != null) _currentPage = page;
    if (limit != null) _currentLimit = limit;
    if (sortBy != null) _currentSortBy = sortBy;
    if (sortOrder != null) _currentSortOrder = sortOrder;

    try {
      final newData = await _sportService.getSports(
        page: _currentPage,
        limit: _currentLimit,
        sortBy: _currentSortBy,
        sortOrder: _currentSortOrder,
      );

      if (_currentPage == 1) {
        _sports = newData;
      } else {
        _sports.addAll(newData);
      }
    } catch (e) {
      debugPrint('Error fetching sports: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addSport({
    required double length,
    required String category,
    String? note,
    required DateTime date,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final newSport = SportModel(
        id: '',
        length: length,
        category: category,
        note: note,
        date: date,
      );
      await _sportService.createSport(newSport);
      await fetchSports(page: 1, forceRefresh: true);
    } catch (e) {
      debugPrint('Error adding sport: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
