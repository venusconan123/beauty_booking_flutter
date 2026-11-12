import 'package:url_launcher/url_launcher.dart';

import '../models/salon.dart';

Uri salonDirectionsUri(Salon salon) {
  return Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    // Marker coordinates are approximate; resolve the named business at its
    // street address instead of routing to a nearby reverse-geocoded house.
    'destination':
        salon.mapsDestination ?? '${salon.name}, ${salon.address}, Việt Nam',
    'dir_action': 'navigate',
  });
}

Future<bool> openSalonDirections(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);
