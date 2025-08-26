// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart'; // généré par flutterfire

import 'widgets/fancy_brand_bar.dart';
// PDF
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart' as pdf;
import 'package:printing/printing.dart';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'screens/login_screen.dart';

//seeder data
import 'menu_seed.dart';
import 'screens/SetupProfileScreen.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final errorCenter = ErrorCenter();

  // Catch Flutter framework errors and keep app alive.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
    errorCenter.report(
      AppError(
        userMessage: 'Oups, une erreur est survenue. L’app peut redémarrer.',
        error: details.exception,
        stackTrace: details.stack,
        onRetry: _maybeRestart,
      ),
    );
  };

  // Catch errors outside Flutter error pipeline (e.g., platform / async).
  ui.PlatformDispatcher.instance.onError = (error, stack) {
    errorCenter.report(
      AppError(
        userMessage: 'Un incident est survenu. L’app va redémarrer.',
        error: error,
        stackTrace: stack,
        onRetry: _maybeRestart,
      ),
    );
    return true; // prevent crash
  };

  // Replace red error widget so it doesn’t break the tree.
  ErrorWidget.builder = (details) => const Material(
    color: Colors.transparent,
    child: Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Un composant a rencontré une erreur.\nAppuyez sur "Redémarrer".',
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );

  // Catch all uncaught errors in a zone.
  runZonedGuarded(
    () async {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      if (kIsWeb) {
        await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
      }
      await initializeDateFormatting('fr_FR');

      runApp(
        ChangeNotifierProvider<ErrorCenter>.value(
          value: errorCenter, // un seul ErrorCenter global
          child: const RestartWidget(child: MyApp()),
        ),
      );
    },
    (error, stack) {
      errorCenter.report(
        AppError(
          userMessage:
              'Un problème imprévu est survenu. L’application reste utilisable.',
          error: error,
          stackTrace: stack,
        ),
      );
    },
  );
}

// ===================================================================
// ERROR CENTER (UX-first)
// ===================================================================

class RestartWidget extends StatefulWidget {
  const RestartWidget({super.key, required this.child});
  final Widget child;

  static void restartApp(BuildContext context) {
    context.findAncestorStateOfType<_RestartWidgetState>()?.restart();
  }

  @override
  State<RestartWidget> createState() => _RestartWidgetState();
}

void _maybeRestart() {
  final ctx = navigatorKey.currentContext;
  if (ctx != null) {
    RestartWidget.restartApp(ctx);
  }
}

class _RestartWidgetState extends State<RestartWidget> {
  Key _key = UniqueKey();
  void restart() => setState(() => _key = UniqueKey());
  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: _key, child: widget.child);
}

class AppError {
  final String userMessage;
  final Object? error;
  final StackTrace? stackTrace;
  final VoidCallback? onRetry;

  // NEW: unique id so we can show a banner only once per error
  final int id;
  AppError({
    required this.userMessage,
    this.error,
    this.stackTrace,
    this.onRetry,
    int? id,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch;
}

class ErrorCenter extends ChangeNotifier {
  AppError? _latest;
  AppError? get latest => _latest;

  void report(AppError e) {
    _latest = e;
    notifyListeners();
  }

  void clear() {
    _latest = null;
    notifyListeners();
  }
}

// Easy SnackBar for page-level, transient errors.
extension ErrorSnack on BuildContext {
  void showError(String message, {VoidCallback? onRetry}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        action: onRetry == null
            ? null
            : SnackBarAction(label: 'Réessayer', onPressed: onRetry),
      ),
    );
  }
}

// ===================================================================
// THEME
// ===================================================================

const _seed = Color(0xFF8B5E3C);
const _accent = Color(0xFFD86B4A);
const _brandName = 'Waldschenke';

ThemeData _restaurantTheme() {
  final base = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
    ),
    useMaterial3: true,
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      titleTextStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      margin: EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
  );
}

// ===================================================================
// DATA MODELS
// ===================================================================

double _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) {
    final s = v.replaceAll('"', '').replaceAll(',', '.').trim();
    return double.tryParse(s) ?? 0.0;
  }
  return 0.0;
}

String _toStringClean(dynamic v) {
  if (v == null) return '';
  final s = v.toString();
  // strip accidental extra quotes
  return s.startsWith('"') && s.endsWith('"')
      ? s.substring(1, s.length - 1)
      : s;
}

class Dish {
  final String id;
  final String name;
  final double price;
  const Dish({required this.id, required this.name, required this.price});

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'price': price};

  factory Dish.fromMap(Map m) => Dish(
    id: _toStringClean(m['id']),
    name: _toStringClean(m['name']),
    price: _toDouble(m['price']),
  );
}

class MenuSubcategory {
  final String id;
  final String name;
  final List<Dish> dishes;
  const MenuSubcategory({
    required this.id,
    required this.name,
    required this.dishes,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'dishes': dishes.map((d) => d.toMap()).toList(),
  };
  factory MenuSubcategory.fromMap(Map m) => MenuSubcategory(
    id: '${m['id']}',
    name: '${m['name']}',
    dishes: (m['dishes'] as List? ?? [])
        .map((e) => Dish.fromMap(Map<String, dynamic>.from(e)))
        .toList(),
  );
}

class MenuCategory {
  final String id;
  final String name;
  final List<MenuSubcategory> subcategories;
  const MenuCategory({
    required this.id,
    required this.name,
    required this.subcategories,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'subcategories': subcategories.map((s) => s.toMap()).toList(),
  };
  factory MenuCategory.fromMap(Map m) => MenuCategory(
    id: '${m['id']}',
    name: '${m['name']}',
    subcategories: (m['subcategories'] as List? ?? [])
        .map((e) => MenuSubcategory.fromMap(Map<String, dynamic>.from(e)))
        .toList(),
  );
}

class OrderItem {
  final Dish dish;
  int quantity;
  OrderItem({required this.dish, this.quantity = 1});
  double get lineTotal => dish.price * quantity;
}

class TableOrder {
  final int tableNumber;
  final List<OrderItem> items;
  TableOrder({required this.tableNumber, List<OrderItem>? items})
    : items = items ?? [];
  double get total => items.fold(0.0, (s, it) => s + it.lineTotal);
  void clear() => items.clear();
}

enum UserRole { manager, server }

// ===================================================================
// APP STATE — Firestore (centralisé) + temps réel
// ===================================================================
class RestaurantState extends ChangeNotifier {
  RestaurantState({
    required this.errorCenter,
    required this.restaurantId,
    required this.currentUid,
    required this.role,
  });

  final ErrorCenter errorCenter;
  final String restaurantId;
  final String currentUid;
  final UserRole role;

  String get todayKey => _todayKey();

  // Firestore refs
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  late final DocumentReference<Map<String, dynamic>> _restaurantDoc = _db
      .collection('restaurants')
      .doc(restaurantId);
  late final CollectionReference<Map<String, dynamic>> _tablesCol =
      _restaurantDoc.collection('tables');
  late final CollectionReference<Map<String, dynamic>> _daysCol = _restaurantDoc
      .collection('days');

  // Menu
  List<MenuCategory> _menu = const [];
  List<MenuCategory> get menuTree => List.unmodifiable(_menu);

  // Tables
  int _tableCount = 8;
  int get tableCount => _tableCount;
  List<TableOrder> _tables = List.generate(
    8,
    (i) => TableOrder(tableNumber: i + 1),
  );
  List<TableOrder> get tables => List.unmodifiable(_tables);

  Future<void> claimTable(int tableNumber) async {
    try {
      await _tableDoc(tableNumber).set({
        'tableNumber': tableNumber,
        'assignedTo': currentUid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e, st) {
      errorCenter.report(
        AppError(
          userMessage: 'Impossible de prendre la table.',
          error: e,
          stackTrace: st,
        ),
      );
    }
  }

  Future<void> releaseTable(int tableNumber) async {
    try {
      await _tableDoc(tableNumber).set({
        'assignedTo': null,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e, st) {
      errorCenter.report(
        AppError(
          userMessage: 'Impossible de libérer la table.',
          error: e,
          stackTrace: st,
        ),
      );
    }
  }

  // Jour
  double _dailyTotal = 0.0;
  double get dailyTotal {
    if (role == UserRole.manager) return _dailyTotal;
    double sum = 0.0;
    for (final e in _journalToday) {
      sum += (e['total'] as num?)?.toDouble() ?? 0.0;
    }
    return sum;
  }

  // Historique 'yyyy-MM-dd' -> total
  final Map<String, double> _historyTotals = {};
  Map<String, double> get historyTotals => Map.unmodifiable(_historyTotals);

  // Journal du jour
  List<Map<String, dynamic>> _journalToday = [];
  List<Map<String, dynamic>> get journalToday =>
      List.unmodifiable(_journalToday);

  // Ready
  bool _ready = false;
  bool get isReady => _ready;

  // Streams + minuit
  StreamSubscription? _restSub;
  StreamSubscription? _tablesSub;
  StreamSubscription? _todaySub;
  StreamSubscription? _todayJournalSub;
  StreamSubscription? _historySub;
  Timer? _midnightTimer;

  Future<void> _ensureTodayDocExists() async {
    final ref = _daysCol.doc(_todayKey());
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'total': 0.0,
        'tz': 'Europe/Madrid',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  // ---------- INIT / DISPOSE ----------
  Future<void> init() async {
    try {
      // 1) Resto root: menuTree + tablesCount
      _restSub = _restaurantDoc.snapshots().listen((doc) async {
        if (!doc.exists) {
          // Bootstrap minimal si le doc n’existe pas
          await _restaurantDoc.set({
            'name': _brandName,
            'tablesCount': _tableCount,
            'menuTree': _menu.map((c) => c.toMap()).toList(),
            'tz': 'Europe/Madrid',
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          return;
        }

        final data = doc.data() ?? {};
        final rawMenu = data['menuTree'] as List? ?? const [];
        _menu = rawMenu
            .map((e) => MenuCategory.fromMap(Map<String, dynamic>.from(e)))
            .toList();

        final tc = data['tablesCount'] as int? ?? 8;
        if (_tableCount != tc) {
          _tableCount = tc;
          // Réinitialise visuel local (les items réels arrivent via stream des tables)
          _tables = List.generate(
            _tableCount,
            (i) => TableOrder(tableNumber: i + 1),
          );
        }

        notifyListeners();
      }, onError: _onStreamError);

      // 2) Tables (temps réel)
      // 2) Tables (temps réel) — tous rôles voient toutes les tables
      _tablesSub = _tablesCol.snapshots().listen((qs) {
        final existing = <int, TableOrder>{};
        for (final d in qs.docs) {
          final data = d.data();
          final tableNo =
              int.tryParse(d.id) ?? (data['tableNumber'] as num?)?.toInt() ?? 0;

          final rawItems = (data['items'] as List?) ?? const [];
          final items = <OrderItem>[];
          for (final m in rawItems) {
            final itemMap = (m as Map).cast<String, dynamic>();
            items.add(
              OrderItem(
                dish: Dish(
                  id: _toStringClean(itemMap['dishId']),
                  name: _toStringClean(itemMap['name']),
                  price: _toDouble(itemMap['price']),
                ),
                quantity: _toInt(itemMap['qty']),
              ),
            );
          }

          if (tableNo > 0) {
            existing[tableNo] = TableOrder(tableNumber: tableNo, items: items);
          }
        }

        // Toujours afficher la grille 1..tableCount, même si des docs manquent
        _tables = List.generate(_tableCount, (i) {
          final tn = i + 1;
          return existing[tn] ?? TableOrder(tableNumber: tn);
        });

        notifyListeners();
      }, onError: _onStreamError);

      // 3) Aujourd’hui (total + journal)
      // 3) Aujourd’hui (total + journal)
      await _ensureTodayDocExists();
      final dayKey = _todayKey();
      final todayDoc = _daysCol.doc(dayKey);

      // Manager : lit le doc du jour (total global)
      if (role == UserRole.manager) {
        _todaySub = todayDoc.snapshots().listen((doc) {
          _dailyTotal = (doc.data()?['total'] as num?)?.toDouble() ?? 0.0;
          notifyListeners();
        }, onError: _onStreamError);
      } else {
        // Serveur : ne lit pas le doc (pas de droit de lecture) ; _dailyTotal = somme de _journalToday via getter
        _dailyTotal = 0.0;
      }

      // Journal (manager = tout ; serveur = filtré par son uid)
      Query<Map<String, dynamic>> jq = todayDoc
          .collection('journal')
          .orderBy('ts');
      if (role == UserRole.server) {
        jq = todayDoc
            .collection('journal')
            .where('serverUid', isEqualTo: currentUid)
            .orderBy('ts');
      }
      _todayJournalSub = jq.snapshots().listen((qs) {
        _journalToday = qs.docs.map((d) => d.data()).toList();
        notifyListeners();
      }, onError: _onStreamError);

      // 4) Historique (90 jours)
      _historySub = _daysCol
          .orderBy('updatedAt', descending: true)
          .limit(90)
          .snapshots()
          .listen(
            (qs) {
              _historyTotals.clear();
              for (final d in qs.docs) {
                final data = d.data();
                final total = (data['total'] as num?)?.toDouble() ?? 0.0;
                _historyTotals[d.id] = total;
              }
              notifyListeners();
            },
            onError: (e, st) {
              _onStreamError(e, st);
            },
          );

      _ready = true;
      notifyListeners();
      _scheduleMidnightTick();
    } catch (e, st) {
      errorCenter.report(
        AppError(
          userMessage: 'Impossible de se connecter au serveur.',
          error: e,
          stackTrace: st,
        ),
      );
      _ready = true;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _restSub?.cancel();
    _tablesSub?.cancel();
    _todaySub?.cancel();
    _todayJournalSub?.cancel();
    _historySub?.cancel();
    _midnightTimer?.cancel();
    super.dispose();
  }

  // ---------- MENU CRUD (identique côté UI, persistance Firestore) ----------
  Future<void> _persistMenu() async {
    try {
      await _restaurantDoc.set({
        'menuTree': _menu.map((c) => c.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e, st) {
      errorCenter.report(
        AppError(
          userMessage: 'Impossible d’enregistrer le menu. Réessayez.',
          error: e,
          stackTrace: st,
          onRetry: () => _persistMenu(),
        ),
      );
    }
  }

  Future<void> addCategory(String name) async {
    _menu = [
      ..._menu,
      MenuCategory(id: _id(), name: name.trim(), subcategories: const []),
    ];
    await _persistMenu();
    notifyListeners();
  }

  Future<void> renameCategory(String id, String name) async {
    _menu = _menu
        .map(
          (c) => c.id == id
              ? MenuCategory(
                  id: id,
                  name: name.trim(),
                  subcategories: c.subcategories,
                )
              : c,
        )
        .toList();
    await _persistMenu();
    notifyListeners();
  }

  Future<void> removeCategory(String id) async {
    _menu = _menu.where((c) => c.id != id).toList();
    await _persistMenu();
    notifyListeners();
  }

  Future<void> addSubcategory(String catId, String name) async {
    _menu = _menu.map((c) {
      if (c.id != catId) return c;
      final sc = [
        ...c.subcategories,
        MenuSubcategory(id: _id(), name: name.trim(), dishes: const []),
      ];
      return MenuCategory(id: c.id, name: c.name, subcategories: sc);
    }).toList();
    await _persistMenu();
    notifyListeners();
  }

  Future<void> renameSubcategory(
    String catId,
    String subId,
    String name,
  ) async {
    _menu = _menu.map((c) {
      if (c.id != catId) return c;
      final sc = c.subcategories.map((s) {
        if (s.id != subId) return s;
        return MenuSubcategory(id: s.id, name: name.trim(), dishes: s.dishes);
      }).toList();
      return MenuCategory(id: c.id, name: c.name, subcategories: sc);
    }).toList();
    await _persistMenu();
    notifyListeners();
  }

  Future<void> removeSubcategory(String catId, String subId) async {
    _menu = _menu.map((c) {
      if (c.id != catId) return c;
      final sc = c.subcategories.where((s) => s.id != subId).toList();
      return MenuCategory(id: c.id, name: c.name, subcategories: sc);
    }).toList();
    await _persistMenu();
    notifyListeners();
  }

  Future<void> addDish(
    String catId,
    String subId,
    String name,
    double price,
  ) async {
    _menu = _menu.map((c) {
      if (c.id != catId) return c;
      final sc = c.subcategories.map((s) {
        if (s.id != subId) return s;
        final dishes = [
          ...s.dishes,
          Dish(id: _id(), name: name.trim(), price: price),
        ];
        return MenuSubcategory(id: s.id, name: s.name, dishes: dishes);
      }).toList();
      return MenuCategory(id: c.id, name: c.name, subcategories: sc);
    }).toList();
    await _persistMenu();
    notifyListeners();
  }

  Future<void> editDish(
    String catId,
    String subId,
    String dishId,
    String name,
    double price,
  ) async {
    _menu = _menu.map((c) {
      if (c.id != catId) return c;
      final sc = c.subcategories.map((s) {
        if (s.id != subId) return s;
        final dishes = s.dishes.map((d) {
          if (d.id != dishId) return d;
          return Dish(id: d.id, name: name.trim(), price: price);
        }).toList();
        return MenuSubcategory(id: s.id, name: s.name, dishes: dishes);
      }).toList();
      return MenuCategory(id: c.id, name: c.name, subcategories: sc);
    }).toList();
    await _persistMenu();
    notifyListeners();
  }

  Future<void> removeDish(String catId, String subId, String dishId) async {
    _menu = _menu.map((c) {
      if (c.id != catId) return c;
      final sc = c.subcategories.map((s) {
        if (s.id != subId) return s;
        final dishes = s.dishes.where((d) => d.id != dishId).toList();
        return MenuSubcategory(id: s.id, name: s.name, dishes: dishes);
      }).toList();
      return MenuCategory(id: c.id, name: c.name, subcategories: sc);
    }).toList();
    await _persistMenu();
    notifyListeners();
  }

  // ---------- TABLES ----------
  Future<void> setTableCount(int newCount) async {
    if (newCount <= 0) return;
    try {
      final prev = _tableCount;
      _tableCount = newCount;

      await _restaurantDoc.set({
        'tablesCount': newCount,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Nettoie les docs Firestore des tables au-delà du nouveau max
      if (newCount < prev) {
        for (int n = newCount + 1; n <= prev; n++) {
          await _tableDoc(n).set({
            'items': [],
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      _tables = List.generate(
        _tableCount,
        (i) => TableOrder(tableNumber: i + 1),
      );
      notifyListeners();
    } catch (e, st) {
      errorCenter.report(
        AppError(
          userMessage: 'Impossible de modifier le nombre de tables.',
          error: e,
          stackTrace: st,
          onRetry: () => setTableCount(newCount),
        ),
      );
    }
  }

  TableOrder? _findTable(int tableNumber) =>
      _tables.firstWhereOrNull((t) => t.tableNumber == tableNumber);

  DocumentReference<Map<String, dynamic>> _tableDoc(int tableNumber) =>
      _tablesCol.doc('$tableNumber');

  Future<void> _mutateTableItemsTransactional({
    required int tableNumber,
    required List<Map<String, dynamic>>
    deltas, // [{dishId, name, price, deltaQty}] ; deltaQty peut être négatif
    bool replaceAllWithEmpty = false, // pour clear()
  }) async {
    final ref = _tableDoc(tableNumber);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = Map<String, dynamic>.from(snap.data() ?? {});
      final raw =
          (data['items'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          <Map<String, dynamic>>[];

      final byId = <String, Map<String, dynamic>>{
        for (final m in raw) (m['dishId'] ?? '') as String: m,
      };

      if (replaceAllWithEmpty) {
        byId.clear();
      } else {
        for (final d in deltas) {
          final id = (d['dishId'] ?? '') as String;
          if (id.isEmpty) continue;
          final name = d['name'] as String? ?? '';
          final price = (d['price'] is num)
              ? (d['price'] as num).toDouble()
              : double.tryParse('${d['price']}'.replaceAll(',', '.')) ?? 0.0;
          final delta = (d['deltaQty'] as num?)?.toInt() ?? 0;

          final existing = byId[id];
          final currentQty = (existing?['qty'] as num?)?.toInt() ?? 0;
          final newQty = currentQty + delta;

          if (newQty <= 0) {
            byId.remove(id);
          } else {
            byId[id] = {
              'dishId': id,
              'name': name.isEmpty ? (existing?['name'] ?? '') : name,
              'price': existing?['price'] ?? price,
              'qty': newQty,
            };
          }
        }
      }

      tx.set(ref, {
        'tableNumber': tableNumber,
        'items': byId.values.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> addDishToTable(
    int tableNumber,
    Dish dish, {
    int quantity = 1,
  }) async {
    if (quantity <= 0) return;
    try {
      await _mutateTableItemsTransactional(
        tableNumber: tableNumber, // <= ICI
        deltas: [
          {
            'dishId': dish.id,
            'name': dish.name,
            'price': dish.price,
            'deltaQty': quantity,
          },
        ],
      );
    } catch (e, st) {
      errorCenter.report(
        AppError(
          userMessage: 'Impossible d’ajouter l’article. Réessayez.',
          error: e,
          stackTrace: st,
        ),
      );
    }
  }

  Future<void> setItemQuantity(int tableNumber, Dish dish, int quantity) async {
    if (quantity < 0) quantity = 0;
    try {
      final table = _findTable(tableNumber);
      final currentQty =
          table?.items
              .firstWhereOrNull((it) => it.dish.id == dish.id)
              ?.quantity ??
          0;
      final delta = quantity - currentQty;
      if (delta == 0) return;

      await _mutateTableItemsTransactional(
        tableNumber: tableNumber, // <= ICI
        deltas: [
          {
            'dishId': dish.id,
            'name': dish.name,
            'price': dish.price,
            'deltaQty': delta,
          },
        ],
      );
    } catch (e, st) {
      errorCenter.report(
        AppError(
          userMessage: 'Impossible de modifier la quantité.',
          error: e,
          stackTrace: st,
        ),
      );
    }
  }

  Future<void> removeItem(int tableNumber, Dish dish) async {
    try {
      final table = _findTable(tableNumber);
      final currentQty =
          table?.items
              .firstWhereOrNull((it) => it.dish.id == dish.id)
              ?.quantity ??
          0;
      if (currentQty == 0) return;

      await _mutateTableItemsTransactional(
        tableNumber: tableNumber, // <= ICI
        deltas: [
          {
            'dishId': dish.id,
            'name': dish.name,
            'price': dish.price,
            'deltaQty': -currentQty,
          },
        ],
      );
    } catch (e, st) {
      errorCenter.report(
        AppError(
          userMessage: 'Impossible de supprimer l’article.',
          error: e,
          stackTrace: st,
        ),
      );
    }
  }

  Future<void> clearTable(int tableNumber) async {
    try {
      await _mutateTableItemsTransactional(
        tableNumber: tableNumber, // <= ICI
        deltas: const [],
        replaceAllWithEmpty: true,
      );
    } catch (e, st) {
      errorCenter.report(
        AppError(
          userMessage: 'Impossible de vider la table.',
          error: e,
          stackTrace: st,
        ),
      );
    }
  }

Future<double> closeTableAndAddToDaily(int tableNumber) async {
  final table = _findTable(tableNumber);
  if (table == null) {
    errorCenter.report(AppError(userMessage: 'Table introuvable.'));
    return 0.0;
  }

  try {
    final amount = table.total;
    final dayKey = _todayKey();
    final todayDoc = _daysCol.doc(dayKey);
    final journalCol = todayDoc.collection('journal');

    await _db.runTransaction((tx) async {
      // 1) total global (manager)
      tx.set(todayDoc, {
        'total': FieldValue.increment(amount),
        'tz': 'Europe/Madrid',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 2) lignes du journal (TOUJOURS avec serverUid)
      for (final it in table.items) {
        tx.set(journalCol.doc(), {
          'ts': FieldValue.serverTimestamp(),
          'table': tableNumber,
          'dishId': it.dish.id,
          'name': it.dish.name,
          'price': it.dish.price,
          'qty': it.quantity,
          'total': it.lineTotal,
          'serverUid': currentUid,
        });
      }

      // 3) vider la table
      tx.set(_tableDoc(tableNumber), {
        'items': [],
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    // 🔸 Miroir local immédiat pour les serveurs
    if (role == UserRole.server) {
      final nowTs = Timestamp.now();
      for (final it in table.items) {
        _journalToday.add({
          'ts': nowTs,
          'table': tableNumber,
          'dishId': it.dish.id,
          'name': it.dish.name,
          'price': it.dish.price,
          'qty': it.quantity,
          'total': it.lineTotal,
          'serverUid': currentUid,
        });
      }
    }

    table.clear();
    notifyListeners();
    return amount;
  } catch (e, st) {
    errorCenter.report(AppError(
      userMessage: 'Impossible de fermer la table.',
      error: e,
      stackTrace: st,
    ));
    return 0.0;
  }
}



  Future<void> closeAllOpenTablesToDaily() async {
    try {
      final dayKey = _todayKey();
      final todayDoc = _daysCol.doc(dayKey);
      final journalCol = todayDoc.collection('journal');

      await _db.runTransaction((tx) async {
        double add = 0.0;
        for (final t in _tables) {
          if (t.items.isEmpty) continue;
          for (final it in t.items) {
            tx.set(journalCol.doc(), {
              'ts': FieldValue.serverTimestamp(),
              'table': t.tableNumber,
              'dishId': it.dish.id,
              'name': it.dish.name,
              'price': it.dish.price,
              'qty': it.quantity,
              'total': it.lineTotal,
              'serverUid': currentUid,
            });
          }
          add += t.total;
          tx.set(_tableDoc(t.tableNumber), {
            'items': [],
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
        if (add > 0) {
          tx.set(todayDoc, {
            'total': FieldValue.increment(add),
            'tz': 'Europe/Madrid',
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      });

      for (final t in _tables) {
        t.clear();
      }
      notifyListeners();
    } catch (e, st) {
      errorCenter.report(
        AppError(
          userMessage: 'Impossible d’ajouter toutes les tables au jour.',
          error: e,
          stackTrace: st,
        ),
      );
    }
  }

  Future<void> resetDailyTotal({bool keepHistory = true}) async {
    try {
      final todayRef = _daysCol.doc(_todayKey());

      if (keepHistory) {
        // 1) Déplacer le journal vers journal_archive
        final qs = await todayRef.collection('journal').get();
        if (qs.docs.isNotEmpty) {
          final batch = _db.batch();
          for (final d in qs.docs) {
            final data = d.data();
            final archRef = todayRef.collection('journal_archive').doc(d.id);
            batch.set(archRef, {
              ...data,
              'archivedAt': FieldValue.serverTimestamp(),
            });
            batch.delete(d.reference);
          }
          await batch.commit();
        }

        // 2) Vider les tables ouvertes (local + Firestore) -> via transaction “clear”
        for (final t in _tables) {
          await _mutateTableItemsTransactional(
            tableNumber: t.tableNumber,
            deltas: const [],
            replaceAllWithEmpty: true,
          );
        }

        // 3) État local minimal (sera remplacé par les streams)
        _journalToday = [];
        notifyListeners();
        return;
      }

      // --- Hard reset (inclut total = 0) ---
      await todayRef.set({'total': 0.0}, SetOptions(merge: true));
      final qs = await todayRef.collection('journal').get();
      if (qs.docs.isNotEmpty) {
        final batch = _db.batch();
        for (final d in qs.docs) batch.delete(d.reference);
        await batch.commit();
      }
      for (final t in _tables) {
        await _mutateTableItemsTransactional(
          tableNumber: t.tableNumber,
          deltas: const [],
          replaceAllWithEmpty: true,
        );
      }
      _dailyTotal = 0.0;
      _journalToday = [];
      notifyListeners();
    } catch (e, st) {
      errorCenter.report(
        AppError(
          userMessage: 'Impossible de réinitialiser le jour.',
          error: e,
          stackTrace: st,
        ),
      );
    }
  }

  /// Supprime une collection par pages (évite la limite 500 opérations/batch).
  Future<void> _deleteCollectionPaged(
    CollectionReference<Map<String, dynamic>> col, {
    bool deleteJournalSub = false,
  }) async {
    const pageSize = 300;
    while (true) {
      final snap = await col.limit(pageSize).get();
      if (snap.docs.isEmpty) break;

      final batch = _db.batch();
      for (final doc in snap.docs) {
        if (deleteJournalSub) {
          // Effacer sous-collection 'journal' si elle existe
          final jr = await doc.reference.collection('journal').get();
          for (final j in jr.docs) {
            batch.delete(j.reference);
          }
        }
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  // ---------- AGGRÉGATS / HISTORIQUE ----------
  String _todayKey() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  double sumLastDays(int days) {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: days - 1));
    double sum = 0.0;
    _historyTotals.forEach((k, v) {
      final d = DateTime.parse(k);
      if (!d.isBefore(start)) sum += v;
    });
    return sum;
  }

  List<MapEntry<String, double>> historySortedDesc() {
    final entries = _historyTotals.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    return entries;
  }

  // ---------- PDF (web-safe) ----------
  Future<void> exportDailyInvoicePdf() async {
    try {
      // ✅ Use Google fonts provided by `printing` (no asset files required)
      final baseFont = await PdfGoogleFonts.robotoRegular();
      final boldFont = await PdfGoogleFonts.robotoBold();

      final doc = pw.Document();
      final now = DateTime.now();
      final dayKey = _todayKey();
      final dateLabel = DateFormat('EEEE d MMMM y', 'fr_FR').format(now);
      final totalJour = _dailyTotal;

      // Try to fetch lines from Firestore (journal -> archive), fallback to in-memory list
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs = [];
      try {
        final todayRef = _daysCol.doc(dayKey);
        final jrSnap = await todayRef.collection('journal').orderBy('ts').get();
        docs = jrSnap.docs;
        if (docs.isEmpty) {
          final archSnap = await todayRef
              .collection('journal_archive')
              .orderBy('ts')
              .get();
          docs = archSnap.docs;
        }
      } catch (e) {
        // Non-blocking: we'll fallback to _journalToday
        debugPrint(
          '[PDF] Firestore read failed, falling back to local journal: $e',
        );
      }

      final rows =
          (docs.isNotEmpty ? docs.map((d) => d.data()).toList() : _journalToday)
              .map((e) {
                final t = e['table'];
                final nm = e['name'];
                final q = e['qty'];
                final p = (e['price'] as num).toDouble();
                final tot = (e['total'] as num).toDouble();
                return ['$t', nm, '$q', _fmt(p), _fmt(tot)];
              })
              .toList();

      doc.addPage(
        pw.MultiPage(
          pageTheme: const pw.PageTheme(margin: pw.EdgeInsets.all(32)),
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        _brandName,
                        style: pw.TextStyle(font: boldFont, fontSize: 24),
                      ),
                      pw.Text(
                        'Facture du jour — $dateLabel',
                        style: pw.TextStyle(font: baseFont, fontSize: 12),
                      ),
                    ],
                  ),
                  pw.Text(
                    'Total: ${_fmt(totalJour)}',
                    style: pw.TextStyle(font: boldFont, fontSize: 18),
                  ),
                ],
              ),
            ),
            if (rows.isEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 40),
                child: pw.Text(
                  totalJour > 0
                      ? 'Impression du total uniquement.'
                      : 'Aucune vente enregistrée aujourd\'hui.',
                  style: pw.TextStyle(font: baseFont, fontSize: 14),
                ),
              )
            else
              pw.Table.fromTextArray(
                headers: ['Table', 'Article', 'Qté', 'Prix', 'Total'],
                data: rows,
                headerStyle: pw.TextStyle(font: boldFont),
                headerDecoration: pw.BoxDecoration(
                  color: pdf.PdfColors.grey300,
                ),
                cellAlignment: pw.Alignment.centerLeft,
                cellStyle: pw.TextStyle(font: baseFont, fontSize: 11),
                columnWidths: {
                  0: const pw.FixedColumnWidth(50),
                  1: const pw.FlexColumnWidth(),
                  2: const pw.FixedColumnWidth(40),
                  3: const pw.FixedColumnWidth(60),
                  4: const pw.FixedColumnWidth(70),
                },
              ),
            pw.SizedBox(height: 12),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: pdf.PdfColor.fromInt(0xFFCCCCCC),
                  ),
                ),
                child: pw.Text(
                  'TOTAL JOUR: ${_fmt(totalJour)}',
                  style: pw.TextStyle(font: boldFont, fontSize: 14),
                ),
              ),
            ),
            pw.SizedBox(height: 24),
            pw.Text(
              'Référence: $dayKey • Généré via ${_brandName}',
              style: pw.TextStyle(font: baseFont),
            ),
          ],
        ),
      );

      final bytes = await doc.save();

      if (kIsWeb) {
        await Printing.layoutPdf(
          onLayout: (_) async => bytes,
        ); // opens print dialog
      } else {
        await Printing.sharePdf(bytes: bytes, filename: 'Facture_$dayKey.pdf');
      }
    } catch (e, st) {
      // show a visible message instead of silent ErrorCenter only
      final ctx = navigatorKey.currentContext;
      if (ctx != null) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(
              'PDF: ${e is FlutterError ? e.message : e.toString()}',
            ),
          ),
        );
      }
      errorCenter.report(
        AppError(
          userMessage: 'Le PDF n’a pas pu être généré ou partagé.',
          error: e,
          stackTrace: st,
          onRetry: () => exportDailyInvoicePdf(),
        ),
      );
    }
  }

  Future<void> exportInvoicePdfForDay(String dayKey) async {
    try {
      final baseFont = await PdfGoogleFonts.robotoRegular();
      final boldFont = await PdfGoogleFonts.robotoBold();

      final doc = pw.Document();

      // Libellé de date lisible
      final date = DateTime.tryParse(dayKey);
      final dateLabel = date == null
          ? dayKey
          : DateFormat('EEEE d MMMM y', 'fr_FR').format(date);

      // --- Récupération des lignes ---
      final dayRef = _daysCol.doc(dayKey);

      // Manager : toutes les lignes ; Serveur : seulement ses lignes
      Query<Map<String, dynamic>> q = dayRef
          .collection('journal')
          .orderBy('ts');
      if (role == UserRole.server) {
        q = dayRef
            .collection('journal')
            .where('serverUid', isEqualTo: currentUid)
            .orderBy('ts');
      }

      List<Map<String, dynamic>> lines = [];
      try {
        final jrSnap = await q.get();
        if (jrSnap.docs.isNotEmpty) {
          lines = jrSnap.docs.map((d) => d.data()).toList();
        } else {
          // si journal vide, on tente l'archive (manager = toutes, serveur = ses lignes)
          Query<Map<String, dynamic>> qa = dayRef
              .collection('journal_archive')
              .orderBy('ts');
          if (role == UserRole.server) {
            qa = dayRef
                .collection('journal_archive')
                .where('serverUid', isEqualTo: currentUid)
                .orderBy('ts');
          }
          final archSnap = await qa.get();
          lines = archSnap.docs.map((d) => d.data()).toList();
        }
      } catch (_) {
        // si une lecture échoue, on continue avec 0 ligne
      }

      // --- Calcul du total ---
      // Manager : on essaie d'afficher le total global ; Serveur : total personnel uniquement
      double totalJour = 0.0;
      if (role == UserRole.manager) {
        try {
          final daySnap = await dayRef.get();
          totalJour = (daySnap.data()?['total'] as num?)?.toDouble() ?? 0.0;
        } catch (_) {
          // fallback : somme des lignes si le doc n'est pas dispo
          for (final e in lines) {
            totalJour += (e['total'] as num?)?.toDouble() ?? 0.0;
          }
        }
      } else {
        // Serveur → total personnel = somme des lignes filtrées
        for (final e in lines) {
          totalJour += (e['total'] as num?)?.toDouble() ?? 0.0;
        }
      }

      // --- Table PDF ---
      List<List<String>> rows = lines.map((e) {
        final t = '${e['table']}';
        final nm = '${e['name']}';
        final qte = '${e['qty']}';
        final p = (e['price'] as num?)?.toDouble() ?? 0.0;
        final tot = (e['total'] as num?)?.toDouble() ?? 0.0;
        return [t, nm, qte, _fmt(p), _fmt(tot)];
      }).toList();

      doc.addPage(
        pw.MultiPage(
          pageTheme: const pw.PageTheme(margin: pw.EdgeInsets.all(32)),
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        _brandName,
                        style: pw.TextStyle(font: boldFont, fontSize: 24),
                      ),
                      pw.Text(
                        role == UserRole.manager
                            ? 'Facture — $dateLabel'
                            : 'Mes ventes — $dateLabel',
                        style: pw.TextStyle(font: baseFont, fontSize: 12),
                      ),
                    ],
                  ),
                  pw.Text(
                    'Total: ${_fmt(totalJour)}',
                    style: pw.TextStyle(font: boldFont, fontSize: 18),
                  ),
                ],
              ),
            ),
            if (rows.isEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 40),
                child: pw.Text(
                  totalJour > 0
                      ? 'Impression du total uniquement.'
                      : (role == UserRole.manager
                            ? 'Aucune vente enregistrée ce jour-là.'
                            : 'Aucune vente enregistrée pour votre compte ce jour-là.'),
                  style: pw.TextStyle(font: baseFont, fontSize: 14),
                ),
              )
            else
              pw.Table.fromTextArray(
                headers: ['Table', 'Article', 'Qté', 'Prix', 'Total'],
                data: rows,
                headerStyle: pw.TextStyle(font: boldFont),
                headerDecoration: pw.BoxDecoration(
                  color: pdf.PdfColors.grey300,
                ),
                cellAlignment: pw.Alignment.centerLeft,
                cellStyle: pw.TextStyle(font: baseFont, fontSize: 11),
                columnWidths: {
                  0: const pw.FixedColumnWidth(50),
                  1: const pw.FlexColumnWidth(),
                  2: const pw.FixedColumnWidth(40),
                  3: const pw.FixedColumnWidth(60),
                  4: const pw.FixedColumnWidth(70),
                },
              ),
            pw.SizedBox(height: 12),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: pdf.PdfColor.fromInt(0xFFCCCCCC),
                  ),
                ),
                child: pw.Text(
                  (role == UserRole.manager
                      ? 'TOTAL JOUR: ${_fmt(totalJour)}'
                      : 'MON TOTAL: ${_fmt(totalJour)}'),
                  style: pw.TextStyle(font: boldFont, fontSize: 14),
                ),
              ),
            ),
            pw.SizedBox(height: 24),
            pw.Text(
              'Référence: $dayKey • Généré via ${_brandName}',
              style: pw.TextStyle(font: baseFont),
            ),
          ],
        ),
      );

      final bytes = await doc.save();
      if (kIsWeb) {
        await Printing.layoutPdf(onLayout: (_) async => bytes);
      } else {
        await Printing.sharePdf(bytes: bytes, filename: 'Facture_$dayKey.pdf');
      }
    } catch (e, st) {
      final ctx = navigatorKey.currentContext;
      if (ctx != null) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(
              'PDF: ${e is FlutterError ? e.message : e.toString()}',
            ),
          ),
        );
      }
      errorCenter.report(
        AppError(
          userMessage: 'Le PDF n’a pas pu être généré ou partagé.',
          error: e,
          stackTrace: st,
          onRetry: () => exportInvoicePdfForDay(dayKey),
        ),
      );
    }
  }

  // ---------- Minuit ----------
void _scheduleMidnightTick() {
  _midnightTimer?.cancel();

  final now = DateTime.now();
  final nextMidnight = DateTime(now.year, now.month, now.day)
      .add(const Duration(days: 1));

  _midnightTimer = Timer(
    nextMidnight.difference(now) + const Duration(seconds: 1),
    () async {
      try {
        await _ensureTodayDocExists();
      } catch (_) {}

      _todaySub?.cancel();
      _todayJournalSub?.cancel();

      final todayDoc = _daysCol.doc(_todayKey());

      // Manager: lit le total global ; Serveur: pas de lecture du doc jour
      if (role == UserRole.manager) {
        _todaySub = todayDoc.snapshots().listen((doc) {
          _dailyTotal = (doc.data()?['total'] as num?)?.toDouble() ?? 0.0;
          notifyListeners();
        }, onError: _onStreamError);
      } else {
        _dailyTotal = 0.0; // le total serveur = somme(_journalToday)
      }

      // Journal: manager = tout ; serveur = filtré par son uid
      Query<Map<String, dynamic>> jq = todayDoc.collection('journal').orderBy('ts');
      if (role == UserRole.server) {
        jq = todayDoc.collection('journal')
            .where('serverUid', isEqualTo: currentUid)
            .orderBy('ts');
      }
      _todayJournalSub = jq.snapshots().listen((qs) {
        _journalToday = qs.docs.map((d) => d.data()).toList();
        notifyListeners();
      }, onError: _onStreamError);

      _scheduleMidnightTick();
    },
  );
}



  // ---------- Utils ----------
  static String _id() => DateTime.now().microsecondsSinceEpoch.toString();

  void _onStreamError(Object e, StackTrace st) {
    errorCenter.report(
      AppError(
        userMessage: 'Problème de liaison en temps réel.',
        error: e,
        stackTrace: st,
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Ristorante Manager',
      theme: _restaurantTheme(),
      home: const _AuthGate(),
    );
  }
}

// Shows Login when signed out; shows app when signed in.
// Also reads /users/{uid} to fetch restaurantId.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snap.data;
        if (user == null) return const LoginScreen();

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, userSnap) {
            // ----- NOUVEAU BLOC -----
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (!userSnap.hasData || !userSnap.data!.exists) {
              // Doc /users/{uid} pas encore créé -> écran de setup
              return SetupProfileScreen(uid: user.uid, email: user.email);
            }

            final data = userSnap.data!.data()!;
            final restaurantId = (data['restaurantId'] as String?) ?? '';
            if (restaurantId.isEmpty) {
              // Doc présent mais sans restaurantId -> écran de setup
              return SetupProfileScreen(uid: user.uid, email: user.email);
            }

            final ec = context.read<ErrorCenter>();
            final roleStr = (data['role'] as String?) ?? 'server';
            final role = roleStr == 'manager'
                ? UserRole.manager
                : UserRole.server;

            return ChangeNotifierProvider(
              create: (_) => RestaurantState(
                errorCenter: ec,
                restaurantId: restaurantId,
                currentUid: user.uid,
                role: role,
              )..init(),
              child: const RootScreen(),
            );
          },
        );
      },
    );
  }
}

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});
  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _index = 0;

  final _pages = const [
    OrdersSinglePage(),
    DailyScreen(),
    HistoryScreen(),
    MenuAndTablesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RestaurantState>();
    if (!state.isReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isManager = state.role == UserRole.manager;

    // Manager: 4 onglets. Serveur: PAS d'historique, mais a Menu & Tables
    final pages = isManager
        ? const [
            OrdersSinglePage(),
            DailyScreen(),
            HistoryScreen(),
            MenuAndTablesScreen(),
          ]
        : const [OrdersSinglePage(), DailyScreen(), MenuAndTablesScreen()];

    final destinations = isManager
        ? const [
            NavigationDestination(
              icon: Icon(Icons.table_restaurant),
              label: 'Commandes',
            ),
            NavigationDestination(icon: Icon(Icons.today), label: 'Jour'),
            NavigationDestination(
              icon: Icon(Icons.history),
              label: 'Historique',
            ),
            NavigationDestination(
              icon: Icon(Icons.restaurant_menu),
              label: 'Menu & Tables',
            ),
          ]
        : const [
            NavigationDestination(
              icon: Icon(Icons.table_restaurant),
              label: 'Commandes',
            ),
            NavigationDestination(icon: Icon(Icons.today), label: 'Jour'),
            NavigationDestination(
              icon: Icon(Icons.restaurant_menu),
              label: 'Menu & Tables',
            ),
          ];

    if (_index >= pages.length) _index = 0;

    return Scaffold(
      appBar: FancyBrandBar(
        actions: [
          if (isManager) // 👈 le serveur ne voit pas le bouton PDF global
            IconButton(
              tooltip: 'PDF du jour',
              onPressed: () =>
                  context.read<RestaurantState>().exportDailyInvoicePdf(),
              icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            ),
          IconButton(
            tooltip: 'Se déconnecter',
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout, color: Colors.white),
          ),
        ],
      ),
      body: SafeArea(child: pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: destinations,
      ),
    );
  }
}

// ===================================================================
// PAGE 1 : Commandes (safe Cat → Sub → Dish)
// ===================================================================

class OrdersSinglePage extends StatefulWidget {
  const OrdersSinglePage({super.key});
  @override
  State<OrdersSinglePage> createState() => _OrdersSinglePageState();
}

class _OrdersSinglePageState extends State<OrdersSinglePage> {
  int _selectedTableIndex = 0;

  String? _catId;
  String? _subId;
  Dish? _dish;

  // ✅ plus de TextEditingController pour la quantité
  int qty = 1;

  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RestaurantState>();
    if (state.tables.isEmpty) {
      return const Center(
        child: Text('Aucune table — ajoute des tables dans "Menu & Tables".'),
      );
    }
    if (_selectedTableIndex >= state.tables.length) _selectedTableIndex = 0;
    final table = state.tables[_selectedTableIndex];

    // Safe selections
    final categories = state.menuTree;
    final selectedCat = categories.firstWhereOrNull((c) => c.id == _catId);
    final subcats = selectedCat?.subcategories ?? const <MenuSubcategory>[];

    final selectedSub = subcats.firstWhereOrNull((s) => s.id == _subId);
    final dishes = selectedSub?.dishes ?? const <Dish>[];

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 8,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height - kToolbarHeight,
          ),
          child: Column(
            children: [
              // ===== Entête : Sélecteur de table (gauche), Statut centré, Totaux (droite)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // LEFT: Table selector
                      Expanded(
                        flex: 4,
                        child: DropdownButtonFormField<int>(
                          value: table.tableNumber,
                          decoration: const InputDecoration(
                            labelText: 'Table',
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          items: state.tables
                              .map(
                                (t) => DropdownMenuItem(
                                  value: t.tableNumber,
                                  child: Text('Table ${t.tableNumber}'),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            final idx = state.tables.indexWhere(
                              (t) => t.tableNumber == v,
                            );
                            if (idx >= 0)
                              setState(() => _selectedTableIndex = idx);
                          },
                        ),
                      ),

                      // CENTER: Status chip
                      Expanded(
                        flex: 3,
                        child: Align(
                          alignment: Alignment.center,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  (table.items.isNotEmpty
                                          ? Colors.green
                                          : Colors.grey)
                                      .withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              table.items.isNotEmpty ? 'Ouverte' : 'Vide',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // RIGHT: Totals
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Sous-total: ${_fmt(table.total)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Total jour: ${_fmt(state.dailyTotal)}',
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // ===== Ajout d’article : Cat -> Sub -> Dish -> Qté(stepper)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildAddLineControls(
                          context,
                          categories,
                          selectedCat,
                          subcats,
                          selectedSub,
                          dishes,
                          state,
                        ),

                        const SizedBox(height: 8),

                        // Hints
                        if (categories.isEmpty)
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Aucune catégorie. Crée ton menu dans "Menu & Tables".',
                              style: TextStyle(fontStyle: FontStyle.italic),
                            ),
                          )
                        else if (selectedCat != null && subcats.isEmpty)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'La catégorie "${selectedCat.name}" est vide. Ajoute au moins une sous-catégorie.',
                              style: TextStyle(color: Colors.orange),
                            ),
                          )
                        else if (selectedSub != null && dishes.isEmpty)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'La sous-catégorie "${selectedSub.name}" ne contient aucun plat.',
                              style: TextStyle(color: Colors.orange),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ===== Liste des articles de la table
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _accent.withOpacity(0.15),
                        child: const Icon(Icons.table_restaurant),
                      ),
                      title: Text(
                        'Table ${table.tableNumber}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text('Articles: ${table.items.length}'),
                      trailing: Text(
                        _fmt(table.total),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Divider(height: 1),
                    if (table.items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: Text('Aucun article.')),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: table.items.length,
                        itemBuilder: (context, i) {
                          final it = table.items[i];
                          final isPhone =
                              MediaQuery.of(context).size.width < 600;
                          return Dismissible(
                            key: ValueKey('${it.dish.id}-$i'),
                            background: const _SwipeBg(left: true),
                            secondaryBackground: const _SwipeBg(left: false),
                            onDismissed: (_) {
                              try {
                                final removed = OrderItem(
                                  dish: it.dish,
                                  quantity: it.quantity,
                                );
                                context.read<RestaurantState>().removeItem(
                                  table.tableNumber,
                                  it.dish,
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Supprimé ${removed.dish.name}',
                                    ),
                                    action: SnackBarAction(
                                      label: 'Annuler',
                                      onPressed: () {
                                        context
                                            .read<RestaurantState>()
                                            .addDishToTable(
                                              table.tableNumber,
                                              removed.dish,
                                              quantity: removed.quantity,
                                            );
                                      },
                                    ),
                                  ),
                                );
                              } catch (_) {
                                context.showError('Suppression impossible.');
                              }
                            },
                            child: ListTile(
                              title: Text(
                                it.dish.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text('${_fmt(it.dish.price)} / unité'),
                              trailing: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: isPhone ? 160 : 220,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => context
                                          .read<RestaurantState>()
                                          .setItemQuantity(
                                            table.tableNumber,
                                            it.dish,
                                            it.quantity - 1,
                                          ),
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                      ),
                                    ),
                                    SizedBox(
                                      width: 32,
                                      child: Center(
                                        child: Text(
                                          '${it.quantity}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => context
                                          .read<RestaurantState>()
                                          .setItemQuantity(
                                            table.tableNumber,
                                            it.dish,
                                            it.quantity + 1,
                                          ),
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        _fmt(it.lineTotal),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // ===== Actions + PDF
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: table.items.isEmpty
                          ? null
                          : () => context.read<RestaurantState>().clearTable(
                              table.tableNumber,
                            ),
                      icon: const Icon(Icons.clear_all),
                      label: const Text('Vider la table'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        final added = await context
                            .read<RestaurantState>()
                            .closeTableAndAddToDaily(table.tableNumber);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Table ${table.tableNumber} fermée. +${_fmt(added)} aujourd’hui.',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.point_of_sale),
                      label: const Text('Fermer & Ajouter au jour'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: Builder(
                  builder: (context) {
                    final isManager =
                        context.read<RestaurantState>().role ==
                        UserRole.manager;
                    return FilledButton.icon(
                      onPressed: () {
                        final st = context.read<RestaurantState>();
                        if (isManager) {
                          st.exportDailyInvoicePdf();
                        } else {
                          st.exportInvoicePdfForDay(
                            st.todayKey,
                          ); // PDF perso (serveur)
                        }
                      },
                      icon: const Icon(Icons.picture_as_pdf),
                      label: Text(
                        isManager ? 'PDF du jour' : 'Mon PDF du jour',
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Ligne d’ajout (Cat/Sub/Dish + Qté stepper + Ajouter)
  Widget _buildAddLineControls(
    BuildContext context,
    List<MenuCategory> categories,
    MenuCategory? selectedCat,
    List<MenuSubcategory> subcats,
    MenuSubcategory? selectedSub,
    List<Dish> dishes,
    RestaurantState state,
  ) {
    final isPhone = MediaQuery.of(context).size.width < 600;

    final categoryField = DropdownButtonFormField<String>(
      value: _catId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Catégorie',
        prefixIcon: Icon(Icons.category),
      ),
      items: categories
          .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
          .toList(),
      onChanged: (v) {
        setState(() {
          _catId = v;
          _subId = null;
          _dish = null;
        });
      },
      validator: (v) => (v == null || v.isEmpty) ? 'Choisir' : null,
    );

    final subcategoryField = DropdownButtonFormField<String>(
      value: subcats.isEmpty ? null : _subId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Sous-catégorie',
        prefixIcon: Icon(Icons.list),
      ),
      items: subcats
          .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
          .toList(),
      onChanged: subcats.isEmpty
          ? null
          : (v) {
              setState(() {
                _subId = v;
                _dish = null;
              });
            },
      validator: (_) {
        if (selectedCat == null) return 'Choisir';
        if (subcats.isEmpty) return null;
        return (_subId == null || _subId!.isEmpty) ? 'Choisir' : null;
      },
    );

    final dishField = DropdownButtonFormField<Dish>(
      value: dishes.isEmpty ? null : _dish,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Plat',
        prefixIcon: Icon(Icons.restaurant_menu),
      ),
      items: dishes
          .map(
            (d) => DropdownMenuItem(
              value: d,
              child: Row(
                children: [
                  Expanded(child: Text(d.name)),
                  const SizedBox(width: 8),
                  Text(
                    _fmt(d.price),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      onChanged: dishes.isEmpty ? null : (d) => setState(() => _dish = d),
      validator: (_) {
        if (selectedSub == null) return null;
        if (dishes.isEmpty) return null;
        return _dish == null ? 'Choisir' : null;
      },
    );

    // ✅ Qté stepper (à la place du TextFormField)
    final qtyStepper = Row(
      children: [
        const Icon(Icons.confirmation_number_outlined),
        const SizedBox(width: 12),
        const Text('Qté', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(width: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: qty > 1 ? () => setState(() => qty--) : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '$qty',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => setState(() => qty++),
              ),
            ],
          ),
        ),
      ],
    );

    final addBtn = FilledButton.icon(
      onPressed: () {
        if (selectedCat == null) {
          context.showError('Choisis d’abord une catégorie.');
          return;
        }
        if (subcats.isEmpty) {
          context.showError(
            'La catégorie "${selectedCat.name}" n’a pas de sous-catégorie. Ajoute-en dans "Menu & Tables".',
          );
          return;
        }
        if (selectedSub == null) {
          context.showError('Choisis une sous-catégorie.');
          return;
        }
        if (dishes.isEmpty) {
          context.showError(
            'La sous-catégorie "${selectedSub.name}" n’a pas de plat. Ajoute des plats dans "Menu & Tables".',
          );
          return;
        }
        if (_dish == null) {
          context.showError('Choisis un plat.');
          return;
        }
        // plus de validation de champ quantité — c’est un entier contrôlé
        try {
          context.read<RestaurantState>().addDishToTable(
            state.tables[_selectedTableIndex].tableNumber,
            _dish!,
            quantity: qty,
          );
          setState(() => qty = 1); // reset si tu veux
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ajouté: ${_dish!.name} ×$qty')),
          );
        } catch (_) {
          context.showError('Impossible d’ajouter l’article.');
        }
      },
      icon: const Icon(Icons.add),
      label: const Text('Ajouter'),
    );

    // Layout responsive
    if (isPhone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          categoryField,
          const SizedBox(height: 8),
          subcategoryField,
          const SizedBox(height: 8),
          dishField,
          const SizedBox(height: 8),
          qtyStepper,
          const SizedBox(height: 8),
          addBtn,
        ],
      );
    } else {
      return Row(
        children: [
          Expanded(flex: 3, child: categoryField),
          const SizedBox(width: 8),
          Expanded(flex: 3, child: subcategoryField),
          const SizedBox(width: 8),
          Expanded(flex: 4, child: dishField),
          const SizedBox(width: 8),
          // stepper prend une largeur fixe lisible
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 160),
            child: qtyStepper,
          ),
          const SizedBox(width: 8),
          addBtn,
        ],
      );
    }
  }
}

// Swipe bg
class _SwipeBg extends StatelessWidget {
  final bool left;
  const _SwipeBg({required this.left});
  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: left ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.delete_outline),
    );
  }
}

// ===================================================================
// PAGE 2 : Jour
// ===================================================================

class DailyScreen extends StatelessWidget {
  const DailyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RestaurantState>();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Résumé
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _accent.withOpacity(0.15),
                child: const Icon(Icons.today),
              ),
              title: const Text(
                'Résumé du jour',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                'Tables ouvertes: ${state.tables.where((t) => t.items.isNotEmpty).length}',
              ),
              trailing: Text(
                _fmt(state.dailyTotal),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Actions (responsive)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Ton UI responsive inchangée
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isPhone = constraints.maxWidth < 480;

                      final resetBtn = OutlinedButton.icon(
                        style: isPhone
                            ? OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                              )
                            : null,
                        onPressed:
                            state.dailyTotal == 0 && state.journalToday.isEmpty
                            ? null
                            : () async {
                                await state.resetDailyTotal(keepHistory: true);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).clearSnackBars();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Journal vidé. Total du jour conservé.',
                                    ),
                                  ),
                                );
                              },

                        icon: const Icon(Icons.refresh),
                        // tu peux garder le label d’origine si tu veux
                        label: const Text('Reset jour'),
                      );

                      final closeAllBtn = FilledButton.icon(
                        style: isPhone
                            ? FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                              )
                            : null,
                        onPressed: () {
                          state.closeAllOpenTablesToDaily();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Toutes les tables ajoutées au jour.',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.point_of_sale),
                        label: const Text('Fermer toutes les tables'),
                      );

                      final isManager =
                          context.read<RestaurantState>().role ==
                          UserRole.manager;
                      final pdfBtn = isManager
                          ? FilledButton.icon(
                              onPressed: () => context
                                  .read<RestaurantState>()
                                  .exportDailyInvoicePdf(),
                              icon: const Icon(Icons.picture_as_pdf),
                              label: const Text('PDF du jour'),
                            )
                          : const SizedBox.shrink(); // 👈 serveur: pas de bouton

                      if (isPhone) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            resetBtn,
                            const SizedBox(height: 10),
                            closeAllBtn,
                            const SizedBox(height: 10),
                            pdfBtn,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: resetBtn),
                          const SizedBox(width: 12),
                          Expanded(child: closeAllBtn),
                          const SizedBox(width: 12),
                          pdfBtn,
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Journal
          Expanded(
            child: Card(
              child: state.journalToday.isEmpty
                  ? const Center(child: Text('Aucun mouvement aujourd\'hui.'))
                  : ListView.separated(
                      itemCount: state.journalToday.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final e = state.journalToday[i];
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 14,
                            child: Text('${e['table']}'),
                          ),
                          title: Text('${e['name']} ×${e['qty']}'),
                          subtitle: Text(
                            '${_fmt((e['price'] as num).toDouble())} / unité',
                          ),
                          trailing: Text(
                            _fmt((e['total'] as num).toDouble()),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===================================================================
// PAGE 3 : Historique
// ===================================================================

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _rangeDays = 30;
  @override
  Widget build(BuildContext context) {
    final state = context.watch<RestaurantState>();
    final entries = state.historySortedDesc();
    // debug
    debugPrint(
      'HISTORY entries: ${entries.length} -> ${entries.map((e) => '${e.key}:${e.value}').toList()}',
    );

    final fmtLabel = DateFormat('EEE, dd MMM', 'fr_FR');

    final last7 = state.sumLastDays(7);
    final last30 = state.sumLastDays(30);
    final last90 = state.sumLastDays(90);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  const ListTile(
                    leading: Icon(Icons.analytics_outlined),
                    title: Text(
                      'Historique (3 mois)',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text('7 j • ${_fmt(last7)}'),
                        selected: _rangeDays == 7,
                        onSelected: (_) => setState(() => _rangeDays = 7),
                      ),
                      ChoiceChip(
                        label: Text('30 j • ${_fmt(last30)}'),
                        selected: _rangeDays == 30,
                        onSelected: (_) => setState(() => _rangeDays = 30),
                      ),
                      ChoiceChip(
                        label: Text('90 j • ${_fmt(last90)}'),
                        selected: _rangeDays == 90,
                        onSelected: (_) => setState(() => _rangeDays = 90),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Card(
              child: Builder(
                builder: (context) {
                  final entries = state.historySortedDesc();
                  if (entries.isEmpty) {
                    return const Center(
                      child: Text('Pas encore d\'historique.'),
                    );
                  }

                  final now = DateTime.now();
                  final start = DateTime(
                    now.year,
                    now.month,
                    now.day,
                  ).subtract(Duration(days: _rangeDays - 1));

                  final filtered = entries.where((e) {
                    final d = DateTime.parse(e.key); // ids "yyyy-MM-dd"
                    return !d.isBefore(start);
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        'Aucun jour dans la période sélectionnée ($_rangeDays j).',
                      ),
                    );
                  }

                  final fmtLabel = DateFormat('EEE, dd MMM', 'fr_FR');

                  return ListView(
                    children: filtered.map((e) {
                      final d = DateTime.parse(e.key);
                      return ListTile(
                        leading: const Icon(Icons.calendar_today_outlined),
                        title: Text(fmtLabel.format(d)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _fmt(e.value),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'PDF du ${fmtLabel.format(d)}',
                              onPressed: () => context
                                  .read<RestaurantState>()
                                  .exportInvoicePdfForDay(e.key),
                              icon: const Icon(Icons.picture_as_pdf),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===================================================================
// PAGE 4 : Menu & Tables
// ===================================================================

class MenuAndTablesScreen extends StatefulWidget {
  const MenuAndTablesScreen({super.key});
  @override
  State<MenuAndTablesScreen> createState() => _MenuAndTablesScreenState();
}

class _MenuAndTablesScreenState extends State<MenuAndTablesScreen> {
  final _tablesCtl = TextEditingController();

  @override
  void dispose() {
    _tablesCtl.dispose();
    super.dispose();
  }

  bool _tablesInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_tablesInit) {
      final state = context.read<RestaurantState>();
      _tablesCtl.text = state.tableCount.toString();
      _tablesInit = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RestaurantState>();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Number of tables (manual input)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Builder(
                builder: (context) {
                  final isPhone = MediaQuery.of(context).size.width < 480;
                  final state = context.watch<RestaurantState>();

                  Future<void> apply(String value) async {
                    final n = int.tryParse(value.trim());
                    if (n == null || n <= 0) {
                      context.showError('Nombre invalide.');
                      _tablesCtl.text = state.tableCount.toString();
                      return;
                    }
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Changer le nombre de tables ?'),
                        content: const Text(
                          'Cela réinitialise les commandes ouvertes. Continuer ?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Annuler'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Oui'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) {
                      try {
                        await context.read<RestaurantState>().setTableCount(n);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Nombre de tables réglé à $n.'),
                          ),
                        );
                      } catch (_) {
                        context.showError(
                          'Impossible de modifier le nombre de tables.',
                        );
                      }
                    } else {
                      _tablesCtl.text = state.tableCount.toString();
                    }
                  }

                  if (isPhone) {
                    // ----- Téléphone : tout en colonne + bouton "Appliquer" plein largeur
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.table_bar),
                            SizedBox(width: 8),
                            Text(
                              'Nombre de tables:',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _tablesCtl,
                          keyboardType: const TextInputType.numberWithOptions(
                            signed: false,
                            decimal: false,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(hintText: 'ex: 12'),
                          onSubmitted: apply,
                        ),

                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => apply(
                              _tablesCtl.text,
                            ), // bouton explicite pour mobile
                            icon: const Icon(Icons.check),
                            label: const Text('Appliquer'),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('Actuel: ${state.tableCount}'),
                      ],
                    );
                  }

                  // ----- Tablette / Desktop : en ligne + icône "check" dans le champ
                  return Row(
                    children: [
                      const Icon(Icons.table_bar),
                      const SizedBox(width: 12),
                      const Text(
                        'Nombre de tables:',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 140,
                        child: TextField(
                          controller: _tablesCtl,
                          keyboardType: const TextInputType.numberWithOptions(
                            signed: false,
                            decimal: false,
                          ),
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            hintText: 'ex: 12',
                            suffixIcon: IconButton(
                              tooltip: 'Appliquer',
                              icon: const Icon(Icons.check),
                              onPressed: () => apply(
                                _tablesCtl.text,
                              ), // clic souris / tactile
                            ),
                          ),
                          onSubmitted: apply, // Enter clavier
                        ),
                      ),
                      const Spacer(),
                      Text('Actuel: ${state.tableCount}'),
                    ],
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Menu tree
          Expanded(
            child: Card(
              child: Column(
                children: const [
                  ListTile(
                    leading: Icon(Icons.restaurant_menu),
                    title: Text(
                      'Menu (Catégories → Sous-catégories → Plats)',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text('Ajoute/édite/supprime librement.'),
                  ),
                  Divider(height: 1),
                  Expanded(child: _MenuTreeView()),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _showAddCategoryDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter une catégorie'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final restId = context.read<RestaurantState>().restaurantId;
                    try {
                      await seedRestaurant(restId);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Menu importé dans Firestore.'),
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      context.showError('Échec d’import du menu.');
                    }
                  },
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: const Text('Importer le menu'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showAddCategoryDialog(BuildContext context) async {
    final ctl = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nouvelle catégorie'),
        content: TextField(
          controller: ctl,
          decoration: const InputDecoration(labelText: 'Nom'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              final name = ctl.text.trim();
              if (name.isEmpty) return;
              try {
                await context.read<RestaurantState>().addCategory(name);
                if (context.mounted) Navigator.pop(context);
              } catch (_) {
                context.showError('Impossible d’ajouter la catégorie.');
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }
}

class _MenuTreeView extends StatelessWidget {
  const _MenuTreeView();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RestaurantState>();
    final tree = state.menuTree;
    if (tree.isEmpty) {
      return const Center(child: Text('Aucune catégorie. Ajoute-en une.'));
    }
    return ListView.builder(
      itemCount: tree.length,
      itemBuilder: (context, i) {
        final cat = tree[i];
        return ExpansionTile(
          leading: const Icon(Icons.category),
          title: Text(
            cat.name,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          trailing: _CatActions(cat: cat),
          children: [
            if (cat.subcategories.isEmpty)
              const ListTile(title: Text('Aucune sous-catégorie.')),
            ...cat.subcategories.map((sub) {
              return Padding(
                padding: const EdgeInsets.only(left: 16),
                child: ExpansionTile(
                  leading: const Icon(Icons.list),
                  title: Text(sub.name),
                  trailing: _SubActions(cat: cat, sub: sub),
                  children: [
                    if (sub.dishes.isEmpty)
                      const ListTile(title: Text('Aucun plat.')),
                    ...sub.dishes.map(
                      (d) => ListTile(
                        leading: const Icon(Icons.local_dining),
                        title: Text(d.name),
                        subtitle: Text(_fmt(d.price)),
                        trailing: _DishActions(cat: cat, sub: sub, dish: d),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _showAddDishDialog(context, cat.id, sub.id),
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter un plat'),
                      ),
                    ),
                  ],
                ),
              );
            }),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: OutlinedButton.icon(
                onPressed: () => _showAddSubDialog(context, cat.id),
                icon: const Icon(Icons.add),
                label: const Text('Ajouter une sous-catégorie'),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAddSubDialog(BuildContext context, String catId) async {
    final ctl = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nouvelle sous-catégorie'),
        content: TextField(
          controller: ctl,
          decoration: const InputDecoration(labelText: 'Nom'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              final name = ctl.text.trim();
              if (name.isEmpty) return;
              try {
                await context.read<RestaurantState>().addSubcategory(
                  catId,
                  name,
                );
                if (context.mounted) Navigator.pop(context);
              } catch (_) {
                context.showError('Impossible d’ajouter la sous-catégorie.');
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddDishDialog(
    BuildContext context,
    String catId,
    String subId,
  ) async {
    final nameCtl = TextEditingController();
    final priceCtl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nouveau plat'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtl,
                decoration: const InputDecoration(labelText: 'Nom'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: priceCtl,
                decoration: const InputDecoration(labelText: 'Prix'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                validator: (v) {
                  final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                  if (n == null || n < 0) return 'Prix invalide';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final name = nameCtl.text.trim();
              final price = double.parse(priceCtl.text.replaceAll(',', '.'));
              try {
                await context.read<RestaurantState>().addDish(
                  catId,
                  subId,
                  name,
                  price,
                );
                if (context.mounted) Navigator.pop(context);
              } catch (_) {
                context.showError('Impossible d’ajouter le plat.');
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }
}

class _CatActions extends StatelessWidget {
  final MenuCategory cat;
  const _CatActions({required this.cat});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Renommer',
          icon: const Icon(Icons.edit),
          onPressed: () async {
            final ctl = TextEditingController(text: cat.name);
            await showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Renommer la catégorie'),
                content: TextField(
                  controller: ctl,
                  decoration: const InputDecoration(labelText: 'Nom'),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      final name = ctl.text.trim();
                      if (name.isEmpty) return;
                      try {
                        await context.read<RestaurantState>().renameCategory(
                          cat.id,
                          name,
                        );
                        if (context.mounted) Navigator.pop(context);
                      } catch (_) {
                        context.showError(
                          'Impossible de renommer la catégorie.',
                        );
                      }
                    },
                    child: const Text('Enregistrer'),
                  ),
                ],
              ),
            );
          },
        ),
        IconButton(
          tooltip: 'Supprimer',
          icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Supprimer la catégorie ?'),
                content: const Text(
                  'Toutes ses sous-catégories et plats seront supprimés.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Annuler'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Supprimer'),
                  ),
                ],
              ),
            );
            if (ok == true) {
              try {
                await context.read<RestaurantState>().removeCategory(cat.id);
              } catch (_) {
                context.showError('Impossible de supprimer la catégorie.');
              }
            }
          },
        ),
      ],
    );
  }
}

class _SubActions extends StatelessWidget {
  final MenuCategory cat;
  final MenuSubcategory sub;
  const _SubActions({required this.cat, required this.sub});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Renommer',
          icon: const Icon(Icons.edit),
          onPressed: () async {
            final ctl = TextEditingController(text: sub.name);
            await showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Renommer la sous-catégorie'),
                content: TextField(
                  controller: ctl,
                  decoration: const InputDecoration(labelText: 'Nom'),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      final name = ctl.text.trim();
                      if (name.isEmpty) return;
                      try {
                        await context.read<RestaurantState>().renameSubcategory(
                          cat.id,
                          sub.id,
                          name,
                        );
                        if (context.mounted) Navigator.pop(context);
                      } catch (_) {
                        context.showError(
                          'Impossible de renommer la sous-catégorie.',
                        );
                      }
                    },
                    child: const Text('Enregistrer'),
                  ),
                ],
              ),
            );
          },
        ),
        IconButton(
          tooltip: 'Supprimer',
          icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Supprimer la sous-catégorie ?'),
                content: const Text(
                  'Tous les plats qu’elle contient seront supprimés.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Annuler'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Supprimer'),
                  ),
                ],
              ),
            );
            if (ok == true) {
              try {
                await context.read<RestaurantState>().removeSubcategory(
                  cat.id,
                  sub.id,
                );
              } catch (_) {
                context.showError('Impossible de supprimer la sous-catégorie.');
              }
            }
          },
        ),
      ],
    );
  }
}

class _DishActions extends StatelessWidget {
  final MenuCategory cat;
  final MenuSubcategory sub;
  final Dish dish;
  const _DishActions({
    required this.cat,
    required this.sub,
    required this.dish,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Éditer',
          icon: const Icon(Icons.edit),
          onPressed: () async {
            final nameCtl = TextEditingController(text: dish.name);
            final priceCtl = TextEditingController(
              text: dish.price.toStringAsFixed(2),
            );
            final formKey = GlobalKey<FormState>();
            await showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Modifier le plat'),
                content: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameCtl,
                        decoration: const InputDecoration(labelText: 'Nom'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Nom requis'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: priceCtl,
                        decoration: const InputDecoration(labelText: 'Prix'),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) {
                          final n = double.tryParse(
                            (v ?? '').replaceAll(',', '.'),
                          );
                          if (n == null || n < 0) return 'Prix invalide';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      final name = nameCtl.text.trim();
                      final price = double.parse(
                        priceCtl.text.replaceAll(',', '.'),
                      );
                      try {
                        await context.read<RestaurantState>().editDish(
                          cat.id,
                          sub.id,
                          dish.id,
                          name,
                          price,
                        );
                        if (context.mounted) Navigator.pop(context);
                      } catch (_) {
                        context.showError('Impossible de modifier le plat.');
                      }
                    },
                    child: const Text('Enregistrer'),
                  ),
                ],
              ),
            );
          },
        ),
        IconButton(
          tooltip: 'Supprimer',
          icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Supprimer ce plat ?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Annuler'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Supprimer'),
                  ),
                ],
              ),
            );
            if (ok == true) {
              try {
                await context.read<RestaurantState>().removeDish(
                  cat.id,
                  sub.id,
                  dish.id,
                );
              } catch (_) {
                context.showError('Impossible de supprimer le plat.');
              }
            }
          },
        ),
      ],
    );
  }
}

// ===================================================================
// HELPERS
// ===================================================================
final NumberFormat _eurFmt = NumberFormat.currency(
  locale: 'fr_FR',
  symbol: '€',
);

String _fmt(num v, {String symbol = '€'}) => _eurFmt.format(v);

// Safe lookup extension: avoids exceptions when lists are empty
extension FirstWhereNullExt<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E e) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}

int _toInt(dynamic v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}
