import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../shared/components/wea_components.dart';
import '../../../shared/widgets/wea_public_widgets.dart';
import '../../authentication/application/auth_controller.dart';
import '../../catalogue/application/catalogue_providers.dart';
import '../../catalogue/data/catalogue_repository.dart';
import '../application/contact_providers.dart';
import '../domain/contact_models.dart';
import 'widgets/enquiry_thread.dart';

/// The public contact page.
///
/// Enquiries go to the academy office through the API. A signed-in sender also
/// sees their previous enquiries and any replies here, so the conversation has
/// one home rather than living only in an inbox.
class ContactScreen extends ConsumerWidget {
  const ContactScreen({super.key});

  /// Fallback used before the office has set the address in the CMS.
  static const fallbackEmail = 'enquirie@gmail.com';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(catalogueOverviewProvider);
    final email = overview.value?.setting('contact_email', fallbackEmail) ??
        fallbackEmail;
    final intro = overview.value?.setting(
          'contact_intro',
          'Send an enquiry and the academy office will respond. If you are signed in, replies appear here as well as by email.',
        ) ??
        'Send an enquiry and the academy office will respond.';

    return WEAPublicPage(
      child: WEAContainer(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: WEAInsets.section),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WEASectionHeading(
                eyebrow: 'CONTACT',
                title: 'Speak with WEA.',
                description: intro,
              ),
              const SizedBox(height: WEAInsets.xl),
              _ContactDetails(
                email: email,
                responseTime: overview.value?.setting(
                  'contact_response_time',
                  'We aim to respond within two working days.',
                ),
              ),
              const SizedBox(height: WEAInsets.xl),
              const _EnquiryForm(),
              const SizedBox(height: WEAInsets.section),
              const _MyEnquiries(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactDetails extends StatelessWidget {
  const _ContactDetails({required this.email, this.responseTime});

  final String email;
  final String? responseTime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(WEAInsets.lg),
      decoration: BoxDecoration(
        color: WEAColors.surfaceMuted,
        border: Border.all(color: WEAColors.border),
        borderRadius: BorderRadius.circular(WEAInsets.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ENQUIRIES',
            style: theme.textTheme.labelSmall?.copyWith(
              color: WEAColors.accent,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: WEAInsets.xs),
          SelectableText(
            email,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: WEAColors.accentDeep,
            ),
          ),
          if (responseTime != null && responseTime!.isNotEmpty) ...[
            const SizedBox(height: WEAInsets.xs),
            Text(responseTime!, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class _EnquiryForm extends ConsumerStatefulWidget {
  const _EnquiryForm();

  @override
  ConsumerState<_EnquiryForm> createState() => _EnquiryFormState();
}

class _EnquiryFormState extends ConsumerState<_EnquiryForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _organisation = TextEditingController();
  final _phone = TextEditingController();
  final _subject = TextEditingController();
  final _message = TextEditingController();

  var _sending = false;
  String? _error;
  String? _reference;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _email,
      _organisation,
      _phone,
      _subject,
      _message,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final reference = await ref
          .read(contactActionsProvider)
          .send(
            EnquiryDraft(
              name: _name.text.trim(),
              email: _email.text.trim(),
              message: _message.text.trim(),
              phone: _phone.text.trim(),
              organisation: _organisation.text.trim(),
              subject: _subject.text.trim(),
            ),
          );
      if (!mounted) return;
      setState(() {
        _sending = false;
        _reference = reference;
      });
      _message.clear();
      _subject.clear();
    } on CatalogueFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = failure.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(currentProfileProvider);
    final signedIn = profile != null;
    final wide = MediaQuery.sizeOf(context).width >= 760;

    final reference = _reference;
    if (reference != null) {
      return Container(
        padding: const EdgeInsets.all(WEAInsets.lg),
        decoration: BoxDecoration(
          color: WEAColors.navy,
          borderRadius: BorderRadius.circular(WEAInsets.radius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ENQUIRY RECEIVED',
              style: theme.textTheme.labelSmall?.copyWith(
                color: WEAColors.accentSoft,
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(height: WEAInsets.sm),
            SelectableText(
              reference,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: WEAColors.offWhite,
              ),
            ),
            const SizedBox(height: WEAInsets.xs),
            Text(
              signedIn
                  ? 'Thank you. The academy office will reply, and the reply will appear below as well as by email.'
                  : 'Thank you. The academy office will reply by email. Quote this reference in any follow-up.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: WEAColors.offWhite.withValues(alpha: .82),
              ),
            ),
            const SizedBox(height: WEAInsets.lg),
            WEAOutlinedButton(
              label: 'SEND ANOTHER ENQUIRY',
              onDark: true,
              onPressed: () => setState(() => _reference = null),
            ),
          ],
        ),
      );
    }

    Widget pair(Widget left, Widget right) => wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              const SizedBox(width: WEAInsets.md),
              Expanded(child: right),
            ],
          )
        : Column(
            children: [left, const SizedBox(height: WEAInsets.md), right],
          );

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('General enquiry', style: theme.textTheme.headlineSmall),
          const SizedBox(height: WEAInsets.xs),
          Text(
            signedIn
                ? 'Sending as ${profile.fullName} (${profile.email}). We already have your details.'
                : 'Tell us how to reach you and the office will reply.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: WEAInsets.lg),

          // A signed-in sender is identified by their session, so the name and
          // email inputs would only be noise — and could not override it anyway.
          if (!signedIn) ...[
            pair(
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Your name'),
                validator: (value) => (value?.trim().isEmpty ?? true)
                    ? 'Please give your name.'
                    : null,
              ),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email address'),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'Please give your email address.';
                  if (!text.contains('@') || !text.contains('.')) {
                    return 'Please give a valid email address.';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: WEAInsets.md),
          ],
          pair(
            TextFormField(
              controller: _organisation,
              decoration: const InputDecoration(
                labelText: 'Organisation (optional)',
              ),
            ),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone (optional)',
              ),
            ),
          ),
          const SizedBox(height: WEAInsets.md),
          TextFormField(
            controller: _subject,
            decoration: const InputDecoration(labelText: 'Subject'),
          ),
          const SizedBox(height: WEAInsets.md),
          TextFormField(
            controller: _message,
            maxLines: 6,
            minLines: 4,
            decoration: const InputDecoration(
              labelText: 'Your message',
              alignLabelWithHint: true,
            ),
            validator: (value) => (value?.trim().length ?? 0) < 10
                ? 'Please include a little more detail.'
                : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: WEAInsets.md),
            Text(
              _error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: WEAColors.error,
              ),
            ),
          ],
          const SizedBox(height: WEAInsets.lg),
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _sending ? null : _send,
                child: Text(_sending ? 'SENDING…' : 'SEND ENQUIRY'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The signed-in sender's own enquiries and the replies to them.
class _MyEnquiries extends ConsumerWidget {
  const _MyEnquiries();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(authControllerProvider).isAuthenticated;
    if (!signedIn) return const _SignInHint();

    final enquiries = ref.watch(myEnquiriesProvider);
    final theme = Theme.of(context);

    return enquiries.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Your enquiries', style: theme.textTheme.headlineSmall),
            const SizedBox(height: WEAInsets.xs),
            Text(
              'Replies from the academy office appear here.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: WEAInsets.lg),
            for (final enquiry in items)
              EnquiryThread(
                enquiry: enquiry,
                onFollowUp: (body) => ref
                    .read(contactActionsProvider)
                    .followUp(enquiryId: enquiry.id, body: body),
              ),
          ],
        );
      },
    );
  }
}

class _SignInHint extends StatelessWidget {
  const _SignInHint();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(WEAInsets.md),
    decoration: BoxDecoration(
      color: WEAColors.surfaceMuted,
      borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, size: 18, color: WEAColors.mutedText),
        const SizedBox(width: WEAInsets.sm),
        Expanded(
          child: Text(
            'Sign in before sending and you will be able to read the reply here, '
            'alongside your programmes.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    ),
  );
}
