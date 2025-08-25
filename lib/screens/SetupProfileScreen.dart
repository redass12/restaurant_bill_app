
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
class SetupProfileScreen extends StatelessWidget {
  final String uid;
  final String? email;
  SetupProfileScreen({super.key, required this.uid, this.email});

  final _ctl = TextEditingController(text: 'resto1'); // change la valeur par défaut

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lier le restaurant')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _ctl,
              decoration: const InputDecoration(labelText: 'restaurantId'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                await FirebaseFirestore.instance.collection('users').doc(uid).set({
                  'email': email,
                  'restaurantId': _ctl.text.trim(),
                  'role': 'manager',
                  'active': true,
                  'createdAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
