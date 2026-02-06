import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:wallpaper_manager_plus/wallpaper_manager_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

// ==========================================
// 1. BACKGROUND SERVICE (The Engine)
// ==========================================
const String taskName = "dailyWallpaperUpdate";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? jsonStr = prefs.getString('wallpaper_config');

      WallpaperConfig config = jsonStr != null
          ? WallpaperConfig.fromJson(json.decode(jsonStr))
          : WallpaperConfig(deadline: DateTime(DateTime.now().year, 12, 31));

      final imageBytes = await WallpaperGenerator.generate(config);

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/daily_update.png');
      await file.writeAsBytes(imageBytes);

      await WallpaperManagerPlus().setWallpaper(
        file,
        WallpaperManagerPlus.lockScreen,
      );
      return Future.value(true);
    } catch (e) {
      return Future.value(false);
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  runApp(DeadlineWallpaperApp());
}

// ==========================================
// 2. CONFIGURATION MODEL (The Brain)
// ==========================================

enum DotShape { circle, square, rounded }

class WallpaperConfig {
  DateTime deadline;
  String customText;

  // Appearance
  int backgroundColor1;
  int backgroundColor2;
  int activeDotColor;
  int inactiveDotColor;
  int textColor;
  int shapeIndex;

  // Dimensions & Layout
  double dotRadius;
  double dotSpacing;
  double topMargin;
  double sideMargin;
  double fontSizeTitle; // NEW: Control title size
  double fontSizeSub; // NEW: Control footer size

  WallpaperConfig({
    required this.deadline,
    this.customText = '2026 FOCUS',
    this.backgroundColor1 = 0xFF0f0f1e,
    this.backgroundColor2 = 0xFF1a1a3f,
    this.activeDotColor = 0xFF00D9FF,
    this.inactiveDotColor = 0xFF2A2A2A,
    this.textColor = 0xFFFFFFFF,
    this.shapeIndex = 0,
    this.dotRadius = 15.0,
    this.dotSpacing = 35.0,
    this.topMargin = 400.0,
    this.sideMargin = 60.0,
    this.fontSizeTitle = 80.0,
    this.fontSizeSub = 40.0,
  });

  Map<String, dynamic> toJson() => {
    'deadline': deadline.toIso8601String(),
    'customText': customText,
    'bg1': backgroundColor1,
    'bg2': backgroundColor2,
    'active': activeDotColor,
    'inactive': inactiveDotColor,
    'text': textColor,
    'shape': shapeIndex,
    'radius': dotRadius,
    'spacing': dotSpacing,
    'top': topMargin,
    'side': sideMargin,
    'fsTitle': fontSizeTitle,
    'fsSub': fontSizeSub,
  };

  factory WallpaperConfig.fromJson(Map<String, dynamic> json) {
    return WallpaperConfig(
      deadline: DateTime.parse(json['deadline']),
      customText: json['customText'] ?? '',
      backgroundColor1: json['bg1'] ?? 0xFF0f0f1e,
      backgroundColor2: json['bg2'] ?? 0xFF1a1a3f,
      activeDotColor: json['active'] ?? 0xFF00D9FF,
      inactiveDotColor: json['inactive'] ?? 0xFF2A2A2A,
      textColor: json['text'] ?? 0xFFFFFFFF,
      shapeIndex: json['shape'] ?? 0,
      dotRadius: (json['radius'] ?? 15.0).toDouble(),
      dotSpacing: (json['spacing'] ?? 35.0).toDouble(),
      topMargin: (json['top'] ?? 400.0).toDouble(),
      sideMargin: (json['side'] ?? 60.0).toDouble(),
      fontSizeTitle: (json['fsTitle'] ?? 80.0).toDouble(),
      fontSizeSub: (json['fsSub'] ?? 40.0).toDouble(),
    );
  }

  Color get bg1Color => Color(backgroundColor1);
  Color get bg2Color => Color(backgroundColor2);
  Color get activeColor => Color(activeDotColor);
  Color get inactiveColor => Color(inactiveDotColor);
  Color get txtColor => Color(textColor);
  DotShape get shape => DotShape.values[shapeIndex];
}

// ==========================================
// 3. THE PAINTER (The Artist)
// ==========================================

class WallpaperGenerator {
  static Future<Uint8List> generate(WallpaperConfig config) async {
    const width = 1440.0;
    const height = 3120.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));

    DateTime now = DateTime.now();
    DateTime startOfYear = DateTime(config.deadline.year);
    int totalDays = config.deadline.difference(startOfYear).inDays + 1;
    int daysSpent = now.difference(startOfYear).inDays.clamp(0, totalDays);

    final painter = WallpaperPainter(
      config: config,
      daysSpent: daysSpent,
      totalDays: totalDays,
    );

    painter.paint(canvas, Size(width, height));

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}

class WallpaperPainter extends CustomPainter {
  final WallpaperConfig config;
  final int daysSpent;
  final int totalDays;
  final Function(bool isOverflowing)? onOverflowCheck;

  WallpaperPainter({
    required this.config,
    required this.daysSpent,
    required this.totalDays,
    this.onOverflowCheck,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 1440.0;

    // Scale Dimensions
    final double sRadius = config.dotRadius * scale;
    final double sSpacing = config.dotSpacing * scale;
    final double sTopMargin = config.topMargin * scale;
    final double sSideMargin = config.sideMargin * scale;
    final double sFontSizeTitle = config.fontSizeTitle * scale;
    final double sFontSizeSub = config.fontSizeSub * scale;

    // 1. Gradient Background (Restored!)
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = ui.Gradient.linear(
      Offset(0, 0),
      Offset(size.width, size.height),
      [config.bg1Color, config.bg2Color],
    );
    canvas.drawRect(rect, Paint()..shader = gradient);

    // 2. Title Text (With Shadow Polish)
    double currentY = sTopMargin;
    if (config.customText.isNotEmpty) {
      final titlePainter = TextPainter(
        text: TextSpan(
          text: config.customText,
          style: TextStyle(
            color: config.txtColor,
            fontSize: sFontSizeTitle,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.5, // Wide, cinematic spacing
            shadows: [
              Shadow(
                blurRadius: 15,
                color: Colors.black.withOpacity(0.5),
                offset: Offset(0, 4),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      titlePainter.layout(maxWidth: size.width - (sSideMargin * 2));
      titlePainter.paint(
        canvas,
        Offset((size.width - titlePainter.width) / 2, currentY),
      );
      currentY += titlePainter.height + (60 * scale);
    }

    // 3. Grid Logic
    final double itemSize = sRadius * 2;
    final double itemStride = itemSize + sSpacing;
    final double contentWidth = size.width - (sSideMargin * 2);

    int cols = (contentWidth / itemStride).floor();
    if (cols < 1) cols = 1;
    final int rows = (totalDays / cols).ceil();

    final double gridWidth = (cols * itemStride) - sSpacing;
    final double gridHeight = (rows * itemStride) - sSpacing;
    final double startX = (size.width - gridWidth) / 2;

    // 4. Overflow Check
    final double contentEnd = currentY + gridHeight + (200 * scale);
    if (onOverflowCheck != null) {
      Future.microtask(() => onOverflowCheck!(contentEnd > size.height));
    }

    // 5. Draw Dots (With Shape Support & Glow)
    for (int i = 0; i < totalDays; i++) {
      final int row = i ~/ cols;
      final int col = i % cols;
      final double dx = startX + (col * itemStride) + sRadius;
      final double dy = currentY + (row * itemStride) + sRadius;
      final center = Offset(dx, dy);
      final bool isActive = i < daysSpent;

      final paint = Paint()
        ..color = isActive ? config.activeColor : config.inactiveColor;

      // Draw Base Shape
      if (config.shape == DotShape.circle) {
        canvas.drawCircle(center, sRadius, paint);
      } else if (config.shape == DotShape.square) {
        canvas.drawRect(
          Rect.fromCenter(
            center: center,
            width: sRadius * 2,
            height: sRadius * 2,
          ),
          paint,
        );
      } else if (config.shape == DotShape.rounded) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: center,
              width: sRadius * 2,
              height: sRadius * 2,
            ),
            Radius.circular(sRadius * 0.4),
          ),
          paint,
        );
      }

      // Draw Glow (Active only) - Subtle & Clean
      if (isActive) {
        final glowPaint = Paint()
          ..color = config.activeColor.withOpacity(0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * scale;

        if (config.shape == DotShape.circle) {
          canvas.drawCircle(center, sRadius + (4 * scale), glowPaint);
        } else {
          canvas.drawRect(
            Rect.fromCenter(
              center: center,
              width: sRadius * 2 + (6 * scale),
              height: sRadius * 2 + (6 * scale),
            ),
            glowPaint,
          );
        }
      }
    }

    // 6. Footer Text (With Custom Size & Shadow)
    final progressText = '$daysSpent / $totalDays days gone';
    final progressPainter = TextPainter(
      text: TextSpan(
        text: progressText,
        style: TextStyle(
          color: config.txtColor.withOpacity(0.8),
          fontSize: sFontSizeSub,
          letterSpacing: 1.2,
          shadows: [
            Shadow(blurRadius: 4, color: Colors.black45, offset: Offset(1, 1)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    progressPainter.layout();
    progressPainter.paint(
      canvas,
      Offset(
        (size.width - progressPainter.width) / 2,
        size.height - (size.height * 0.08),
      ),
    );
  }

  @override
  bool shouldRepaint(covariant WallpaperPainter oldDelegate) => true;
}

// ==========================================
// 4. UI: EDITOR SCREEN
// ==========================================

class DeadlineWallpaperApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ticking Point',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.cyan,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: WallpaperEditorScreen(),
    );
  }
}

class WallpaperEditorScreen extends StatefulWidget {
  @override
  _WallpaperEditorScreenState createState() => _WallpaperEditorScreenState();
}

class _WallpaperEditorScreenState extends State<WallpaperEditorScreen> {
  WallpaperConfig _config = WallpaperConfig(
    deadline: DateTime(DateTime.now().year, 12, 31),
  );
  final TextEditingController _textController = TextEditingController();
  bool _isOverflowing = false;
  bool _isLoading = true;
  bool _autoUpdateEnabled = false;

  // --- GRADIENT PRESETS (Restored) ---
  final List<List<Color>> _bgGradients = [
    [Color(0xFF0f0f1e), Color(0xFF1a1a3f)], // Deep Space
    [Color(0xFF000000), Color(0xFF111111)], // Void Black
    [Color(0xFF1A0B2E), Color(0xFF381658)], // Royal Purple
    [Color(0xFF0F2027), Color(0xFF2C5364)], // Teal Deep
    [Color(0xFF232526), Color(0xFF414345)], // Gunmetal
    [Color(0xFF141E30), Color(0xFF243B55)], // Night Sky
  ];

  // --- DOT COLOR PRESETS ---
  final List<Color> _dotColors = [
    Color(0xFF00D9FF), // Cyan
    Color(0xFF00FF9D), // Neon Green
    Color(0xFFFF0055), // Neon Red
    Color(0xFFFFDD00), // Gold
    Color(0xFFFFFFFF), // White
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('wallpaper_config');
    final autoUpdate = prefs.getBool('auto_update') ?? false;

    if (jsonStr != null) {
      setState(() {
        _config = WallpaperConfig.fromJson(json.decode(jsonStr));
        _textController.text = _config.customText;
        _autoUpdateEnabled = autoUpdate;
      });
    } else {
      _textController.text = _config.customText;
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wallpaper_config', json.encode(_config.toJson()));
    await prefs.setBool('auto_update', _autoUpdateEnabled);
  }

  Future<void> _toggleAutoUpdate(bool value) async {
    setState(() => _autoUpdateEnabled = value);
    await _saveSettings();

    if (value) {
      await Workmanager().registerPeriodicTask(
        "daily_sync",
        taskName,
        frequency: Duration(hours: 12),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update, // FIX APPLIED
        constraints: Constraints(), // FIX APPLIED
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Auto-Update Enabled (Daily)")));
    } else {
      await Workmanager().cancelAll();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Auto-Update Disabled")));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Design Wallpaper",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        actions: [
          Row(
            children: [
              Text(
                "Auto-Set",
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
              Switch(
                value: _autoUpdateEnabled,
                onChanged: _toggleAutoUpdate,
                activeColor: _config.activeColor,
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // --- PREVIEW AREA ---
          Expanded(
            flex: 4,
            child: Container(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 9 / 19.5,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white12, width: 2),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(blurRadius: 20, color: Colors.black),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          DateTime now = DateTime.now();
                          DateTime startOfYear = DateTime(
                            _config.deadline.year,
                          );
                          int totalDays =
                              _config.deadline.difference(startOfYear).inDays +
                              1;
                          int daysSpent = now
                              .difference(startOfYear)
                              .inDays
                              .clamp(0, totalDays);

                          return CustomPaint(
                            size: Size(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            ),
                            painter: WallpaperPainter(
                              config: _config,
                              daysSpent: daysSpent,
                              totalDays: totalDays,
                              onOverflowCheck: (val) {
                                if (_isOverflowing != val) {
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (mounted)
                                      setState(() => _isOverflowing = val);
                                  });
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // --- CONTROLS AREA ---
          Expanded(
            flex: 5,
            child: Container(
              decoration: BoxDecoration(
                color: Color(0xFF121212),
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white10,
                    blurRadius: 2,
                    offset: Offset(0, -1),
                  ),
                ],
              ),
              child: ListView(
                padding: EdgeInsets.all(24),
                children: [
                  // 1. Text & Date
                  _buildHeader("Goal"),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: "Enter Title",
                            hintStyle: TextStyle(color: Colors.grey),
                            filled: true,
                            fillColor: Colors.white10,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (val) =>
                              setState(() => _config.customText = val),
                        ),
                      ),
                      SizedBox(width: 10),
                      IconButton(
                        icon: Icon(
                          Icons.calendar_month,
                          color: _config.activeColor,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white10,
                        ),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _config.deadline,
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null)
                            setState(() => _config.deadline = picked);
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 20),

                  // 2. Background Gradients
                  _buildHeader("Background Style"),
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _bgGradients.length,
                      itemBuilder: (ctx, i) {
                        bool isSelected =
                            _config.backgroundColor1 ==
                            _bgGradients[i][0].value;
                        return GestureDetector(
                          onTap: () => setState(() {
                            _config.backgroundColor1 = _bgGradients[i][0].value;
                            _config.backgroundColor2 = _bgGradients[i][1].value;
                          }),
                          child: Container(
                            margin: EdgeInsets.only(right: 12),
                            width: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(colors: _bgGradients[i]),
                              border: isSelected
                                  ? Border.all(color: Colors.white, width: 2)
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 20),

                  // 3. Dot Style (Shape & Color)
                  _buildHeader("Dot Style"),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _dotColors.length,
                            itemBuilder: (ctx, i) =>
                                _buildColorBtn(_dotColors[i]),
                          ),
                        ),
                      ),
                      Container(width: 1, height: 30, color: Colors.white24),
                      SizedBox(width: 10),
                      _buildShapeBtn(DotShape.circle, Icons.circle),
                      _buildShapeBtn(DotShape.rounded, Icons.crop_square),
                      _buildShapeBtn(DotShape.square, Icons.square),
                    ],
                  ),
                  SizedBox(height: 20),

                  // 4. Dimensions Sliders
                  _buildHeader("Layout & Sizing"),
                  _buildSlider(
                    "Top Margin",
                    _config.topMargin,
                    0,
                    1000,
                    (v) => setState(() => _config.topMargin = v),
                  ),
                  _buildSlider(
                    "Side Margin",
                    _config.sideMargin,
                    0,
                    200,
                    (v) => setState(() => _config.sideMargin = v),
                  ),
                  _buildSlider(
                    "Dot Size",
                    _config.dotRadius,
                    5,
                    50,
                    (v) => setState(() => _config.dotRadius = v),
                  ),
                  _buildSlider(
                    "Spacing",
                    _config.dotSpacing,
                    5,
                    60,
                    (v) => setState(() => _config.dotSpacing = v),
                  ),

                  // 5. Typography Sliders (RESTORED)
                  _buildHeader("Typography"),
                  _buildSlider(
                    "Title Size",
                    _config.fontSizeTitle,
                    20,
                    150,
                    (v) => setState(() => _config.fontSizeTitle = v),
                  ),
                  _buildSlider(
                    "Footer Size",
                    _config.fontSizeSub,
                    10,
                    80,
                    (v) => setState(() => _config.fontSizeSub = v),
                  ),

                  SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _isOverflowing
                        ? null
                        : () => _applyWallpaper(context),
                    child: Text(
                      _isOverflowing
                          ? "OVERFLOW DETECTED"
                          : "SAVE & SET WALLPAPER",
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isOverflowing
                          ? Colors.red.withOpacity(0.5)
                          : _config.activeColor,
                      foregroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(vertical: 20),
                      textStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShapeBtn(DotShape shape, IconData icon) {
    bool isSelected = _config.shape == shape;
    return IconButton(
      icon: Icon(
        icon,
        color: isSelected ? _config.activeColor : Colors.grey[700],
      ),
      onPressed: () => setState(() => _config.shapeIndex = shape.index),
      iconSize: 24,
      padding: EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildColorBtn(Color c) {
    bool isSelected = _config.activeDotColor == c.value;
    return GestureDetector(
      onTap: () => setState(() => _config.activeDotColor = c.value),
      child: Container(
        margin: EdgeInsets.only(right: 8),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
        ),
      ),
    );
  }

  Widget _buildSlider(
    String label,
    double value,
    double min,
    double max,
    Function(double) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        SizedBox(
          height: 30,
          child: Slider(
            value: value,
            min: min,
            max: max,
            activeColor: _config.activeColor,
            inactiveColor: Colors.white10,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(String title) => Padding(
    padding: EdgeInsets.only(bottom: 10, top: 10),
    child: Text(
      title.toUpperCase(),
      style: TextStyle(
        color: Colors.white54,
        fontWeight: FontWeight.bold,
        fontSize: 11,
        letterSpacing: 1,
      ),
    ),
  );

  Future<void> _applyWallpaper(BuildContext context) async {
    await _saveSettings();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(child: CircularProgressIndicator()),
    );

    try {
      final imageBytes = await WallpaperGenerator.generate(_config);

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/wallpaper.png');
      await file.writeAsBytes(imageBytes);

      await WallpaperManagerPlus().setWallpaper(
        file,
        WallpaperManagerPlus.lockScreen,
      );

      if (_autoUpdateEnabled) _toggleAutoUpdate(true);

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Wallpaper Updated!"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }
}
