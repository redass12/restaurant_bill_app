import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

// PDF
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart' as pdf;
import 'package:printing/printing.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter(); // Web = IndexedDB, mobile/desktop = files
  await initializeDateFormatting('fr_FR');
  runApp(
    ChangeNotifierProvider(
      create: (_) => RestaurantState()..init(),
      child: const MyApp(),
    ),
  );
}

// ----- THEME -----

const _seed = Color(0xFF8B5E3C); // warm brown
const _accent = Color(0xFFD86B4A); // terracotta accent
const _brandName = 'Ristorante';   // shown on the PDF header

ThemeData _restaurantTheme() {
  final base = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.light),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

// ----- DATA MODELS -----

class Dish {
  final String id;
  final String name;
  final double price;

  const Dish({required this.id, required this.name, required this.price});

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'price': price};
  factory Dish.fromMap(Map m) => Dish(
        id: '${m['id']}',
        name: '${m['name']}',
        price: (m['price'] is num) ? (m['price'] as num).toDouble() : double.tryParse('${m['price']}') ?? 0.0,
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

  double get total => items.fold(0.0, (sum, item) => sum + item.lineTotal);

  void clear() => items.clear();
}

// ----- APP STATE + HIVE PERSISTENCE + JOURNAL -----

class RestaurantState extends ChangeNotifier {
  // Editable menu (loaded from Hive or defaults)
  List<Dish> _menu = const [
    Dish(id: '1', name: 'Margherita Pizza', price: 9.50),
    Dish(id: '2', name: 'Pasta Alfredo', price: 12.00),
    Dish(id: '3', name: 'Caesar Salad', price: 7.00),
    Dish(id: '4', name: 'Grilled Salmon', price: 18.50),
    Dish(id: '5', name: 'Tiramisu', price: 5.50),
    Dish(id: '6', name: 'Espresso', price: 2.50),
  ];
  List<Dish> get menu => List.unmodifiable(_menu);

  final int tableCount = 8;
  late final List<TableOrder> tables =
      List.generate(tableCount, (i) => TableOrder(tableNumber: i + 1));

  // Daily total
  double _dailyTotal = 0.0;
  double get dailyTotal => _dailyTotal;

  // History per day: 'yyyy-MM-dd' -> total
  final Map<String, double> _historyTotals = {};
  Map<String, double> get historyTotals => Map.unmodifiable(_historyTotals);

  // Journal of today: list of sold lines (table, dish, qty, price, total)
  List<Map<String, dynamic>> _journalToday = [];
  List<Map<String, dynamic>> get journalToday => List.unmodifiable(_journalToday);

  static const _maxDays = 90;

  // Hive
  static const _boxName = 'rb_history_v1';
  static const _historyKey = 'historyTotals';
  static const _menuKey = 'menu';
  static String _journalKey(String day) => 'journal_$day';
  late Box _box;

  bool _ready = false;
  bool get isReady => _ready;

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);

    // Menu
    final rawMenu = _box.get(_menuKey);
    if (rawMenu is List) {
      _menu = rawMenu.map((e) => Dish.fromMap(Map<String, dynamic>.from(e))).toList();
    } else {
      await _box.put(_menuKey, _menu.map((d) => d.toMap()).toList());
    }

    // History totals
    final raw = _box.get(_historyKey);
    if (raw is Map) {
      raw.forEach((k, v) {
        if (k is String) {
          final numVal = (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0.0;
          _historyTotals[k] = numVal;
        }
      });
    }

    final today = _todayKey();
    _dailyTotal = _historyTotals[today] ?? 0.0;

    // Journal today
    final journalRaw = _box.get(_journalKey(today));
    if (journalRaw is List) {
      _journalToday = journalRaw.map((e) => Map<String, dynamic>.from(e)).toList();
    }

    _pruneOld(daysToKeep: _maxDays);
    await _saveAll();

    _ready = true;
    notifyListeners();
  }

  // ----- MENU CRUD -----

  Future<void> addMenuItem(String name, double price) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    _menu = [..._menu, Dish(id: id, name: name.trim(), price: price)];
    await _box.put(_menuKey, _menu.map((d) => d.toMap()).toList());
    notifyListeners();
  }

  Future<void> updateMenuItem(String id, {required String name, required double price}) async {
    _menu = _menu.map((d) => d.id == id ? Dish(id: id, name: name.trim(), price: price) : d).toList();
    await _box.put(_menuKey, _menu.map((d) => d.toMap()).toList());
    notifyListeners();
  }

  Future<void> removeMenuItem(String id) async {
    _menu = _menu.where((d) => d.id != id).toList();
    await _box.put(_menuKey, _menu.map((d) => d.toMap()).toList());
    notifyListeners();
  }

  // ----- TABLE OPS -----

  void addDishToTable(int tableNumber, Dish dish, {int quantity = 1}) {
    final table = tables.firstWhere((t) => t.tableNumber == tableNumber);
    final existing = table.items.where((it) => it.dish.id == dish.id).toList();
    if (existing.isNotEmpty) {
      existing.first.quantity += quantity;
    } else {
      table.items.add(OrderItem(dish: dish, quantity: quantity));
    }
    notifyListeners();
  }

  void setItemQuantity(int tableNumber, Dish dish, int quantity) {
    final table = tables.firstWhere((t) => t.tableNumber == tableNumber);
    final idx = table.items.indexWhere((it) => it.dish.id == dish.id);
    if (idx >= 0) {
      if (quantity <= 0) {
        table.items.removeAt(idx);
      } else {
        table.items[idx].quantity = quantity;
      }
      notifyListeners();
    }
  }

  void removeItem(int tableNumber, Dish dish) {
    final table = tables.firstWhere((t) => t.tableNumber == tableNumber);
    table.items.removeWhere((it) => it.dish.id == dish.id);
    notifyListeners();
  }

  void clearTable(int tableNumber) {
    final table = tables.firstWhere((t) => t.tableNumber == tableNumber);
    table.clear();
    notifyListeners();
  }

  // Close a table: add subtotal to daily total AND journalize each line
  double closeTableAndAddToDaily(int tableNumber) {
    _ensureToday();
    final table = tables.firstWhere((t) => t.tableNumber == tableNumber);

    for (final it in table.items) {
      _journalToday.add({
        'table': tableNumber,
        'dishId': it.dish.id,
        'name': it.dish.name,
        'price': it.dish.price,
        'qty': it.quantity,
        'total': it.lineTotal,
      });
    }

    final amount = table.total;
    _dailyTotal += amount;
    table.clear();

    _syncDailyIntoHistoryAndSave();
    return amount;
  }

  void resetDailyTotal() {
    _ensureToday();
    _dailyTotal = 0.0;
    _journalToday.clear();
    _syncDailyIntoHistoryAndSave();
  }

  void closeAllOpenTablesToDaily() {
    _ensureToday();
    for (final t in tables) {
      for (final it in t.items) {
        _journalToday.add({
          'table': t.tableNumber,
          'dishId': it.dish.id,
          'name': it.dish.name,
          'price': it.dish.price,
          'qty': it.quantity,
          'total': it.lineTotal,
        });
      }
      _dailyTotal += t.total;
      t.clear();
    }
    _syncDailyIntoHistoryAndSave();
  }

  // ----- HISTORY / SAVE -----

  String _todayKey() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  void _ensureToday() {
    final today = _todayKey();
    if (!_historyTotals.containsKey(today)) {
      _dailyTotal = 0.0;
      _historyTotals[today] = 0.0;
      _journalToday = [];
      _pruneOld(daysToKeep: _maxDays);
    } else {
      _dailyTotal = _historyTotals[today]!;
      final jr = _box.get(_journalKey(today));
      _journalToday = (jr is List) ? jr.map((e) => Map<String, dynamic>.from(e)).toList() : _journalToday;
    }
  }

  Future<void> _saveAll() async {
    await _box.put(_historyKey, _historyTotals);
    await _box.put(_menuKey, _menu.map((d) => d.toMap()).toList());
    await _box.put(_journalKey(_todayKey()), _journalToday);
  }

  void _syncDailyIntoHistoryAndSave() {
    final today = _todayKey();
    _historyTotals[today] = _dailyTotal;
    _pruneOld(daysToKeep: _maxDays);
    _saveAll();
    notifyListeners();
  }

  void _pruneOld({required int daysToKeep}) {
    final keys = _historyTotals.keys.toList()..sort((a, b) => b.compareTo(a));
    if (keys.length <= daysToKeep) return;
    final toRemove = keys.sublist(daysToKeep);
    for (final k in toRemove) {
      _historyTotals.remove(k);
      _box.delete(_journalKey(k)); // also remove old journals
    }
  }

  // Aggregates
  double sumLastDays(int days) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));
    double sum = 0.0;
    _historyTotals.forEach((k, v) {
      final d = DateTime.parse(k);
      if (!d.isBefore(start)) sum += v;
    });
    return sum;
  }

  List<MapEntry<String, double>> historySortedDesc() {
    final entries = _historyTotals.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
    return entries;
  }

  // ----- PDF: DAILY INVOICE -----

  Future<void> exportDailyInvoicePdf() async {
    final doc = pw.Document(); // avoid name clash with import alias
    final now = DateTime.now();
    final dayKey = _todayKey();
    final dateLabel = DateFormat('EEEE d MMMM y', 'fr_FR').format(now);

    // rows for the table
    final rows = _journalToday.map((e) {
      final t = e['table'];
      final nm = e['name'];
      final q = e['qty'];
      final p = (e['price'] as num).toDouble();
      final tot = (e['total'] as num).toDouble();
      return ['$t', nm, '$q', _fmt(p), _fmt(tot)];
    }).toList();

    final totalJour = _dailyTotal;

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
                    pw.Text(_brandName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Facture du jour — $dateLabel', style: const pw.TextStyle(fontSize: 12)),
                  ],
                ),
                pw.Text('Total: ${_fmt(totalJour)}',
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
          if (rows.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 40),
              child: pw.Text('Aucune vente enregistrée aujourd\'hui.',
                  style: const pw.TextStyle(fontSize: 14)),
            )
          else
            pw.Table.fromTextArray(
              headers: ['Table', 'Article', 'Qté', 'Prix', 'Total'],
              data: rows,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: pw.BoxDecoration(color: pdf.PdfColors.grey300),
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: const pw.TextStyle(fontSize: 11),
              columnWidths: {
                0: const pw.FixedColumnWidth(50),
                1: const pw.FlexColumnWidth(),
                2: const pw.FixedColumnWidth(40),
                3: const pw.FixedColumnWidth(60),
                4: const pw.FixedColumnWidth(70),
              },
            ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: pdf.PdfColor.fromInt(0xFFCCCCCC)),
                ),
                child: pw.Text(
                  'TOTAL JOUR: ${_fmt(totalJour)}',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Text('Référence: $dayKey • Généré via ${_brandName}'),
        ],
      ),
    );

    final bytes = await doc.save();
    await Printing.sharePdf(bytes: bytes, filename: 'Facture_$dayKey.pdf');
  }
}

// ----- UI -----

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Restaurant Billing',
      theme: _restaurantTheme(),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.watch<RestaurantState>();
    if (state.isReady && _tabController == null) {
      // tables + Daily + History + Menu
      _tabController = TabController(length: state.tableCount + 3, vsync: this);
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RestaurantState>();
    if (!state.isReady || _tabController == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final tabs = [
      ...state.tables.map(
        (t) => Tab(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.table_bar, size: 18),
              const SizedBox(width: 6),
              Text('Table ${t.tableNumber}'),
            ],
          ),
        ),
      ),
      const Tab(icon: Icon(Icons.today), text: 'Daily'),
      const Tab(icon: Icon(Icons.history), text: 'History'),
      const Tab(icon: Icon(Icons.restaurant_menu), text: 'Menu'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ristorante Manager'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_seed, _accent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: tabs,
          labelPadding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        actions: [
          IconButton(
            tooltip: 'Tout fermer vers le total du jour',
            onPressed: () {
              final before = state.dailyTotal;
              state.closeAllOpenTablesToDaily();
              final diff = state.dailyTotal - before;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Tables fermées. +${_fmt(diff)} sur le jour.')),
              );
            },
            icon: const Icon(Icons.playlist_add_check_circle_outlined),
          ),
          IconButton(
            tooltip: 'Générer PDF (facture du jour)',
            onPressed: () async {
              await context.read<RestaurantState>().exportDailyInvoicePdf();
            },
            icon: const Icon(Icons.picture_as_pdf),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ...state.tables.map((t) => TableScreen(tableOrder: t)),
          const DailyScreen(),
          const HistoryScreen(),
          const MenuScreen(),
        ],
      ),
    );
  }
}

class TableScreen extends StatefulWidget {
  final TableOrder tableOrder;
  const TableScreen({super.key, required this.tableOrder});

  @override
  State<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends State<TableScreen> {
  Dish? _selectedDish;
  final _qtyController = TextEditingController(text: '1');
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RestaurantState>();
    final table = widget.tableOrder;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _AddItemCard(
            formKey: _formKey,
            menu: state.menu,
            selectedDish: _selectedDish,
            onDishChanged: (d) => setState(() => _selectedDish = d),
            qtyController: _qtyController,
            onAdd: () {
              if (!_formKey.currentState!.validate()) return;
              final qty = int.tryParse(_qtyController.text.trim()) ?? 1;
              if (_selectedDish == null) return;

              state.addDishToTable(table.tableNumber, _selectedDish!, quantity: qty);
              setState(() {
                _selectedDish = null;
                _qtyController.text = '1';
              });
            },
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
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
                      'Sous-total: ${_fmt(table.total)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: table.items.isEmpty
                        ? const Center(
                            child: Text('Aucun article. Ajoute depuis le menu ci-dessus.'),
                          )
                        : ListView.builder(
                            itemCount: table.items.length,
                            itemBuilder: (context, index) {
                              final item = table.items[index];
                              return Dismissible(
                                key: ValueKey('${item.dish.id}-$index'),
                                background: const _SwipeBg(left: true),
                                secondaryBackground: const _SwipeBg(left: false),
                                onDismissed: (_) {
                                  context
                                      .read<RestaurantState>()
                                      .removeItem(table.tableNumber, item.dish);
                                },
                                child: ListTile(
                                  title: Text(
                                    item.dish.name,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Text('${_fmt(item.dish.price)} / unité'),
                                  trailing: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 220),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        IconButton(
                                          tooltip: 'Moins',
                                          onPressed: () {
                                            final q = item.quantity - 1;
                                            context
                                                .read<RestaurantState>()
                                                .setItemQuantity(table.tableNumber, item.dish, q);
                                          },
                                          icon: const Icon(Icons.remove_circle_outline),
                                        ),
                                        SizedBox(
                                          width: 36,
                                          child: Center(
                                            child: Text(
                                              '${item.quantity}',
                                              style: const TextStyle(fontWeight: FontWeight.w700),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Plus',
                                          onPressed: () {
                                            final q = item.quantity + 1;
                                            context
                                                .read<RestaurantState>()
                                                .setItemQuantity(table.tableNumber, item.dish, q);
                                          },
                                          icon: const Icon(Icons.add_circle_outline),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(_fmt(item.lineTotal)),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: table.items.isEmpty
                      ? null
                      : () => context.read<RestaurantState>().clearTable(table.tableNumber),
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Vider la table'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: table.items.isEmpty
                      ? null
                      : () {
                          final added = context
                              .read<RestaurantState>()
                              .closeTableAndAddToDaily(table.tableNumber);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Table ${table.tableNumber} fermée. +${_fmt(added)} aujourd\'hui.',
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
        ],
      ),
    );
  }
}

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

class _AddItemCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final List<Dish> menu;
  final Dish? selectedDish;
  final void Function(Dish?) onDishChanged;
  final TextEditingController qtyController;
  final VoidCallback onAdd;

  const _AddItemCard({
    required this.formKey,
    required this.menu,
    required this.selectedDish,
    required this.onDishChanged,
    required this.qtyController,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Form(
          key: formKey,
          child: Row(
            children: [
              Expanded(
                flex: 6,
                child: DropdownButtonFormField<Dish>(
                  value: selectedDish,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Sélectionne un plat',
                    prefixIcon: Icon(Icons.restaurant_menu),
                  ),
                  items: menu
                      .map(
                        (d) => DropdownMenuItem(
                          value: d,
                          child: Row(
                            children: [
                              const Icon(Icons.local_dining, size: 18),
                              const SizedBox(width: 8),
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
                  onChanged: onDishChanged,
                  validator: (v) => v == null ? 'Choisis un plat' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: qtyController,
                  decoration: const InputDecoration(
                    labelText: 'Qté',
                    prefixIcon: Icon(Icons.confirmation_number_outlined),
                  ),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n <= 0) return '1+';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DailyScreen extends StatelessWidget {
  const DailyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RestaurantState>();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
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
              subtitle:
                  Text('Tables ouvertes: ${state.tables.where((t) => t.items.isNotEmpty).length}'),
              trailing: Text(
                _fmt(state.dailyTotal),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: state.dailyTotal == 0 && state.journalToday.isEmpty
                          ? null
                          : () {
                              state.resetDailyTotal();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Total et journal du jour réinitialisés.')),
                              );
                            },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset jour'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        state.closeAllOpenTablesToDaily();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Toutes les tables ajoutées au jour.')),
                        );
                      },
                      icon: const Icon(Icons.point_of_sale),
                      label: const Text('Fermer toutes les tables'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
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
                          title: Text('${e['name']}  ×${e['qty']}'),
                          subtitle: Text('${_fmt((e['price'] as num).toDouble())} / unité'),
                          trailing: Text(
                            _fmt((e['total'] as num).toDouble()),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.read<RestaurantState>().exportDailyInvoicePdf(),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Générer PDF — facture du jour'),
            ),
          ),
        ],
      ),
    );
  }
}

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
    final fmtLabel = DateFormat('EEE, dd MMM', 'fr_FR');

    final last7 = state.sumLastDays(7);
    final last30 = state.sumLastDays(30);
    final last90 = state.sumLastDays(90);

    return Padding(
      padding: const EdgeInsets.all(16.0),
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
              child: entries.isEmpty
                  ? const Center(
                      child: Text('Pas encore d\'historique.'),
                    )
                  : ListView(
                      children: entries
                          .where((e) {
                            final now = DateTime.now();
                            final start = DateTime(now.year, now.month, now.day)
                                .subtract(Duration(days: _rangeDays - 1));
                            final d = DateTime.parse(e.key);
                            return !d.isBefore(start);
                          })
                          .map((e) {
                            final d = DateTime.parse(e.key);
                            return ListTile(
                              leading: const Icon(Icons.calendar_today_outlined),
                              title: Text(fmtLabel.format(d)),
                              trailing: Text(
                                _fmt(e.value),
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            );
                          })
                          .toList(),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ----- MENU SCREEN (CRUD) -----

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});
  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<RestaurantState>();
    final items = state.menu;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const ListTile(
            leading: Icon(Icons.restaurant_menu),
            title: Text('Menu du restaurant', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('Ajoute, modifie ou supprime des plats'),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Card(
              child: items.isEmpty
                  ? const Center(child: Text('Menu vide. Ajoute un plat.'))
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final d = items[i];
                        return ListTile(
                          title: Text(d.name),
                          subtitle: Text(_fmt(d.price)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Éditer',
                                icon: const Icon(Icons.edit),
                                onPressed: () => _showDishDialog(context, edit: d),
                              ),
                              IconButton(
                                tooltip: 'Supprimer',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () async {
                                  await context.read<RestaurantState>().removeMenuItem(d.id);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _showDishDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un plat'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDishDialog(BuildContext context, {Dish? edit}) async {
    final nameCtl = TextEditingController(text: edit?.name ?? '');
    final priceCtl = TextEditingController(text: edit?.price.toStringAsFixed(2) ?? '');
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(edit == null ? 'Nouveau plat' : 'Modifier le plat'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtl,
                decoration: const InputDecoration(labelText: 'Nom du plat'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: priceCtl,
                decoration: const InputDecoration(labelText: 'Prix'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final name = nameCtl.text.trim();
              final price = double.parse(priceCtl.text.replaceAll(',', '.'));
              final state = context.read<RestaurantState>();
              if (edit == null) {
                await state.addMenuItem(name, price);
              } else {
                await state.updateMenuItem(edit.id, name: name, price: price);
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(edit == null ? 'Ajouter' : 'Enregistrer'),
          ),
        ],
      ),
    );
  }
}

// ----- HELPERS -----

String _fmt(num v, {String symbol = '€'}) => '${v.toStringAsFixed(2)} $symbol';
String _fmtDiff(num v) => (v >= 0 ? '+ ' : '- ') + _fmt(v.abs());
