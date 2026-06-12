import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // IMPORTADO
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert'; 
import 'package:shared_preferences/shared_preferences.dart'; 
import 'dart:math'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase não inicializado: rodando em modo local/simulado.");
  }
  runApp(const VazusApp());
}

class VazusApp extends StatelessWidget {
  const VazusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vazus',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.cyan), 
        useMaterial3: true,
      ),
      // FLUXO AUTOMÁTICO DE LOGIN IMPLEMENTADO
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.active) {
            User? usuario = snapshot.data;
            if (usuario != null) {
              return const NavegacaoAbas(); 
            }
            return const TelaLogin(); 
          }
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ============================================================================
// TELA DE LOGIN (CONVERTIDA PARA STATEFUL PARA GERENCIAR LOGIN REAL)
// ============================================================================
class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key});

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  bool _carregando = false;

  Future<void> _fazerLogin() async {
    String email = _emailController.text.trim();
    String senha = _senhaController.text.trim();

    if (email.isEmpty || senha.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, preencha todos os campos.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _carregando = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: senha);
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const NavegacaoAbas()));
      }
    } on FirebaseAuthException catch (e) {
      String mensagemErro = 'E-mail ou senha incorretos.';
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        mensagemErro = 'Credenciais inválidas. Verifique os dados e tente novamente.';
      } else if (e.code == 'invalid-email') {
        mensagemErro = 'O formato do e-mail é inválido.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensagemErro), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.cyan.shade300, Colors.cyan.shade900],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.opacity, size: 100, color: Colors.white),
                const SizedBox(height: 10),
                const Text('Vazus', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
                const Text('Monitoramento Inteligente de Água', style: TextStyle(fontSize: 16, color: Colors.white70)),
                const SizedBox(height: 40),
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: 'E-mail', prefixIcon: Icon(Icons.email)),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _senhaController,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'Senha', prefixIcon: Icon(Icons.lock)),
                        ),
                        const SizedBox(height: 24),
                        _carregando 
                          ? const CircularProgressIndicator()
                          : SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.cyan.shade700,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: _fazerLogin,
                                child: const Text('ENTRAR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const TelaCadastro()));
                  },
                  child: const Text('Não tem uma conta? Cadastre-se', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// TELA DE CADASTRO (CONVERTIDA PARA STATEFUL PARA REGISTRO REAL)
// ============================================================================
class TelaCadastro extends StatefulWidget {
  const TelaCadastro({super.key});

  @override
  State<TelaCadastro> createState() => _TelaCadastroState();
}

class _TelaCadastroState extends State<TelaCadastro> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  final TextEditingController _confirmarSenhaController = TextEditingController();
  bool _carregando = false;

  Future<void> _cadastrarUsuario() async {
    String email = _emailController.text.trim();
    String senha = _senhaController.text.trim();
    String confirmar = _confirmarSenhaController.text.trim();

    if (email.isEmpty || senha.isEmpty || confirmar.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, preencha todos os campos.'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (senha != confirmar) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('As senhas não coincidem.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _carregando = true);

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: senha);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conta criada com sucesso!'), backgroundColor: Colors.green),
        );
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const NavegacaoAbas()));
      }
    } on FirebaseAuthException catch (e) {
      String mensagemErro = 'Ocorreu um erro ao criar a conta.';
      if (e.code == 'weak-password') {
        mensagemErro = 'A senha é muito fraca (mínimo 6 caracteres).';
      } else if (e.code == 'email-already-in-use') {
        mensagemErro = 'Este e-mail já está cadastrado.';
      } else if (e.code == 'invalid-email') {
        mensagemErro = 'O formato do e-mail é inválido.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensagemErro), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar Conta', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.cyan.shade800,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'E-mail', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _senhaController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Senha (mínimo 6 dígitos)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmarSenhaController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirmar Senha', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock_clock)),
                ),
                const SizedBox(height: 32),
                _carregando
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyan.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _cadastrarUsuario,
                        child: const Text('CONCLUIR CADASTRO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// NAVEGAÇÃO POR ABAS (TABS)
// ============================================================================
class NavegacaoAbas extends StatefulWidget {
  const NavegacaoAbas({super.key});

  @override
  State<NavegacaoAbas> createState() => _NavegacaoAbasState();
}

class _NavegacaoAbasState extends State<NavegacaoAbas> {
  int _abaSelecionada = 0;

  final List<Widget> _telas = [
    const TelaDashboard(),
    const TelaPerfil(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _telas[_abaSelecionada],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _abaSelecionada,
        onTap: (index) => setState(() => _abaSelecionada = index),
        selectedItemColor: Colors.cyan.shade800,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}

// ============================================================================
// ABA 1: DASHBOARD (MÉTODO BUILD E SIMULADOR REESTRUTURADOS)
// ============================================================================
class TelaDashboard extends StatefulWidget {
  const TelaDashboard({super.key});

  @override
  State<TelaDashboard> createState() => _TelaDashboardState();
}

class _TelaDashboardState extends State<TelaDashboard> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('sensor_vazao');
      
  int _segundosTorneiraAberta = 0;
  Timer? _cronometroAlerta;
  
  bool _alertaTorneiraExcedida = false; 
  bool _dispositivoVinculado = false;
  bool _modoSimuladorAtivo = false;
  bool _carregandoEstado = true;
  double _volumeEntradaUsuario = 0.0;

  int _tempoMaximoFluxo = 15;
  double _simvazao = 0.0;
  double _simvolume = 0.0;
  double _vazaoAtual = 0.0;

  StreamSubscription? _simuladorSubscription;

  @override
  void initState() {
    super.initState();
    _checarDispositivoSalvo();
    
    _cronometroAlerta = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_dispositivoVinculado) return;

      if (_vazaoAtual > 0.5) {
        setState(() {
          _segundosTorneiraAberta++;
          if (_segundosTorneiraAberta >= _tempoMaximoFluxo && !_alertaTorneiraExcedida) {
            _alertaTorneiraExcedida = true;
          }
        });
      } else {
        if (_segundosTorneiraAberta > 0 || _alertaTorneiraExcedida) {
          setState(() {
            _segundosTorneiraAberta = 0;
            _alertaTorneiraExcedida = false;
          });
        }
      }
    });
  }

  Future<void> _checarDispositivoSalvo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _dispositivoVinculado = prefs.getBool('medidor_adicionado') ?? false;
      _modoSimuladorAtivo = prefs.getBool('modo_simulador_ativo') ?? false;
      _volumeEntradaUsuario = prefs.getDouble('volume_entrada_usuario') ?? 0.0;
      _tempoMaximoFluxo = prefs.getInt('tempo_maximo_fluxo') ?? 15;
      _carregandoEstado = false;
    });

    if (_dispositivoVinculado && _modoSimuladorAtivo) {
      _ativarLoopSimuladorFisico();
    }
  }

  void _ativarLoopSimuladorFisico() {
    _simuladorSubscription?.cancel();
    _simuladorSubscription = _dbRef.onValue.listen((event) {
      if (!mounted || !_modoSimuladorAtivo) return;
      
      if (event.snapshot.value != null) {
        try {
          final dados = event.snapshot.value as Map<dynamic, dynamic>;
          setState(() {
            _simvazao = mapToDouble(dados['vazao']);
            _simvolume = mapToDouble(dados['volume']);
            _vazaoAtual = _simvazao; 
          });
        } catch (e) {
          debugPrint("Erro no simulador com Firebase: $e");
        }
      }
    });
  }

  Future<void> _removerDispositivo() async {
    _simuladorSubscription?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('medidor_adicionado', false);
    await prefs.setBool('modo_simulador_ativo', false);
    await prefs.setDouble('volume_entrada_usuario', 0.0);
    await prefs.setInt('tempo_maximo_fluxo', 15);
    _simvolume = 0.0;
    _simvazao = 0.0;
    _vazaoAtual = 0.0;
    _checarDispositivoSalvo();
  }

  void _mostrarDialogoEntradaUsuario() {
    TextEditingController controlador = TextEditingController(
      text: _volumeEntradaUsuario > 0 ? _volumeEntradaUsuario.toString() : ""
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Registrar Leitura da Rua', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Insira o valor atual de volume (em Litros) registrado no relógio da rua da sua casa:'),
              const SizedBox(height: 16),
              TextField(
                controller: controlador,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Volume de Entrada (Litros)',
                  border: OutlineInputBorder(),
                  suffixText: 'L',
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan[700], foregroundColor: Colors.white),
              onPressed: () async {
                double? valorInserido = double.tryParse(controlador.text.trim());
                if (valorInserido != null) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setDouble('volume_entrada_usuario', valorInserido);
                  setState(() {
                    _volumeEntradaUsuario = valorInserido;
                  });
                }
                Navigator.pop(context);
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  void _mostrarDialogoTempoLimite() {
    TextEditingController controlador = TextEditingController(text: _tempoMaximoFluxo.toString());
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Configurar Alerta de Torneira', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Defina o tempo máximo (em segundos) de fluxo contínuo permitido antes de disparar o aviso de esquecimento:'),
              const SizedBox(height: 16),
              TextField(
                controller: controlador,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Tempo Limite (Segundos)',
                  border: OutlineInputBorder(),
                  suffixText: 's',
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan[700], foregroundColor: Colors.white),
              onPressed: () async {
                int? valorInserido = int.tryParse(controlador.text.trim());
                if (valorInserido != null && valorInserido > 0) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setInt('tempo_maximo_fluxo', valorInserido);
                  setState(() {
                    _tempoMaximoFluxo = valorInserido;
                    _alertaTorneiraExcedida = false;
                    _segundosTorneiraAberta = 0;
                  });
                }
                Navigator.pop(context);
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  double mapToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return double.tryParse(value.toString()) ?? 0.0;
  }

  @override
  void dispose() {
    _cronometroAlerta?.cancel();
    _simuladorSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_carregandoEstado) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_modoSimuladorAtivo ? 'Vazus - [SIMULADOR]' : 'Vazus - Monitor', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _modoSimuladorAtivo ? Colors.purple.shade100 : Theme.of(context).colorScheme.inversePrimary,
        actions: _dispositivoVinculado 
          ? [
              IconButton(
                icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                tooltip: 'Desvincular Hardware',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Remover Medidor?'),
                      content: const Text('O medidor será removido desta tela.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _removerDispositivo();
                          },
                          child: const Text('Remover', style: TextStyle(color: Colors.red)),
                        )
                      ],
                    ),
                  );
                },
              )
            ]
          : null,
      ),
      body: !_dispositivoVinculado 
          ? _construirTelaVazia() 
          : _modoSimuladorAtivo 
              ? _renderizarLayoutDashboard(_simvazao, _simvolume) 
              : StreamBuilder<DatabaseEvent>(
                  stream: _dbRef.onValue,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    double vazaoMedidor = 0.0;
                    double volumeMedidor = 0.0;

                    if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                      try {
                        final dados = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                        vazaoMedidor = mapToDouble(dados['vazao']);
                        volumeMedidor = mapToDouble(dados['volume']);
                        _vazaoAtual = vazaoMedidor; 
                      } catch (e) {
                        debugPrint("Erro ao processar dados do Firebase: $e");
                      }
                    }
                    
                    return _renderizarLayoutDashboard(vazaoMedidor, volumeMedidor);
                  },
                ),
    );
  }

  Widget _renderizarLayoutDashboard(double vazao, double volume) {
    double diferencaVolume = _volumeEntradaUsuario - volume;
    
    bool vazamentoDetectado = _volumeEntradaUsuario > 0 && 
                              volume > 0 && 
                              diferencaVolume > (_volumeEntradaUsuario * 0.10);

    bool entradaDesatualizada = _volumeEntradaUsuario > 0 && 
                                volume > (_volumeEntradaUsuario + 1.0);

    Color backgroundColor = Colors.green[50]!;
    Color borderColor = Colors.green;
    Color textColor = Colors.green[900]!;
    IconData statusIcon = Icons.gpp_good_rounded;
    String statusTitle = 'Rede Equilibrada';
    String statusDescription = _volumeEntradaUsuario == 0 
        ? 'Insira o volume do relógio da rua para ativar a análise de vazamentos.'
        : 'Os dados batem! O volume aferido internamente está compatível com a entrada da rua.';

    if (vazamentoDetectado && !entradaDesatualizada) {
      backgroundColor = Colors.red[50]!;
      borderColor = Colors.red;
      textColor = Colors.red[900]!;
      statusIcon = Icons.warning_amber_rounded;
      statusTitle = 'Possível Vazamento!';
      statusDescription = 'Discrepância crítica! O relógio da rua registrou ${_volumeEntradaUsuario.toStringAsFixed(1)} L, mas seu medidor interno só contou ${volume.toStringAsFixed(1)} L (Perda de ${diferencaVolume.abs().toStringAsFixed(1)} L).';
    } else if (entradaDesatualizada) {
      backgroundColor = Colors.orange[50]!;
      borderColor = Colors.orange.shade700;
      textColor = Colors.orange[900]!;
      statusIcon = Icons.edit_calendar_rounded;
      statusTitle = 'Entrada Desatualizada!';
      statusDescription = 'Seu medidor interno já registrou ${volume.toStringAsFixed(1)} L, o que é maior que a última leitura da rua (${_volumeEntradaUsuario.toStringAsFixed(1)} L). Por favor, atualize o volume da rua para normalizar o monitoramento.';
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_modoSimuladorAtivo)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            decoration: BoxDecoration(color: Colors.purple.shade600, borderRadius: BorderRadius.circular(6)),
            child: const Text('Rodando em modo de simulação interna (Alimentado pelo Firebase).', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ),
          
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(statusIcon, color: borderColor, size: 44),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(statusTitle, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                    const SizedBox(height: 4),
                    Text(statusDescription, style: const TextStyle(color: Colors.black87)),
                  ],
                ),
              )
            ],
          ),
        ),

        if (_alertaTorneiraExcedida) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.amber[100], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amber[800]!)),
            child: Row(
              children: [
                Icon(Icons.notification_important, color: Colors.amber[900]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Atenção: Fluxo contínuo ativo há mais de $_tempoMaximoFluxo segundos! Verifique se há alguma torneira aberta por esquecimento.', 
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)
                  )
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 24),
        const Text('Pontos de Medição', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 10),
        
        Card(
          elevation: 1.5,
          shape: entradaDesatualizada 
              ? RoundedRectangleBorder(side: BorderSide(color: Colors.orange.shade400, width: 1.5), borderRadius: BorderRadius.circular(12)) 
              : null,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: entradaDesatualizada ? Colors.orange[100] : Colors.blueAccent,
              child: Icon(Icons.house, color: entradaDesatualizada ? Colors.orange[900] : Colors.white),
            ),
            title: const Text('Entrada Principal (Rua)', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(entradaDesatualizada ? 'Necessita atualização' : _volumeEntradaUsuario > 0 ? 'Leitura manual inserida' : 'Nenhum dado informado'),
            trailing: Text('${_volumeEntradaUsuario.toStringAsFixed(1)} L', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),

        Card(
          elevation: 1.5,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: vazao > 0.5 ? Colors.cyan[100] : Colors.grey[100],
              child: Icon(Icons.opacity, color: vazao > 0.5 ? Colors.cyan[800] : Colors.grey[500]),
            ),
            title: Text(_modoSimuladorAtivo ? 'Medidor Interno (Virtual)' : 'Medidor Interno', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(vazao > 0.5 ? 'Em atividade (${vazao.toStringAsFixed(1)} L/m)' : 'Sem fluxo de água'),
                Text('Tempo limite: ${_tempoMaximoFluxo}s', style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${volume.toStringAsFixed(1)} L', style: TextStyle(fontSize: 16, color: vazao > 0.5 ? Colors.cyan[700] : Colors.grey[600], fontWeight: FontWeight.bold)),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.timer_outlined, color: Colors.cyan, size: 22),
                  tooltip: 'Definir limite de tempo',
                  onPressed: _mostrarDialogoTempoLimite,
                )
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 20),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: entradaDesatualizada ? Colors.orange[700] : Colors.blueAccent, 
            foregroundColor: Colors.white
          ),
          onPressed: _mostrarDialogoEntradaUsuario,
          icon: Icon(entradaDesatualizada ? Icons.update : Icons.add_chart),
          label: Text(entradaDesatualizada ? 'Atualizar Volume da Rua Agora' : 'Informar Volume da Rua'),
        ),
      ],
    );
  }

  Widget _construirTelaVazia() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.router_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('Nenhum Dispositivo Vinculado', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Para monitorar o fluxo da sua residência, faça o pareamento do seu sensor físico ou ative o simulador.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (context) => const TelaAdicionarDispositivo()));
                _checarDispositivoSalvo(); 
              },
              icon: const Icon(Icons.bluetooth_searching),
              label: const Text('Parear Novo Sensor', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// TELA ADICIONAR DISPOSITIVO
// ============================================================================
class TelaAdicionarDispositivo extends StatefulWidget {
  const TelaAdicionarDispositivo({super.key});

  @override
  State<TelaAdicionarDispositivo> createState() => _TelaAdicionarDispositivoState();
}

class _TelaAdicionarDispositivoState extends State<TelaAdicionarDispositivo> {
  bool _buscando = false;
  List<ScanResult> _resultadosScan = [];

  void _iniciarBusca() async {
    var status = await Permission.location.request();
    if (!status.isGranted) return;

    setState(() {
      _buscando = true;
      _resultadosScan.clear();
    });

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
      FlutterBluePlus.scanResults.listen((results) {
        if (mounted) {
          setState(() {
            _resultadosScan = results.where((r) => r.device.platformName.isNotEmpty).toList();
          });
        }
      });

      await Future.delayed(const Duration(seconds: 4));
    } catch (e) {
      debugPrint("Erro ao escanear: $e");
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  void _vincularMockSimulador() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('medidor_adicionado', true);
    await prefs.setBool('modo_simulador_ativo', true);
    if (mounted) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Simulador conectado com sucesso!'), backgroundColor: Colors.purple),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parear Medidor')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            InkWell(
              onTap: _vincularMockSimulador,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.shade300, width: 1.5),
                ),
                child: Row(
                  children: [
                    Icon(Icons.bolt, color: Colors.purple[800], size: 36),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Usar Simulador Integrado', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.purple[900])),
                          const Text('Modo de desenvolvimento. Conecta com o Firebase sem precisar do ESP32 por perto.', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Text('Dispositivos Físicos Próximos', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey)),
                const Spacer(),
                if (_buscando)
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  TextButton.icon(onPressed: _iniciarBusca, icon: const Icon(Icons.refresh), label: const Text('Buscar'))
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _resultadosScan.isEmpty
                  ? Center(child: Text(_buscando ? 'Buscando sinais Bluetooth...' : 'Nenhum hardware Bluetooth listado.', style: const TextStyle(color: Colors.grey)))
                  : ListView.builder(
                    itemCount: _resultadosScan.length,
                    itemBuilder: (context, index) {
                      final r = _resultadosScan[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.bluetooth),
                          title: Text(r.device.platformName.isNotEmpty ? r.device.platformName : 'Dispositivo Desconhecido'),
                          subtitle: Text(r.device.remoteId.str),
                          trailing: ElevatedButton(
                            onPressed: () async {
                              // 1. Para o scan antes de tentar conectar                                await FlutterBluePlus.stopScan();
                              
                              if (!context.mounted) return;
                               // 2. Navega para a tela de configuração de Wi-Fi
                              bool? configuradoComSucesso = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TelaConfigurarWiFi(dispositivo: r.device),
                                ),
                              );
                               // 3. Se a configuração deu certo, fecha a tela de busca e volta pro Dashboard
                              if (configuradoComSucesso == true && context.mounted) {
                                Navigator.pop(context, true);
                              }
                            },
                            child: const Text('Conectar'),
                          ),
                        ),
                      );
                    },
                  )
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ABA 2: PERFIL (ATUALIZADA COM LOGOUT REAL DO FIREBASE)
// ============================================================================
class TelaPerfil extends StatelessWidget {
  const TelaPerfil({super.key});

  @override
  Widget build(BuildContext context) {
    // Pega o usuário logado atualmente no Firebase Auth
    final User? usuarioAtual = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Meu Perfil'), backgroundColor: Colors.transparent, elevation: 0),
      body: ListView(
        children: [
          ListTile(
            leading: const CircleAvatar(
              radius: 25,
              backgroundColor: Colors.cyan,
              child: Icon(Icons.person, color: Colors.white),
            ),
            title: const Text('Dono da Casa', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(usuarioAtual?.email ?? 'usuario@email.com'), // Exibe o e-mail real do usuário
          ),
          const Divider(),
          const ListTile(leading: Icon(Icons.settings), title: Text('Configurações da Conta')),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red), 
            title: const Text('Sair da Conta', style: TextStyle(color: Colors.red)),
            onTap: () async {
              // Faz o logout definitivo no Firebase
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                // Redireciona de volta para a tela de login limpando a pilha de navegação
                Navigator.pushAndRemoveUntil(
                  context, 
                  MaterialPageRoute(builder: (context) => const TelaLogin()),
                  (route) => false
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
// ============================================================================
// TELA CONFIGURAR WI-FI DO ESP32
// ============================================================================
class TelaConfigurarWiFi extends StatefulWidget {
  final BluetoothDevice dispositivo;

  const TelaConfigurarWiFi({super.key, required this.dispositivo});

  @override
  State<TelaConfigurarWiFi> createState() => _TelaConfigurarWiFiState();
}

class _TelaConfigurarWiFiState extends State<TelaConfigurarWiFi> {
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  bool _conectando = false;
  bool _enviando = false;

  // UUIDs que DEVEM ser os mesmos programados no ESP32
  final String _serviceUuid = "4faac601-1b4a-11e7-b060-0002a5d5c51b"; // Substitua pelo seu
  final String _characteristicUuid = "bea5a097-1b4a-11e7-b060-0002a5d5c51b"; // Substitua pelo seu

  @override
  void initState() {
    super.initState();
    _conectarAoDispositivo();
  }

  Future<void> _conectarAoDispositivo() async {
    setState(() => _conectando = true);
    try {
      // Conecta ao ESP32
      await widget.dispositivo.connect(timeout: const Duration(seconds: 10));
    } catch (e) {
      debugPrint("Erro ao conectar: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Falha ao conectar ao dispositivo.'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _conectando = false);
    }
  }

  Future<void> _enviarCredenciais() async {
    String ssid = _ssidController.text.trim();
    String senha = _senhaController.text.trim();

    if (ssid.isEmpty || senha.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha o nome da rede e a senha.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _enviando = true);

    try {
      // 1. Descobre os serviços do ESP32
      List<BluetoothService> services = await widget.dispositivo.discoverServices();
      BluetoothCharacteristic? wifiCharacteristic;

      // 2. Procura a característica específica para enviar os dados
      for (var service in services) {
        if (service.uuid.toString() == _serviceUuid) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString() == _characteristicUuid) {
              wifiCharacteristic = characteristic;
              break;
            }
          }
        }
      }

      if (wifiCharacteristic != null) {
        // 3. Monta os dados (aqui estou usando JSON, mas pode ser uma string separada por vírgula)
        String dadosWifi = jsonEncode({"ssid": ssid, "senha": senha});
        
        // 4. Escreve na característica do ESP32
        await wifiCharacteristic.write(utf8.encode(dadosWifi));

        // 5. Salva no app que o medidor físico foi vinculado
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('medidor_adicionado', true);
        await prefs.setBool('modo_simulador_ativo', false); // Desativa o simulador

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Credenciais enviadas! Dispositivo vinculado.'), backgroundColor: Colors.green),
          );
          // Desconecta do Bluetooth (o ESP32 vai usar o Wi-Fi agora)
          await widget.dispositivo.disconnect();
          
          // Retorna 'true' para a tela anterior para fechar e atualizar o Dashboard
          Navigator.pop(context, true); 
        }
      } else {
        throw Exception("Serviço ou característica não encontrada no ESP32.");
      }
    } catch (e) {
      debugPrint("Erro ao enviar dados: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar credenciais: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  void dispose() {
    widget.dispositivo.disconnect(); // Garante que desconecte ao sair da tela
    _ssidController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Configurar ${widget.dispositivo.platformName}')),
      body: _conectando
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Estabelecendo conexão Bluetooth...'),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi, size: 80, color: Colors.cyan),
                  const SizedBox(height: 16),
                  const Text(
                    'Conecte o medidor à rede Wi-Fi',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _ssidController,
                    decoration: const InputDecoration(
                      labelText: 'Nome da Rede (SSID)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.router),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _senhaController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Senha da Rede',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _enviando
                      ? const CircularProgressIndicator()
                      : SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.cyan.shade700,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _enviarCredenciais,
                            child: const Text('ENVIAR PARA O MEDIDOR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                ],
              ),
            ),
    );
  }
}