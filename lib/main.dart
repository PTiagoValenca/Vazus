import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart'; // Biblioteca de gráficos que adicionamos

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
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
      home: const TelaLogin(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ============================================================================
// TELA DE LOGIN
// ============================================================================
class TelaLogin extends StatelessWidget {
  const TelaLogin({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.cyan[700],
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.water_drop, size: 100, color: Colors.white),
              const SizedBox(height: 20),
              const Text('Vazus', style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white)),
              const Text('Controle inteligente de água', style: TextStyle(fontSize: 16, color: Colors.white70)),
              const SizedBox(height: 60),
              TextField(decoration: InputDecoration(filled: true, fillColor: Colors.white, hintText: 'E-mail', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 15),
              TextField(obscureText: true, decoration: InputDecoration(filled: true, fillColor: Colors.white, hintText: 'Senha', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const TelaPrincipal())),
                  child: const Text('Entrar', style: TextStyle(fontSize: 18)),
                ),
              ),
              TextButton(onPressed: () {}, child: const Text('Criar uma conta', style: TextStyle(color: Colors.white)))
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// TELA MESTRE (Abas)
// ============================================================================
class TelaPrincipal extends StatefulWidget {
  const TelaPrincipal({super.key});

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> {
  int _indiceAbaAtual = 0;
  final List<Widget> _telas = const [TelaDashboard(), TelaAdicionar(), TelaPerfil()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _indiceAbaAtual, children: _telas),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indiceAbaAtual,
        onTap: (indice) => setState(() => _indiceAbaAtual = indice),
        selectedItemColor: Colors.cyan[700],
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Visão Geral'),
          BottomNavigationBarItem(icon: Icon(Icons.bluetooth_connected), label: 'Parear'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Conta'),
        ],
      ),
    );
  }
}

// ============================================================================
// ABA 1: VISÃO GERAL (Dashboard e Gráficos)
// ============================================================================
class TelaDashboard extends StatefulWidget {
  const TelaDashboard({super.key});

  @override
  State<TelaDashboard> createState() => _TelaDashboardState();
}

class _TelaDashboardState extends State<TelaDashboard> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('usuarios/user_123/sensores');
  Timer? _simuladorTimer;
  bool _simulando = false;

  void _alternarSimulacao() {
    setState(() => _simulando = !_simulando);

    if (_simulando) {
      _dbRef.child('Entrada_Principal').update({'nome': 'Relógio da Rua', 'tipo': 'entrada', 'vazao': 0.0});
      _dbRef.child('Saida_01').update({'nome': 'Chuveiro Filhos', 'tipo': 'saida', 'vazao': 0.0});
      _dbRef.child('Saida_02').update({'nome': 'Pia da Cozinha', 'tipo': 'saida', 'vazao': 0.0});

      _simuladorTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
        double vazaoChuveiro = Random().nextDouble() * 10.0; 
        double vazaoPia = Random().nextDouble() * 5.0; 
        double vazaoEntrada = vazaoChuveiro + vazaoPia + 3.5; 
        
        _dbRef.child('Entrada_Principal').update({'vazao': vazaoEntrada});
        _dbRef.child('Saida_01').update({'vazao': vazaoChuveiro});
        _dbRef.child('Saida_02').update({'vazao': vazaoPia});
      });
    } else {
      _simuladorTimer?.cancel();
      _dbRef.child('Entrada_Principal').update({'vazao': 0.0});
      _dbRef.child('Saida_01').update({'vazao': 0.0});
      _dbRef.child('Saida_02').update({'vazao': 0.0});
    }
  }

  @override
  void dispose() {
    _simuladorTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visão Geral', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: Icon(_simulando ? Icons.stop_circle : Icons.play_circle_fill),
            color: _simulando ? Colors.red : Colors.green,
            onPressed: _alternarSimulacao,
          )
        ],
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: _dbRef.onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) return const Center(child: Text('Nenhum sensor detectado.'));

          Map<dynamic, dynamic> sensores = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          
          double vazaoEntrada = 0.0;
          double somaSaidas = 0.0;
          List<Widget> cardsSaidas = [];

          sensores.forEach((key, value) {
            double vazao = (value['vazao'] ?? 0.0).toDouble();
            if (value['tipo'] == 'entrada') {
              vazaoEntrada = vazao;
            } else {
              somaSaidas += vazao;
              cardsSaidas.add(_construirCardSensor(value['nome'], vazao, false));
            }
          });

          double diferenca = vazaoEntrada - somaSaidas;
          bool alertaVazamento = diferenca > 0.5;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Alerta de Vazamento
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: alertaVazamento ? Colors.red[100] : Colors.green[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: alertaVazamento ? Colors.red : Colors.green),
                ),
                child: Row(
                  children: [
                    Icon(alertaVazamento ? Icons.warning : Icons.check_circle, color: alertaVazamento ? Colors.red : Colors.green, size: 40),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(alertaVazamento ? 'Vazamento Detectado!' : 'Sistema Normal', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(alertaVazamento ? 'Divergência de ${diferenca.toStringAsFixed(1)} L/m na rede.' : 'Entrada e saídas balanceadas.'),
                        ],
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // Relógios em Tempo Real
              const Text('Relógio Principal (Entrada)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              _construirCardSensor('Água da Rua', vazaoEntrada, true),
              const SizedBox(height: 20),
              const Text('Pontos de Consumo (Saídas)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ...cardsSaidas,
              
              const SizedBox(height: 30),
              
              // Gráfico Histórico
              const Text('Histórico de Consumo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _construirGrafico(),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  Widget _construirCardSensor(String nome, double vazao, bool isEntrada) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: Icon(isEntrada ? Icons.account_balance : Icons.shower, color: Colors.cyan, size: 30),
        title: Text(nome, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Text('${vazao.toStringAsFixed(1)} L/m', style: TextStyle(fontSize: 18, color: vazao > 0 ? Colors.cyan[700] : Colors.grey, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // Função que constrói o Gráfico de Barras do fl_chart
  Widget _construirGrafico() {
    return Container(
      height: 250,
      padding: const EdgeInsets.only(top: 20, right: 20, left: 10, bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 500, // Limite superior do eixo Y (Litros)
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              // A propriedade atualizada na versão mais recente do fl_chart:
              getTooltipColor: (group) => Colors.blueGrey,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${rod.toY.round()} L', 
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  const dias = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sab', 'Dom'];
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(dias[value.toInt()], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  if (value % 100 != 0) return const SizedBox.shrink();
                  return Text('${value.toInt()}', style: const TextStyle(fontSize: 10, color: Colors.grey));
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey[300], strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          // Dados Simulados da Semana (Litros por dia)
          barGroups: [
            BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 320, color: Colors.cyan, width: 16, borderRadius: BorderRadius.circular(4))]),
            BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 280, color: Colors.cyan, width: 16, borderRadius: BorderRadius.circular(4))]),
            BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 410, color: Colors.cyan, width: 16, borderRadius: BorderRadius.circular(4))]),
            BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: 150, color: Colors.cyan, width: 16, borderRadius: BorderRadius.circular(4))]),
            BarChartGroupData(x: 4, barRods: [BarChartRodData(toY: 210, color: Colors.cyan, width: 16, borderRadius: BorderRadius.circular(4))]),
            BarChartGroupData(x: 5, barRods: [BarChartRodData(toY: 480, color: Colors.cyan, width: 16, borderRadius: BorderRadius.circular(4))]),
            BarChartGroupData(x: 6, barRods: [BarChartRodData(toY: 390, color: Colors.cyan, width: 16, borderRadius: BorderRadius.circular(4))]),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ABA 2: ADICIONAR (Mock do Bluetooth)
// ============================================================================
class TelaAdicionar extends StatelessWidget {
  const TelaAdicionar({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parear Medidor'), backgroundColor: Colors.transparent, elevation: 0),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bluetooth_searching, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            const Text('Buscar Medidores Próximos', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Ligue o medidor e certifique-se de estar com o Bluetooth do celular ativado para enviar a senha do Wi-Fi.', textAlign: TextAlign.center),
            ),
            ElevatedButton(onPressed: () {}, child: const Text('Escanear Dispositivos')),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ABA 3: PERFIL (Mock da Conta)
// ============================================================================
class TelaPerfil extends StatelessWidget {
  const TelaPerfil({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meu Perfil'), backgroundColor: Colors.transparent, elevation: 0),
      body: ListView(
        children: const [
          ListTile(
            leading: CircleAvatar(backgroundColor: Colors.cyan, child: Icon(Icons.person, color: Colors.white)),
            title: Text('Dono da Casa', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('usuario@email.com'),
          ),
          Divider(),
          ListTile(leading: Icon(Icons.settings), title: Text('Configurações da Conta')),
          ListTile(leading: Icon(Icons.logout, color: Colors.red), title: Text('Sair', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}