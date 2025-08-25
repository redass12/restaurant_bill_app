import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // >>> Déclarations qui manquaient
  final TextEditingController emailCtl = TextEditingController();
  final TextEditingController passCtl  = TextEditingController();
  bool loading = false;

  @override
  void dispose() {
    emailCtl.dispose();
    passCtl.dispose();
    super.dispose();
  }

  Future<void> _signin() async {
    setState(() => loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailCtl.text.trim(),
        password: passCtl.text,
      );
      // _AuthGate écoutera l'état et naviguera tout seul
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Erreur de connexion')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _signup() async {
    setState(() => loading = true);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailCtl.text.trim(),
        password: passCtl.text,
      );
      final uid = cred.user!.uid;

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'email': emailCtl.text.trim(),
        'restaurantId': 'resto1',
        'role': 'manager', // ou 'server'
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      // _AuthGate détectera le user + son document et chargera l'app
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Erreur inscription')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connexion')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: emailCtl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: passCtl,
              decoration: const InputDecoration(labelText: 'Mot de passe'),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: loading ? null : _signin,
                    child: Text(loading ? '...' : 'Se connecter'),
                  ),
                ),
                const SizedBox(width: 12),
                // Expanded(
                //   child: OutlinedButton(
                //     onPressed: loading ? null : _signup,
                //     child: const Text('Créer un compte'),
                //   ),
                // ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
