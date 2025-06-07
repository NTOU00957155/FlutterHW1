import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(const MaterialApp(home: MenuScreen()));
}

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Color Catch',
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ColorCatchGame(difficulty: 'easy'))),
              child: const Text('Easy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ColorCatchGame(difficulty: 'normal'))),
              child: const Text('Normal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ColorCatchGame(difficulty: 'hard'))),
              child: const Text('Hard'),
            ),
          ],
        ),
      ),
    );
  }
}

class ColorCatchGame extends StatefulWidget {
  final String difficulty;
  const ColorCatchGame({super.key, required this.difficulty});

  @override
  State<ColorCatchGame> createState() => _ColorCatchGameState();
}

class _ColorCatchGameState extends State<ColorCatchGame> {
  double playerX = 0;
  double playerY = 1.0; // 玩家初始垂直位置固定在底部 (1.0)
  double fallingX = 0;
  double fallingY = -1;
  int score = 0;
  int highScore = 0;
  Timer? gameLoop;
  Timer? speedUpTimer;
  final AudioPlayer player = AudioPlayer();
  int timerSeconds = 30;
  int pointMultiplier = 1;

  // 掉落速度控制
  late double fallingSpeed; // 每次更新移動量
  late Duration fallingInterval; // 掉落更新間隔

  // 用於 joystick 控制
  double joystickX = 0;
  double joystickY = 0;

  @override
  void initState() {
    super.initState();
    loadHighScore();
    setDifficulty();
    startGameLoop();
    resetFalling();
  }

  @override
  void dispose() {
    gameLoop?.cancel();
    speedUpTimer?.cancel();
    player.dispose();
    super.dispose();
  }

  void setDifficulty() {
    switch (widget.difficulty) {
      case 'easy':
        pointMultiplier = 1;
        fallingInterval = const Duration(milliseconds: 1500);
        fallingSpeed = 0.02;
        break;
      case 'normal':
        pointMultiplier = 2;
        fallingInterval = const Duration(milliseconds: 1000);
        fallingSpeed = 0.04;
        break;
      case 'hard':
        pointMultiplier = 3;
        fallingInterval = const Duration(milliseconds: 600);
        fallingSpeed = 0.07;
        break;
      default:
        pointMultiplier = 1;
        fallingInterval = const Duration(milliseconds: 1500);
        fallingSpeed = 0.02;
    }
  }

  void startGameLoop() {
    // 用 Timer.periodic 控制掉落邏輯，但加速效果用另一個 Timer 逐漸調高 fallingSpeed
    gameLoop = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      setState(() {
        // 掉落方塊位置往下移動，乘上速度 (速度會加速)
        fallingY += fallingSpeed;

        // 玩家移動 (Joystick 控制，每次調整位置，clamp 保持在 -1 ~ 1 範圍內)
        playerX = (playerX + joystickX * 0.05).clamp(-1.0, 1.0);
        playerY = (playerY + joystickY * 0.05).clamp(-1.0, 1.0);
      });

      // 掉落到底或被接住重置方塊位置
      if (fallingY > 1.2) {
        resetFalling();
      } else if ((fallingY >= playerY - 0.1 && fallingY <= playerY + 0.1) &&
          (playerX - fallingX).abs() < 0.2) {
        player.play(AssetSource('catch.mp3'));
        setState(() => score += pointMultiplier);
        resetFalling();
      }
    });

    // 計時器
    Timer.periodic(const Duration(seconds: 1), (t) {
      if (timerSeconds == 0) {
        t.cancel();
        gameLoop?.cancel();
        speedUpTimer?.cancel();
        updateHighScore();
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('Time Up!'),
            content: Text('Your score: $score\nHigh score: $highScore'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const MenuScreen()),
                ),
                child: const Text('Back to Menu'),
              )
            ],
          ),
        );
      } else {
        setState(() => timerSeconds--);
      }
    });

    // 掉落速度逐漸加快 (每 5 秒增加速度 10%)
    speedUpTimer = Timer.periodic(const Duration(seconds: 5), (t) {
      setState(() {
        fallingSpeed *= 1.1;
      });
    });
  }

  void resetFalling() {
    fallingX = (Random().nextDouble() * 2) - 1;
    fallingY = -1;
  }

  void loadHighScore() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() => highScore = prefs.getInt('highScore') ?? 0);
  }

  void updateHighScore() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (score > highScore) {
      await prefs.setInt('highScore', score);
      setState(() => highScore = score);
    }
  }

  Widget getImageBlock(String asset, double x, double y, {double size = 60}) {
    return Align(
      alignment: Alignment(x, y),
      child: Image.asset(asset, width: size, height: size),
    );
  }

  // 自製簡易虛擬搖桿
  Widget buildJoystick() {
    return Align(
      alignment: const Alignment(0, 0.85),
      child: GestureDetector(
        onPanStart: (details) {
          updateJoystick(details.localPosition);
        },
        onPanUpdate: (details) {
          updateJoystick(details.localPosition);
        },
        onPanEnd: (details) {
          setState(() {
            joystickX = 0;
            joystickY = 0;
          });
        },
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.grey.shade300.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey.shade700,
                shape: BoxShape.circle,
              ),
              transform: Matrix4.translationValues(
                joystickX * 30,
                joystickY * 30,
                0,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 解析搖桿觸控位置，轉換成 -1 ~ 1 範圍的 x, y
  void updateJoystick(Offset localPos) {
    final center = const Offset(60, 60);
    double dx = (localPos.dx - center.dx) / 60;
    double dy = (localPos.dy - center.dy) / 60;

    // 限制範圍
    if (dx > 1) dx = 1;
    if (dx < -1) dx = -1;
    if (dy > 1) dy = 1;
    if (dy < -1) dy = -1;

    setState(() {
      joystickX = dx;
      joystickY = dy;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 背景圖片
          Positioned.fill(
            child:
                Image.asset('assets/images/background.png', fit: BoxFit.cover),
          ),

          // 分數與倒數時間
          Positioned(
            top: 40,
            left: 20,
            child: Text("Score: $score",
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [Shadow(blurRadius: 3, color: Colors.black)])),
          ),
          Positioned(
            top: 70,
            left: 20,
            child: Text("Time: $timerSeconds",
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [Shadow(blurRadius: 3, color: Colors.black)])),
          ),

          // 掉落方塊
          getImageBlock('assets/images/falling.png', fallingX, fallingY),

          // 玩家角色
          getImageBlock('assets/images/player.png', playerX, playerY, size: 80),

          // 虛擬搖桿
          buildJoystick(),
        ],
      ),
    );
  }
}
