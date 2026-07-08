import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/import_export_repository.dart';
import '../domain/export_snapshot.dart';

class ImportExportState {
  const ImportExportState({
    this.snapshot,
    this.loading = false,
    this.message,
  });

  final ExportSnapshot? snapshot;
  final bool loading;
  final String? message;

  ImportExportState copyWith({
    ExportSnapshot? snapshot,
    bool? loading,
    String? message,
  }) {
    return ImportExportState(
      snapshot: snapshot ?? this.snapshot,
      loading: loading ?? this.loading,
      message: message,
    );
  }
}

class ImportExportController extends StateNotifier<ImportExportState> {
  ImportExportController(this._repository) : super(const ImportExportState());

  final ImportExportRepository _repository;

  Future<void> exportData() async {
    state = state.copyWith(loading: true, message: null);
    try {
      final snapshot = await _repository.exportSnapshot();
      state = ImportExportState(
        snapshot: snapshot,
        loading: false,
        message: '已导出 ${snapshot.eventCount} 个行程、${snapshot.todoCount} 个待办、${snapshot.tagCount} 个标签。',
      );
    } catch (_) {
      state = state.copyWith(loading: false, message: '导出失败');
    }
  }

  Future<void> importSample() async {
    state = state.copyWith(loading: true, message: null);
    try {
      await _repository.importSample();
      state = state.copyWith(loading: false, message: '已导入一份示例数据');
    } catch (_) {
      state = state.copyWith(loading: false, message: '导入失败');
    }
  }
}

final importExportControllerProvider = StateNotifierProvider<ImportExportController, ImportExportState>(
  (ref) => ImportExportController(ref.watch(importExportRepositoryProvider)),
);
