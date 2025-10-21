import 'package:flutter/material.dart';

class NavItem {
  final String title;
  final IconData icon;
  final String route;
  const NavItem(this.title, this.icon, this.route);
}

const navItems = <NavItem>[
  NavItem('Home', Icons.home, '/home'),
  NavItem('POS', Icons.point_of_sale, '/pos'),
  NavItem('KOT Board', Icons.receipt_long, '/kot'),
  NavItem('Online Orders', Icons.cloud, '/online'),
  NavItem('Shift & Cash', Icons.account_balance_wallet, '/shift'),
  NavItem('Menu Builder', Icons.restaurant_menu, '/menu'),
  NavItem('Inventory', Icons.inventory_2, '/inventory'), // swap to Icons.inventory if needed
  NavItem('Reports', Icons.insights, '/reports'),
  NavItem('Users & Roles', Icons.group, '/users'),
  NavItem('Settings', Icons.settings, '/settings'),
];
