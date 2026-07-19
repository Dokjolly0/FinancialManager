import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../categories/data/providers.dart';
import '../../../templates/data/providers.dart';
import '../../../templates/domain/models/transaction_template.dart';
import '../../domain/models/transaction_direction.dart';

/// Title field with template-backed autocomplete (plan.md section 7.6,
/// 17.3): after 1+ characters, shows matching templates for the current
/// direction — title, category, and usage count — debounced so it doesn't
/// fire a request per keystroke. Selecting a suggestion is reported via
/// [onSuggestionSelected]; typing further without selecting just leaves a
/// plain title, matching section 4.4 ("the user can still change any
/// field").
class TitleAutocompleteField extends ConsumerStatefulWidget {
  const TitleAutocompleteField({
    super.key,
    required this.controller,
    required this.direction,
    required this.onSuggestionSelected,
    this.errorText,
    this.onChanged,
  });

  final TextEditingController controller;
  final TransactionDirection direction;
  final ValueChanged<TransactionTemplate> onSuggestionSelected;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  @override
  ConsumerState<TitleAutocompleteField> createState() =>
      _TitleAutocompleteFieldState();
}

class _TitleAutocompleteFieldState
    extends ConsumerState<TitleAutocompleteField> {
  final _focusNode = FocusNode();
  Timer? _debounce;
  List<TransactionTemplate> _suggestions = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    widget.onChanged?.call(value);
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(value));
  }

  Future<void> _search(String query) async {
    setState(() => _isSearching = true);
    try {
      final results = await ref
          .read(templateRepositoryProvider)
          .search(direction: widget.direction, query: query);
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _suggestions = [];
        _isSearching = false;
      });
    }
  }

  void _selectSuggestion(TransactionTemplate template) {
    widget.controller.text = template.title;
    widget.onSuggestionSelected(template);
    setState(() => _suggestions = []);
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final showSuggestions =
        _focusNode.hasFocus && (_suggestions.isNotEmpty || _isSearching);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            labelText: 'Titolo',
            errorText: widget.errorText,
            suffixIcon: _isSearching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
          onChanged: _onTextChanged,
        ),
        if (showSuggestions)
          Container(
            margin: const EdgeInsets.only(top: AppSpacing.xs),
            constraints: const BoxConstraints(maxHeight: 240),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                final matchingCategories = categories
                    .where((c) => c.id == suggestion.defaultCategoryId)
                    .toList();
                final category = matchingCategories.isEmpty
                    ? null
                    : matchingCategories.first;
                return ListTile(
                  dense: true,
                  title: Text(suggestion.title),
                  subtitle: category != null ? Text(category.name) : null,
                  trailing: Text(
                    'Usato ${suggestion.usageCount}x',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  onTap: () => _selectSuggestion(suggestion),
                );
              },
            ),
          ),
      ],
    );
  }
}
