import 'package:flutter/material.dart';

import '../account/account_drawer.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../models/app_profile.dart';
import 'search_view.dart';

/// Parent home: a Search view with a persistent bottom bar. "Account" opens the side drawer instead of
/// replacing the page, so the parent never loses their place in the search results.
class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({super.key, required this.profile});
  final AppProfile profile;

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _index = 0; // 0 = Search, 1 = Account (highlighted while the drawer is open)
  int _refresh = 0; // bumped when an Account screen may have changed what Search should show

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Tutobridge'),
        actions: [IconButton(tooltip: 'Log out', onPressed: () => confirmSignOut(context), icon: const Icon(Icons.logout_rounded))],
      ),
      body: SearchView(profile: widget.profile, refreshToken: _refresh),
      endDrawer: AccountDrawer(profile: widget.profile, onReturn: () => setState(() => _refresh++)),
      onEndDrawerChanged: (open) => setState(() => _index = open ? 1 : 0),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.tealLight,
        onDestinationSelected: (i) {
          if (i == 1) {
            _scaffoldKey.currentState?.openEndDrawer();
          } else {
            _scaffoldKey.currentState?.closeEndDrawer();
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search_rounded), selectedIcon: Icon(Icons.search_rounded, color: AppColors.teal), label: 'Search'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded, color: AppColors.teal), label: 'Account'),
        ],
      ),
    );
  }
}
