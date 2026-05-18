import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/ai/ai_oneri_model.dart';

/// AI Öneri Kartı Widget
/// Önerileri dikey bir akışta gösterir
class AIOneriKartiWidget extends StatefulWidget {
  final List<AIOneriModel> oneriler;
  final String baslik;
  final Function(AIOneriModel)? onOneriClick;

  const AIOneriKartiWidget({
    super.key,
    required this.oneriler,
    this.baslik = 'AI Önerileri',
    this.onOneriClick,
  });

  @override
  State<AIOneriKartiWidget> createState() => _AIOneriKartiWidgetState();
}

class _AIOneriKartiWidgetState extends State<AIOneriKartiWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
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

  Color _kategoriRengi(String kategori) {
    switch (kategori) {
      case 'Kritik':
        return Colors.red;
      case 'Önemli':
        return Colors.orange;
      case 'Öneri':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _kategoriIkonu(String kategori) {
    switch (kategori) {
      case 'Kritik':
        return Icons.warning_rounded;
      case 'Önemli':
        return Icons.info_outline;
      case 'Öneri':
        return Icons.lightbulb_outline;
      default:
        return Icons.help_outline;
    }
  }

  Color _oncelikRengi(int oncelik) {
    if (oncelik <= 2) return Colors.red;
    if (oncelik <= 4) return Colors.orange;
    return Colors.blue;
  }

  void _kopyalaOneri(AIOneriModel oneri) {
    Clipboard.setData(ClipboardData(text: oneri.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${oneri.baslik} kopyalandı'),
        backgroundColor: Colors.indigo,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.oneriler.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            Text(
              'Öneri Bulunamadı',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.indigo,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Araç genel durumu iyi. Ek öneri gerekmiyor.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
            child: Row(
              children: [
                const Icon(
                  Icons.lightbulb_outline,
                  color: Colors.indigo,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.baslik,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.indigo,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.indigo,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${widget.oneriler.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: widget.oneriler.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final oneri = widget.oneriler[index];
              final kategoriRengi = _kategoriRengi(oneri.kategori);
              final kategoriIkonu = _kategoriIkonu(oneri.kategori);

              return SizeTransition(
                sizeFactor: _animation,
                child: FadeTransition(
                  opacity: _animation,
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: kategoriRengi.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: InkWell(
                      onTap: widget.onOneriClick != null
                          ? () => widget.onOneriClick!(oneri)
                          : null,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: kategoriRengi,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        kategoriIkonu,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        oneri.kategori,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    oneri.baslik,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blueGrey.shade900,
                                        ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _oncelikRengi(oneri.oncelik)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Öncelik: ${oneri.oncelik}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _oncelikRengi(oneri.oncelik),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 18),
                                  onPressed: () => _kopyalaOneri(oneri),
                                  tooltip: 'Kopyala',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              oneri.aciklama,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.blueGrey.shade700,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blueGrey.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline,
                                    size: 18,
                                    color: Colors.indigo,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      oneri.onerilenEylem ?? '',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.indigo.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (oneri.ilgiliAdim != null && oneri.ilgiliAdim! > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.layers,
                                      size: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Adım ${oneri.ilgiliAdim}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
