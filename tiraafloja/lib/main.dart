import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:tiraafloja/services/mqtt/mqttController.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Juego de Tira y Afloja',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        fontFamily: 'Poppins',
      ),
      home: const TugOfWarScreen(),
    );
  }
}

class TugOfWarScreen extends StatefulWidget {
  const TugOfWarScreen({super.key});

  @override
  State<TugOfWarScreen> createState() => _TugOfWarScreenState();
}

class _TugOfWarScreenState extends State<TugOfWarScreen> with TickerProviderStateMixin {
  // Game State
  int _redScore = 0;
  int _blueScore = 0;
  int _timeLeft = 60;
  Timer? _timer;
  bool _isGameOver = false;

  // Animation & UI Constants
  static const int winningDifference = 10;
  static const double ribbonStartPercent = 0.5;
  static const double ribbonEndPercent = 0.1;

  double _ribbonPosition = ribbonStartPercent;

  // Particle and Confetti controllers
  final List<Particle> _particles = [];
  final List<Confetti> _confetti = [];
  late AnimationController _buttonPressController;



  @override
  void initState() {
    super.initState();
    _buttonPressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    startGame();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _buttonPressController.dispose();
    super.dispose();
  }

  // --- Game Logic ---

  void startGame() {
    MqttController.tryStartMqttConnection();
    setState(() {
      _redScore = 0;
      _blueScore = 0;
      _timeLeft = 60;
      _isGameOver = false;
      _ribbonPosition = ribbonStartPercent;
      _confetti.clear();
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => updateTimer());
  }

  void updateTimer() {
    if (_timeLeft > 0) {
      setState(() {
        _timeLeft--;
      });
    } else {
      _endGameByTimeout();
    }
  }

  void _handleButtonPress(String team, BuildContext buttonContext) {
    if (_isGameOver) return;

    // Create particles effect
    _createParticles(buttonContext, team == 'red' ? Colors.red.shade400 : Colors.blue.shade400);

    setState(() {
      if (team == 'red') {
        _redScore++;
      } else {
        _blueScore++;
      }
      _updateRibbonPosition();
      _checkWinCondition();
    });
  }

  void _updateRibbonPosition() {
    final scoreDiff = _redScore - _blueScore;
    final pullPercentage = (scoreDiff / winningDifference).clamp(-1.0, 1.0);
    const travelDistance = ribbonStartPercent - ribbonEndPercent;

    setState(() {
      _ribbonPosition = ribbonStartPercent - (pullPercentage * travelDistance);
    });
  }

  void _checkWinCondition() {
    final scoreDiff = _redScore - _blueScore;
    if (scoreDiff >= winningDifference) {
      _endGame('Rojo', '¡Victoria Instantánea!');
    } else if (scoreDiff <= -winningDifference) {
      _endGame('Azul', '¡Victoria Instantánea!');
    }
  }

  void _endGameByTimeout() {
    String winner;
    String subtitle = "¡Se acabó el tiempo!";
    if (_redScore > _blueScore) {
      winner = 'Rojo';
    } else if (_blueScore > _redScore) {
      winner = 'Azul';
    } else {
      winner = 'Nadie';
      subtitle = "¡Es un empate!";
    }
    _endGame(winner, subtitle, isDramatic: false);
  }

  void _endGame(String winner, String subtitle, {bool isDramatic = true}) {
    if (_isGameOver) return;
    setState(() {
      _isGameOver = true;
      _timer?.cancel();
    });
    _createConfetti(winner, isDramatic ? 150 : 50);
    _showWinnerDialog(winner, subtitle);
  }

  // --- UI & Animations ---

  void _createParticles(BuildContext context, Color color) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final position = renderBox.localToGlobal(Offset.zero);

    final random = Random();
    for (int i = 0; i < 8; i++) {
      final particle = Particle(
        startPosition: position + Offset(size.width / 2, size.height / 2),
        color: color,
        random: random,
      );
      setState(() {
        _particles.add(particle);
      });
    }
  }

  void _createConfetti(String winner, int count) {
    final random = Random();
    Color baseColor = winner == 'Rojo' ? Colors.red.shade400 : (winner == 'Azul' ? Colors.blue.shade400 : Colors.amber);
    final colors = [baseColor, Colors.amber, Colors.yellow.shade600, Colors.white];

    for (int i = 0; i < count; i++) {
      setState(() {
        _confetti.add(Confetti(random: random, colors: colors));
      });
    }
  }

  void _showWinnerDialog(String winner, String subtitle) {
    Color winnerColor = winner == 'Rojo' ? Colors.red.shade400 : (winner == 'Azul' ? Colors.blue.shade400 : Colors.amber);
    String title = winner == 'Nadie' ? "¡Empate!" : "¡Equipo $winner Gana!";

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.black.withOpacity(0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: winnerColor, shadows: [Shadow(blurRadius: 10, color: winnerColor)])),
              const SizedBox(height: 16),
              Text(subtitle, style: const TextStyle(fontSize: 18, color: Colors.white70)),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  startGame();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellow.shade600,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                ),
                child: const Text('Jugar de Nuevo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1f2937), Color(0xFF111827)],
              ),
            ),
          ),

          // Main Layout
          Row(
            children: [
              // Red Team Panel
              Expanded(child: _buildTeamPanel('red')),
              // Center Arena
              _buildCenterArena(screenHeight),
              // Blue Team Panel
              Expanded(child: _buildTeamPanel('blue')),
            ],
          ),

          // Timer on Top
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                '${(_timeLeft / 60).floor()}:${(_timeLeft % 60).toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 50, fontWeight: FontWeight.bold, color: Colors.white54),
              ),
            ),
          ),

          // Particle Effects Overlay
          ..._particles,

          // Confetti Effects Overlay
          if (_isGameOver) ..._confetti,

        ],
      ),
    );
  }

  Widget _buildTeamPanel(String team) {
    final bool isRed = team == 'red';
    final Color color = isRed ? Colors.red.shade400 : Colors.blue.shade400;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          isRed ? 'EQUIPO ROJO' : 'EQUIPO AZUL',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 24),
        Text(
          '${isRed ? _redScore : _blueScore}',
          style: const TextStyle(fontSize: 72, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 48),
        SizedBox(
          width: 180,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              return Builder(
                builder: (buttonContext) => _TeamButton(
                  color: color,
                  onPressed: () => _handleButtonPress(team, buttonContext),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCenterArena(double screenHeight) {
    return SizedBox(
      width: 150,
      height: screenHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Goal Lines
          Positioned(top: screenHeight * 0.1, child: _GoalLine(color: Colors.red.shade400)),
          Positioned(bottom: screenHeight * 0.1, child: _GoalLine(color: Colors.blue.shade400)),
          const Positioned(top: 40, child: Text("META", style: TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold))),
          const Positioned(bottom: 40, child: Text("META", style: TextStyle(color: Colors.blue, fontSize: 18, fontWeight: FontWeight.bold))),

          // Rope
          Center(
            child: Container(
              width: 10,
              height: screenHeight * 0.8,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  gradient: const LinearGradient(colors: [Color(0xFFa16207), Color(0xFF854d0e)])
              ),
            ),
          ),

          // Ribbon
          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            top: screenHeight * _ribbonPosition - 15,
            child: _Ribbon(),
          ),
        ],
      ),
    );
  }
}

// --- Custom Widgets ---

class _TeamButton extends StatefulWidget {
  final Color color;
  final VoidCallback onPressed;

  const _TeamButton({required this.color, required this.onPressed});

  @override
  _TeamButtonState createState() => _TeamButtonState();
}

class _TeamButtonState extends State<_TeamButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        widget.onPressed();
      },
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [widget.color, Color.lerp(widget.color, Colors.black, 0.3)!],
          ),
          boxShadow: _isPressed ? [] : [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              spreadRadius: 2,
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        transform: Matrix4.translationValues(0, _isPressed ? 2 : 0, 0),
      ),
    );
  }
}

class _GoalLine extends StatelessWidget {
  final Color color;
  const _GoalLine({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      height: 6,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
        boxShadow: [
          BoxShadow(color: color, blurRadius: 15, spreadRadius: 3),
        ],
      ),
    );
  }
}

class _Ribbon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 30,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.red.shade300, Colors.red.shade600]),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.red.shade100, width: 3),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
    );
  }
}

// --- Particle and Confetti Animation Widgets ---

class Particle extends StatefulWidget {
  final Offset startPosition;
  final Color color;
  final Random random;

  const Particle({super.key, required this.startPosition, required this.color, required this.random});

  @override
  State<Particle> createState() => _ParticleState();
}

class _ParticleState extends State<Particle> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late double _endX;
  late double _endY;
  late double _size;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    final angle = widget.random.nextDouble() * 2 * pi;
    final distance = widget.random.nextDouble() * 80 + 40;
    _endX = cos(angle) * distance;
    _endY = sin(angle) * distance;
    _size = widget.random.nextDouble() * 8 + 4;

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final value = _animation.value;
        return Positioned(
          left: widget.startPosition.dx + _endX * value,
          top: widget.startPosition.dy + _endY * value,
          child: Opacity(
            opacity: 1.0 - value,
            child: Container(
              width: _size * (1 - value),
              height: _size * (1 - value),
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }
}

class Confetti extends StatefulWidget {
  final Random random;
  final List<Color> colors;
  const Confetti({super.key, required this.random, required this.colors});

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late double _startX;
  late double _rotation;
  late Color _color;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: Duration(milliseconds: widget.random.nextInt(2000) + 2000));
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));

    _startX = widget.random.nextDouble();
    _rotation = widget.random.nextDouble() * 360;
    _color = widget.colors[widget.random.nextInt(widget.colors.length)];

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Positioned(
          left: _startX * screenWidth,
          top: -20 + (_animation.value * (screenHeight + 40)),
          child: Transform.rotate(
            angle: _rotation * pi / 180,
            child: Container(
              width: 10,
              height: 20,
              color: _color,
            ),
          ),
        );
      },
    );
  }
}

