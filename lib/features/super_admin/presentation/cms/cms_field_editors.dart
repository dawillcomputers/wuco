import 'dart:convert';

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

      case CmsFieldKind.prices:
        return _PricesField(field: field, value: value, onChanged: onChanged);

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

/// The currencies this is sold in, and the amount charged in each.
///
/// A selector, not a text box. The academy switches a currency on and types
/// what it charges in it — because **WEA never converts**, so each price is a
/// number somebody here chose rather than one derived from another. Switching
/// a currency off is how the academy stops selling in it.
///
/// It reads the stored `{"NGN": 150000}` map back, which it has to: the editor
/// resends every field on save, so a price this could not parse would be a
/// price it silently deleted from any event somebody merely opened.
class _PricesField extends StatefulWidget {
  const _PricesField({
    required this.field,
    required this.value,
    required this.onChanged,
  });

  final CmsField field;
  final Object? value;
  final ValueChanged<Object?> onChanged;

  @override
  State<_PricesField> createState() => _PricesFieldState();
}

/// The currencies the academy sells in, in the order they are offered.
const _sellableCurrencies = <({String code, String name, String symbol})>[
  (code: 'NGN', name: 'Nigerian Naira', symbol: '₦'),
  (code: 'USD', name: 'US Dollar', symbol: r'$'),
  (code: 'GBP', name: 'Pound Sterling', symbol: '£'),
  (code: 'EUR', name: 'Euro', symbol: '€'),
];

class _PricesFieldState extends State<_PricesField> {
  late final Map<String, TextEditingController> _amounts = {
    for (final currency in _sellableCurrencies)
      currency.code: TextEditingController(
        text: _plain(_decode(widget.value)[currency.code]),
      ),
  };

  late final Set<String> _active = _decode(widget.value).keys.toSet();

  /// The stored value as a currency map, however it arrived.
  static Map<String, double> _decode(Object? value) {
    final raw = value is Map ? value : _parse(value);
    if (raw == null) return {};

    final prices = <String, double>{};
    for (final entry in raw.entries) {
      final code = '${entry.key}'.trim().toUpperCase();
      final amount = entry.value is num
          ? (entry.value as num).toDouble()
          : double.tryParse('${entry.value}') ?? 0;
      if (code.length == 3 && amount > 0) prices[code] = amount;
    }
    return prices;
  }

  static Map<Object?, Object?>? _parse(Object? value) {
    final text = '${value ?? ''}'.trim();
    if (!text.startsWith('{')) return null;
    try {
      final parsed = jsonDecode(text);
      return parsed is Map ? parsed : null;
    } on FormatException {
      return null;
    }
  }

  /// An amount without the trailing `.0` a double would print.
  static String _plain(double? amount) {
    if (amount == null || amount <= 0) return '';
    return amount == amount.truncateToDouble()
        ? amount.toStringAsFixed(0)
        : '$amount';
  }

  /// Emits the map. A currency switched off, or with no amount typed yet, is
  /// absent — which is exactly what "not sold in that currency" means to
  /// everything downstream.
  void _emit() {
    final prices = <String, double>{};
    for (final currency in _sellableCurrencies) {
      if (!_active.contains(currency.code)) continue;
      final amount = double.tryParse(
        _amounts[currency.code]!.text.replaceAll(',', '').trim(),
      );
      if (amount != null && amount > 0) prices[currency.code] = amount;
    }
    widget.onChanged(prices);
  }

  @override
  void dispose() {
    for (final controller in _amounts.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.field.label, style: theme.textTheme.labelLarge),
        if (widget.field.help.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            widget.field.help,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ],
        const SizedBox(height: 8),
        for (final currency in _sellableCurrencies)
          _CurrencyAmountRow(
            code: currency.code,
            name: currency.name,
            symbol: currency.symbol,
            active: _active.contains(currency.code),
            controller: _amounts[currency.code]!,
            onToggled: (on) => setState(() {
              if (on) {
                _active.add(currency.code);
              } else {
                _active.remove(currency.code);
                // Cleared as well as switched off, so switching it back on
                // does not silently restore a price the academy removed.
                _amounts[currency.code]!.clear();
              }
              _emit();
            }),
            onAmountChanged: (_) => _emit(),
          ),
      ],
    );
  }
}

/// One currency: whether it is sold in, and what it costs.
class _CurrencyAmountRow extends StatelessWidget {
  const _CurrencyAmountRow({
    required this.code,
    required this.name,
    required this.symbol,
    required this.active,
    required this.controller,
    required this.onToggled,
    required this.onAmountChanged,
  });

  final String code;
  final String name;
  final String symbol;
  final bool active;
  final TextEditingController controller;
  final ValueChanged<bool> onToggled;
  final ValueChanged<String> onAmountChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Switch(value: active, onChanged: onToggled),
          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(code, style: theme.textTheme.titleSmall),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: controller,
              enabled: active,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                isDense: true,
                prefixText: '$symbol ',
                hintText: active ? 'Amount' : 'Not sold in $code',
                border: const OutlineInputBorder(),
              ),
              onChanged: onAmountChanged,
              validator: (value) {
                if (!active) return null;
                final amount = double.tryParse(
                  (value ?? '').replaceAll(',', '').trim(),
                );
                // A currency switched on with no amount would be a price of
                // nothing, which is worse than not offering the currency.
                if (amount == null || amount <= 0) return 'Set an amount';
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }
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
