import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Brand colors (match the rest of your app)
const _seed = Color(0xFF8B5E3C);   // brown
const _accent = Color(0xFFD86B4A); // warm terracotta

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final emailCtl = TextEditingController();
  final passCtl  = TextEditingController();
  bool loading = false;
  bool obscure = true;

  @override
  void dispose() {
    emailCtl.dispose();
    passCtl.dispose();
    super.dispose();
  }

  Future<void> _signin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailCtl.text.trim(),
        password: passCtl.text,
      );
      // _AuthGate in main.dart will take over navigation.
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final msg = _authMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = emailCtl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entre un email valide pour réinitialiser.')),
      );
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email de réinitialisation envoyé.')),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final msg = _authMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  String _authMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Aucun compte avec cet email.';
      case 'wrong-password':
        return 'Mot de passe incorrect.';
      case 'invalid-email':
        return 'Email invalide.';
      case 'user-disabled':
        return 'Compte désactivé.';
      default:
        return e.message ?? 'Erreur de connexion.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        _seed.withOpacity(0.95),
        const Color(0xFFA56445), // mid
        _accent.withOpacity(0.85),
      ],
    );

    return Scaffold(
      resizeToAvoidBottomInset: true, // explicite
      body: GestureDetector(
        behavior: HitTestBehavior.translucent, // capte les taps sur zones vides
        onTap: () => FocusScope.of(context).unfocus(), // fermer le clavier
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(gradient: gradient),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 80),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    FadeInUp(
                      duration: const Duration(milliseconds: 900),
                      child: const Text(
                        "Connexion",
                        style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 10),
                    FadeInUp(
                      duration: const Duration(milliseconds: 1200),
                      child: const Text(
                        "Ravi de vous revoir",
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ======= Panneau blanc scrollable =======
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
                    return Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(60),
                          topRight: Radius.circular(60),
                        ),
                      ),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(30, 30, 30, 30 + bottomInset),
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        child: ConstrainedBox(
                          // Conserve un look "plein écran" même sans clavier
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: <Widget>[
                                const SizedBox(height: 40),
                                FadeInUp(
                                  duration: const Duration(milliseconds: 1300),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _accent.withOpacity(.20),
                                          blurRadius: 24,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      children: <Widget>[
                                        // Email
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            border: Border(
                                              bottom: BorderSide(color: Colors.grey.shade200),
                                            ),
                                          ),
                                          child: TextFormField(
                                            controller: emailCtl,
                                            keyboardType: TextInputType.emailAddress,
                                            textInputAction: TextInputAction.next,
                                            scrollPadding: EdgeInsets.only(bottom: bottomInset + 120),
                                            decoration: const InputDecoration(
                                              hintText: "Email",
                                              prefixIcon: Icon(Icons.email_outlined),
                                              border: InputBorder.none,
                                            ),
                                            validator: (v) {
                                              final s = (v ?? '').trim();
                                              if (s.isEmpty) return 'Email requis';
                                              if (!s.contains('@')) return 'Email invalide';
                                              return null;
                                            },
                                          ),
                                        ),
                                        // Password
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          child: TextFormField(
                                            controller: passCtl,
                                            obscureText: obscure,
                                            textInputAction: TextInputAction.done,
                                            scrollPadding: EdgeInsets.only(bottom: bottomInset + 120),
                                            decoration: InputDecoration(
                                              hintText: "Mot de passe",
                                              prefixIcon: const Icon(Icons.lock_outline),
                                              border: InputBorder.none,
                                              suffixIcon: IconButton(
                                                onPressed: () => setState(() => obscure = !obscure),
                                                icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                                              ),
                                            ),
                                            validator: (v) {
                                              final s = v ?? '';
                                              if (s.isEmpty) return 'Mot de passe requis';
                                              if (s.length < 6) return 'Au moins 6 caractères';
                                              return null;
                                            },
                                            onFieldSubmitted: (_) {
                                              if (!loading) _signin();
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 18),

                                // Forgot password
                                FadeInUp(
                                  duration: const Duration(milliseconds: 1400),
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: loading ? null : _resetPassword,
                                      style: TextButton.styleFrom(
                                        foregroundColor: _seed,
                                      ),
                                      child: const Text("Mot de passe oublié ?"),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 8),

                                // Login button
                                FadeInUp(
                                  duration: const Duration(milliseconds: 1500),
                                  child: SizedBox(
                                    width: double.infinity,
                                    height: 52,
                                    child: FilledButton(
                                      onPressed: loading ? null : _signin,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: _seed,
                                        disabledBackgroundColor: _seed.withOpacity(0.4),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(50),
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        child: loading
                                            ? const SizedBox(
                                                width: 22,
                                                height: 22,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2.2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Text(
                                                "Se connecter",
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Footer
                                FadeInUp(
                                  duration: const Duration(milliseconds: 1700),
                                  child: Text(
                                    '© Waldschenke',
                                    style: TextStyle(
                                      color: Colors.brown.shade300,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
