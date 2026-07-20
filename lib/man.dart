import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:http/http.dart' as http;
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Proteção Família',
      theme: ThemeData.dark(),
      home: const AuthScreen(),
      debugShowCheckedModeBanner: false
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  final TextEditingController _apiController = TextEditingController();
  final TextEditingController _keyController = TextEditingController();
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _apiController.text = prefs.getString('api')?? '';
    _keyController.text = prefs.getString('key')?? '';
  }

  Future<void> _authenticate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api', _apiController.text);
    await prefs.setString('key', _keyController.text);
    
    final didAuthenticate = await auth.authenticate(
      localizedReason: 'Autentique para acessar',
      options: const AuthenticationOptions(biometricOnly: true)
    );
    if (didAuthenticate) setState(() => _isAuthenticated = true);
  }

  Future<void> _sendCommand(String action) async {
    final prefs = await SharedPreferences.getInstance();
    final api = prefs.getString('api')!;
    final key = prefs.getString('key')!;
    final jwt = JWT({'action': action});
    final token = jwt.sign(SecretKey(key));
    try {
      await http.post(Uri.parse('http://$api/execute'), headers: {'Authorization': 'Bearer $token'});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Comando $action enviado!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('Configuração')),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            TextField(controller: _apiController, decoration: const InputDecoration(labelText: 'IP:Porta do Raspberry')),
            TextField(controller: _keyController, decoration: const InputDecoration(labelText: 'Chave Secreta JWT')),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _authenticate, child: const Text('Autenticar com Digital')),
          ])
        )
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Painel de Controle')),
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          ElevatedButton(onPressed: () => _sendCommand('block'), child: const Text('BLOQUEAR TUDO')),
          ElevatedButton(onPressed: () => _sendCommand('allow'), child: const Text('LIBERAR TUDO')),
          ElevatedButton(onPressed: () => _sendCommand('shutdown'), child: const Text('DESLIGAR PC')),
        ])
      )
    );
  }
}
