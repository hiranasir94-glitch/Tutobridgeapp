import 'constants.dart';

class Plan {
  const Plan({required this.id, required this.name, required this.priceLabel, required this.tagline, required this.features, this.popular = false});
  final String id; // matches the check constraint on public.subscriptions.plan_id
  final String name;
  final String priceLabel;
  final String tagline;
  final List<String> features;
  final bool popular;

  bool get isFree => id.endsWith('_free');
}

// PLACEHOLDER PRICES AND BENEFITS: edit freely. Nothing here is enforced by the app or database yet, and no payment
// provider is connected, so choosing a paid plan only records a request (status 'pending_payment').
const kParentPlans = [
  Plan(
    id: 'parent_free',
    name: 'Free',
    priceLabel: 'PKR 0',
    tagline: 'Everything you need to find a teacher',
    features: ['Search verified teachers near you', 'Chat with up to 3 teachers', 'Send trial booking requests'],
  ),
  Plan(
    id: 'parent_plus',
    name: 'Plus',
    priceLabel: 'PKR 499 / month',
    tagline: 'For families comparing several teachers',
    popular: true,
    features: ['Everything in Free', 'Unlimited chats with teachers', 'Save and compare shortlisted teachers', 'Priority support'],
  ),
  Plan(
    id: 'parent_premium',
    name: 'Premium',
    priceLabel: 'PKR 999 / month',
    tagline: 'We help you find the right fit',
    features: ['Everything in Plus', 'Personal teacher-matching help', 'Early access to new Star Teachers'],
  ),
];

const kTeacherPlans = [
  Plan(
    id: 'teacher_free',
    name: 'Free',
    priceLabel: 'PKR 0',
    tagline: 'Get listed and start receiving requests',
    features: ['Profile listed once verified', 'Receive booking requests', 'Chat with parents who connect'],
  ),
  Plan(
    id: 'teacher_pro',
    name: 'Pro',
    priceLabel: 'PKR 799 / month',
    tagline: 'Be found sooner',
    popular: true,
    features: ['Everything in Free', 'Priority placement in search results', 'Profile views and request statistics'],
  ),
  Plan(
    id: 'teacher_featured',
    name: 'Featured',
    priceLabel: 'PKR 1,499 / month',
    tagline: 'Stand out on the home screen',
    features: ['Everything in Pro', 'Featured spot in the home banner', 'Faster verification review'],
  ),
];

List<Plan> plansFor(UserRole role) => role == UserRole.teacher ? kTeacherPlans : kParentPlans;
