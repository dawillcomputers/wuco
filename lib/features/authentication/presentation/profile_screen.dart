import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../shared/components/wea_brand.dart';
import '../../../shared/components/wea_components.dart';
import '../application/auth_controller.dart';
import '../domain/account_status.dart';
import '../domain/auth_state.dart';
import '../domain/user_profile.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  var _editing = false;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstName;
  late TextEditingController _lastName;
  late TextEditingController _phone;
  late TextEditingController _country;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(currentProfileProvider);
    _firstName = TextEditingController(text: profile?.firstName ?? '');
    _lastName = TextEditingController(text: profile?.lastName ?? '');
    _phone = TextEditingController(text: profile?.phone ?? '');
    _country = TextEditingController(text: profile?.country ?? '');
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _country.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ok = await ref
        .read(authControllerProvider.notifier)
        .updateProfile(
          firstName: _firstName.text,
          lastName: _lastName.text,
          phone: _phone.text,
          country: _country.text,
        );
    if (ok && mounted) setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final profile = auth.profile;
    final theme = Theme.of(context);

    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: WEAColors.background,
      appBar: AppBar(
        backgroundColor: WEAColors.navy,
        foregroundColor: WEAColors.offWhite,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 84,
        titleSpacing: WEAInsets.lg,
        title: const WEABrandLockup(height: 56, onDark: true),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: WEAInsets.lg),
            child: SizedBox(
              height: 36,
              child: WEAOutlinedButton(
                label: 'BACK',
                compact: true,
                onDark: true,
                onPressed: () => context.go(profile.role.landingRoute),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: WEAContainer(
            maxWidth: 720,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: WEAInsets.sectionSmall,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (auth is AuthError)
                    Padding(
                      padding: const EdgeInsets.only(bottom: WEAInsets.md),
                      child: Text(
                        auth.failure.message,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: WEAColors.error,
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: WEAColors.accent,
                        foregroundColor: Colors.white,
                        child: Text(
                          profile.initials,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: WEAInsets.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.fullName,
                              style: theme.textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              profile.email,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: WEAInsets.lg),
                  Wrap(
                    spacing: WEAInsets.xs,
                    runSpacing: WEAInsets.xs,
                    children: [
                      _Tag(label: profile.role.label, tone: WEAColors.accent),
                      _Tag(
                        label: profile.status.label,
                        tone: profile.status == AccountStatus.active
                            ? WEAColors.success
                            : WEAColors.warning,
                      ),
                      _Tag(
                        label: profile.emailVerified
                            ? 'Email verified'
                            : 'Email not verified',
                        tone: profile.emailVerified
                            ? WEAColors.success
                            : WEAColors.warning,
                      ),
                    ],
                  ),
                  const SizedBox(height: WEAInsets.xl),
                  const Divider(color: WEAColors.border),
                  const SizedBox(height: WEAInsets.lg),
                  if (_editing)
                    _EditForm(
                      formKey: _formKey,
                      firstName: _firstName,
                      lastName: _lastName,
                      phone: _phone,
                      country: _country,
                      busy: auth is AuthLoading,
                      onSave: _save,
                      onCancel: () => setState(() => _editing = false),
                    )
                  else
                    _Details(profile: profile),
                  const SizedBox(height: WEAInsets.xl),
                  if (!_editing)
                    Wrap(
                      spacing: WEAInsets.sm,
                      runSpacing: WEAInsets.sm,
                      children: [
                        WEAOutlinedButton(
                          label: 'EDIT PROFILE',
                          onPressed: () => setState(() => _editing = true),
                        ),
                        WEAOutlinedButton(
                          label: 'CHANGE PASSWORD',
                          onPressed: () => context.go('/change-password'),
                        ),
                        WEATextButton(
                          label: 'Log out',
                          onPressed: () async {
                            await ref
                                .read(authControllerProvider.notifier)
                                .signOut();
                            if (context.mounted) context.go('/');
                          },
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _Row(label: 'First name', value: profile.firstName),
      _Row(label: 'Last name', value: profile.lastName),
      _Row(label: 'Email', value: profile.email),
      _Row(label: 'Phone', value: profile.phone ?? '—'),
      _Row(label: 'Country', value: profile.country ?? '—'),
      _Row(label: 'Role', value: profile.role.label),
      _Row(label: 'Account status', value: profile.status.label),
    ],
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: WEAInsets.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 160,
          child: Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: WEAColors.mutedText,
              letterSpacing: 1.1,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '—' : value,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ],
    ),
  );
}

class _EditForm extends StatelessWidget {
  const _EditForm({
    required this.formKey,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.country,
    required this.busy,
    required this.onSave,
    required this.onCancel,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController firstName;
  final TextEditingController lastName;
  final TextEditingController phone;
  final TextEditingController country;
  final bool busy;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Form(
    key: formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Role and status are absent by design: a user cannot promote
        // themselves or change their own account state.
        TextFormField(
          controller: firstName,
          decoration: const InputDecoration(labelText: 'First name'),
          validator: (value) => (value == null || value.trim().isEmpty)
              ? 'Please enter your first name.'
              : null,
        ),
        const SizedBox(height: WEAInsets.md),
        TextFormField(
          controller: lastName,
          decoration: const InputDecoration(labelText: 'Last name'),
          validator: (value) => (value == null || value.trim().isEmpty)
              ? 'Please enter your last name.'
              : null,
        ),
        const SizedBox(height: WEAInsets.md),
        TextFormField(
          controller: phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Phone'),
        ),
        const SizedBox(height: WEAInsets.md),
        TextFormField(
          controller: country,
          decoration: const InputDecoration(labelText: 'Country'),
        ),
        const SizedBox(height: WEAInsets.lg),
        Row(
          children: [
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: busy ? null : onSave,
                child: Text(busy ? 'Saving…' : 'SAVE CHANGES'),
              ),
            ),
            const SizedBox(width: WEAInsets.sm),
            WEATextButton(label: 'Cancel', onPressed: onCancel),
          ],
        ),
      ],
    ),
  );
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.tone});

  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: tone.withValues(alpha: .10),
      border: Border.all(color: tone.withValues(alpha: .40)),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: tone),
    ),
  );
}
