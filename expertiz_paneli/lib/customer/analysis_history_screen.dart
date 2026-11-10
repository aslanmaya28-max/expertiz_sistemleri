/// MÜŞTERİ ANALİZ GEÇMİŞİ EKRANI
///
/// UserProvider üzerinden kullanıcıya ait tüm AI analizlerini listeler
/// Supabase reports tablosundan çekilir
library;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:yerimebak_sistemleri/tema/renkler.dart';
import 'package:yerimebak_sistemleri/bilesenler/bilesenler.dart';
import 'package:provider/provider.dart';
import '../services/yerimebak_expertiz_api_service.dart';
import '../providers/user_provider.dart';
import '../models/ai_analysis_result.dart';

class AnalysisHistoryScreen extends StatefulWidget {
  const AnalysisHistoryScreen({super.key});

  @override
  State<AnalysisHistoryScreen> createState() => _AnalysisHistoryScreenState();
}

class _AnalysisHistoryScreenState extends State<AnalysisHistoryScreen> {
  List<Map<String, dynamic>> _analyses = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAnalyses();
  }

  Future<void> _loadAnalyses() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userProvider = context.read<UserProvider>();
      final userId = userProvider.userId;
      if (userId == null) {
        setState(() {
          _error = 'Oturum bulunamadı';
          _isLoading = false;
        });
        return;
      }

      final response = await YerimebakExpertizApiService().getMyRequests();
      final rows =
          (response['requests'] as List? ?? const []).whereType<Map>().map((r) {
        final vehicle = r['vehicle'] is Map ? r['vehicle'] as Map : const {};
        return <String, dynamic>{
          'id': r['report_id'] ?? r['id'],
          'plaka': r['plate'],
          'marka': vehicle['marka'] ?? vehicle['brand'],
          'model': vehicle['model'],
          'yil': vehicle['yil'] ?? vehicle['year'],
          'status': r['status'],
          'created_at': r['created_at'],
        };
      }).toList();

      if (!mounted) return;
      setState(() {
        _analyses = rows;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analiz Geçmişi'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: _loadAnalyses,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Padding(
          padding: EdgeInsets.all(24),
          child: Column(children: [
            YbIskelet(height: 80),
            SizedBox(height: 16),
            YbIskelet(height: 80),
            SizedBox(height: 16),
            YbIskelet(height: 80)
          ]));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.circleAlert,
                  size: 64, color: context.renkler.tehlike),
              const SizedBox(height: 16),
              Text(
                'Veri yüklenemedi',
                style: TextStyle(
                    color: context.renkler.metinIkincil, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(
                    color: context.renkler.metinIkincil, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadAnalyses,
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      );
    }

    if (_analyses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.chartNoAxesCombined,
                size: 80, color: context.renkler.metin.withValues(alpha: 0.15)),
            const SizedBox(height: 20),
            Text(
              'Henüz analiz bulunmuyor',
              style:
                  TextStyle(color: context.renkler.metinIkincil, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Yeni bir ekspertiz talebi oluşturarak\nAI analizinden faydalanabilirsiniz',
              style:
                  TextStyle(color: context.renkler.metinIkincil, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAnalyses,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _analyses.length,
        itemBuilder: (context, index) {
          final analysis = _analyses[index];
          return _buildAnalysisCard(analysis);
        },
      ),
    );
  }

  Widget _buildAnalysisCard(Map<String, dynamic> analysis) {
    final plaka = analysis['plaka']?.toString() ?? '---';
    final marka = analysis['marka']?.toString() ?? '';
    final model = analysis['model']?.toString() ?? '';
    final yil = analysis['yil']?.toString() ?? '';
    final status = analysis['status']?.toString() ?? 'Bilinmiyor';
    final createdAt = analysis['created_at']?.toString() ?? '';

    // AI analiz sonucu varsa puanı göster
    double? aiScore;
    if (analysis['ai_analysis_result'] != null) {
      try {
        final aiResult = AIAnalysisResult.fromJson(
          analysis['ai_analysis_result'] as Map<String, dynamic>,
        );
        aiScore = aiResult.reliabilityScore;
      } catch (_) {}
    }

    final aracBilgi =
        [marka, model, yil].where((s) => s.isNotEmpty).join(' - ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: YbKart(
        child: InkWell(
          onTap: () {
            // TODO: Analiz detayına git
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Araç ikonu
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: context.renkler.birincil.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    LucideIcons.car,
                    color: context.renkler.birincil,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                // Bilgiler
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plaka,
                        style: TextStyle(
                          color: context.renkler.metin,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (aracBilgi.isNotEmpty)
                        Text(
                          aracBilgi,
                          style: TextStyle(
                            color: context.renkler.metinIkincil,
                            fontSize: 13,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _buildStatusBadge(status),
                          if (createdAt.isNotEmpty)
                            Text(
                              _formatDate(createdAt),
                              style: TextStyle(
                                color: context.renkler.metinIkincil,
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // AI Skoru
                if (aiScore != null)
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _getScoreColor(aiScore),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        aiScore.toStringAsFixed(0),
                        style: TextStyle(
                          color: _getScoreColor(aiScore),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Icon(LucideIcons.chevronRight, color: context.renkler.kenarlik),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'published':
        color = context.renkler.birincilMetin;
        break;
      case 'pending':
        color = context.renkler.uyari;
        break;
      case 'in_progress':
        color = context.renkler.birincil;
        break;
      case 'completed':
        color = context.renkler.birincil;
        break;
      default:
        color = context.renkler.metinIkincil;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 71) return context.renkler.birincilMetin;
    if (score >= 41) return context.renkler.uyari;
    return context.renkler.tehlike;
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return '${date.day}.${date.month}.${date.year}';
    } catch (_) {
      return isoDate;
    }
  }
}
