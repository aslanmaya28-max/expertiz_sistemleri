import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import '../../models/ai/ai_skor_model.dart';

/// AI Skor Göstergesi Widget
/// Puanları gösteren gauge widget
class AISkorGostergeWidget extends StatefulWidget {
  final AISkorModel skorlar;
  final String baslik;
  final double boyut;

  const AISkorGostergeWidget({
    super.key,
    required this.skorlar,
    this.baslik = 'Genel Puan',
    this.boyut = 200,
  });

  @override
  State<AISkorGostergeWidget> createState() => _AISkorGostergeWidgetState();
}

class _AISkorGostergeWidgetState extends State<AISkorGostergeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: widget.skorlar.genelPuan).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color _getPuanRengi(double puan) {
    if (puan >= 71) return Colors.green;
    if (puan >= 41) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.indigo.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Text(
              widget.baslik,
              style: TextStyle(
                color: Colors.indigo.shade900,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              height: widget.boyut,
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return SfRadialGauge(
                    axes: <RadialAxis>[
                      RadialAxis(
                        minimum: 0,
                        maximum: 100,
                        startAngle: 135,
                        endAngle: 45,
                        interval: 10,
                        showLabels: true,
                        showTicks: true,
                        axisLineStyle: const AxisLineStyle(
                          thickness: 15,
                          cornerStyle: CornerStyle.bothCurve,
                        ),
                        ranges: <GaugeRange>[
                          GaugeRange(
                            startValue: 0,
                            endValue: 40,
                            color: Colors.red.withValues(alpha: 0.3),
                            startWidth: 15,
                            endWidth: 15,
                          ),
                          GaugeRange(
                            startValue: 40,
                            endValue: 70,
                            color: Colors.orange.withValues(alpha: 0.3),
                            startWidth: 15,
                            endWidth: 15,
                          ),
                          GaugeRange(
                            startValue: 70,
                            endValue: 100,
                            color: Colors.green.withValues(alpha: 0.3),
                            startWidth: 15,
                            endWidth: 15,
                          ),
                        ],
                        pointers: <GaugePointer>[
                          NeedlePointer(
                            value: _animation.value,
                            needleLength: 0.6,
                            needleStartWidth: 1,
                            needleEndWidth: 5,
                            needleColor: Colors.blueGrey.shade800,
                            knobStyle: KnobStyle(
                              knobRadius: 8,
                              color: Colors.blueGrey.shade800,
                            ),
                            tailStyle: const TailStyle(
                              length: 0.15,
                              width: 4,
                              color: Colors.blueGrey,
                            ),
                          ),
                        ],
                        annotations: <GaugeAnnotation>[
                          GaugeAnnotation(
                            widget: Text(
                              _animation.value.toStringAsFixed(0),
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: _getPuanRengi(_animation.value),
                              ),
                            ),
                            angle: 90,
                            positionFactor: 0.5,
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getPuanRengi(widget.skorlar.genelPuan)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getPuanRengi(widget.skorlar.genelPuan),
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _getPuanIkonu(widget.skorlar.genelPuan),
                    color: _getPuanRengi(widget.skorlar.genelPuan),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.skorlar.puanDegerlendirmesi,
                    style: TextStyle(
                      color: _getPuanRengi(widget.skorlar.genelPuan),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  IconData _getPuanIkonu(double puan) {
    if (puan >= 71) return Icons.check_circle;
    if (puan >= 41) return Icons.info;
    return Icons.warning;
  }
}
