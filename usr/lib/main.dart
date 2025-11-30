import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart'; // Required for Ticker
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Platformer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const GameScreen(),
      },
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  // Game Loop
  late Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  // Physics Constants
  final double gravity = 1000.0;
  final double jumpForce = -550.0;
  final double moveSpeed = 200.0;
  final double maxFallSpeed = 600.0;

  // Game State
  double playerX = 50;
  double playerY = 300;
  double velocityX = 0;
  double velocityY = 0;
  bool isGrounded = false;
  bool isDead = false;
  bool hasWon = false;
  int score = 0;

  // Inputs
  bool leftPressed = false;
  bool rightPressed = false;
  bool jumpPressed = false;

  // World
  final double playerSize = 40;
  final List<Rect> platforms = [
    const Rect.fromLTWH(0, 500, 1000, 50), // Ground
    const Rect.fromLTWH(200, 400, 100, 20),
    const Rect.fromLTWH(400, 300, 100, 20),
    const Rect.fromLTWH(600, 200, 100, 20),
    const Rect.fromLTWH(800, 350, 150, 20),
    const Rect.fromLTWH(50, 250, 80, 20),
  ];

  final Rect goal = const Rect.fromLTWH(900, 280, 40, 60);

  // Enemies
  List<Enemy> enemies = [
    Enemy(x: 300, y: 460, range: 100),
    Enemy(x: 500, y: 460, range: 150),
    Enemy(x: 820, y: 310, range: 100),
  ];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _resetGame() {
    setState(() {
      playerX = 50;
      playerY = 300;
      velocityX = 0;
      velocityY = 0;
      isDead = false;
      hasWon = false;
      score = 0;
      // Reset enemies
      enemies = [
        Enemy(x: 300, y: 460, range: 100),
        Enemy(x: 500, y: 460, range: 150),
        Enemy(x: 820, y: 310, range: 100),
      ];
    });
  }

  void _onTick(Duration elapsed) {
    if (isDead || hasWon) return;

    final double dt = (elapsed - _lastElapsed).inMilliseconds / 1000.0;
    _lastElapsed = elapsed;

    if (dt > 0.1) return; // Prevent huge jumps on lag

    setState(() {
      _updatePhysics(dt);
      _updateEnemies(dt);
      _checkInteractions();
    });
  }

  void _updatePhysics(double dt) {
    // Horizontal Movement
    double targetVelocityX = 0;
    if (leftPressed) targetVelocityX -= moveSpeed;
    if (rightPressed) targetVelocityX += moveSpeed;

    // Simple acceleration/friction
    velocityX += (targetVelocityX - velocityX) * 10 * dt;

    // Apply Gravity
    velocityY += gravity * dt;
    if (velocityY > maxFallSpeed) velocityY = maxFallSpeed;

    // Jump
    if (jumpPressed && isGrounded) {
      velocityY = jumpForce;
      isGrounded = false;
      jumpPressed = false; // Consume jump
    }

    // Move X
    playerX += velocityX * dt;
    _checkCollisionX();

    // Move Y
    playerY += velocityY * dt;
    isGrounded = false; // Assume falling until collision proves otherwise
    _checkCollisionY();

    // Screen Bounds (Simple)
    if (playerX < 0) playerX = 0;
    if (playerY > 1000) {
      isDead = true; // Fell off world
    }
  }

  void _checkCollisionX() {
    Rect playerRect = Rect.fromLTWH(playerX, playerY, playerSize, playerSize);
    for (final platform in platforms) {
      if (playerRect.overlaps(platform)) {
        if (velocityX > 0) {
          playerX = platform.left - playerSize;
        } else if (velocityX < 0) {
          playerX = platform.right;
        }
        velocityX = 0;
      }
    }
  }

  void _checkCollisionY() {
    Rect playerRect = Rect.fromLTWH(playerX, playerY, playerSize, playerSize);
    for (final platform in platforms) {
      if (playerRect.overlaps(platform)) {
        if (velocityY > 0) {
          // Falling down
          playerY = platform.top - playerSize;
          isGrounded = true;
          velocityY = 0;
        } else if (velocityY < 0) {
          // Jumping up (hitting head)
          playerY = platform.bottom;
          velocityY = 0;
        }
      }
    }
  }

  void _updateEnemies(double dt) {
    for (var enemy in enemies) {
      if (!enemy.isDead) {
        enemy.update(dt);
      }
    }
  }

  void _checkInteractions() {
    Rect playerRect = Rect.fromLTWH(playerX, playerY, playerSize, playerSize);

    // Goal
    if (playerRect.overlaps(goal)) {
      hasWon = true;
    }

    // Enemies
    for (var enemy in enemies) {
      if (enemy.isDead) continue;
      
      Rect enemyRect = enemy.getRect();
      if (playerRect.overlaps(enemyRect)) {
        // Check if jumping on top
        bool isFalling = velocityY > 0;
        bool isAbove = (playerY + playerSize) < (enemy.y + enemy.height * 0.7);

        if (isFalling && isAbove) {
          // Kill enemy
          enemy.isDead = true;
          velocityY = jumpForce * 0.5; // Bounce
          score += 100;
        } else {
          // Die
          isDead = true;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue[100],
      body: KeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) leftPressed = true;
            if (event.logicalKey == LogicalKeyboardKey.arrowRight) rightPressed = true;
            if (event.logicalKey == LogicalKeyboardKey.space || event.logicalKey == LogicalKeyboardKey.arrowUp) jumpPressed = true;
          } else if (event is KeyUpEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) leftPressed = false;
            if (event.logicalKey == LogicalKeyboardKey.arrowRight) rightPressed = false;
            if (event.logicalKey == LogicalKeyboardKey.space || event.logicalKey == LogicalKeyboardKey.arrowUp) jumpPressed = false;
          }
        },
        child: Stack(
          children: [
            // Background Elements (Clouds etc could go here)
            
            // Platforms
            ...platforms.map((rect) => Positioned(
              left: rect.left,
              top: rect.top,
              width: rect.width,
              height: rect.height,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.brown,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.green[800]!, width: 2),
                ),
                child: Container(color: Colors.green, margin: const EdgeInsets.only(top: 0, bottom: 15)),
              ),
            )),

            // Goal
            Positioned(
              left: goal.left,
              top: goal.top,
              width: goal.width,
              height: goal.height,
              child: Container(
                color: Colors.yellow,
                child: const Center(child: Icon(Icons.star, color: Colors.orange)),
              ),
            ),

            // Enemies
            ...enemies.where((e) => !e.isDead).map((e) => Positioned(
              left: e.x,
              top: e.y,
              width: e.width,
              height: e.height,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.mood_bad, color: Colors.white, size: 20),
                ),
              ),
            )),

            // Player
            Positioned(
              left: playerX,
              top: playerY,
              width: playerSize,
              height: playerSize,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.face, color: Colors.white, size: 30),
              ),
            ),

            // UI / HUD
            Positioned(
              top: 40,
              left: 20,
              child: Text(
                'Score: $score',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),

            // Game Over / Win Screen
            if (isDead || hasWon)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        hasWon ? 'YOU WON!' : 'GAME OVER',
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: hasWon ? Colors.greenAccent : Colors.redAccent,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _resetGame,
                        child: const Text('Play Again'),
                      ),
                    ],
                  ),
                ),
              ),

            // Mobile Controls
            Positioned(
              bottom: 20,
              left: 20,
              child: Row(
                children: [
                  _ControlBtn(
                    icon: Icons.arrow_back,
                    onDown: () => leftPressed = true,
                    onUp: () => leftPressed = false,
                  ),
                  const SizedBox(width: 20),
                  _ControlBtn(
                    icon: Icons.arrow_forward,
                    onDown: () => rightPressed = true,
                    onUp: () => rightPressed = false,
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 20,
              right: 20,
              child: _ControlBtn(
                icon: Icons.arrow_upward,
                onDown: () => jumpPressed = true,
                onUp: () => jumpPressed = false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Enemy {
  double x;
  double y;
  double startX;
  double range;
  double speed = 100;
  double width = 40;
  double height = 40;
  int direction = 1;
  bool isDead = false;

  Enemy({required this.x, required this.y, required this.range}) : startX = x;

  void update(double dt) {
    x += speed * direction * dt;
    if (x > startX + range) {
      direction = -1;
      x = startX + range;
    } else if (x < startX) {
      direction = 1;
      x = startX;
    }
  }

  Rect getRect() {
    return Rect.fromLTWH(x, y, width, height);
  }
}

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onDown;
  final VoidCallback onUp;

  const _ControlBtn({
    required this.icon,
    required this.onDown,
    required this.onUp,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onDown(),
      onTapUp: (_) => onUp(),
      onTapCancel: () => onUp(),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 30),
      ),
    );
  }
}
