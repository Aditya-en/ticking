import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:wallpaper_manager_plus/wallpaper_manager_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

// ==========================================
// 1. CONFIGURATION MODEL
// ==========================================

class WallpaperConfig {
  DateTime deadline;
  String customText;

  // Appearance
  Color backgroundColor1;
  Color backgroundColor2;
  Color activeDotColor;
  Color inactiveDotColor;
  Color textColor;

  // Dimensions (Based on 1440px width reference)
  double dotRadius;
  double dotSpacing;
  double topMargin;
  double sideMargin; // NEW: Side padding

  WallpaperConfig({
    required this.deadline,
    this.customText = '',
    this.backgroundColor1 = const Color(0xFF0f0f1e),
    this.backgroundColor2 = const Color(0xFF1a1a3f),
    this.activeDotColor = const Color(0xFF00D9FF),
    this.inactiveDotColor = const Color(0xFF2A2A2A),
    this.textColor = Colors.white,
    this.dotRadius = 15.0,
    this.dotSpacing = 35.0,
    this.topMargin = 400.0,
    this.sideMargin = 60.0, // Default side margin
  });
}

void main() {
  runApp(DeadlineWallpaperApp());
}

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
        sliderTheme: SliderThemeData(
          showValueIndicator: ShowValueIndicator.always,
        ),
      ),
      home: WallpaperEditorScreen(),
    );
  }
}

// ==========================================
// 2. THE UNIFIED PAINTER
// ==========================================

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
    // 1. Calculate Scale Factor (Reference Width: 1440px)
    final double scale = size.width / 1440.0;

    // 2. Scale all dimensions
    final double sRadius = config.dotRadius * scale;
    final double sSpacing = config.dotSpacing * scale;
    final double sTopMargin = config.topMargin * scale;
    final double sSideMargin = config.sideMargin * scale;
    final double sFontSizeTitle = 80.0 * scale;
    final double sFontSizeSub = 40.0 * scale;

    // 3. Draw Background
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = ui.Gradient.linear(
      Offset(0, 0),
      Offset(size.width, size.height),
      [config.backgroundColor1, config.backgroundColor2],
    );
    canvas.drawRect(rect, Paint()..shader = gradient);

    // 4. Draw Title
    double currentY = sTopMargin;

    if (config.customText.isNotEmpty) {
      final titlePainter = TextPainter(
        text: TextSpan(
          text: config.customText,
          style: TextStyle(
            color: config.textColor,
            fontSize: sFontSizeTitle,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            shadows: [
              Shadow(
                blurRadius: 10,
                color: Colors.black45,
                offset: Offset(2, 2),
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

    // 5. Calculate Grid Layout
    final double itemSize = sRadius * 2;
    final double itemStride = itemSize + sSpacing;

    // Calculate Available Width using the NEW Side Margin
    final double contentWidth = size.width - (sSideMargin * 2);

    // How many columns fit?
    int cols = (contentWidth / itemStride).floor();
    if (cols < 1) cols = 1;

    // How many rows needed?
    final int rows = (totalDays / cols).ceil();

    // Calculate Grid Dimensions
    final double gridWidth = (cols * itemStride) - sSpacing;
    final double gridHeight = (rows * itemStride) - sSpacing;

    // Center the grid Horizontally
    final double startX = (size.width - gridWidth) / 2;

    // 6. Check for Overflow
    final double contentEnd = currentY + gridHeight + (200 * scale);
    if (onOverflowCheck != null) {
      Future.microtask(() => onOverflowCheck!(contentEnd > size.height));
    }

    // 7. Draw Dots
    for (int i = 0; i < totalDays; i++) {
      final int row = i ~/ cols;
      final int col = i % cols;

      final double dx = startX + (col * itemStride) + sRadius;
      final double dy = currentY + (row * itemStride) + sRadius;
      final center = Offset(dx, dy);

      final bool isActive = i < daysSpent;

      // Draw Dot
      canvas.drawCircle(
        center,
        sRadius,
        Paint()
          ..color = isActive ? config.activeDotColor : config.inactiveDotColor
          ..style = PaintingStyle.fill,
      );

      // Draw Glow
      if (isActive) {
        canvas.drawCircle(
          center,
          sRadius + (4 * scale),
          Paint()
            ..color = config.activeDotColor.withOpacity(0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2 * scale,
        );
      }
    }

    // 8. Draw Footer Text
    final progressText = '$daysSpent / $totalDays days gone';
    final progressPainter = TextPainter(
      text: TextSpan(
        text: progressText,
        style: TextStyle(
          color: config.textColor.withOpacity(0.6),
          fontSize: sFontSizeSub,
          letterSpacing: 1.2,
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
// 3. UI: EDITOR SCREEN
// ==========================================

class WallpaperEditorScreen extends StatefulWidget {
  @override
  _WallpaperEditorScreenState createState() => _WallpaperEditorScreenState();
}

class _WallpaperEditorScreenState extends State<WallpaperEditorScreen> {
  late WallpaperConfig _config;
  final TextEditingController _textController = TextEditingController();
  bool _isOverflowing = false;

  // --- PRESET COLORS ---
  final List<Color> _dotColors = [
    Color(0xFF00D9FF), // Cyan
    Color(0xFF00FF9D), // Neon Green
    Color(0xFFFF0055), // Neon Red
    Color(0xFFFFDD00), // Yellow
    Color(0xFFFF9100), // Orange
    Color(0xFFB300FF), // Purple
    Color(0xFFFFFFFF), // White
    Color(0xFF3B3B3B), // Grey
  ];

  final List<List<Color>> _bgGradients = [
    [Color(0xFF0f0f1e), Color(0xFF1a1a3f)], // Deep Blue
    [Color(0xFF000000), Color(0xFF111111)], // Pure Black
    [Color(0xFF1A0B2E), Color(0xFF381658)], // Royal Purple
    [Color(0xFF0F2027), Color(0xFF203A43)], // Teal Dark
    [Color(0xFF232526), Color(0xFF414345)], // Gunmetal
    [Color(0xFF3a1c71), Color(0xFFd76d77)], // Sunset
  ];

  @override
  void initState() {
    super.initState();
    _config = WallpaperConfig(
      deadline: DateTime(DateTime.now().year, 12, 31),
      customText: "2026 FOCUS",
    );
    _textController.text = _config.customText;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text("Design Wallpaper"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // PREVIEW AREA
          Expanded(
            flex: 4,
            child: Container(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 9 / 19.5,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white24, width: 2),
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

          // CONTROLS AREA
          Expanded(
            flex: 5,
            child: Container(
              decoration: BoxDecoration(
                color: Color(0xFF1E1E1E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 10,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: ListView(
                padding: EdgeInsets.all(24),
                children: [
                  _buildHeader("Colors"),
                  SizedBox(height: 10),
                  Text(
                    "Background",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  SizedBox(height: 8),
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _bgGradients.length,
                      itemBuilder: (ctx, i) {
                        return GestureDetector(
                          onTap: () => setState(() {
                            _config.backgroundColor1 = _bgGradients[i][0];
                            _config.backgroundColor2 = _bgGradients[i][1];
                          }),
                          child: Container(
                            margin: EdgeInsets.only(right: 12),
                            width: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: _bgGradients[i],
                              ),
                              border: Border.all(
                                color:
                                    _config.backgroundColor1 ==
                                        _bgGradients[i][0]
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    "Active Dots",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  SizedBox(height: 8),
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _dotColors.length,
                      itemBuilder: (ctx, i) {
                        return GestureDetector(
                          onTap: () => setState(
                            () => _config.activeDotColor = _dotColors[i],
                          ),
                          child: Container(
                            margin: EdgeInsets.only(right: 12),
                            width: 50,
                            decoration: BoxDecoration(
                              color: _dotColors[i],
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _config.activeDotColor == _dotColors[i]
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  SizedBox(height: 25),
                  _buildHeader("Layout"),
                  _buildSlider(
                    "Top Margin",
                    _config.topMargin,
                    0,
                    1500,
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
                    "Dot Radius",
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

                  SizedBox(height: 25),
                  _buildHeader("Content"),
                  TextField(
                    controller: _textController,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Title",
                      labelStyle: TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (val) =>
                        setState(() => _config.customText = val),
                  ),
                  SizedBox(height: 10),
                  OutlinedButton.icon(
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
                    icon: Icon(
                      Icons.calendar_month,
                      color: _config.activeDotColor,
                    ),
                    label: Text(
                      "Change Deadline (${_config.deadline.toString().split(' ')[0]})",
                      style: TextStyle(color: Colors.white),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.all(16),
                    ),
                  ),

                  SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _isOverflowing
                        ? null
                        : () => _generateAndSetWallpaper(context),
                    child: Text(
                      _isOverflowing ? "OVERFLOW ERROR" : "APPLY WALLPAPER",
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isOverflowing
                          ? Colors.red.withOpacity(0.5)
                          : _config.activeDotColor,
                      foregroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(vertical: 20),
                      textStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  if (_isOverflowing)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        "Reduce radius or spacing to fit screen.",
                        style: TextStyle(color: Colors.redAccent, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateAndSetWallpaper(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(child: CircularProgressIndicator()),
    );

    try {
      const width = 1440.0;
      const height = 3120.0;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));

      DateTime now = DateTime.now();
      DateTime startOfYear = DateTime(_config.deadline.year);
      int totalDays = _config.deadline.difference(startOfYear).inDays + 1;
      int daysSpent = now.difference(startOfYear).inDays.clamp(0, totalDays);

      final painter = WallpaperPainter(
        config: _config,
        daysSpent: daysSpent,
        totalDays: totalDays,
      );
      painter.paint(canvas, Size(width, height));

      final picture = recorder.endRecording();
      final img = await picture.toImage(width.toInt(), height.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      final buffer = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/wallpaper.png');
      await file.writeAsBytes(buffer);

      await WallpaperManagerPlus().setWallpaper(
        file,
        WallpaperManagerPlus.lockScreen,
      );

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Wallpaper Set!"),
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

  Widget _buildHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        color: Colors.white54,
        fontSize: 13,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
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
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: Colors.white70)),
            Text(
              value.toInt().toString(),
              style: TextStyle(
                color: _config.activeDotColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          activeColor: _config.activeDotColor,
          inactiveColor: Colors.white10,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
