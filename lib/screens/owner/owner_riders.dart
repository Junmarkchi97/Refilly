import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api.dart';

class OwnerRiders extends StatefulWidget {
  final Station station;
  const OwnerRiders({super.key, required this.station});
  @override
  State<OwnerRiders> createState() => _OwnerRidersState();
}

class _OwnerRidersState extends State<OwnerRiders> {
  late Future<List<Profile>> _f = Api.riders(widget.station.id);
  final _phone = TextEditingController();

  Future<void> _add() async {
    final ok = await Api.addRiderByPhone(widget.station.id, _phone.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Rider added' : 'No unassigned rider with that phone')));
    setState(() => _f = Api.riders(widget.station.id));
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Riders sign up in the app with the "Rider" role, then you add them by phone number.'),
        Row(children: [
          Expanded(child: TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Rider phone'))),
          FilledButton(onPressed: _add, child: const Text('Add')),
        ]),
        const SizedBox(height: 16),
        FutureBuilder<List<Profile>>(
          future: _f,
          builder: (context, s) => Column(children: [
            for (final r in s.data ?? <Profile>[])
              ListTile(leading: const Icon(Icons.delivery_dining), title: Text(r.fullName ?? 'Rider'), subtitle: Text(r.phone ?? '')),
          ]),
        ),
      ]);
}
