import 'package:flutter/material.dart';
import 'dart:ui';
import '../../core/theme/futuristic_theme.dart';
import '../../core/constants/yerimebak_colors.dart';
import '../../models/personel_model.dart';
import '../../core/mappers/location_mapper.dart';

class CyberPersonelCard extends StatefulWidget {
  final PersonelModel personel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onStatusChange;

  const CyberPersonelCard({
    super.key,
    required this.personel,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChange,
  });

  @override
  State<CyberPersonelCard> createState() => _CyberPersonelCardState();
}

class _CyberPersonelCardState extends State<CyberPersonelCard> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final LocationMapper _locationMapper = LocationMapper();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _getExpertiseColor(int count) {
    if (count > 50) return const Color(0xFFFFD700);
    if (count > 20) return const Color(0xFFC0C0C0);
    return const Color(0xFFCD7F32);
  }

  @override
  Widget build(BuildContext context) {
    final bool isActive = widget.personel.aktif;
    final int completedTasks = widget.personel.tamamlananGorevSayisi ?? 0;
    final Color ringColor = _getExpertiseColor(completedTasks);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(
            color: _isHovered 
                ? FuturisticTheme.neon.withValues(alpha: 0.6) 
                : Colors.white.withValues(alpha: 0.15),
            width: 1.5,
          ),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: FuturisticTheme.neon.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                  )
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _buildAvatarSection(isActive, ringColor),
                  
                  const SizedBox(width: 16),
                  
                  Expanded(
                    child: _buildInfoSection(completedTasks),
                  ),

                  _buildPerformanceGauge(completedTasks),
                  
                  const SizedBox(width: 12),
                  
                  _buildActionButtons(isActive),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSection(bool isActive, Color ringColor) {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: ringColor, width: 2),
            boxShadow: [
              BoxShadow(
                color: ringColor.withValues(alpha: 0.4),
                blurRadius: 10,
              )
            ]
          ),
          child: const CircleAvatar(
            radius: 24,
            backgroundColor: Color(0xFF1E1E1E),
            child: Icon(Icons.person, color: Colors.white70, size: 28),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: isActive ? YerimeBakColors.green : Colors.orange,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: YerimeBakColors.green.withValues(alpha: _pulseAnimation.value),
                            blurRadius: 10 * _pulseAnimation.value,
                            spreadRadius: 2 * _pulseAnimation.value,
                          )
                        ]
                      : [],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection(int completedTasks) {
    final fullName = '${widget.personel.ad} ${widget.personel.soyad}';
    final ilAdi = _locationMapper.getIlAdi(widget.personel.ilId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          fullName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.badge, size: 12, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
               widget.personel.unvan,
               style: TextStyle(color: Colors.grey[700], fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Icon(Icons.location_on, size: 12, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
               ilAdi,
               style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPerformanceGauge(int completedTasks) {
    double score = (completedTasks / 100).clamp(0.0, 1.0);
    
    return SizedBox(
       width: 50,
       height: 50,
       child: CustomPaint(
         painter: _MiniGaugePainter(score: score, color: FuturisticTheme.neon),
          child: Center(
            child: Text(
              "${(score * 100).toInt()}",
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: FuturisticTheme.neon
              ),
            ),
          ),
       ),
    );
  }

  Widget _buildActionButtons(bool isActive) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
         Transform.scale(
           scale: 0.7,
           child: Switch(
             value: isActive,
             activeTrackColor: FuturisticTheme.neon,
             onChanged: widget.onStatusChange,
           ),
         ),
         Row(
           children: [
             IconButton(
               icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                onPressed: widget.onEdit,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
             const SizedBox(width: 8),
             IconButton(
               icon: const Icon(Icons.delete, size: 18, color: Colors.red),
               onPressed: widget.onDelete,
               padding: EdgeInsets.zero,
               constraints: const BoxConstraints(),
             ),
           ],
         )
       ],
    );
  }
}

class _MiniGaugePainter extends CustomPainter {
  final double score;
  final Color color;
  
  _MiniGaugePainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    final bgPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
      
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 2),
      0,
      2 * 3.14159,
      false,
      bgPaint
    );
    
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
      
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-3.14159 / 2);
    
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: radius - 2),
      0,
      score * 2 * 3.14159,
      false,
      progressPaint
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MiniGaugePainter oldDelegate) {
    return oldDelegate.score != score;
  }
}
