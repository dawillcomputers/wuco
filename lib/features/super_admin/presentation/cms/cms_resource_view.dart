import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../catalogue/data/catalogue_repository.dart';
import '../../application/cms_providers.dart';
import 'cms_field_editors.dart';
import 'cms_schema.dart';

/// List and editor for one CMS resource.
class CmsResourceView extends ConsumerStatefulWidget {
  const CmsResourceView({super.key, required this.resource});

  final CmsResource resource;

  @override
  ConsumerState<CmsResourceView> createState() => _CmsResourceViewState();
}

class _CmsResourceViewState extends ConsumerState<CmsResourceView> {
  String? _parentId;
  String _search = '';

  CmsQuery get _query => (
    resource: widget.resource.name,
    filterColumn: widget.resource.filterBy?.$1,
    filterValue: widget.resource.filterBy == null ? null : _parentId,
  );

  Future<void> _openEditor([Map<String, dynamic>? existing]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) =>
          _CmsEditorDialog(resource: widget.resource, existing: existing),
    );
    if (saved == true && mounted) setState(() {});
  }

  Future<void> _confirmDelete(Map<String, dynamic> row) async {
    final title = '${row[widget.resource.titleColumn] ?? 'this item'}';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${widget.resource.singular.toLowerCase()}?'),
        content: Text(
          '“$title” will be removed permanently. Anything published beneath it '
          'is removed too. Consider archiving instead if you may want it back.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(
      () => ref
          .read(cmsActionsProvider)
          .delete(widget.resource.name, '${row['id']}'),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on CatalogueFailure catch (failure) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: WEAColors.navy,
          content: Text(failure.message),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final resource = widget.resource;
    final rows = ref.watch(cmsListProvider(_query));
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(resource.plural, style: theme.textTheme.headlineSmall),
                  if (resource.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(resource.description, style: theme.textTheme.bodyMedium),
                  ],
                ],
              ),
            ),
            const SizedBox(width: WEAInsets.md),
            ElevatedButton.icon(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add, size: 18),
              label: Text('NEW ${resource.singular.toUpperCase()}'),
            ),
          ],
        ),
        const SizedBox(height: WEAInsets.lg),
        if (resource.filterBy != null)
          _ParentFilter(
            parentResource: resource.filterBy!.$2,
            selected: _parentId,
            onSelected: (value) => setState(() => _parentId = value),
          ),
        TextField(
          onChanged: (value) => setState(() => _search = value.toLowerCase()),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search, size: 20),
            hintText: 'Search ${resource.plural.toLowerCase()}',
          ),
        ),
        const SizedBox(height: WEAInsets.md),
        rows.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(WEAInsets.xl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => _ErrorPanel(
            message: error is CatalogueFailure
                ? error.message
                : 'We could not load this content.',
            onRetry: () => ref.invalidate(cmsListProvider(_query)),
          ),
          data: (items) {
            final visible = [
              for (final row in items)
                if (_search.isEmpty ||
                    '${row[resource.titleColumn] ?? ''}'
                        .toLowerCase()
                        .contains(_search))
                  row,
            ];
            if (visible.isEmpty) {
              return _EmptyPanel(
                resource: resource,
                filtered: _search.isNotEmpty || _parentId != null,
                onCreate: () => _openEditor(),
              );
            }
            return Column(
              children: [
                for (final row in visible)
                  _ResourceRow(
                    resource: resource,
                    row: row,
                    onEdit: () => _openEditor(row),
                    onDelete: () => _confirmDelete(row),
                    onStatus: (status) => _run(
                      () => ref
                          .read(cmsActionsProvider)
                          .setStatus(resource.name, '${row['id']}', status),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ParentFilter extends ConsumerWidget {
  const _ParentFilter({
    required this.parentResource,
    required this.selected,
    required this.onSelected,
  });

  final String parentResource;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(cmsOptionsProvider(parentResource));
    final parent = cmsResourceByName(parentResource);
    return Padding(
      padding: const EdgeInsets.only(bottom: WEAInsets.md),
      child: options.when(
        loading: () => const SizedBox.shrink(),
        error: (_, _) => const SizedBox.shrink(),
        data: (rows) => DropdownButtonFormField<String>(
          initialValue: selected,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Filter by ${parent.singular.toLowerCase()}',
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('— All —')),
            for (final row in rows)
              DropdownMenuItem(
                value: '${row['id']}',
                child: Text(
                  '${row[parent.titleColumn] ?? row['id']}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: onSelected,
        ),
      ),
    );
  }
}

class _ResourceRow extends StatelessWidget {
  const _ResourceRow({
    required this.resource,
    required this.row,
    required this.onEdit,
    required this.onDelete,
    required this.onStatus,
  });

  final CmsResource resource;
  final Map<String, dynamic> row;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<String> onStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = '${row['status'] ?? ''}';
    final subtitle = resource.subtitleColumn == null
        ? ''
        : '${row[resource.subtitleColumn] ?? ''}';

    return Container(
      margin: const EdgeInsets.only(bottom: WEAInsets.xs),
      padding: const EdgeInsets.all(WEAInsets.md),
      decoration: BoxDecoration(
        color: WEAColors.card,
        border: Border.all(color: WEAColors.border),
        borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${row[resource.titleColumn] ?? 'Untitled'}',
                  style: theme.textTheme.titleMedium,
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: WEAInsets.sm),
          if (resource.hasStatus && status.isNotEmpty) _StatusChip(status: status),
          const SizedBox(width: WEAInsets.xs),
          if (resource.hasStatus)
            IconButton(
              tooltip: status == 'PUBLISHED' ? 'Unpublish' : 'Publish',
              onPressed: () =>
                  onStatus(status == 'PUBLISHED' ? 'DRAFT' : 'PUBLISHED'),
              icon: Icon(
                status == 'PUBLISHED'
                    ? Icons.visibility_off_outlined
                    : Icons.public,
                size: 19,
              ),
            ),
          IconButton(
            tooltip: 'Edit',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 19),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, size: 19),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (tone, icon) = switch (status) {
      'PUBLISHED' => (WEAColors.success, Icons.public),
      'ARCHIVED' => (WEAColors.mutedText, Icons.inventory_2_outlined),
      'REGISTRATION_CLOSED' => (WEAColors.warning, Icons.lock_clock),
      'COMPLETED' => (WEAColors.mutedText, Icons.task_alt),
      'CANCELLED' => (WEAColors.error, Icons.cancel_outlined),
      _ => (WEAColors.warning, Icons.edit_note),
    };
    final label = statusLabel(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: .10),
        border: Border.all(color: tone.withValues(alpha: .34)),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: tone),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: tone),
          ),
        ],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.resource,
    required this.filtered,
    required this.onCreate,
  });

  final CmsResource resource;
  final bool filtered;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: WEAInsets.xxl),
    alignment: Alignment.center,
    child: Column(
      children: [
        Icon(resource.icon, size: 28, color: WEAColors.accent),
        const SizedBox(height: WEAInsets.sm),
        Text(
          filtered
              ? 'Nothing matches that filter'
              : 'No ${resource.plural.toLowerCase()} yet',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: WEAInsets.xs),
        Text(
          filtered
              ? 'Clear the search or filter to see everything.'
              : 'Create the first one — it appears on the public site as soon as you publish it.',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        if (!filtered) ...[
          const SizedBox(height: WEAInsets.md),
          OutlinedButton(
            onPressed: onCreate,
            child: Text('NEW ${resource.singular.toUpperCase()}'),
          ),
        ],
      ],
    ),
  );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(WEAInsets.xl),
    alignment: Alignment.center,
    child: Column(
      children: [
        const Icon(Icons.cloud_off_outlined, size: 26, color: WEAColors.mutedText),
        const SizedBox(height: WEAInsets.sm),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: WEAInsets.md),
        OutlinedButton(onPressed: onRetry, child: const Text('TRY AGAIN')),
      ],
    ),
  );
}

/// Create/edit form built from the resource descriptor.
class _CmsEditorDialog extends ConsumerStatefulWidget {
  const _CmsEditorDialog({required this.resource, this.existing});

  final CmsResource resource;
  final Map<String, dynamic>? existing;

  @override
  ConsumerState<_CmsEditorDialog> createState() => _CmsEditorDialogState();
}

class _CmsEditorDialogState extends ConsumerState<_CmsEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, Object?> _values = {
    for (final field in widget.resource.fields)
      field.column: widget.existing?[field.column],
  };
  var _saving = false;
  String? _error;

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final actions = ref.read(cmsActionsProvider);
      // Only send what the form actually holds; the API treats absent keys as
      // "leave unchanged".
      final payload = <String, dynamic>{
        for (final entry in _values.entries)
          if (entry.value != null) entry.key: entry.value,
      };
      if (widget.existing == null) {
        await actions.create(widget.resource.name, payload);
      } else {
        await actions.update(
          widget.resource.name,
          '${widget.existing!['id']}',
          payload,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on CatalogueFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = failure.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final resource = widget.resource;
    final editing = widget.existing != null;

    return Dialog(
      insetPadding: const EdgeInsets.all(WEAInsets.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 760),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(WEAInsets.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      editing
                          ? 'Edit ${resource.singular.toLowerCase()}'
                          : 'New ${resource.singular.toLowerCase()}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(WEAInsets.lg),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final field in resource.fields) ...[
                        CmsFieldEditor(
                          field: field,
                          value: _values[field.column],
                          onChanged: (value) => _values[field.column] = value,
                        ),
                        const SizedBox(height: WEAInsets.md),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: WEAInsets.lg),
                child: Text(
                  _error!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: WEAColors.error),
                ),
              ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(WEAInsets.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('CANCEL'),
                  ),
                  const SizedBox(width: WEAInsets.sm),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'SAVING…' : 'SAVE'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
