import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../catalogue/domain/catalogue_models.dart';
import '../../application/cms_providers.dart';
import 'cms_schema.dart';

/// Renders one editable field.
///
/// The editor is chosen from the field descriptor, so a new managed column
/// needs a descriptor entry rather than a bespoke widget.
class CmsFieldEditor extends ConsumerWidget {
  const CmsFieldEditor({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
  });

  final CmsField field;
  final Object? value;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (field.kind) {
      case CmsFieldKind.toggle:
        return SwitchListTile.adaptive(
          value: value == true || value == 1 || value == '1',
          onChanged: (next) => onChanged(next ? 1 : 0),
          contentPadding: EdgeInsets.zero,
          title: Text(field.label),
          subtitle: field.help.isEmpty ? null : Text(field.help),
        );

      case CmsFieldKind.status:
        // Most content is draft/published/archived, but some entities have a
        // longer life — an event closes registration and then completes — so
        // the descriptor may name its own statuses.
        final statuses = field.options.isEmpty
            ? const ['DRAFT', 'PUBLISHED', 'ARCHIVED']
            : field.options;
        final current = '${value ?? 'DRAFT'}';
        return DropdownButtonFormField<String>(
          initialValue: statuses.contains(current) ? current : statuses.first,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: field.label,
            helperText: field.help.isEmpty ? null : field.help,
          ),
          items: [
            for (final status in statuses)
              DropdownMenuItem(value: status, child: Text(statusLabel(status))),
          ],
          onChanged: onChanged,
        );

      case CmsFieldKind.select:
        final current = '${value ?? ''}';
        return DropdownButtonFormField<String>(
          initialValue: field.options.contains(current) ? current : null,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: field.label,
            helperText: field.help.isEmpty ? null : field.help,
          ),
          items: [
            for (final option in field.options)
              DropdownMenuItem(value: option, child: Text(field.labelFor(option))),
          ],
          onChanged: onChanged,
        );

      case CmsFieldKind.reference:
        return _ReferenceField(
          field: field,
          value: value == null ? '' : '$value',
          onChanged: onChanged,
        );

      case CmsFieldKind.image:
        return _ImageField(
          field: field,
          value: value == null ? '' : '$value',
          onChanged: onChanged,
        );

      case CmsFieldKind.stringList:
        return _StringListField(field: field, value: value, onChanged: onChanged);

      case CmsFieldKind.date:
      case CmsFieldKind.dateTime:
        return _DateField(
          field: field,
          value: value == null ? '' : '$value',
          onChanged: onChanged,
          withTime: field.kind == CmsFieldKind.dateTime,
        );

      default:
        return _TextField(field: field, value: value, onChanged: onChanged);
    }
  }
}

class _TextField extends StatefulWidget {
  const _TextField({
    required this.field,
    required this.value,
    required this.onChanged,
  });

  final CmsField field;
  final Object? value;
  final ValueChanged<Object?> onChanged;

  @override
  State<_TextField> createState() => _TextFieldState();
}

class _TextFieldState extends State<_TextField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value == null ? '' : '${widget.value}',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _lines => switch (widget.field.kind) {
    CmsFieldKind.richText => 8,
    CmsFieldKind.multiline => 3,
    _ => 1,
  };

  @override
  Widget build(BuildContext context) {
    final numeric =
        widget.field.kind == CmsFieldKind.number ||
        widget.field.kind == CmsFieldKind.currency;
    return TextFormField(
      controller: _controller,
      maxLines: _lines,
      minLines: _lines > 1 ? _lines : 1,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: widget.field.label,
        helperText: widget.field.help.isEmpty ? null : widget.field.help,
      ),
      validator: widget.field.required
          ? (value) => (value?.trim().isEmpty ?? true)
                ? 'Please provide the ${widget.field.label.toLowerCase()}.'
                : null
          : null,
      onChanged: (text) => widget.onChanged(
        numeric ? (num.tryParse(text.trim()) ?? 0) : text,
      ),
    );
  }
}

/// A date, or a date and a time, chosen from a picker.
///
/// Typing an ISO timestamp by hand is how a launch date ends up a year out, so
/// the field is read-only and opens a calendar — then a clock where the column
/// stores a time as well. The stored format is exactly what the API expects:
/// `YYYY-MM-DD` for a date, `YYYY-MM-DDTHH:MM:SS` for a moment.
class _DateField extends StatefulWidget {
  const _DateField({
    required this.field,
    required this.value,
    required this.onChanged,
    required this.withTime,
  });

  final CmsField field;
  final String value;
  final ValueChanged<Object?> onChanged;
  final bool withTime;

  @override
  State<_DateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<_DateField> {
  late DateTime? _value = _parse(widget.value);

  static DateTime? _parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    // Accepts both the ISO form and SQLite's "2026-09-25 09:00:00".
    return DateTime.tryParse(text.contains(' ') ? text.replaceFirst(' ', 'T') : text);
  }

  String _format(DateTime value) {
    final date =
        '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
    if (!widget.withTime) return date;
    final time =
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}:00';
    return '${date}T$time';
  }

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  /// What the operator reads, rather than what the column stores.
  String get _readable {
    final value = _value;
    if (value == null) return '';
    final date = '${value.day} ${_months[value.month - 1]} ${value.year}';
    if (!widget.withTime) return date;
    final time =
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
    return '$date at $time';
  }

  Future<void> _pick() async {
    final now = DateTime.now();
    final current = _value ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      // Wide enough for a past event being recorded and one years ahead.
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (date == null || !mounted) return;

    var chosen = DateTime(date.year, date.month, date.day);
    if (widget.withTime) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(current),
      );
      if (!mounted) return;
      // Cancelling the clock keeps the date, at midnight, rather than
      // discarding a choice the operator has already made.
      if (time != null) {
        chosen = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      }
    }

    setState(() => _value = chosen);
    widget.onChanged(_format(chosen));
  }

  void _clear() {
    setState(() => _value = null);
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: _pick,
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: widget.field.label,
        helperText: widget.field.help.isEmpty ? null : widget.field.help,
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_value != null)
              IconButton(
                tooltip: 'Clear',
                onPressed: _clear,
                icon: const Icon(Icons.close, size: 18),
              ),
            Icon(
              widget.withTime ? Icons.event_outlined : Icons.calendar_today_outlined,
              size: 19,
              color: WEAColors.accent,
            ),
            const SizedBox(width: WEAInsets.sm),
          ],
        ),
      ),
      child: Text(
        _readable.isEmpty ? 'Choose a date' : _readable,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: _readable.isEmpty ? WEAColors.mutedText : WEAColors.primaryText,
        ),
      ),
    ),
  );
}

/// A list edited as one line per entry, stored as a JSON array.
class _StringListField extends StatefulWidget {
  const _StringListField({
    required this.field,
    required this.value,
    required this.onChanged,
  });

  final CmsField field;
  final Object? value;
  final ValueChanged<Object?> onChanged;

  @override
  State<_StringListField> createState() => _StringListFieldState();
}

class _StringListFieldState extends State<_StringListField> {
  late final TextEditingController _controller = TextEditingController(
    text: _decode(widget.value).join('\n'),
  );

  static List<String> _decode(Object? value) {
    if (value is List) return [for (final item in value) '$item'];
    final text = '${value ?? ''}'.trim();
    if (text.isEmpty || text == '[]') return const [];
    // Stored as a JSON array; fall back to treating it as plain text.
    if (text.startsWith('[')) {
      return text
          .substring(1, text.length - 1)
          .split('","')
          .map((part) => part.replaceAll('"', '').trim())
          .where((part) => part.isNotEmpty)
          .toList();
    }
    return [text];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: _controller,
    maxLines: 5,
    minLines: 3,
    decoration: InputDecoration(
      labelText: widget.field.label,
      helperText: widget.field.help.isEmpty
          ? 'One entry per line.'
          : widget.field.help,
    ),
    onChanged: (text) => widget.onChanged([
      for (final line in text.split('\n'))
        if (line.trim().isNotEmpty) line.trim(),
    ]),
  );
}

/// Picks a row from another resource, e.g. the area a programme belongs to.
class _ReferenceField extends ConsumerWidget {
  const _ReferenceField({
    required this.field,
    required this.value,
    required this.onChanged,
  });

  final CmsField field;
  final String value;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(cmsOptionsProvider(field.referenceResource!));
    return options.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => Text('Could not load ${field.label.toLowerCase()}.'),
      data: (rows) {
        final ids = rows.map((row) => '${row['id']}').toSet();
        return DropdownButtonFormField<String>(
          initialValue: ids.contains(value) ? value : null,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: field.label,
            helperText: field.help.isEmpty ? null : field.help,
          ),
          items: [
            if (!field.required)
              const DropdownMenuItem(value: '', child: Text('— None —')),
            for (final row in rows)
              DropdownMenuItem(
                value: '${row['id']}',
                child: Text(
                  '${row[field.referenceLabelColumn] ?? row['title'] ?? row['id']}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          validator: field.required
              ? (selected) => (selected == null || selected.isEmpty)
                    ? 'Please choose a ${field.label.toLowerCase()}.'
                    : null
              : null,
          onChanged: (selected) =>
              onChanged(selected == null || selected.isEmpty ? null : selected),
        );
      },
    );
  }
}

/// Uploads an image and stores its asset key.
///
/// This is what makes artwork editable without a release: the operator picks a
/// file, it goes to R2 through the Worker, and the returned key is saved on the
/// row.
class _ImageField extends ConsumerStatefulWidget {
  const _ImageField({
    required this.field,
    required this.value,
    required this.onChanged,
  });

  final CmsField field;
  final String value;
  final ValueChanged<Object?> onChanged;

  @override
  ConsumerState<_ImageField> createState() => _ImageFieldState();
}

class _ImageFieldState extends ConsumerState<_ImageField> {
  late String _key = widget.value;
  var _busy = false;
  String? _error;

  static const _mimeByExtension = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'gif': 'image/gif',
    'svg': 'image/svg+xml',
    'pdf': 'application/pdf',
  };

  Future<void> _pick() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'gif', 'svg'],
        // Required on web, where there is no readable file path.
        withData: true,
      );
      final file = result?.files.singleOrNull;
      final bytes = file?.bytes;
      if (file == null || bytes == null) {
        setState(() => _busy = false);
        return;
      }
      final extension = (file.extension ?? 'jpg').toLowerCase();
      final key = await ref
          .read(cmsActionsProvider)
          .uploadImage(
            bytes: bytes,
            filename: file.name,
            contentType: _mimeByExtension[extension] ?? 'image/jpeg',
          );
      if (!mounted) return;
      setState(() {
        _key = key;
        _busy = false;
      });
      widget.onChanged(key);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'That image could not be uploaded. Please try another file.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = resolveMediaUrl(imageKey: _key);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.field.label, style: theme.textTheme.labelLarge),
        const SizedBox(height: WEAInsets.xs),
        Container(
          padding: const EdgeInsets.all(WEAInsets.sm),
          decoration: BoxDecoration(
            border: Border.all(color: WEAColors.border),
            borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
          ),
          child: Row(
            children: [
              Container(
                width: 96,
                height: 64,
                decoration: BoxDecoration(
                  color: WEAColors.elevated,
                  borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
                ),
                clipBehavior: Clip.antiAlias,
                child: preview == null
                    ? const Icon(
                        Icons.image_outlined,
                        color: WEAColors.mutedText,
                      )
                    : Image.network(
                        preview,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.broken_image_outlined,
                          color: WEAColors.mutedText,
                        ),
                      ),
              ),
              const SizedBox(width: WEAInsets.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _key.isEmpty ? 'No image uploaded' : _key,
                      style: theme.textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: WEAInsets.xs),
                    Wrap(
                      spacing: WEAInsets.xs,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _pick,
                          icon: _busy
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.upload_outlined, size: 16),
                          label: Text(
                            _busy
                                ? 'UPLOADING…'
                                : _key.isEmpty
                                ? 'UPLOAD IMAGE'
                                : 'REPLACE',
                          ),
                        ),
                        if (_key.isNotEmpty && !_busy)
                          TextButton(
                            onPressed: () {
                              setState(() => _key = '');
                              widget.onChanged('');
                            },
                            child: const Text('REMOVE'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: WEAInsets.xs),
          Text(
            _error!,
            style: theme.textTheme.bodySmall?.copyWith(color: WEAColors.error),
          ),
        ],
      ],
    );
  }
}
