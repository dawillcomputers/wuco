import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../authentication/application/auth_controller.dart';
import '../../../authentication/domain/user_profile.dart';
import '../../application/learner_providers.dart';
import '../../domain/learner_profile.dart';
import 'learner_detail_widgets.dart';

/// Editing form for the learner's own profile.
///
/// Writes split by ownership: identity fields go to the auth controller,
/// professional fields to the learner repository. Role, status and email are
/// absent by design — a learner cannot promote or re-identify themselves.
class ProfileEditForm extends ConsumerStatefulWidget {
  const ProfileEditForm({
    super.key,
    required this.account,
    required this.learner,
    required this.onDone,
  });

  final UserProfile account;
  final LearnerProfile learner;
  final VoidCallback onDone;

  @override
  ConsumerState<ProfileEditForm> createState() => _ProfileEditFormState();
}

class _ProfileEditFormState extends ConsumerState<ProfileEditForm> {
  final _formKey = GlobalKey<FormState>();
  late final _firstName = TextEditingController(text: widget.account.firstName);
  late final _lastName = TextEditingController(text: widget.account.lastName);
  late final _phone = TextEditingController(text: widget.account.phone ?? '');
  late final _country = TextEditingController(
    text: widget.account.country ?? '',
  );
  late final _city = TextEditingController(text: widget.learner.city ?? '');
  late final _title = TextEditingController(
    text: widget.learner.professionalTitle,
  );
  late final _organisation = TextEditingController(
    text: widget.learner.organisation,
  );
  late final _bio = TextEditingController(text: widget.learner.bio);
  late final _expertise = TextEditingController(
    text: widget.learner.expertise.join(', '),
  );
  late final _linkedIn = TextEditingController(
    text: widget.learner.linkedInUrl ?? '',
  );
  late final _website = TextEditingController(
    text: widget.learner.websiteUrl ?? '',
  );

  late var _visibility = widget.learner.visibility;
  var _saving = false;

  @override
  void dispose() {
    for (final controller in [
      _firstName,
      _lastName,
      _phone,
      _country,
      _city,
      _title,
      _organisation,
      _bio,
      _expertise,
      _linkedIn,
      _website,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _optionalUrl(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return 'Enter a full web address, including https://';
    }
    return null;
  }

  String? _emptyToNull(String value) =>
      value.trim().isEmpty ? null : value.trim();

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    await ref
        .read(authControllerProvider.notifier)
        .updateProfile(
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          phone: _phone.text.trim(),
          country: _country.text.trim(),
        );

    await ref
        .read(learnerActionsProvider)
        .saveProfile(
          widget.learner.copyWith(
            professionalTitle: _title.text.trim(),
            organisation: _organisation.text.trim(),
            bio: _bio.text.trim(),
            city: _city.text.trim(),
            visibility: _visibility,
            linkedInUrl: _emptyToNull(_linkedIn.text),
            websiteUrl: _emptyToNull(_website.text),
            expertise: [
              for (final part in _expertise.text.split(','))
                if (part.trim().isNotEmpty) part.trim(),
            ],
          ),
        );

    if (!mounted) return;
    setState(() => _saving = false);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final twoColumn = MediaQuery.sizeOf(context).width >= 720;

    Widget pair(Widget left, Widget right) => twoColumn
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              const SizedBox(width: WEAInsets.md),
              Expanded(child: right),
            ],
          )
        : Column(
            children: [
              left,
              const SizedBox(height: WEAInsets.md),
              right,
            ],
          );

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LearnerPanel(
            title: 'Personal details',
            child: Column(
              children: [
                pair(
                  TextFormField(
                    controller: _firstName,
                    decoration: const InputDecoration(labelText: 'First name'),
                    textInputAction: TextInputAction.next,
                    validator: (value) => (value?.trim().isEmpty ?? true)
                        ? 'Please enter your first name.'
                        : null,
                  ),
                  TextFormField(
                    controller: _lastName,
                    decoration: const InputDecoration(labelText: 'Last name'),
                    textInputAction: TextInputAction.next,
                    validator: (value) => (value?.trim().isEmpty ?? true)
                        ? 'Please enter your last name.'
                        : null,
                  ),
                ),
                const SizedBox(height: WEAInsets.md),
                pair(
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone number',
                    ),
                  ),
                  TextFormField(
                    controller: _country,
                    decoration: const InputDecoration(labelText: 'Country'),
                  ),
                ),
                const SizedBox(height: WEAInsets.md),
                TextFormField(
                  controller: _city,
                  decoration: const InputDecoration(labelText: 'City'),
                ),
                const SizedBox(height: WEAInsets.md),
                TextFormField(
                  initialValue: widget.account.email,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    helperText:
                        'Your sign-in email is managed in account security.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: WEAInsets.lg),
          LearnerPanel(
            title: 'Professional details',
            child: Column(
              children: [
                pair(
                  TextFormField(
                    controller: _title,
                    decoration: const InputDecoration(
                      labelText: 'Professional title',
                    ),
                  ),
                  TextFormField(
                    controller: _organisation,
                    decoration: const InputDecoration(
                      labelText: 'Organisation',
                    ),
                  ),
                ),
                const SizedBox(height: WEAInsets.md),
                TextFormField(
                  controller: _bio,
                  maxLines: 4,
                  minLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Professional biography',
                  ),
                ),
                const SizedBox(height: WEAInsets.md),
                TextFormField(
                  controller: _expertise,
                  decoration: const InputDecoration(
                    labelText: 'Areas of expertise',
                    helperText: 'Separate each area with a comma.',
                  ),
                ),
                const SizedBox(height: WEAInsets.md),
                pair(
                  TextFormField(
                    controller: _linkedIn,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'LinkedIn profile',
                      hintText: 'https://linkedin.com/in/…',
                    ),
                    validator: _optionalUrl,
                  ),
                  TextFormField(
                    controller: _website,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Website',
                      hintText: 'https://…',
                    ),
                    validator: _optionalUrl,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: WEAInsets.lg),
          LearnerPanel(
            title: 'Who can see this profile',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final option in ProfileVisibility.values)
                  Semantics(
                    inMutuallyExclusiveGroup: true,
                    selected: option == _visibility,
                    label: '${option.label}. ${option.description}',
                    child: ListTile(
                      onTap: () => setState(() => _visibility = option),
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        option == _visibility
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: option == _visibility
                            ? WEAColors.accent
                            : WEAColors.mutedText,
                      ),
                      title: Text(option.label),
                      subtitle: Text(
                        option.description,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: WEAInsets.lg),
          Row(
            children: [
              SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'SAVING…' : 'SAVE PROFILE'),
                ),
              ),
              const SizedBox(width: WEAInsets.sm),
              TextButton(
                onPressed: _saving ? null : widget.onDone,
                child: const Text('CANCEL'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
