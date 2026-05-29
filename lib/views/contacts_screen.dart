import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  // Coordonnées approximatives pour l'ENSET Mohammedia
  static const LatLng _enset = LatLng(33.6900, -7.3900);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: const [
              Icon(Icons.contact_phone, size: 32, color: Colors.blueAccent),
              SizedBox(width: 12),
              Text(
                'Contacts',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        Expanded(
          child: FlutterMap(
            // ⚠️ CORRECTION : initialCenter et initialZoom pour flutter_map v6+
            options: const MapOptions(initialCenter: _enset, initialZoom: 15.0),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName:
                    'com.example.aiStudyAssistant', // Assurez-vous que ça correspond à votre app
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _enset,
                    width: 80,
                    height: 80,
                    //  'child' au lieu de 'builder' pour flutter_map v6+
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Text(
            'Zone: ENSET Mohammedia',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
