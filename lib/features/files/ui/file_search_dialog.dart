import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/i18n/l10n.dart';
import '../../../core/utils/file_utils.dart';
import '../data/services/file_search_service.dart';

class FileSearchDialog extends StatefulWidget {
  const FileSearchDialog({
    super.key,
    required this.service,
    required this.locale,
  });

  final FileSearchService service;
  final Locale locale;

  @override
  State<FileSearchDialog> createState() => _FileSearchDialogState();
}

class _FileSearchDialogState extends State<FileSearchDialog> {
  final _queryController = TextEditingController();
  Timer? _debounce;
  Timer? _indexRefresh;
  List<SearchResult> _results = const [];
  String? _error;
  bool _searching = false;
  bool _hasMoreResults = false;
  SearchProgress _progress = const SearchProgress(
    scanning: false,
    indexedEntries: 0,
    scannedRoots: 0,
    totalRoots: 0,
  );

  @override
  void initState() {
    super.initState();
    _progress = widget.service.progress;
    _queryController.addListener(_scheduleSearch);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startIndexing());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _indexRefresh?.cancel();
    _queryController
      ..removeListener(_scheduleSearch)
      ..dispose();
    super.dispose();
  }

  Future<void> _startIndexing({bool force = false}) async {
    try {
      await widget.service.indexAll(
        force: force,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _progress = progress);
          if (_queryController.text.trim().isNotEmpty &&
              _indexRefresh == null) {
            _indexRefresh = Timer(const Duration(milliseconds: 750), () {
              _indexRefresh = null;
              _runSearch();
            });
          }
        },
      );
      if (mounted) setState(() => _progress = widget.service.progress);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _addSearchLocation() async {
    try {
      final path = await FilePicker.platform.getDirectoryPath(
        dialogTitle: tr(context, 'add_search_location'),
      );
      if (path == null) return;
      await widget.service.addSearchRoot(path);
      await _startIndexing(force: true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  void _scheduleSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _runSearch);
  }

  Future<void> _runSearch() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _results = const [];
          _hasMoreResults = false;
          _error = null;
          _searching = false;
        });
      }
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results = await widget.service.search(query, limit: 501);
      if (!mounted || query != _queryController.text.trim()) return;
      setState(() {
        _results = results.take(500).toList();
        _hasMoreResults = results.length > 500;
        _searching = false;
      });
    } catch (error) {
      if (!mounted || query != _queryController.text.trim()) return;
      setState(() {
        _error = error.toString();
        _hasMoreResults = false;
        _searching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Row(
          children: [
            Expanded(child: Text(tr(context, 'quick_search'))),
            IconButton(
              tooltip: tr(context, 'add_search_location'),
              onPressed: _progress.scanning ? null : _addSearchLocation,
              icon: const Icon(Icons.create_new_folder_outlined),
            ),
            IconButton(
              tooltip: tr(context, 'refresh_search_index'),
              onPressed: _progress.scanning ? null : () => _startIndexing(force: true),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        content: SizedBox(
          width: 760,
          height: 520,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_hasMoreResults)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(tr(context, 'search_refine_query')),
                ),
              TextField(
                controller: _queryController,
                autofocus: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: tr(context, 'search_query_hint'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr(context, 'search_syntax_help'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                tr(context, 'search_content_note'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              if (_progress.scanning)
                LinearProgressIndicator(
                  value: _progress.totalRoots == 0
                      ? null
                      : _progress.scannedRoots / _progress.totalRoots,
                ),
              if (_progress.indexedEntries > 0 || _progress.scanning)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '${tr(context, 'search_index_status')}: '
                    '${_progress.indexedEntries} · '
                    '${_progress.scannedRoots}/${_progress.totalRoots}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              Expanded(
                child: _searching
                    ? const Center(child: CircularProgressIndicator())
                    : _results.isEmpty
                        ? Center(
                            child: Text(
                              _queryController.text.trim().isEmpty
                                  ? tr(context, 'search_start_typing')
                                  : tr(context, 'search_no_results'),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _results.length,
                            itemBuilder: (context, index) {
                              final result = _results[index];
                              return ListTile(
                                dense: true,
                                leading: Icon(result.isDirectory
                                    ? Icons.folder
                                    : Icons.insert_drive_file),
                                title: Text(
                                  result.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  result.path,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: result.isDirectory
                                    ? null
                                    : Text(formatSize(result.size, widget.locale)),
                                onTap: () =>
                                    Navigator.pop<SearchResult>(context, result),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr(context, 'cancel')),
          ),
        ],
      );
}
