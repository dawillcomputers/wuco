import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../data/services/public_content_service.dart';
import '../../../shared/components/wea_brand.dart';
import '../../../shared/components/wea_components.dart';
import '../../authentication/application/auth_controller.dart';
import '../../authentication/data/auth_repository.dart';
import '../../authentication/domain/account_status.dart';
import '../../authentication/domain/auth_failure.dart';
import '../../authentication/domain/user_profile.dart';
import '../../authentication/domain/user_role.dart';

/// The roles the signed-in administrator is actually allowed to grant.
///
/// Only an owner may hand out administrative authority. Offering a role the
/// API will refuse produces a 403 the operator cannot act on, so the choice is
/// narrowed here to match — the API still decides, this only stops the
/// interface promising something it cannot deliver.
List<UserRole> _grantableRoles(BuildContext context) {
  // Read through the container rather than a WidgetRef: these pickers live in
  // plain dialogs, and this keeps the rule in one place instead of threading
  // the actor's role through every constructor.
  final actor = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(currentRoleProvider);
  if (actor == UserRole.owner) return UserRole.values;
  return [
    for (final role in UserRole.values)
      if (!role.isPrivileged) role,
  ];
}

/// Minimal Super Admin console: account administration and programme places.
///
/// The full Super Admin dashboard belongs to a later module. This covers only
/// the operations needed to run the platform today — creating and removing
/// accounts, granting roles, and placing learners on programmes.
class SuperAdminConsole extends ConsumerStatefulWidget {
  const SuperAdminConsole({super.key});

  @override
  ConsumerState<SuperAdminConsole> createState() => _SuperAdminConsoleState();
}

class _SuperAdminConsoleState extends ConsumerState<SuperAdminConsole> {
  late Future<List<UserProfile>> _users;

  @override
  void initState() {
    super.initState();
    _users = ref.read(authControllerProvider.notifier).listUsers();
  }

  void _reload() {
    setState(() {
      _users = ref.read(authControllerProvider.notifier).listUsers();
    });
  }

  void _report(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? WEAColors.error : null,
      ),
    );
  }

  Future<void> _addUser() async {
    final result = await showDialog<({String email, UserRole role, String first, String last})>(
      context: context,
      builder: (context) => const _AddUserDialog(),
    );
    if (result == null) return;
    try {
      final created = await ref
          .read(authControllerProvider.notifier)
          .createUser(
            email: result.email,
            role: result.role,
            firstName: result.first,
            lastName: result.last,
          );
      _reload();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) =>
            _TemporaryPasswordDialog(credentials: created.credentials),
      );
    } on AuthFailure catch (failure) {
      _report(failure.message, error: true);
    }
  }

  Future<void> _deleteUser(UserProfile user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: Text(
          '${user.email} will be removed permanently, along with their '
          'programme places. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: WEAColors.error),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(authControllerProvider.notifier).deleteUser(user.id);
      _reload();
      _report('${user.email} was deleted.');
    } on AuthFailure catch (failure) {
      _report(failure.message, error: true);
    }
  }

  Future<void> _enrol(UserProfile user) async {
    final result = await showDialog<({String programmeId, bool waive})>(
      context: context,
      builder: (context) => _EnrolDialog(user: user),
    );
    if (result == null) return;
    try {
      await ref
          .read(authControllerProvider.notifier)
          .enrol(
            userId: user.id,
            programmeId: result.programmeId,
            waivePayment: result.waive,
          );
      _report(
        result.waive
            ? '${user.email} enrolled with payment waived.'
            : '${user.email} enrolled; payment pending.',
      );
    } on AuthFailure catch (failure) {
      _report(failure.message, error: true);
    }
  }

  /// Resets somebody's password for them.
  ///
  /// For the person who cannot receive the reset email, or who is on the
  /// telephone now. Confirmed first because it signs them out everywhere: a
  /// mis-click here ends whatever they were part-way through.
  Future<void> _resetPassword(UserProfile user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset password?'),
        content: Text(
          '${user.email} will be signed out everywhere and asked to choose a '
          'new password. A one-time link and a temporary password are emailed '
          'to them, and shown to you so you can pass them on.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('RESET PASSWORD'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final issued = await ref
          .read(authControllerProvider.notifier)
          .resetUserPassword(user.id, user.email);
      _reload();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => _TemporaryPasswordDialog(
          credentials: issued,
          title: 'Password reset',
        ),
      );
    } on AuthFailure catch (failure) {
      _report(failure.message, error: true);
    }
  }

  Future<void> _changeRole(UserProfile user) async {
    final role = await showDialog<UserRole>(
      context: context,
      builder: (context) => _RoleDialog(current: user.role),
    );
    if (role == null || role == user.role) return;
    try {
      await ref.read(authControllerProvider.notifier).setRole(user.id, role);
      _reload();
      _report('${user.email} is now ${role.label}.');
    } on AuthFailure catch (failure) {
      _report(failure.message, error: true);
    }
  }

  /// Suspends, disables or reactivates an account.
  ///
  /// Suspension is the tool for "stop this person now, decide later": it is
  /// reversible and keeps everything they have done, where deleting them does
  /// not.
  Future<void> _changeStatus(UserProfile user, AccountStatus status) async {
    if (status == user.status) return;
    try {
      await ref.read(authControllerProvider.notifier).setStatus(user.id, status);
      _reload();
      _report('${user.email} is now ${status.label.toLowerCase()}.');
    } on AuthFailure catch (failure) {
      _report(failure.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: WEAColors.background,
      appBar: AppBar(
        backgroundColor: WEAColors.navy,
        foregroundColor: WEAColors.offWhite,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 84,
        titleSpacing: WEAInsets.lg,
        title: const WEABrandLockup(height: 56, onDark: true, linkToHome: true),
        actions: [
          TextButton(
            onPressed: () => context.go('/super-admin/content'),
            style: TextButton.styleFrom(foregroundColor: WEAColors.offWhite),
            child: const Text('MANAGE CONTENT'),
          ),
          TextButton(
            onPressed: () => context.go('/profile'),
            style: TextButton.styleFrom(foregroundColor: WEAColors.offWhite),
            child: const Text('PROFILE'),
          ),
          Padding(
            padding: const EdgeInsets.only(
              left: WEAInsets.xs,
              right: WEAInsets.lg,
            ),
            child: SizedBox(
              height: 36,
              child: WEAOutlinedButton(
                label: 'SIGN OUT',
                compact: true,
                onDark: true,
                onPressed: () async {
                  await ref.read(authControllerProvider.notifier).signOut();
                  if (context.mounted) context.go('/');
                },
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: WEAContainer(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: WEAInsets.sectionSmall,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SUPER ADMINISTRATION',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: WEAColors.accent,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: WEAInsets.sm),
                Text('User management', style: theme.textTheme.displayMedium),
                const SizedBox(height: WEAInsets.md),
                Text(
                  'Create accounts with a one-time password, grant roles, place '
                  'learners on programmes and remove accounts.',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: WEAInsets.lg),
                Wrap(
                  spacing: WEAInsets.sm,
                  runSpacing: WEAInsets.sm,
                  children: [
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _addUser,
                        icon: const Icon(Icons.person_add_alt, size: 18),
                        label: const Text('ADD USER'),
                      ),
                    ),
                    WEAOutlinedButton(label: 'REFRESH', onPressed: _reload),
                  ],
                ),
                const SizedBox(height: WEAInsets.xl),
                FutureBuilder<List<UserProfile>>(
                  future: _users,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(WEAInsets.xl),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      final error = snapshot.error;
                      return WEAErrorState(
                        message: error is AuthFailure
                            ? error.message
                            : 'Unable to load accounts.',
                        onRetry: _reload,
                      );
                    }
                    final users = snapshot.data ?? const <UserProfile>[];
                    if (users.isEmpty) {
                      return const WEAEmptyState(
                        title: 'No accounts yet',
                        message: 'Create the first account to get started.',
                      );
                    }
                    return _UserTable(
                      users: users,
                      onDelete: _deleteUser,
                      onChangeStatus: _changeStatus,
                      onEnrol: _enrol,
                      onChangeRole: _changeRole,
                      onResetPassword: _resetPassword,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserTable extends StatelessWidget {
  const _UserTable({
    required this.users,
    required this.onDelete,
    required this.onEnrol,
    required this.onChangeRole,
    required this.onChangeStatus,
    required this.onResetPassword,
  });

  final List<UserProfile> users;
  final ValueChanged<UserProfile> onDelete;
  final ValueChanged<UserProfile> onEnrol;
  final ValueChanged<UserProfile> onChangeRole;
  final void Function(UserProfile, AccountStatus) onChangeStatus;
  final ValueChanged<UserProfile> onResetPassword;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: WEAColors.border),
      borderRadius: BorderRadius.circular(WEAInsets.radius),
    ),
    child: Column(
      children: [
        for (var index = 0; index < users.length; index++)
          Container(
            padding: const EdgeInsets.all(WEAInsets.md),
            decoration: BoxDecoration(
              border: index == 0
                  ? null
                  : const Border(
                      top: BorderSide(color: WEAColors.border),
                    ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final identity = _Identity(user: users[index]);
                final actions = _Actions(
                  user: users[index],
                  onDelete: onDelete,
                  onEnrol: onEnrol,
                  onChangeRole: onChangeRole,
                  onChangeStatus: onChangeStatus,
                  onResetPassword: onResetPassword,
                );
                if (constraints.maxWidth < 620) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      identity,
                      const SizedBox(height: WEAInsets.sm),
                      actions,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: identity),
                    actions,
                  ],
                );
              },
            ),
          ),
      ],
    ),
  );
}

class _Identity extends StatelessWidget {
  const _Identity({required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: WEAColors.elevated,
          foregroundColor: WEAColors.navy,
          child: Text(user.initials, style: theme.textTheme.labelSmall),
        ),
        const SizedBox(width: WEAInsets.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.fullName, style: theme.textTheme.titleMedium),
              Text(user.email, style: theme.textTheme.bodySmall),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                children: [
                  Text(
                    user.role.label.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: WEAColors.accent,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    '· ${user.status.label}',
                    style: theme.textTheme.labelSmall,
                  ),
                  if (user.mustChangePassword)
                    Text(
                      '· temporary password',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: WEAColors.warning,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.user,
    required this.onDelete,
    required this.onEnrol,
    required this.onChangeRole,
    required this.onChangeStatus,
    required this.onResetPassword,
  });

  final UserProfile user;
  final ValueChanged<UserProfile> onDelete;
  final ValueChanged<UserProfile> onEnrol;
  final ValueChanged<UserProfile> onChangeRole;
  final void Function(UserProfile, AccountStatus) onChangeStatus;
  final ValueChanged<UserProfile> onResetPassword;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: WEAInsets.xs,
    children: [
      IconButton(
        tooltip: 'Enrol on a programme',
        onPressed: () => onEnrol(user),
        icon: const Icon(Icons.school_outlined, size: 20),
      ),
      IconButton(
        tooltip: 'Change role',
        onPressed: () => onChangeRole(user),
        icon: const Icon(Icons.badge_outlined, size: 20),
      ),
      IconButton(
        tooltip: 'Reset password',
        onPressed: () => onResetPassword(user),
        icon: const Icon(Icons.lock_reset_outlined, size: 20),
      ),
      // Reversible measures first, and the irreversible one last.
      PopupMenuButton<AccountStatus>(
        tooltip: 'Change status',
        icon: const Icon(Icons.toggle_on_outlined, size: 20),
        onSelected: (status) => onChangeStatus(user, status),
        itemBuilder: (context) => [
          for (final status in AccountStatus.values)
            if (status != user.status && status != AccountStatus.pending)
              PopupMenuItem(
                value: status,
                child: Row(
                  children: [
                    Icon(_statusIcon(status), size: 18, color: _statusTone(status)),
                    const SizedBox(width: WEAInsets.sm),
                    Text(_statusAction(status)),
                  ],
                ),
              ),
        ],
      ),
      IconButton(
        tooltip: 'Delete account',
        onPressed: () => onDelete(user),
        icon: const Icon(Icons.delete_outline, size: 20),
        color: WEAColors.error,
      ),
    ],
  );
}

/// What choosing a status actually does, in the operator's words.
String _statusAction(AccountStatus status) => switch (status) {
  AccountStatus.active => 'Reactivate',
  AccountStatus.suspended => 'Suspend — they cannot sign in',
  AccountStatus.disabled => 'Disable permanently',
  AccountStatus.pendingApproval => 'Hold for approval',
  AccountStatus.pending => 'Mark pending',
};

IconData _statusIcon(AccountStatus status) => switch (status) {
  AccountStatus.active => Icons.check_circle_outline,
  AccountStatus.suspended => Icons.pause_circle_outline,
  AccountStatus.disabled => Icons.block,
  _ => Icons.schedule,
};

Color _statusTone(AccountStatus status) => switch (status) {
  AccountStatus.active => WEAColors.success,
  AccountStatus.suspended => WEAColors.warning,
  AccountStatus.disabled => WEAColors.error,
  _ => WEAColors.mutedText,
};

class _AddUserDialog extends StatefulWidget {
  const _AddUserDialog();

  @override
  State<_AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<_AddUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _first = TextEditingController();
  final _last = TextEditingController();
  var _role = UserRole.learner;

  @override
  void dispose() {
    _email.dispose();
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add user'),
    content: SizedBox(
      width: 420,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email address'),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return 'Enter an email address.';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
                  return 'Enter a valid email address.';
                }
                return null;
              },
            ),
            const SizedBox(height: WEAInsets.sm),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _first,
                    decoration: const InputDecoration(labelText: 'First name'),
                  ),
                ),
                const SizedBox(width: WEAInsets.sm),
                Expanded(
                  child: TextFormField(
                    controller: _last,
                    decoration: const InputDecoration(labelText: 'Last name'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: WEAInsets.sm),
            DropdownButtonFormField<UserRole>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Role'),
              items: [
                for (final role in _grantableRoles(context))
                  DropdownMenuItem(value: role, child: Text(role.label)),
              ],
              onChanged: (value) => setState(() => _role = value ?? _role),
            ),
            const SizedBox(height: WEAInsets.sm),
            Text(
              'The account is created with a one-time password that must be '
              'changed at first sign-in.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('CANCEL'),
      ),
      TextButton(
        onPressed: () {
          if (!(_formKey.currentState?.validate() ?? false)) return;
          Navigator.of(context).pop((
            email: _email.text.trim(),
            role: _role,
            first: _first.text.trim(),
            last: _last.text.trim(),
          ));
        },
        child: const Text('CREATE'),
      ),
    ],
  );
}

/// Shows the generated password once. It is not recoverable afterwards.
/// The sign-in details to pass to somebody, shown once.
///
/// Two ways in, because they are used differently. The link is what most
/// people will use — it opens straight onto "set your password" and needs
/// nothing typed — and the temporary password is for the person on the
/// telephone who cannot reach their email at all.
///
/// Both are emailed as well, so the account holder has them even if whoever
/// created the account passes nothing on.
class _TemporaryPasswordDialog extends StatelessWidget {
  const _TemporaryPasswordDialog({
    required this.credentials,
    this.title = 'Account created',
  });

  final IssuedCredentials credentials;
  final String title;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(title),
    content: SizedBox(
      width: 460,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sent to ${credentials.email}. You can also pass these on '
            'yourself.',
          ),
          if (credentials.hasLink) ...[
            const SizedBox(height: WEAInsets.md),
            _CopyableValue(
              label: 'SET-PASSWORD LINK',
              value: credentials.setPasswordUrl,
              monospace: false,
              hint: credentials.expiresAt == null
                  ? 'Works once, and expires an hour after it was issued.'
                  : 'Works once, and expires at '
                        '${_clock(credentials.expiresAt!)}.',
            ),
          ],
          const SizedBox(height: WEAInsets.md),
          _CopyableValue(
            label: 'TEMPORARY PASSWORD',
            value: credentials.temporaryPassword,
            monospace: true,
            hint: 'Shown only once. Must be changed at first sign-in.',
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('DONE'),
      ),
    ],
  );
}

/// A time as an operator would read it off a clock.
String _clock(DateTime when) {
  final local = when.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${local.hour < 12 ? 'am' : 'pm'}';
}

/// One value to hand over, with a button that copies it.
///
/// Selectable as well as copyable: a long link is awkward to select by hand,
/// and a password read off the screen has to be readable rather than merely
/// present.
class _CopyableValue extends StatefulWidget {
  const _CopyableValue({
    required this.label,
    required this.value,
    required this.hint,
    required this.monospace,
  });

  final String label;
  final String value;
  final String hint;
  final bool monospace;

  @override
  State<_CopyableValue> createState() => _CopyableValueState();
}

class _CopyableValueState extends State<_CopyableValue> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.value));
    if (!mounted) return;
    setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: WEAColors.mutedText,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(WEAInsets.sm),
          decoration: BoxDecoration(
            color: WEAColors.surfaceMuted,
            border: Border.all(color: WEAColors.border),
            borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: SelectableText(
                  widget.value,
                  style: widget.monospace
                      ? theme.textTheme.titleMedium?.copyWith(
                          fontFamily: 'monospace',
                          letterSpacing: 1.4,
                        )
                      : theme.textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: WEAInsets.xs),
              IconButton(
                onPressed: _copy,
                tooltip: _copied ? 'Copied' : 'Copy',
                icon: Icon(
                  _copied ? Icons.check : Icons.copy_outlined,
                  size: 18,
                  color: _copied ? WEAColors.accent : null,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(widget.hint, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _RoleDialog extends StatefulWidget {
  const _RoleDialog({required this.current});

  final UserRole current;

  @override
  State<_RoleDialog> createState() => _RoleDialogState();
}

class _RoleDialogState extends State<_RoleDialog> {
  late UserRole _role = widget.current;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Change role'),
    content: SizedBox(
      width: 360,
      child: RadioGroup<UserRole>(
        groupValue: _role,
        onChanged: (value) => setState(() => _role = value ?? _role),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final role in _grantableRoles(context))
              RadioListTile<UserRole>(
                value: role,
                title: Text(role.label),
                subtitle: role.isPrivileged
                    ? const Text('Privileged — grant deliberately')
                    : null,
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('CANCEL'),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(_role),
        child: const Text('APPLY'),
      ),
    ],
  );
}

class _EnrolDialog extends StatefulWidget {
  const _EnrolDialog({required this.user});

  final UserProfile user;

  @override
  State<_EnrolDialog> createState() => _EnrolDialogState();
}

class _EnrolDialogState extends State<_EnrolDialog> {
  String? _programmeId;
  var _waive = true;

  @override
  Widget build(BuildContext context) {
    final programmes = PublicContentService.programmes;
    return AlertDialog(
      title: const Text('Enrol on a programme'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Learner: ${widget.user.email}'),
            const SizedBox(height: WEAInsets.md),
            DropdownButtonFormField<String>(
              initialValue: _programmeId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Programme'),
              items: [
                for (final programme in programmes)
                  DropdownMenuItem(
                    value: programme.id,
                    child: Text(
                      programme.title,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _programmeId = value),
            ),
            const SizedBox(height: WEAInsets.sm),
            CheckboxListTile(
              value: _waive,
              onChanged: (value) => setState(() => _waive = value ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Waive payment'),
              subtitle: const Text(
                'Records the place as granted without payment.',
              ),
            ),
            Text(
              'An account may hold places on several programmes; enrolling '
              'again does not require a new account.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        TextButton(
          onPressed: _programmeId == null
              ? null
              : () => Navigator.of(
                  context,
                ).pop((programmeId: _programmeId!, waive: _waive)),
          child: const Text('ENROL'),
        ),
      ],
    );
  }
}
