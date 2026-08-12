import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../domain/contact_models.dart';

/// One enquiry and its conversation.
///
/// Shared by the public contact page and the office view, so a reply reads the
/// same to both sides. [onFollowUp] is omitted where replying is not offered.
class EnquiryThread extends StatefulWidget {
  const EnquiryThread({
    super.key,
    required this.enquiry,
    this.onFollowUp,
    this.replyLabel = 'SEND FOLLOW-UP',
    this.trailing,
    this.showSender = false,
    this.initiallyExpanded = false,
  });

  final Enquiry enquiry;
  final Future<void> Function(String body)? onFollowUp;
  final String replyLabel;
  final Widget? trailing;

  /// The office needs to see who sent it; the sender does not.
  final bool showSender;
  final bool initiallyExpanded;

  @override
  State<EnquiryThread> createState() => _EnquiryThreadState();
}

class _EnquiryThreadState extends State<EnquiryThread> {
  final _reply = TextEditingController();
  late bool _expanded = widget.initiallyExpanded;
  var _sending = false;
  String? _error;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _when(DateTime? moment) {
    if (moment == null) return '';
    final time =
        '${moment.hour.toString().padLeft(2, '0')}:'
        '${moment.minute.toString().padLeft(2, '0')}';
    return '${moment.day} ${_months[moment.month - 1]} ${moment.year} · $time';
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _reply.text.trim();
    if (body.isEmpty) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.onFollowUp!(body);
      if (!mounted) return;
      _reply.clear();
      setState(() => _sending = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = 'That could not be sent. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enquiry = widget.enquiry;

    return Container(
      margin: const EdgeInsets.only(bottom: WEAInsets.md),
      decoration: BoxDecoration(
        color: WEAColors.card,
        border: Border.all(color: WEAColors.border),
        borderRadius: BorderRadius.circular(WEAInsets.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(WEAInsets.radius),
            child: Padding(
              padding: const EdgeInsets.all(WEAInsets.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              enquiry.reference,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: WEAColors.accent,
                              ),
                            ),
                            const SizedBox(width: WEAInsets.xs),
                            _StatusChip(status: enquiry.status),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          enquiry.subject.isEmpty
                              ? 'General enquiry'
                              : enquiry.subject,
                          style: theme.textTheme.titleMedium,
                        ),
                        if (widget.showSender) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${enquiry.name} · ${enquiry.email}'
                            '${enquiry.organisation.isEmpty ? '' : ' · ${enquiry.organisation}'}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: 2),
                        Text(
                          [
                            _when(enquiry.createdAt),
                            if (enquiry.replies.isNotEmpty)
                              '${enquiry.replies.length} '
                                  '${enquiry.replies.length == 1 ? 'reply' : 'replies'}',
                          ].where((part) => part.isNotEmpty).join(' · '),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (widget.trailing != null) ...[
                    const SizedBox(width: WEAInsets.sm),
                    widget.trailing!,
                  ],
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: WEAColors.mutedText,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(WEAInsets.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Bubble(
                    body: enquiry.message,
                    author: widget.showSender ? enquiry.name : 'You',
                    when: _when(enquiry.createdAt),
                    fromAcademy: false,
                  ),
                  for (final reply in enquiry.replies)
                    _Bubble(
                      body: reply.body,
                      author: reply.fromAcademy
                          ? (reply.authorName.isEmpty
                                ? 'WUCO Executive Academy'
                                : '${reply.authorName} · WEA')
                          : (widget.showSender ? enquiry.name : 'You'),
                      when: _when(reply.createdAt),
                      fromAcademy: reply.fromAcademy,
                    ),
                  if (widget.onFollowUp != null) ...[
                    const SizedBox(height: WEAInsets.sm),
                    TextField(
                      controller: _reply,
                      maxLines: 3,
                      minLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'Write a reply…',
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: WEAInsets.xs),
                      Text(
                        _error!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: WEAColors.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: WEAInsets.sm),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton(
                        onPressed: _sending ? null : _send,
                        child: Text(_sending ? 'SENDING…' : widget.replyLabel),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.body,
    required this.author,
    required this.when,
    required this.fromAcademy,
  });

  final String body;
  final String author;
  final String when;
  final bool fromAcademy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: WEAInsets.sm),
      padding: const EdgeInsets.all(WEAInsets.md),
      decoration: BoxDecoration(
        // An academy reply is tinted and carries its author, so the two sides
        // of the conversation are never confused.
        color: fromAcademy
            ? WEAColors.accent.withValues(alpha: .07)
            : WEAColors.surfaceMuted,
        border: Border.all(
          color: fromAcademy
              ? WEAColors.accent.withValues(alpha: .28)
              : WEAColors.border,
        ),
        borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                fromAcademy ? Icons.school_outlined : Icons.person_outline,
                size: 14,
                color: fromAcademy ? WEAColors.accent : WEAColors.mutedText,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  author,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: fromAcademy
                        ? WEAColors.accentDeep
                        : WEAColors.mutedText,
                    letterSpacing: 1,
                  ),
                ),
              ),
              Text(when, style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: WEAInsets.xs),
          SelectableText(body, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final EnquiryStatus status;

  @override
  Widget build(BuildContext context) {
    final (tone, icon) = switch (status) {
      EnquiryStatus.isNew => (WEAColors.warning, Icons.fiber_new_outlined),
      EnquiryStatus.read => (WEAColors.mutedText, Icons.drafts_outlined),
      EnquiryStatus.replied => (WEAColors.success, Icons.reply),
      EnquiryStatus.closed => (WEAColors.mutedText, Icons.check_circle_outline),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: .10),
        border: Border.all(color: tone.withValues(alpha: .34)),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: tone),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: tone),
          ),
        ],
      ),
    );
  }
}
