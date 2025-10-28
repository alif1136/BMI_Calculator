import 'dart:math';
import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

void main() {
  runApp(const BMIAssignmentApp());
}

class BMIAssignmentApp extends StatelessWidget {
  const BMIAssignmentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Module 17 — BMI Calculator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212), // #121212
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: const BMIScreen(),
    );
  }
}

class BMIScreen extends StatefulWidget {
  const BMIScreen({super.key});

  @override
  State<BMIScreen> createState() => _BMIScreenState();
}

class _BMIScreenState extends State<BMIScreen> {
  // Unit state
  bool isKg = true; // true => kg, false => lb
  String heightUnit = 'cm'; // 'cm', 'm', 'ft' (ft means ft+in)

  // Controllers (allow decimals)
  final TextEditingController weightController = TextEditingController();
  final TextEditingController heightController = TextEditingController(); // for cm or m
  final TextEditingController feetController = TextEditingController();
  final TextEditingController inchController = TextEditingController();

  double? bmi;
  String bmiCategory = '';
  Color bmiColor = Colors.grey;

  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
  GlobalKey<ScaffoldMessengerState>();

  @override
  void dispose() {
    weightController.dispose();
    heightController.dispose();
    feetController.dispose();
    inchController.dispose();
    super.dispose();
  }

  // Validate inputs and show snackbar if invalid
  bool _validateInputs() {
    try {
      // weight
      final weightText = weightController.text.trim();
      if (weightText.isEmpty) {
        _showSnack('Enter weight (kg or lb).');
        return false;
      }
      final weightVal = double.tryParse(weightText);
      if (weightVal == null) {
        _showSnack('Invalid weight. Use numbers (e.g. 70.5).');
        return false;
      }
      if (weightVal <= 0) {
        _showSnack('Weight must be greater than 0.');
        return false;
      }

      // height
      if (heightUnit == 'ft') {
        final fText = feetController.text.trim();
        final iText = inchController.text.trim();
        if (fText.isEmpty && iText.isEmpty) {
          _showSnack('Enter height in feet and/or inches.');
          return false;
        }
        final fVal = fText.isEmpty ? 0.0 : double.tryParse(fText);
        final iVal = iText.isEmpty ? 0.0 : double.tryParse(iText);
        if (fVal == null || iVal == null) {
          _showSnack('Invalid feet/inches. Use numbers (e.g. 5 and 7.5).');
          return false;
        }
        if (fVal < 0 || iVal < 0) {
          _showSnack('Feet and inches must be non-negative.');
          return false;
        }
        // allow zero total height check later after converting
      } else {
        final hText = heightController.text.trim();
        if (hText.isEmpty) {
          _showSnack('Enter height.');
          return false;
        }
        final hVal = double.tryParse(hText);
        if (hVal == null) {
          _showSnack('Invalid height. Use numbers (e.g. 170 or 1.72).');
          return false;
        }
        if (hVal <= 0) {
          _showSnack('Height must be greater than 0.');
          return false;
        }
      }

      return true;
    } catch (e) {
      _showSnack('Invalid input.');
      return false;
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  // Inch auto-carry: if inches >= 12, convert to additional feet
  void _autoCarryInches() {
    final inchText = inchController.text.trim();
    if (inchText.isEmpty) return;
    final inchVal = double.tryParse(inchText);
    if (inchVal == null) return;

    if (inchVal >= 12) {
      final extraFeet = (inchVal / 12).floor();
      final remainingInch = inchVal - extraFeet * 12;
      final currentFeet = double.tryParse(feetController.text.trim()) ?? 0.0;
      final newFeet = currentFeet + extraFeet;
      feetController.text = newFeet.toStringAsFixed(0);
      // keep decimals for remaining inches (e.g., 7.5)
      final remStr = remainingInch % 1 == 0
          ? remainingInch.toStringAsFixed(0)
          : remainingInch.toString(); // preserve decimal if present
      inchController.text = remStr;
    }
  }

  // Compute BMI and set category and color
  void _computeBMI() {
    if (!_validateInputs()) return;

    // apply inch auto-carry BEFORE calculation
    if (heightUnit == 'ft') {
      _autoCarryInches();
    }

    // Parse weight
    double weightVal = double.parse(weightController.text.trim());
    if (!isKg) {
      // lb -> kg
      weightVal = weightVal * 0.45359237;
    }

    // Parse height into meters
    double heightMeters = 0.0;
    if (heightUnit == 'cm') {
      double cm = double.parse(heightController.text.trim());
      heightMeters = cm / 100.0;
    } else if (heightUnit == 'm') {
      double m = double.parse(heightController.text.trim());
      heightMeters = m;
    } else {
      // ft + in
      double feet = double.tryParse(feetController.text.trim()) ?? 0.0;
      double inches = double.tryParse(inchController.text.trim()) ?? 0.0;
      final totalInches = feet * 12.0 + inches;
      heightMeters = totalInches * 0.0254;
    }

    if (heightMeters <= 0) {
      _showSnack('Height must be greater than 0.');
      return;
    }

    final double result = weightVal / pow(heightMeters, 2);
    // Round to 1 decimal for display
    final double rounded = (result * 10).roundToDouble() / 10.0;

    String category;
    Color color;
    if (rounded < 18.5) {
      category = 'Underweight';
      color = Colors.blue; // assignment: Blue
    } else if (rounded < 25.0) {
      category = 'Normal';
      color = Colors.green; // Green
    } else if (rounded < 30.0) {
      category = 'Overweight';
      color = Colors.orange; // Orange
    } else {
      category = 'Obese';
      color = Colors.red; // Red
    }

    setState(() {
      bmi = rounded;
      bmiCategory = category;
      bmiColor = color;
    });
  }

  // Map BMI into 0..1 for circular gauge
  double _bmiToPercent() {
    if (bmi == null) return 0.0;
    // Cap at 45 for gauge mapping to avoid overflow - assignment range 0-40 suggested earlier
    final capped = bmi!.clamp(0.0, 45.0);
    return capped / 45.0;
  }

  String _weightHint() => isKg ? 'e.g. 70.5' : 'e.g. 155.0';

  String _heightHint() {
    if (heightUnit == 'cm') return 'e.g. 170.0';
    if (heightUnit == 'm') return 'e.g. 1.72';
    return 'ft e.g. 5  inch e.g. 7.5';
  }

  // Quick helper for small label chips
  Widget _categoryChip() {
    return Chip(
      label: Text(
        bmiCategory,
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold),
      ),
      backgroundColor: bmiColor,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Use scaffold messenger via ScaffoldMessenger.of(context)
      appBar: AppBar(
        title: const Text('Module 17 — BMI Calculator'),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Column(
          children: [
            // Weight Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Weight', style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ToggleButtons(
                        borderRadius: BorderRadius.circular(8),
                        isSelected: [isKg, !isKg],
                        onPressed: (index) {
                          setState(() {
                            isKg = index == 0;
                            weightController.clear();
                          });
                        },
                        children: const [
                          Padding(padding: EdgeInsets.symmetric(horizontal: 14),
                              child: Text('kg')),
                          Padding(padding: EdgeInsets.symmetric(horizontal: 14),
                              child: Text('lb'))
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: weightController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            hintText: _weightHint(),
                            labelText: 'Weight (${isKg ? 'kg' : 'lb'})',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Height Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Height', style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ToggleButtons(
                        borderRadius: BorderRadius.circular(8),
                        isSelected: [
                          heightUnit == 'cm',
                          heightUnit == 'm',
                          heightUnit == 'ft'
                        ],
                        onPressed: (index) {
                          setState(() {
                            if (index == 0) {
                              heightUnit = 'cm';
                            } else if (index == 1) {
                              heightUnit = 'm';
                            } else {
                              heightUnit = 'ft';
                            }
                            heightController.clear();
                            feetController.clear();
                            inchController.clear();
                          });
                        },
                        children: const [
                          Padding(padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text('cm')),
                          Padding(padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text('m')),
                          Padding(padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text('ft + in')),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (heightUnit == 'ft') ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: feetController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Feet',
                              hintText: 'e.g. 5',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: inchController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Inch',
                              hintText: 'e.g. 7.5',
                            ),
                            onEditingComplete: () {
                              // auto carry when user finishes editing inch field
                              _autoCarryInches();
                              // unfocus so keyboard hides
                              FocusScope.of(context).unfocus();
                            },
                          ),
                        ),
                      ],
                    )
                  ] else
                    TextField(
                      controller: heightController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                          labelText: 'Height (${heightUnit == 'cm'
                              ? 'cm'
                              : 'm'})',
                          hintText: heightUnit == 'cm'
                              ? 'e.g. 170.0'
                              : 'e.g. 1.72'),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Calculate button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _computeBMI,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Calculate BMI', style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),

            const SizedBox(height: 22),

            // Result area
            if (bmi != null)
              Column(
                children: [
                  // Circular gauge
                  CircularPercentIndicator(
                    radius: 120,
                    lineWidth: 14,
                    animation: true,
                    animationDuration: 700,
                    percent: _bmiToPercent(),
                    center: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(bmi!.toStringAsFixed(1), style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                        const SizedBox(height: 4),
                        _categoryChip(),
                      ],
                    ),
                    circularStrokeCap: CircularStrokeCap.round,
                    progressColor: bmiColor,
                    backgroundColor: Colors.grey.shade800,
                  ),

                  const SizedBox(height: 14),

                  // Result Card with details
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Result', style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Text('BMI: ', style: TextStyle(
                                fontSize: 16, color: Colors.white70)),
                            Text(bmi!.toStringAsFixed(1),
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                            const Spacer(),
                            // Color legend small
                            Row(
                              children: [
                                _legendItem(Colors.blue, 'Underweight'),
                                const SizedBox(width: 8),
                                _legendItem(Colors.green, 'Normal'),
                                const SizedBox(width: 8),
                                _legendItem(Colors.orange, 'Overweight'),
                                const SizedBox(width: 8),
                                _legendItem(Colors.red, 'Obese'),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text('Category: ', style: TextStyle(
                            fontSize: 15, color: Colors.white70)),
                        const SizedBox(height: 6),
                        _categoryChip(),
                        const SizedBox(height: 10),
                        // Optional suggestions based on category — helpful for UX/assignment
                        _adviceForCategory(),
                      ],
                    ),
                  ),
                ],
              )
            else
            // placeholder / instruction
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                    'Enter weight and height, then press "Calculate BMI".',
                    style: TextStyle(color: Colors.white70)),
              ),

            const SizedBox(height: 24),

            // Example tests (as assignment asked)

          ],
        ),
      ),
    );
  }

  // Small legend widget
  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(
            label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
      ],
    );
  }

  // Basic advice per category (small text)
  Widget _adviceForCategory() {
    if (bmiCategory == 'Underweight') {
      return const Text(
          'Advice: Consider a calorie-rich balanced diet and strength training.',
          style: TextStyle(color: Colors.white70));
    } else if (bmiCategory == 'Normal') {
      return const Text(
          'Advice: Great! Maintain with balanced diet and regular exercise.',
          style: TextStyle(color: Colors.white70));
    } else if (bmiCategory == 'Overweight') {
      return const Text(
          'Advice: Reduce calorie intake, increase cardio and strength training.',
          style: TextStyle(color: Colors.white70));
    } else if (bmiCategory == 'Obese') {
      return const Text(
          'Advice: Consult a healthcare professional and adopt a controlled diet and exercise plan.',
          style: TextStyle(color: Colors.white70));
    }
    return const SizedBox.shrink();
  }

// Example tests card — to verify correctness for assignment
}


