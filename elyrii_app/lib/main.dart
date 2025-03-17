import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Elyrii App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF6E3EFF),
        fontFamily: 'Poppins',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6E3EFF),
          primary: const Color(0xFF6E3EFF),
          secondary: const Color(0xFF8A54FF),
          tertiary: const Color(0xFFE9E7FF),
          background: const Color(0xFFF6F6FE),
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F6FE),
        useMaterial3: true,
        textTheme: const TextTheme(
          displayMedium: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF6E3EFF),
          ),
          bodyLarge: TextStyle(
            color: Color(0xFF4A4A4A),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF2F2FE),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  late AnimationController _pulseAnimationController;
  late AnimationController _floatingAnimationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _floatingAnimation;
  final List<String> _chatHistory = [];
  bool _isTyping = false;
  String _mascotteBubbleMessage = 'Bonjour ! Comment puis-je t\'aider aujourd\'hui ?';
  bool _showMascotView = true;
  
  @override
  void initState() {
    super.initState();
    
    // Create pulse animation controller
    _pulseAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    // Create floating animation controller
    _floatingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    
    // Create pulse animation
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseAnimationController, curve: Curves.easeInOut),
    );
    
    // Create floating animation
    _floatingAnimation = Tween<double>(begin: -5.0, end: 5.0).animate(
      CurvedAnimation(parent: _floatingAnimationController, curve: Curves.easeInOut),
    );
  }
  
  @override
  void dispose() {
    _pulseAnimationController.dispose();
    _floatingAnimationController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_messageController.text.isEmpty) return;
    
    final message = _messageController.text;
    setState(() {
      // Ajoute le message à l'historique si on est en mode chat
      if (!_showMascotView) {
        _chatHistory.add(message);
      }
      _messageController.clear();
      _isTyping = true;
    });
    
    // Simulate AI response after a delay
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          final response = "Je comprends ta question : \"$message\". Comment puis-je t'aider davantage ?";
          
          // Met à jour la bulle si on est en mode mascotte, sinon ajoute au chat
          if (_showMascotView) {
            _mascotteBubbleMessage = response;
          } else {
            _chatHistory.add(response);
          }
          _isTyping = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE9E7FF), Color(0xFFF6F6FE)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Animated Header with gradient
              _buildAnimatedHeader(),
              
              // Content area (mascot or chat)
              Expanded(
                child: _showMascotView ? _buildMascotView() : _buildChatListView(),
              ),
              
              // Input area
              _buildInputArea(),
            ],
          ),
        ),
      ),
      floatingActionButton: _showMascotView ? null : FloatingActionButton(
        onPressed: () {
          setState(() {
            _showMascotView = true;
            _mascotteBubbleMessage = 'Bonjour ! Comment puis-je t\'aider aujourd\'hui ?';
          });
        },
        backgroundColor: const Color(0xFF6E3EFF),
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }

  Widget _buildAnimatedHeader() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _showMascotView ? 80 : 60, // Hauteur réduite
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6E3EFF), Color(0xFF8A54FF)],
          stops: [0.3, 1.0],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20.0), // Radius réduit
          bottomRight: Radius.circular(20.0),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6E3EFF).withOpacity(0.2), // Ombre plus subtile
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Menu button
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              width: 32,
              height: 32,
              child: IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                padding: EdgeInsets.zero,
                iconSize: 16,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Menu principal"))
                  );
                },
              ),
            ),
            
            // Title with dots animation when typing
            Row(
              children: [
                // Option avec étoiles scintillantes
                Row(
                  children: [
                    _ShiningStarIcon(),
                    const SizedBox(width: 5),
                    
                    ShaderMask(
                      shaderCallback: (Rect bounds) {
                        return LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.white, Colors.white.withOpacity(0.8), Colors.white],
                          stops: const [0.0, 0.5, 1.0],
                        ).createShader(bounds);
                      },
                      child: const Text(
                        "ELYRII",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22.0,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 5),
                    _ShiningStarIcon(),
                  ],
                ),
                const SizedBox(width: 8),
                
                // Indicator dots (only shown when typing)
                if (_isTyping)
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _DotPulse(delay: 100),
                      SizedBox(width: 3),
                      _DotPulse(delay: 300),
                      SizedBox(width: 3),
                      _DotPulse(delay: 500),
                    ],
                  ),
              ],
            ),
            
            // Actions
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  width: 32,
                  height: 32,
                  child: IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white),
                    padding: EdgeInsets.zero,
                    iconSize: 16,
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Paramètres"))
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatContent() {
    return _showMascotView ? _buildMascotView() : _buildChatListView();
  }

  Widget _buildWelcomeView() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Position the mascot slightly lower to make room for the bubble
          Positioned(
            bottom: 40,
            child: AnimatedBuilder(
              animation: _floatingAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _floatingAnimation.value),
                  child: ScaleTransition(
                    scale: _pulseAnimation,
                    child: Hero(
                      tag: 'mascotteHero',
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6E3EFF).withOpacity(0.15),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(110),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Bonjour ! Je suis Elyrii !"))
                              );
                            },
                            child: Image.asset(
                              'assets/mascotte.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }
            ),
          ),
          
          // Speech bubble positioned above mascot
          Positioned(
            bottom: 260,
            child: Column(
              children: [
                // Speech bubble
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.8,
                  ),
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Bonjour ! Comment puis-je t\'aider aujourd\'hui ?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18.0,
                      color: Color(0xFF4A4A4A),
                    ),
                  ),
                ),
                
                // Small triangle for speech bubble
                Transform.translate(
                  offset: const Offset(0, -1),
                  child: CustomPaint(
                    size: const Size(20, 15),
                    painter: SpeechBubbleArrowPainter(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatListView() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      itemCount: _chatHistory.length,
      itemBuilder: (context, index) {
        final message = _chatHistory[index];
        final isUserMessage = index % 2 == 0;
        
        return Align(
          alignment: isUserMessage ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            margin: const EdgeInsets.only(bottom: 12.0),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: isUserMessage 
                  ? const Color(0xFF6E3EFF) 
                  : Colors.white,
              borderRadius: BorderRadius.circular(20.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              message,
              style: TextStyle(
                fontSize: 16.0,
                color: isUserMessage ? Colors.white : const Color(0xFF4A4A4A),
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30.0),
          topRight: Radius.circular(30.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Pose-moi une question...',
                contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: const Color(0xFFF2F2FE),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.mic, color: Color(0xFF6E3EFF)),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Fonctionnalité vocale disponible bientôt"))
                    );
                  },
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 10.0),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6E3EFF), Color(0xFF8A54FF)],
              ),
              borderRadius: BorderRadius.circular(25),
            ),
            child: FloatingActionButton(
              onPressed: _sendMessage,
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMascotView() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Position the mascot slightly lower to make room for the bubble
          Positioned(
            bottom: 40,
            child: AnimatedBuilder(
              animation: _floatingAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _floatingAnimation.value),
                  child: ScaleTransition(
                    scale: _pulseAnimation,
                    child: Hero(
                      tag: 'mascotteHero',
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6E3EFF).withOpacity(0.15),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(110),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Bonjour ! Je suis Elyrii !"))
                              );
                            },
                            child: Image.asset(
                              'assets/mascotte.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }
            ),
          ),
          
          // Speech bubble positioned above mascot
          Positioned(
            bottom: 260,
            child: Column(
              children: [
                // Speech bubble
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.8,
                  ),
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      if (_isTyping)
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _DotPulse(delay: 100),
                            SizedBox(width: 4),
                            _DotPulse(delay: 300),
                            SizedBox(width: 4),
                            _DotPulse(delay: 500),
                          ],
                        )
                      else
                        Text(
                          _mascotteBubbleMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18.0,
                            color: Color(0xFF4A4A4A),
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Small triangle for speech bubble
                Transform.translate(
                  offset: const Offset(0, -1),
                  child: CustomPaint(
                    size: const Size(20, 15),
                    painter: SpeechBubbleArrowPainter(),
                  ),
                ),
              ],
            ),
          ),
          
          // Bouton pour voir l'historique complet
          if (_chatHistory.isNotEmpty)
            Positioned(
              top: 20,
              right: 0,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showMascotView = false;
                  });
                },
                icon: const Icon(Icons.history, color: Color(0xFF6E3EFF)),
                label: const Text(
                  'Voir l\'historique',
                  style: TextStyle(color: Color(0xFF6E3EFF)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Custom animated dots for typing indicator
class _DotPulse extends StatefulWidget {
  final int delay;
  
  const _DotPulse({required this.delay});
  
  @override
  _DotPulseState createState() => _DotPulseState();
}

class _DotPulseState extends State<_DotPulse> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _animation = Tween<double>(begin: 0, end: 6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut)
    )..addListener(() {
      setState(() {});
    });
    
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.5),
            blurRadius: _animation.value,
            spreadRadius: 0,
          ),
        ],
      ),
    );
  }
}

// Suggestion chip for welcome screen
class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  
  const _SuggestionChip({required this.label, required this.onTap});
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE9E7FF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF6E3EFF).withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF6E3EFF),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// Add this class for the speech bubble arrow
class SpeechBubbleArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, paint);
    
    // Add shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    canvas.drawPath(path, shadowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Ajouter cette classe pour l'animation d'étoile
class _ShiningStarIcon extends StatefulWidget {
  @override
  State<_ShiningStarIcon> createState() => _ShiningStarIconState();
}

class _ShiningStarIconState extends State<_ShiningStarIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut)
    );
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
        return Opacity(
          opacity: _animation.value,
          child: Icon(
            Icons.auto_awesome,
            color: Colors.white,
            size: 16 * _animation.value,
          ),
        );
      }
    );
  }
}
