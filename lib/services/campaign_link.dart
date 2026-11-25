import 'package:flutter/widgets.dart';

import 'api_service.dart';

/// A link to an event page, usually from a Campaign QR code (SRS 4.14):
/// `https://<site>/events/{id}?promo={token or code}`.
class CampaignLink {
  final int eventId;
  final String? promo;
  const CampaignLink(this.eventId, [this.promo]);

  /// Null when [raw] is not an event link of this BiletFlow site. A bare
  /// `/events/...` path (how some platforms deliver links) is accepted too.
  static CampaignLink? parse(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null) return null;
    if (uri.hasScheme || uri.hasAuthority) {
      final web = uri.scheme == 'https' || uri.scheme == 'http';
      if (!web || uri.host != Uri.parse(kBaseUrl).host) return null;
    }
    final path = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (path.length != 2 || path.first != 'events') return null;
    final id = int.tryParse(path[1]);
    if (id == null || id <= 0) return null;
    final promo = uri.queryParameters['promo']?.trim();
    return CampaignLink(id, promo == null || promo.isEmpty ? null : promo);
  }
}

/// Receives links the operating system opens the app with. The home screen
/// takes [pending] once the user is signed in.
class DeepLinks with WidgetsBindingObserver {
  static final pending = ValueNotifier<CampaignLink?>(null);

  /// Call before `runApp`, so links are seen before the navigator gets them.
  static void start() {
    final binding = WidgetsBinding.instance;
    pending.value =
        CampaignLink.parse(binding.platformDispatcher.defaultRouteName);
    binding.addObserver(DeepLinks());
  }

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) async {
    final link = CampaignLink.parse(routeInformation.uri.toString());
    if (link == null) return false;
    pending.value = link;
    return true;
  }
}
