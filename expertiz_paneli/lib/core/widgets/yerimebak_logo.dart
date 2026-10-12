import 'package:flutter/material.dart';

/// YerimeBak kurumsal logosu.
///
/// Logo koyu lacivert olduğu için koyu zeminlerde ([onDark] = true) açık renkli
/// bir kart içinde gösterilir; açık zeminde doğrudan çizilir.
class YerimeBakLogo extends StatelessWidget {
  const YerimeBakLogo({super.key, this.height = 40, this.onDark = false, this.markOnly = false});

  static const String fullAsset = 'assets/images/yerimebak_logo.png';
  static const String markAsset = 'assets/images/yerimebak_mark.png';

  final double height;
  final bool onDark;

  /// Sadece "Y" işareti (dar alanlar için).
  final bool markOnly;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      markOnly ? markAsset : fullAsset,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: 'YerimeBak',
      errorBuilder: (_, __, ___) => Text(
        'YerimeBak',
        style: TextStyle(fontSize: height * 0.45, fontWeight: FontWeight.w900, color: onDark ? Colors.white : const Color(0xFF0B2A45)),
      ),
    );
    if (!onDark) return image;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: height * 0.25, vertical: height * 0.12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(height * 0.22),
      ),
      child: image,
    );
  }
}
