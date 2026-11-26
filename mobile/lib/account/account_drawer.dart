import 'package:flutter/material.dart';

import '../chat/chats_list_screen.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../models/app_profile.dart';
import 'account_widgets.dart';
import 'address_screen.dart';
import 'help_center_screen.dart';
import 'subscription_screen.dart';
import 'terms_screen.dart';

/// The Account side drawer. Each box closes the drawer and opens its screen on top of the page underneath, so the
/// back button always returns to where the user was. [onReturn] runs when they come back.
class AccountDrawer extends StatelessWidget {
  const AccountDrawer({super.key, required this.profile, this.onReturn});
  final AppProfile profile;
  final VoidCallback? onReturn;

  void _open(BuildContext context, Widget screen) {
    final nav = Navigator.of(context);
    nav.pop(); // close the drawer
    nav.push(MaterialPageRoute(builder: (_) => screen)).then((_) => onReturn?.call());
  }

  @override
  Widget build(BuildContext context) {
    final roleLabel = profile.role == UserRole.teacher ? 'Teacher' : 'Parent / Student';
    return Drawer(
      backgroundColor: AppColors.cream,
      child: SafeArea(
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.teal, AppColors.tealDark]),
            ),
            child: Row(children: [
              Avatar(name: profile.fullName, url: profile.avatarUrl, radius: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(profile.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                  const SizedBox(height: 6),
                  Pill(roleLabel, color: AppColors.tealDark, background: Colors.white),
                ]),
              ),
            ]),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.all(16), children: [
              AccountMenuCard(
                icon: Icons.chat_bubble_rounded,
                title: 'Chats',
                subtitle: 'Your conversations with ${profile.role == UserRole.teacher ? 'parents' : 'teachers'}',
                onTap: () => _open(context, const ChatsListScreen()),
              ),
              const SizedBox(height: 12),
              AccountMenuCard(
                icon: Icons.home_rounded,
                title: 'Address',
                subtitle: 'Current and saved addresses',
                color: AppColors.coral,
                onTap: () => _open(context, AddressScreen(profile: profile)),
              ),
              const SizedBox(height: 12),
              AccountMenuCard(
                icon: Icons.workspace_premium_rounded,
                title: 'Subscription',
                subtitle: 'Plans and pricing',
                color: const Color(0xFFB7791F),
                onTap: () => _open(context, SubscriptionScreen(profile: profile)),
              ),
              const SizedBox(height: 12),
              AccountMenuCard(
                icon: Icons.help_rounded,
                title: 'General',
                subtitle: 'Help Center and FAQs',
                color: AppColors.green,
                onTap: () => _open(context, const HelpCenterScreen()),
              ),
              const SizedBox(height: 12),
              AccountMenuCard(
                icon: Icons.policy_rounded,
                title: 'Terms and Policies',
                subtitle: 'Terms of Service and Privacy Policy',
                color: AppColors.muted,
                onTap: () => _open(context, const TermsScreen()),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), foregroundColor: AppColors.coral, side: const BorderSide(color: AppColors.coral, width: 2)),
              onPressed: () => confirmSignOut(context),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Log out'),
            ),
          ),
        ]),
      ),
    );
  }
}
