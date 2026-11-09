import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'rapor_dis_ekspertiz.dart';
import 'rapor_ic_mekan.dart';
import 'rapor_kaporta_sayfasi.dart';

class KategoriSecimiSayfasi extends StatelessWidget {
  final Map<String, dynamic>? formData;

  const KategoriSecimiSayfasi({super.key, this.formData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Rapor Kategorisi Seçimi")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              "Hangi raporu doldurmak istiyorsunuz?",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            _buildKategoriButton(
              context,
              "Dış Ekspertiz",
              LucideIcons.carFront,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RaporDisEkspertiz(aracBilgileri: formData ?? {}),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildKategoriButton(
              context,
              "İç Mekan Kontrol",
              LucideIcons.armchair,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RaporIcMekan(aracBilgileri: formData ?? {}),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildKategoriButton(
              context,
              "Kaporta / Boya Kontrol",
              LucideIcons.wrench,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RaporKaportaSayfasi(aracBilgileri: formData ?? {}),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKategoriButton(BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 26),
        label: Text(title, style: const TextStyle(fontSize: 17)),
      ),
    );
  }
}
