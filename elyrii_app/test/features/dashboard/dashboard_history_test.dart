import 'package:elyrii_app/core/config/dev_session.dart';
import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/dashboard/data/models/dashboard_models.dart';
import 'package:elyrii_app/features/dashboard/data/repositories/dashboard_repository.dart';
import 'package:elyrii_app/features/dashboard/domain/civil_day.dart';
import 'package:elyrii_app/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RangeRepository extends DashboardRepository {
  _RangeRepository()
    : super(client: ApiClient(storage: SecureStorageService()));
  final ranges = <String>[];

  @override
  Future<DashboardData> getDashboard({String range = '30d'}) {
    ranges.add(range);
    return Future.value(
      DashboardData.fromJson({
        'stats': {
          'rangeDays': int.parse(range.replaceAll('d', '')),
          'streak': 3,
          'activityTimeline': [
            {'day': '2026-10-22', 'moodLogs': 2, 'journalEntries': 1},
          ],
        },
      }),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('CivilDay', () {
    test('analyse, sérialise et compare des jours serveur', () {
      final day = CivilDay.parse('2026-10-22');
      expect(day.isoDate, '2026-10-22');
      expect(day.year, 2026);
      expect(day.month, 10);
      expect(day.day, 22);
      expect(day.weekday, 4); // jeudi
      expect(day, CivilDay(2026, 10, 22));
      expect(day.hashCode, CivilDay(2026, 10, 22).hashCode);
    });

    test('rejette les dates mal formées ou impossibles', () {
      expect(() => CivilDay.parse('2026-10-22T00:00'), throwsFormatException);
      expect(() => CivilDay.parse(''), throwsFormatException);
      expect(() => CivilDay(2026, 2, 30), throwsFormatException);
      expect(() => CivilDay(2026, 13, 1), throwsFormatException);
      expect(CivilDay(2024, 2, 29).day, 29); // bissextile
    });

    test('arithmétique de jours sans fuseau ni changement d’heure', () {
      final day = CivilDay(2026, 10, 31);
      expect(day.addDays(1), CivilDay(2026, 11, 1));
      expect(day.daysUntil(CivilDay(2026, 11, 4)), 4);
      expect(CivilDay(2026, 11, 4).daysUntil(day), -4);
      expect(CivilDay(2026, 12, 31).addDays(1), CivilDay(2027, 1, 1));
    });

    test('mois civil : bornes, décalages et couverture', () {
      final month = CivilMonth(2026, 10);
      expect(month.firstDay, CivilDay(2026, 10, 1));
      expect(month.lastDay, CivilDay(2026, 10, 31));
      expect(month.days.length, 31);
      expect(month.shifted(3), CivilMonth(2027, 1));
      expect(month.shifted(-10), CivilMonth(2025, 12));

      final today = CivilDay(2026, 10, 22);
      final full = CalendarCoverage(
        firstDay: CivilDay(2026, 1, 1),
        throughDay: today,
      );
      expect(full.containsMonth(CivilMonth(2026, 9), today), isTrue);
      expect(full.containsMonth(CivilMonth(2026, 10), today), isTrue);
      expect(full.containsMonth(CivilMonth(2026, 11), today), isFalse);
      expect(full.contains(CivilDay(2026, 10, 21)), isTrue);
      expect(full.contains(CivilDay(2025, 12, 31)), isFalse);

      final partial = CalendarCoverage(
        firstDay: CivilDay(2026, 10, 15),
        throughDay: today,
      );
      expect(partial.containsMonth(CivilMonth(2026, 10), today), isFalse);
      expect(partial.containsMonth(CivilMonth(2026, 9), today), isFalse);
    });
  });

  group('DashboardStats', () {
    test('les jours du timeline deviennent des CivilDay typés', () {
      final stats = DashboardStats.fromJson({
        'rangeDays': 30,
        'streak': 7,
        'activityTimeline': [
          {'day': '2026-10-21', 'moodLogs': 3, 'journalEntries': 0},
          {'day': '2026-10-22', 'moodLogs': 0, 'journalEntries': 2},
        ],
      });
      expect(stats.activityTimeline.first.day, CivilDay(2026, 10, 21));
      expect(stats.activityTimeline.last.journalEntries, 2);
    });

    test('un jour mal formé est une erreur de contrat', () {
      expect(
        () => DashboardStats.fromJson({
          'activityTimeline': [
            {'day': 'hier', 'moodLogs': 1},
          ],
        }),
        throwsFormatException,
      );
    });
  });

  group('DashboardProvider.ensureCalendarHistory', () {
    test('le calendrier charge la plage du mois puis reste en cache', () async {
      final repository = _RangeRepository();
      final provider = DashboardProvider(
        repository: repository,
        now: () {
          return DateTime(2026, 10, 22, 9);
        },
      );
      addTearDown(provider.dispose);
      provider.onUserChanged(userId: 'alice');

      await provider.loadDashboardData();
      expect(repository.ranges, ['30d']);
      expect(provider.coverage!.throughDay, CivilDay(2026, 10, 22));
      expect(
        provider.coverage!.firstDay,
        CivilDay(2026, 9, 23),
      ); // 30 jours bornés à aujourd'hui
      expect(provider.history[CivilDay(2026, 10, 22)]!.moodLogs, 2);

      // Le mois courant tient dans la plage de 30 jours déjà chargée.
      await provider.ensureCalendarHistory(CivilMonth(2026, 10));
      expect(repository.ranges, ['30d']);

      // Un mois ancien force exactement la plage dont il a besoin.
      await provider.ensureCalendarHistory(CivilMonth(2026, 2));
      expect(repository.ranges, ['30d', '264d']);
      expect(provider.coverage!.firstDay, CivilDay(2026, 2, 1));

      // Déjà couvert : aucune nouvelle requête.
      await provider.ensureCalendarHistory(CivilMonth(2026, 6));
      expect(repository.ranges, ['30d', '264d']);

      // Un refresh conserve la plage large déjà demandée.
      await provider.refresh();
      expect(repository.ranges, ['30d', '264d', '264d']);
    });

    test('un mois ancien au-delà de 365 jours reste plafonné', () async {
      final repository = _RangeRepository();
      final provider = DashboardProvider(
        repository: repository,
        now: () {
          return DateTime(2026, 10, 22, 9);
        },
      );
      addTearDown(provider.dispose);
      provider.onUserChanged(userId: 'alice');
      await provider.ensureCalendarHistory(CivilMonth(2024, 1));
      expect(repository.ranges, ['365d']);
    });

    test(
      'une demande plus large pendant un vol n’émet qu’une requête de plus',
      () async {
        final repository = _RangeRepository();
        final provider = DashboardProvider(
          repository: repository,
          now: () {
            return DateTime(2026, 10, 22, 9);
          },
        );
        addTearDown(provider.dispose);
        provider.onUserChanged(userId: 'alice');
        final first = provider.loadDashboardData();
        await provider.ensureCalendarHistory(CivilMonth(2026, 2));
        await first;
        expect(repository.ranges, ['30d', '264d']);
      },
    );

    test('la démo expose le même mois sans toucher au dépôt', () async {
      final repository = _RangeRepository();
      final provider = DashboardProvider(
        repository: repository,
        isDemoSession: () => true,
        now: () => DateTime(2026, 10, 22, 9),
      );
      addTearDown(provider.dispose);
      provider.onUserChanged(userId: DevSession.userId, isDemo: true);
      await provider.loadDashboardData();
      expect(repository.ranges, isEmpty);
      expect(provider.currentStreak, DevSession.streakDays);
      expect(provider.coverage!.throughDay, CivilDay(2026, 10, 22));
      expect(provider.coverage!.firstDay, CivilDay(2026, 9, 23));
      expect(provider.history[CivilDay(2026, 10, 22)]!.moodLogs, 1);
    });
  });
}
