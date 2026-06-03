import 'package:flutter/foundation.dart';

import '../../../core/api/repositories/signal_library_repository.dart';
import '../../../core/models/signal_library_models.dart';

class SignalLibraryViewModel extends ChangeNotifier {
  final SignalLibraryRepository _repository;

  List<LibraryPatternModel> patterns = const [];
  Set<String> savedPatternIds = {};
  Set<String> privateActionPatternIds = {};
  String? message;
  bool loading = false;
  String _language = 'en';

  SignalLibraryViewModel(this._repository);

  Future<void> load({String language = 'en'}) async {
    _language = language;
    loading = true;
    notifyListeners();
    patterns = await _repository.listCuratedPatterns(language: language);
    loading = false;
    notifyListeners();
  }

  Future<void> markAlsoHaveThis(LibraryPatternModel pattern) async {
    await _repository.recordPrivateAction(
      patternId: pattern.id,
      action: 'i_also_have_this',
    );
    privateActionPatternIds = {...privateActionPatternIds, pattern.id};
    message = _message('kept_private');
    notifyListeners();
  }

  Future<void> saveToMyObservation(LibraryPatternModel pattern) async {
    await _repository.saveToMyObservation(pattern: pattern);
    savedPatternIds = {...savedPatternIds, pattern.id};
    message = _message('saved');
    notifyListeners();
  }

  Future<void> markNotForMe(LibraryPatternModel pattern) async {
    await _repository.recordPrivateAction(
      patternId: pattern.id,
      action: 'not_for_me',
    );
    privateActionPatternIds = {...privateActionPatternIds, pattern.id};
    message = _message('noted');
    notifyListeners();
  }

  void markSharePrepared(LibraryPatternModel pattern) {
    message = _message('shared');
    notifyListeners();
  }

  String _message(String key) {
    final language = _language.toLowerCase();
    final zhHans =
        language == 'zh-hans' || language == 'zh_hans' || language == 'zh-cn';
    final zhHant = language == 'zh-hant' ||
        language == 'zh_hant' ||
        language == 'zh-tw' ||
        language == 'zh-hk';
    final ja = language == 'ja' || language == 'ja-jp';

    switch (key) {
      case 'kept_private':
        if (zhHans) return '已私密记录，不会分享。';
        if (zhHant) return '已私密記錄，不會分享。';
        if (ja) return '非公開で記録しました。共有されません。';
        return 'Kept private. Nothing is shared.';
      case 'saved':
        if (zhHans) return '已私密放进你的观察里。';
        if (zhHant) return '已私密放進你的觀察裡。';
        if (ja) return '自分の観察に非公開で保存しました。';
        return 'Saved privately into your observations.';
      case 'noted':
        if (zhHans) return '已私密记下。';
        if (zhHant) return '已私密記下。';
        if (ja) return '非公開で記録しました。';
        return 'Noted privately.';
      case 'shared':
        if (zhHans) return '已复制官方整理内容，不包含个人记录或用户故事。';
        if (zhHant) return '已複製官方整理內容，不包含個人記錄或使用者故事。';
        if (ja) return '公式に整理した内容をコピーしました。個人の記録やユーザーの物語は含まれません。';
        return 'Official abstract pattern copied. No personal note or user story is included.';
      default:
        return '';
    }
  }
}
