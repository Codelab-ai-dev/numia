import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'api_client.dart';
import 'token_storage.dart';
import '../features/auth/data/user_repository.dart';
import '../features/auth/domain/auth_models.dart';
import '../features/budget/data/budget_repository.dart';
import '../features/budget/domain/budget.dart';
import '../features/budget/domain/budget_summary.dart';
import '../features/budget/domain/expense.dart';
import '../features/coach/data/conversation_repository.dart';
import '../features/dashboard/data/dashboard_repository.dart';
import '../features/dashboard/domain/account.dart';
import '../features/dashboard/domain/debt.dart';
import '../features/dashboard/domain/financial_summary.dart';
import '../features/goals/data/goal_repository.dart';
import '../features/goals/domain/goal.dart';
import '../features/investments/data/investment_repository.dart';
import '../features/investments/domain/investment.dart';
import '../features/transactions/data/transaction_repository.dart';
import '../features/transactions/domain/transaction.dart';
import '../app/router.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/budget/presentation/budget_screen.dart';
import '../features/coach/presentation/coach_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/goals/presentation/goals_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/transactions/presentation/transactions_screen.dart';

// ─── Core ─────────────────────────────────────────────────────
final tokenStorageProvider = Provider<TokenStorage>((_) => TokenStorage());

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(tokenStorageProvider)),
);

final authStateProvider = StateProvider<bool>((ref) => false);

// ─── Repositories ─────────────────────────────────────────────
final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(ref.watch(apiClientProvider)),
);

final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) => TransactionRepository(ref.watch(apiClientProvider)),
);

final goalRepositoryProvider = Provider<GoalRepository>(
  (ref) => GoalRepository(ref.watch(apiClientProvider)),
);

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepository(ref.watch(apiClientProvider)),
);

final conversationRepositoryProvider = Provider<ConversationRepository>(
  (ref) => ConversationRepository(ref.watch(apiClientProvider)),
);

final budgetRepositoryProvider = Provider<BudgetRepository>(
  (ref) => BudgetRepository(ref.watch(apiClientProvider)),
);

final investmentRepositoryProvider = Provider<InvestmentRepository>(
  (ref) => InvestmentRepository(ref.watch(apiClientProvider)),
);

// ─── Data Providers ───────────────────────────────────────────
final userProfileProvider = FutureProvider<UserProfile?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(userRepositoryProvider).getProfile();
});

final onboardingDoneProvider = Provider<bool?>((ref) {
  return ref.watch(userProfileProvider).when(
        data: (p) => p?.onboardingDone ?? true,
        loading: () => null,
        error: (_, __) => true,
      );
});

// ─── Router ──────────────────────────────────────────────────
class RouterRefreshNotifier extends ChangeNotifier {
  RouterRefreshNotifier(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
    ref.listen(onboardingDoneProvider, (_, __) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = RouterRefreshNotifier(ref);
  final isAuth = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      if (skipAuth) return null;

      final loc = state.matchedLocation;
      final isOnAuthPage = loc == '/login' || loc == '/register';
      final isOnOnboarding = loc == '/onboarding';

      if (!isAuth && !isOnAuthPage && !isOnOnboarding) return '/login';
      if (isAuth && isOnAuthPage) return '/';

      final onboardingDone = ref.read(onboardingDoneProvider);
      if (isAuth && onboardingDone == null) return null;
      if (isAuth && onboardingDone == false && !isOnOnboarding) return '/onboarding';
      if (isAuth && onboardingDone == true && isOnOnboarding) return '/';

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const DashboardScreen()),
          GoRoute(path: '/budget', builder: (_, __) => const BudgetScreen()),
          GoRoute(path: '/transactions', builder: (_, __) => const TransactionsScreen()),
          GoRoute(path: '/coach', builder: (_, __) => const CoachScreen()),
          GoRoute(path: '/goals', builder: (_, __) => const GoalsScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),
    ],
  );
});

final dashboardSummaryProvider = FutureProvider<FinancialSummary>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(dashboardRepositoryProvider).getSummary();
});

final accountsProvider = FutureProvider<List<Account>>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(dashboardRepositoryProvider).getAccounts();
});

final debtsProvider = FutureProvider<List<Debt>>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(dashboardRepositoryProvider).getDebts();
});

final transactionsProvider = FutureProvider<List<Transaction>>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(transactionRepositoryProvider).getTransactions();
});

final categoryBreakdownProvider = FutureProvider<List<CategoryBreakdown>>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(transactionRepositoryProvider).getCategoryBreakdown();
});

final goalsProvider = FutureProvider<List<Goal>>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(goalRepositoryProvider).getGoals(status: 'active');
});

final budgetProvider = FutureProvider<Budget?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(budgetRepositoryProvider).getBudget();
});

final budgetSummaryProvider = FutureProvider<BudgetSummary?>((ref) async {
  ref.watch(authStateProvider);
  try {
    return await ref.watch(budgetRepositoryProvider).getSummary();
  } catch (_) {
    return null;
  }
});

final investmentsProvider = FutureProvider<List<Investment>>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(investmentRepositoryProvider).getInvestments(activeOnly: true);
});

final coachInsightProvider = FutureProvider<String>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(conversationRepositoryProvider).getInsight();
});

final selectedMonthProvider = StateProvider<DateTime>((ref) => DateTime.now());

final expensesProvider = FutureProvider<List<Expense>>((ref) {
  ref.watch(authStateProvider);
  final month = ref.watch(selectedMonthProvider);
  final start = DateTime(month.year, month.month, 1);
  final end = DateTime(month.year, month.month + 1, 0);
  final fmt = '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
  final fmtEnd = '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';
  return ref.watch(budgetRepositoryProvider).getExpenses(start: fmt, end: fmtEnd);
});
