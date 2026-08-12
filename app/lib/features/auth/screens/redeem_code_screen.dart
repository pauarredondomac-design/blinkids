import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RedeemCodeScreen extends StatefulWidget {
  const RedeemCodeScreen({super.key});

  @override
  State<RedeemCodeScreen> createState() => _RedeemCodeScreenState();
}

class _RedeemCodeScreenState extends State<RedeemCodeScreen> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String _errorMsg = '';
  bool _success = false;

  Future<void> _redeem() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _errorMsg = 'El código tiene 6 caracteres.');
      return;
    }
    setState(() {
      _loading = true;
      _errorMsg = '';
    });
    try {
      await Supabase.instance.client
          .rpc('redeem_invite_code', params: {'p_code': code});
      if (mounted)
        setState(() {
          _success = true;
          _loading = false;
        });
      await Future.delayed(2.seconds);
      if (mounted) context.go('/world');
    } catch (e) {
      final msg = e.toString();
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMsg = msg.contains('Invalid') || msg.contains('invalid')
              ? 'Código inválido o expirado.'
              : 'Error al canjear. Intenta de nuevo.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF060618), Color(0xFF0D0D2B), Color(0xFF12124A)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: _success ? _buildSuccess() : _buildForm(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('🔗', style: TextStyle(fontSize: 64))
            .animate()
            .scale(duration: 600.ms, curve: Curves.elasticOut),
        const SizedBox(height: 20),
        const Text(
          '¡Vincula tu cuenta!',
          style: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w900,
              fontSize: 28,
              color: Colors.white),
          textAlign: TextAlign.center,
        ).animate().fadeIn(delay: 200.ms),
        const SizedBox(height: 8),
        const Text(
          'Pide el código de 6 letras a tu papá o mamá\ne introdúcelo aquí.',
          style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 14,
              color: Colors.white54,
              height: 1.5),
          textAlign: TextAlign.center,
        ).animate().fadeIn(delay: 300.ms),
        const SizedBox(height: 32),

        // Campo del código
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
          ),
          child: TextField(
            controller: _codeCtrl,
            maxLength: 6,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]'))
            ],
            style: const TextStyle(
              color: Color(0xFF1A1A2E),
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w900,
              fontSize: 32,
              letterSpacing: 8,
            ),
            decoration: const InputDecoration(
              hintText: 'ABC123',
              hintStyle: TextStyle(
                  color: Color(0xFF9EA3B8),
                  fontSize: 28,
                  letterSpacing: 8,
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700),
              counterStyle: TextStyle(color: Color(0xFF9EA3B8), fontSize: 11),
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            onChanged: (_) => setState(() => _errorMsg = ''),
          ),
        ),

        if (_errorMsg.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.4)),
            ),
            child: Text(
              _errorMsg,
              style: const TextStyle(
                  color: Colors.redAccent, fontFamily: 'Nunito', fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        ],

        const SizedBox(height: 24),

        _loading
            ? const CircularProgressIndicator(color: Color(0xFF4FC3F7))
            : GestureDetector(
                onTap: _redeem,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF4FC3F7), Color(0xFF0288D1)]),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Text(
                    'Vincular cuenta',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: Colors.white),
                  ),
                ),
              ),

        const SizedBox(height: 16),
        TextButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/world'),
          child: const Text('Más tarde',
              style: TextStyle(color: Colors.white38, fontFamily: 'Nunito')),
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('🎉', style: TextStyle(fontSize: 80))
            .animate()
            .scale(duration: 600.ms, curve: Curves.elasticOut),
        const SizedBox(height: 20),
        const Text(
          '¡Cuenta vinculada!',
          style: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w900,
              fontSize: 28,
              color: Color(0xFF4CAF50)),
          textAlign: TextAlign.center,
        ).animate().fadeIn(),
        const SizedBox(height: 8),
        const Text(
          '¡Ya puedes disfrutar el juego completo!',
          style: TextStyle(
              fontFamily: 'Nunito', fontSize: 16, color: Colors.white70),
          textAlign: TextAlign.center,
        ).animate().fadeIn(delay: 200.ms),
      ],
    );
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }
}
