import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../core/theme/futuristic_theme.dart';
import '../core/widgets/glass_card.dart';
import '../models/arac_rapor_model.dart';
import '../providers/expertiz_provider.dart';
import '../widgets/cyber/cyber_background.dart';
import '../widgets/cyber/neon_hologram_seal.dart';

/// Report Detail Screen - Silver Quality & Cyber-Premium
/// ExpertizProvider'dan gelen canlı verileri kullanır
class ReportDetailScreen extends StatefulWidget {
  final AracRapor rapor;

  const ReportDetailScreen({super.key, required this.rapor});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _loadController;
  late Animation<double> _scanAnimation;
  // Staggered Animations
  late Animation<double> _headerAnim;
  late Animation<double> _scoresAnim;
  late Animation<double> _gridAnim;
  late Animation<double> _sealAnim;

  @override
  void initState() {
    super.initState();
    _loadController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3), // Slightly longer for the reveal effect
    );

    // Scan line spans the entire reveal duration
    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _loadController,
        curve: Curves.easeInOut,
      ),
    );

    // Staggered reveal animations synchronized with the scan line
    _headerAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _loadController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    _scoresAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _loadController,
        curve: const Interval(0.3, 0.6, curve: Curves.easeOut),
      ),
    );

    _gridAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _loadController,
        curve: const Interval(0.5, 0.8, curve: Curves.easeOut),
      ),
    );

    _sealAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _loadController,
        curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
      ),
    );

    _loadController.forward();
  }

  @override
  void dispose() {
    _loadController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "EKSPERTİZ RAPORU",
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
              fontSize: 16),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: FuturisticTheme.neon),
            onPressed: () {
              // Share functionality
            },
          )
        ],
      ),
      body: CyberBackground(
        showParticles: true,
        child: Stack(
          children: [
            // Carbon Texture Overlay (Simulated)
            Positioned.fill(
              child: Opacity(
                opacity: 0.1,
                child: Image.network(
                  "https://www.transparenttextures.com/patterns/carbon-fibre.png",
                  repeat: ImageRepeat.repeat,
                  errorBuilder: (c, o, s) => Container(color: Colors.black12),
                ),
              ),
            ),
             
            // Main Content with Staggered Animations
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 100, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Section
                  FadeTransition(
                    opacity: _headerAnim,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(_headerAnim),
                      child: _buildHeader(),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // AI Scores - ExpertizProvider'dan gelen veriler
                  FadeTransition(
                    opacity: _scoresAnim,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(_scoresAnim),
                      child: _buildScores(),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Hardware Section - selectedOptions'tan gelen veriler
                  FadeTransition(
                    opacity: _gridAnim,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(_gridAnim),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "ARAÇ DONANIMLARI",
                            style: TextStyle(
                              fontFamily: 'Orbitron',
                              color: FuturisticTheme.neon,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildHardwareGrid(),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // AI Seal
                  FadeTransition(
                    opacity: _sealAnim,
                    child: const Center(child: NeonHologramSeal(isActive: true)),
                  ),
                ],
              ),
            ),

            // Scanning Overlay Animation (Top to Bottom)
            AnimatedBuilder(
              animation: _scanAnimation,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: FuturisticTheme.neon.withValues(alpha: 0.8),
                      blurRadius: 15,
                      spreadRadius: 2,
                    )
                  ],
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      FuturisticTheme.neon,
                      FuturisticTheme.neon.withValues(alpha: 0.5),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              builder: (context, child) {
                if (_scanAnimation.value >= 1.0) return const SizedBox.shrink();
                 
                final height = MediaQuery.of(context).size.height;
                final topPos = _scanAnimation.value * height;
                 
                return Positioned(
                  top: topPos,
                  left: 0,
                  right: 0,
                  child: child!,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return GlassCard(
      padding: const EdgeInsets.all(0),
      child: Column(
        children: [
          // Car Image Area
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              image: const DecorationImage(
                image: NetworkImage("https://images.unsplash.com/photo-1549669227-2bbc69e36aa4?q=80&w=2670&auto=format&fit=crop"),
                fit: BoxFit.cover,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                )
              ]
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.8),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${widget.rapor.marka} ${widget.rapor.model}".toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          shadows: [Shadow(color: FuturisticTheme.neon, blurRadius: 10)]
                        ),
                      ),
                      Text(
                        "${widget.rapor.yil} • ${widget.rapor.secilenPaket ?? 'Standart'}",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Basic Info Strip
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                 _buildInfoItem(Icons.speed, "${widget.rapor.aiAnaliziYapildiMi ? (widget.rapor.aiPiyasaDegeri?.toStringAsFixed(0) ?? '0') : '0'} TL"),
                 _buildInfoItem(Icons.calendar_today, DateFormat('dd.MM.yyyy').format(widget.rapor.olusturmaTarihi)),
                 _buildInfoItem(Icons.local_gas_station, widget.rapor.marka?.contains('Dizel') == true ? 'Dizel' : 'Benzin'),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
     return Row(
       children: [
         Icon(icon, color: FuturisticTheme.neon, size: 18),
         const SizedBox(width: 8),
         Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13)),
       ],
     );
  }

  Widget _buildScores() {
    // AI analiz sonuçlarından skorları al
    final aiSonuc = widget.rapor.aiAnalizSonucu;
    final motorSkor = aiSonuc?.skorlar.motorMekanikPuan.toInt() ?? 85;
    final kaportaSkor = aiSonuc?.skorlar.hasarPuan.toInt() ?? 80;
    final aracDurumuSkor = aiSonuc?.skorlar.aracDurumuPuan.toInt() ?? 75;
    final genelSkor = aiSonuc?.skorlar.genelPuan.toInt() ?? 80;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildScoreCircle("MOTOR", motorSkor, FuturisticTheme.neon.withValues(alpha: 0.7)),
            _buildScoreCircle("KAPORTA", kaportaSkor, FuturisticTheme.neon),
            _buildScoreCircle("ARAÇ", aracDurumuSkor, FuturisticTheme.neon.withValues(alpha: 0.5)),
          ],
        ),
        const SizedBox(height: 20),
        // Genel Skor
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: FuturisticTheme.bgSecondary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: FuturisticTheme.neon.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              const Text(
                "GENEL SKOR",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "$genelSkor/100",
                style: const TextStyle(
                  color: FuturisticTheme.neon,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: FuturisticTheme.neon, blurRadius: 10)]
                ),
              ),
              const SizedBox(height: 8),
              Text(
                aiSonuc?.skorlar.puanDegerlendirmesi ?? "AI analizi yapılmadı",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScoreCircle(String label, int score, Color color) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: [
                color.withValues(alpha: 0.1),
                color,
                color.withValues(alpha: 0.1),
              ],
              startAngle: 0.0,
              endAngle: 3.14 * 2 * (score / 100),
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 15,
                spreadRadius: 2,
              )
            ],
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1)
          ),
          child: Center(
            child: Container(
              width: 70,
              height: 70,
               decoration: BoxDecoration(
                color: FuturisticTheme.bgPrimary,
                shape: BoxShape.circle,
               ),
               child: Center(
                 child: Text(
                   "$score",
                   style: TextStyle(
                     color: color,
                     fontSize: 22,
                     fontWeight: FontWeight.bold,
                   ),
                 ),
               ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1.0),
        )
      ],
    );
  }

  Widget _buildHardwareGrid() {
    // ExpertizProvider'dan donanım listesini al
    final expertizProvider = context.watch<ExpertizProvider>();
    final selectedOptions = expertizProvider.selectedOptions;
    
    // Donanım listesini oluştur
    final hardwareItems = [
      {'icon': Icons.wb_sunny, 'name': 'Sunroof', 'status': selectedOptions['Sunroof'] ?? false},
      {'icon': Icons.light_mode, 'name': 'Matrix LED', 'status': selectedOptions['Matrix LED'] ?? false},
      {'icon': Icons.monitor, 'name': 'Hayalet Ekran', 'status': selectedOptions['Hayalet Ekran'] ?? false},
      {'icon': Icons.security, 'name': 'Şerit Takip', 'status': selectedOptions['Şerit Takip'] ?? false},
      {'icon': Icons.camera_alt, 'name': '360° Kamera', 'status': selectedOptions['360° Kamera'] ?? false},
      {'icon': Icons.heat_pump, 'name': 'Koltuk Isıtma', 'status': selectedOptions['Koltuk Isıtma'] ?? false},
      {'icon': Icons.ac_unit, 'name': 'Klima', 'status': selectedOptions['Klima'] ?? false},
      {'icon': Icons.speaker, 'name': 'Ses Sistemi', 'status': selectedOptions['Ses Sistemi'] ?? false},
      {'icon': Icons.bluetooth, 'name': 'Bluetooth', 'status': selectedOptions['Bluetooth'] ?? false},
      {'icon': Icons.navigation, 'name': 'Navigasyon', 'status': selectedOptions['Navigasyon'] ?? false},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 2.2, // Adjusted for new badge
      ),
      itemCount: hardwareItems.length,
      itemBuilder: (context, index) {
        final item = hardwareItems[index];
        final isActive = item['status'] as bool;
        
        return GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
               Container(
                 padding: const EdgeInsets.all(8),
                 decoration: BoxDecoration(
                   color: isActive ? FuturisticTheme.neon.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.1),
                   borderRadius: BorderRadius.circular(8),
                   border: Border.all(color: isActive ? FuturisticTheme.neon : Colors.grey.withValues(alpha: 0.3))
                 ),
                 child: Icon(
                   item['icon'] as IconData,
                   color: isActive ? FuturisticTheme.neon : Colors.grey,
                   size: 18,
                 ),
               ),
               const SizedBox(width: 8),
               Expanded(
                 child: Column(
                   mainAxisAlignment: MainAxisAlignment.center,
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(
                       item['name'] as String,
                       style: TextStyle(
                         color: isActive ? Colors.white : Colors.white38,
                         fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                         fontSize: 12
                       ),
                       maxLines: 1,
                       overflow: TextOverflow.ellipsis,
                     ),
                     if (isActive) 
                       Padding(
                         padding: const EdgeInsets.only(top: 2.0),
                         child: Container(
                           padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                           decoration: BoxDecoration(
                             color: Colors.greenAccent.withValues(alpha: 0.2),
                             borderRadius: BorderRadius.circular(4),
                             border: Border.all(color: Colors.greenAccent, width: 0.5),
                             boxShadow: [
                               BoxShadow(color: Colors.greenAccent.withValues(alpha: 0.3), blurRadius: 4)
                             ]
                           ),
                           child: const Text(
                             "ORİJİNAL",
                             style: TextStyle(
                               fontSize: 8,
                               color: Colors.greenAccent,
                               fontWeight: FontWeight.bold,
                               letterSpacing: 0.5
                             ),
                           ),
                         ),
                       )
                   ],
                 ),
               ),
               if (isActive)
                 const Icon(Icons.check_circle, color: FuturisticTheme.neon, size: 14)
            ],
          ),
        );
      },
    );
  }
}
