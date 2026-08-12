import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../core/services/app_environment.dart';
import '../../application/events_providers.dart';

/// Where a shared link is going, so the visit can be attributed to it.
enum ShareChannel {
  linkedin('LinkedIn', 'linkedin', Icons.business_center_outlined),
  facebook('Facebook', 'facebook', Icons.thumb_up_outlined),
  x('X', 'x', Icons.tag),
  whatsapp('WhatsApp', 'whatsapp', Icons.chat_outlined),
  email('Email', 'email', Icons.mail_outline);

  const ShareChannel(this.label, this.utmSource, this.icon);

  final String label;
  final String utmSource;
  final IconData icon;
}

/// Builds the URL the academy circulates for a piece of public content.
///
/// It points at the API's share endpoint rather than straight at the
/// application, because the site paints its pages in the browser: a crawler
/// fetching the application URL would find an empty shell and produce a blank
/// preview card. The share endpoint serves the title, description and artwork,
/// then sends the visitor on to the real page.
String buildShareUrl({
  required String kind,
  required String slug,
  String? utmSource,
  String utmMedium = 'social',
  String? campaign,
}) {
  final base = AppEnvironmentConfig.apiBaseUrl;
  // Without an API there is no card to serve, so the link goes straight to the
  // application route. The preview will be plain, but the link still works.
  final origin = base.isEmpty
      ? Uri.base.replace(path: '', query: '', fragment: '').toString()
      : base;
  final path = base.isEmpty
      ? (kind == 'event' ? '/events/$slug' : '/programmes/$slug')
      : '/share/$kind/$slug';
  final uri = Uri.parse('${origin.replaceAll(RegExp(r'/$'), '')}$path');
  return uri
      .replace(
        queryParameters: {
          'utm_source': ?utmSource,
          if (utmSource != null) 'utm_medium': utmMedium,
          if (campaign != null && campaign.isNotEmpty) 'utm_campaign': campaign,
        },
      )
      .toString();
}

/// Share actions for an event or programme.
///
/// Each channel carries its own campaign source, so the analytics view can say
/// which platform actually produced registrations rather than reporting one
/// undifferentiated pile of "social".
class EventShareBar extends ConsumerWidget {
  const EventShareBar({
    super.key,
    required this.kind,
    required this.slug,
    required this.title,
    this.campaign,
    this.onDark = false,
  });

  final String kind;
  final String slug;
  final String title;
  final String? campaign;
  final bool onDark;

  Future<void> _open(BuildContext context, WidgetRef ref, ShareChannel channel) async {
    final url = buildShareUrl(
      kind: kind,
      slug: slug,
      utmSource: channel.utmSource,
      campaign: campaign,
    );
    final encoded = Uri.encodeComponent(url);
    final text = Uri.encodeComponent(title);

    final target = switch (channel) {
      ShareChannel.linkedin =>
        'https://www.linkedin.com/sharing/share-offsite/?url=$encoded',
      ShareChannel.facebook => 'https://www.facebook.com/sharer/sharer.php?u=$encoded',
      ShareChannel.x => 'https://twitter.com/intent/tweet?url=$encoded&text=$text',
      ShareChannel.whatsapp => 'https://wa.me/?text=$text%20$encoded',
      ShareChannel.email => 'mailto:?subject=$text&body=$encoded',
    };

    ref.read(eventActionsProvider).unawaitedReport(name: 'event_shared');
    final launched = await launchUrl(
      Uri.parse(target),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      _notify(context, 'Could not open ${channel.label}.');
    }
  }

  Future<void> _copy(BuildContext context, WidgetRef ref) async {
    final url = buildShareUrl(
      kind: kind,
      slug: slug,
      utmSource: 'direct',
      utmMedium: 'link',
      campaign: campaign,
    );
    await Clipboard.setData(ClipboardData(text: url));
    ref.read(eventActionsProvider).unawaitedReport(name: 'event_shared');
    if (context.mounted) _notify(context, 'Share link copied.');
  }

  void _notify(BuildContext context, String message) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: WEAColors.navy,
          content: Text(message),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final foreground = onDark ? WEAColors.offWhite : WEAColors.secondaryText;

    return Wrap(
      spacing: WEAInsets.xs,
      runSpacing: WEAInsets.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'SHARE',
          style: theme.textTheme.labelSmall?.copyWith(
            color: foreground.withValues(alpha: .8),
            letterSpacing: 1.3,
          ),
        ),
        for (final channel in ShareChannel.values)
          IconButton(
            tooltip: 'Share on ${channel.label}',
            onPressed: () => _open(context, ref, channel),
            icon: Icon(channel.icon, size: 19, color: foreground),
            visualDensity: VisualDensity.compact,
          ),
        IconButton(
          tooltip: 'Copy link',
          onPressed: () => _copy(context, ref),
          icon: Icon(Icons.link, size: 19, color: foreground),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}
