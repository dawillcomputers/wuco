import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../application/learner_providers.dart';
import '../../domain/learner_note.dart';
import 'learner_detail_widgets.dart';
import 'learner_lists.dart';
import 'learner_states.dart';

/// The learner's private notes against a lesson.
///
/// Writes go through [LearnerActions], so the panel never talks to a repository
/// directly and swapping in a backed store changes nothing here.
class LessonNotesPanel extends ConsumerStatefulWidget {
  const LessonNotesPanel({
    super.key,
    required this.courseId,
    required this.lessonId,
  });

  final String courseId;
  final String lessonId;

  @override
  ConsumerState<LessonNotesPanel> createState() => _LessonNotesPanelState();
}

class _LessonNotesPanelState extends ConsumerState<LessonNotesPanel> {
  final _controller = TextEditingController();
  String? _editingId;
  var _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ({String courseId, String lessonId}) get _key =>
      (courseId: widget.courseId, lessonId: widget.lessonId);

  Future<void> _save() async {
    final body = _controller.text.trim();
    if (body.isEmpty) return;
    setState(() => _saving = true);
    await ref
        .read(learnerActionsProvider)
        .saveNote(
          courseId: widget.courseId,
          lessonId: widget.lessonId,
          body: body,
          noteId: _editingId,
        );
    if (!mounted) return;
    _controller.clear();
    setState(() {
      _saving = false;
      _editingId = null;
    });
  }

  Future<void> _delete(LessonNote note) async {
    await ref
        .read(learnerActionsProvider)
        .deleteNote(
          courseId: widget.courseId,
          lessonId: widget.lessonId,
          noteId: note.id,
        );
    if (!mounted) return;
    if (_editingId == note.id) {
      _controller.clear();
      setState(() => _editingId = null);
    }
  }

  void _edit(LessonNote note) {
    _controller.text = note.body;
    setState(() => _editingId = note.id);
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(lessonNotesProvider(_key));

    return LearnerPanel(
      title: 'My notes',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            maxLines: 3,
            minLines: 2,
            decoration: InputDecoration(
              hintText: _editingId == null
                  ? 'Capture a thought while it is fresh…'
                  : 'Edit your note…',
            ),
          ),
          const SizedBox(height: WEAInsets.sm),
          Row(
            children: [
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: Text(_editingId == null ? 'SAVE NOTE' : 'UPDATE NOTE'),
              ),
              if (_editingId != null) ...[
                const SizedBox(width: WEAInsets.xs),
                TextButton(
                  onPressed: () {
                    _controller.clear();
                    setState(() => _editingId = null);
                  },
                  child: const Text('CANCEL'),
                ),
              ],
            ],
          ),
          const SizedBox(height: WEAInsets.md),
          notes.when(
            loading: () => const LearnerSkeleton(height: 48),
            error: (_, _) => Text(
              'We could not load your notes. They are safe — please try again.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            data: (items) => items.isEmpty
                ? Text(
                    'You have no notes on this lesson yet.',
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                : Column(
                    children: [
                      for (final note in items)
                        _NoteTile(
                          note: note,
                          onEdit: () => _edit(note),
                          onDelete: () => _delete(note),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({
    required this.note,
    required this.onEdit,
    required this.onDelete,
  });

  final LessonNote note;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: WEAInsets.xs),
      padding: const EdgeInsets.all(WEAInsets.sm),
      decoration: BoxDecoration(
        color: WEAColors.surfaceMuted,
        borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(note.body, style: theme.textTheme.bodyMedium),
          const SizedBox(height: WEAInsets.xs),
          Row(
            children: [
              Expanded(
                child: Text(
                  formatRelative(note.lastTouched),
                  style: theme.textTheme.bodySmall,
                ),
              ),
              IconButton(
                tooltip: 'Edit note',
                iconSize: 17,
                visualDensity: VisualDensity.compact,
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Delete note',
                iconSize: 17,
                visualDensity: VisualDensity.compact,
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
