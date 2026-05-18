import 'package:flutter/material.dart';
import '../controllers/app_menu_controller.dart';
import '../responsive.dart';
import '../constants.dart';
import 'package:provider/provider.dart';

class Header extends StatelessWidget {
  const Header({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final role = context.read<AppMenuController>().currentRole;
    
    return Row(
      children: [
        // Mobilde menü butonu
        if (!Responsive.isDesktop(context))
          IconButton(
            icon: Icon(Icons.menu, color: Colors.white),
            onPressed: context.read<AppMenuController>().controlMenu,
          ),
        
        // Masaüstünde başlık
        if (!Responsive.isMobile(context))
          Text(
            role == 'admin' ? 'Admin Paneli' :
            role == 'personel' ? 'Personel Paneli' : 'Müşteri Paneli',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        
        if (!Responsive.isMobile(context))
          Spacer(flex: Responsive.isDesktop(context) ? 2 : 1),
        
        // Arama alanı
        Expanded(child: _buildSearchField()),
        
        // Profil kartı
        _buildProfileCard(context),
      ],
    );
  }

  Widget _buildSearchField() {
    return Container(
      margin: EdgeInsets.only(right: defaultPadding),
      child: TextField(
        decoration: InputDecoration(
          hintText: "Ara...",
          hintStyle: TextStyle(color: Colors.white54),
          fillColor: secondaryColor,
          filled: true,
          border: OutlineInputBorder(
            borderSide: BorderSide.none,
            borderRadius: BorderRadius.circular(10),
          ),
          prefixIcon: Icon(Icons.search, color: Colors.white54),
          contentPadding: EdgeInsets.symmetric(
            horizontal: defaultPadding,
            vertical: defaultPadding / 2,
          ),
        ),
        style: TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    final role = context.read<AppMenuController>().currentRole;
    String userName = '';
    String userRoleText = '';

    switch (role) {
      case 'admin':
        userName = 'Admin Kullanıcı';
        userRoleText = 'Sistem Yöneticisi';
        break;
      case 'field_staff':
        userName = 'Saha Personeli';
        userRoleText = 'Saha Personeli';
        break;
      case 'customer':
        userName = 'Müşteri';
        userRoleText = 'Müşteri';
        break;
      default:
        userName = 'Kullanıcı';
        userRoleText = '';
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: defaultPadding / 2,
        vertical: defaultPadding / 3,
      ),
      decoration: BoxDecoration(
        color: secondaryColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // Kullanıcı avatarı
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                userName.split(' ').map((n) => n[0]).join(),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          SizedBox(width: defaultPadding / 2),
          
          // Kullanıcı bilgileri (sadece masaüstü)
          if (!Responsive.isMobile(context))
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  userRoleText,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          
          // Açılır ok işareti
          if (!Responsive.isMobile(context))
            SizedBox(width: defaultPadding / 2),
          
          if (!Responsive.isMobile(context))
            Icon(Icons.keyboard_arrow_down, color: Colors.white54),
        ],
      ),
    );
  }
}