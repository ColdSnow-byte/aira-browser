import { BookmarkStorageScope, SearchSuggestion } from '../../common/models/BrowserModels';
import { BookmarkRepository } from '../../data/repositories/BrowserRepositories';
import {
  OMNIBOX_BOOKMARK_VISIBLE_LIMIT,
  matchBookmarkSuggestions
} from './LocalOmniboxSuggestionMatcher';

export class BookmarkOmniboxSuggestionService {
  private readonly repository: BookmarkRepository;

  constructor(repository: BookmarkRepository) {
    this.repository = repository;
  }

  buildSuggestions(
    query: string,
    scope: BookmarkStorageScope,
    limit: number = OMNIBOX_BOOKMARK_VISIBLE_LIMIT
  ): SearchSuggestion[] {
    if (query.trim().length === 0 || limit <= 0) {
      return [];
    }
    return matchBookmarkSuggestions(this.repository.listSuggestionCandidates(undefined, scope), query, limit);
  }
}
