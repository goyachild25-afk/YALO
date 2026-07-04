import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_colors.dart';

/// Hoja de opciones para abrir unas coordenadas en la app de mapas que el
/// usuario prefiera. Es la pieza que mantiene la coordinación dentro de YALO:
/// el prestador toca la ubicación compartida y navega directo, sin pedir
/// "mándame la ubicación por WhatsApp".
Future<void> showOpenInMapsSheet(
  BuildContext context, {
  required double lat,
  required double lng,
  String title = 'Abrir ubicación',
}) async {
  final coords = '$lat,$lng';

  Future<void> open(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  await showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.map_outlined, color: AppColors.primary),
            title: const Text('Google Maps'),
            subtitle: const Text('Navegar hasta el punto',
                style: TextStyle(fontSize: 12)),
            onTap: () {
              Navigator.of(ctx).pop();
              open(Uri.parse(
                  'https://www.google.com/maps/dir/?api=1&destination=$coords'));
            },
          ),
          ListTile(
            leading: const Icon(Icons.navigation_outlined,
                color: Color(0xFF33CCFF)),
            title: const Text('Waze'),
            subtitle: const Text('Navegar hasta el punto',
                style: TextStyle(fontSize: 12)),
            onTap: () {
              Navigator.of(ctx).pop();
              open(Uri.parse('https://waze.com/ul?ll=$coords&navigate=yes'));
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy_outlined,
                color: AppColors.textSecondary),
            title: const Text('Copiar coordenadas'),
            subtitle: Text(coords, style: const TextStyle(fontSize: 12)),
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: coords));
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Coordenadas copiadas')),
                );
              }
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
