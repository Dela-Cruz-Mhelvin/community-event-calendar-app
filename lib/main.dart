import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const CalendarApp());

// ---------------------------------------------------------------------------
// Data
// ---------------------------------------------------------------------------

enum EventCategory { meeting, health, sports, culture, learning }

extension EventCategoryInfo on EventCategory {
  String get label {
    switch (this) {
      case EventCategory.meeting:
        return 'Meeting';
      case EventCategory.health:
        return 'Health';
      case EventCategory.sports:
        return 'Sports';
      case EventCategory.culture:
        return 'Culture';
      case EventCategory.learning:
        return 'Learning';
    }
  }

  Color get color {
    switch (this) {
      case EventCategory.meeting:
        return const Color(0xFF2F6FED);
      case EventCategory.health:
        return const Color(0xFFD1495B);
      case EventCategory.sports:
        return const Color(0xFF1F8A7D);
      case EventCategory.culture:
        return const Color(0xFFC9780D);
      case EventCategory.learning:
        return const Color(0xFF7A5CC8);
    }
  }
}

const List<String> kMonths = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

const List<String> kWeekdays = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
];

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String two(int n) => n.toString().padLeft(2, '0');

String dateKey(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

String prettyDate(DateTime d) =>
    '${kWeekdays[d.weekday - 1]}, ${kMonths[d.month - 1]} ${d.day}';

String shortDate(DateTime d) =>
    '${kMonths[d.month - 1].substring(0, 3)} ${d.day}, ${d.year}';

class EventItem {
  final String id;
  final String title;
  final DateTime date;
  final TimeOfDay? time;
  final String place;
  final EventCategory category;

  const EventItem({
    required this.id,
    required this.title,
    required this.date,
    required this.time,
    required this.place,
    required this.category,
  });

  int get minutes => time == null ? -1 : time!.hour * 60 + time!.minute;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'date': dateKey(date),
        'time': time == null ? null : '${two(time!.hour)}:${two(time!.minute)}',
        'place': place,
        'category': category.name,
      };

  factory EventItem.fromJson(Map<String, dynamic> j) {
    final d = DateTime.parse(j['date'] as String);
    TimeOfDay? t;
    final ts = j['time'] as String?;
    if (ts != null) {
      final parts = ts.split(':');
      t = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }
    return EventItem(
      id: j['id'] as String,
      title: j['title'] as String,
      date: DateTime(d.year, d.month, d.day),
      time: t,
      place: (j['place'] as String?) ?? '',
      category: EventCategory.values.firstWhere(
        (c) => c.name == j['category'],
        orElse: () => EventCategory.meeting,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// App (theme: light / dark, saved on the device)
// ---------------------------------------------------------------------------

class CalendarApp extends StatefulWidget {
  const CalendarApp({super.key});

  @override
  State<CalendarApp> createState() => _CalendarAppState();
}

class _CalendarAppState extends State<CalendarApp> {
  ThemeMode _mode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('theme');
    if (saved != null) {
      setState(() => _mode = saved == 'light' ? ThemeMode.light : ThemeMode.dark);
    }
  }

  Future<void> _setMode(ThemeMode mode) async {
    setState(() => _mode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', mode == ThemeMode.light ? 'light' : 'dark');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Community Event Calendar',
      debugShowCheckedModeBanner: false,
            builder: (context, child) => ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: child,
          ),
        ),
      ),
      themeMode: _mode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF14213D)),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF2A93B),
          brightness: Brightness.dark,
        ),
      ),
      home: HomePage(onModeChanged: _setMode),
    );
  }
}

// ---------------------------------------------------------------------------
// Home screen
// ---------------------------------------------------------------------------

class HomePage extends StatefulWidget {
  final ValueChanged<ThemeMode> onModeChanged;

  const HomePage({super.key, required this.onModeChanged});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<EventItem> _events = [];
  bool _loading = true;
  late DateTime _month;
  late DateTime _selected;
  EventCategory? _filter;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selected = DateTime(now.year, now.month, now.day);
    _month = DateTime(now.year, now.month, 1);
    _load();
  }

  // ----- storage -----

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('events');
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        _events = list
            .map((e) => EventItem.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _events = [];
      }
    } else {
      _events = _sampleEvents();
      await _save();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'events',
      jsonEncode(_events.map((e) => e.toJson()).toList()),
    );
  }

  List<EventItem> _sampleEvents() {
    final now = DateTime.now();
    DateTime inDays(int n) => DateTime(now.year, now.month, now.day + n);
    return [
      EventItem(id: 's1', title: 'Barangay assembly', date: inDays(2),
          time: const TimeOfDay(hour: 9, minute: 0), place: 'Barangay hall',
          category: EventCategory.meeting),
      EventItem(id: 's2', title: 'Community clean-up drive', date: inDays(5),
          time: const TimeOfDay(hour: 6, minute: 30), place: 'Main street',
          category: EventCategory.health),
      EventItem(id: 's3', title: 'Inter-purok basketball', date: inDays(7),
          time: const TimeOfDay(hour: 15, minute: 0), place: 'Covered court',
          category: EventCategory.sports),
      EventItem(id: 's4', title: 'Cultural night', date: inDays(10),
          time: const TimeOfDay(hour: 18, minute: 0), place: 'Town plaza',
          category: EventCategory.culture),
      EventItem(id: 's5', title: 'Livelihood skills workshop', date: inDays(14),
          time: const TimeOfDay(hour: 13, minute: 0), place: 'Multipurpose hall',
          category: EventCategory.learning),
    ];
  }

  // ----- helpers -----

  List<EventItem> get _visible {
    final list = _events
        .where((e) => _filter == null || e.category == _filter)
        .toList();
    list.sort((a, b) {
      final c = a.date.compareTo(b.date);
      return c != 0 ? c : a.minutes.compareTo(b.minutes);
    });
    return list;
  }

  void _changeMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta, 1));
  }

  void _goToday() {
    final now = DateTime.now();
    setState(() {
      _selected = DateTime(now.year, now.month, now.day);
      _month = DateTime(now.year, now.month, 1);
    });
  }

  Future<void> _addEvent() async {
    final item = await showModalBottomSheet<EventItem>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => AddEventSheet(initialDate: _selected),
    );
    if (item == null) return;
    setState(() {
      _events.add(item);
      _selected = item.date;
      _month = DateTime(item.date.year, item.date.month, 1);
    });
    await _save();
  }

  Future<void> _confirmDelete(EventItem e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete event?'),
        content: Text('"${e.title}" will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      setState(() => _events.removeWhere((x) => x.id == e.id));
      await _save();
    }
  }

  // ----- UI -----

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Events'),
        actions: [
          IconButton(
            tooltip: isDark ? 'Switch to light theme' : 'Switch to dark theme',
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => widget.onModeChanged(
              isDark ? ThemeMode.light : ThemeMode.dark,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addEvent,
        icon: const Icon(Icons.add),
        label: const Text('Add event'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  _buildFilters(),
                  const SizedBox(height: 12),
                  _buildCalendarCard(),
                  const SizedBox(height: 16),
                  ..._buildDayEvents(),
                  const SizedBox(height: 16),
                  ..._buildUpcoming(),
                ],
              ),
            ),
    );
  }

    Widget _buildFilters() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('All'),
          selected: _filter == null,
          onSelected: (_) => setState(() => _filter = null),
        ),
        for (final c in EventCategory.values)
          ChoiceChip(
            avatar: CircleAvatar(backgroundColor: c.color, radius: 6),
            label: Text(c.label),
            selected: _filter == c,
            onSelected: (_) => setState(() => _filter = c),
          ),
      ],
    );
  }

  Widget _buildCalendarCard() {
    final first = DateTime(_month.year, _month.month, 1);
    final startOffset = first.weekday % 7; // Sunday = 0
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;

    final cells = <Widget>[
      for (int i = 0; i < startOffset; i++) const SizedBox.shrink(),
      for (int d = 1; d <= daysInMonth; d++)
        _buildDayCell(DateTime(_month.year, _month.month, d)),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Previous month',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _changeMonth(-1),
                ),
                Expanded(
                  child: Text(
                    '${kMonths[_month.month - 1]} ${_month.year}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Next month',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: _goToday, child: const Text('Today')),
            ),
            Row(
              children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                  .map((d) => Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 6),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              children: cells,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayCell(DateTime day) {
    final cs = Theme.of(context).colorScheme;
    final selected = sameDay(day, _selected);
    final today = sameDay(day, DateTime.now());
    final dayEvents = _visible.where((e) => sameDay(e.date, day)).take(3);

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => _selected = day),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? cs.primary : null,
          border: (today && !selected)
              ? Border.all(color: cs.primary, width: 2)
              : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                fontWeight: today ? FontWeight.bold : FontWeight.normal,
                color: selected ? cs.onPrimary : cs.onSurface,
              ),
            ),
            const SizedBox(height: 3),
            SizedBox(
              height: 6,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final e in dayEvents)
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: e.category.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDayEvents() {
    final list = _visible.where((e) => sameDay(e.date, _selected)).toList();
    return [
      Text(prettyDate(_selected), style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      if (list.isEmpty)
        const Text('Nothing scheduled. Tap "Add event" to create one.'),
      for (final e in list) _buildEventTile(e),
    ];
  }

  List<Widget> _buildUpcoming() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final list = _visible.where((e) => !e.date.isBefore(start)).take(5).toList();
    return [
      Text('Coming up', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      if (list.isEmpty) const Text('No upcoming events.'),
      for (final e in list) _buildEventTile(e, showDate: true),
    ];
  }

  Widget _buildEventTile(EventItem e, {bool showDate = false}) {
    final subtitle = [
      if (showDate) shortDate(e.date),
      e.time?.format(context) ?? 'All day',
      if (e.place.isNotEmpty) e.place,
      e.category.label,
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: e.category.color,
          child: const Icon(Icons.event, color: Colors.white),
        ),
        title: Text(e.title),
        subtitle: Text(subtitle),
        trailing: IconButton(
          tooltip: 'Delete event',
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _confirmDelete(e),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add-event form (bottom sheet)
// ---------------------------------------------------------------------------

class AddEventSheet extends StatefulWidget {
  final DateTime initialDate;

  const AddEventSheet({super.key, required this.initialDate});

  @override
  State<AddEventSheet> createState() => _AddEventSheetState();
}

class _AddEventSheetState extends State<AddEventSheet> {
  final _title = TextEditingController();
  final _place = TextEditingController();
  late DateTime _date;
  TimeOfDay? _time;
  EventCategory _category = EventCategory.meeting;
  String? _error;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
  }

  @override
  void dispose() {
    _title.dispose();
    _place.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
    );
    if (t != null) setState(() => _time = t);
  }

  void _submit() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Please enter an event name.');
      return;
    }
    Navigator.pop(
      context,
      EventItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        date: DateTime(_date.year, _date.month, _date.day),
        time: _time,
        place: _place.text.trim(),
        category: _category,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add event', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              maxLength: 60,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Event name',
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(shortDate(_date)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.access_time),
                    label: Text(_time?.format(context) ?? 'Any time'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _place,
              decoration: const InputDecoration(
                labelText: 'Place (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final c in EventCategory.values)
                  ChoiceChip(
                    label: Text(c.label),
                    selected: _category == c,
                    onSelected: (_) => setState(() => _category = c),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: const Text('Save event'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}