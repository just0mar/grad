import '../models/api_models.dart';
import 'api_client.dart';

class SearchService {
  SearchService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient.instance;

  final ApiClient _api;

  Future<SearchResponseDto> search({
    required String query,
    String type = 'all',
    int page = 1,
    int pageSize = 30,
  }) async {
    final json = await _api.get(
      '/search',
      queryParams: {
        'q': query,
        'type': type,
        'page': page.toString(),
        'pageSize': pageSize.toString(),
      },
    );
    return SearchResponseDto.fromJson(Map<String, dynamic>.from(json as Map));
  }
}
