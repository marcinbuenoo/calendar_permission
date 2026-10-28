import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/material.dart';

void main() => runApp(const CalendarApp());

class CalendarApp extends StatelessWidget {
  const CalendarApp({super.key});

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF183B36);
    return MaterialApp(
      title: 'Compromissos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: ink,
          surface: const Color(0xFFF7F8F5),
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F8F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF7F8F5),
          foregroundColor: ink,
        ),
      ),
      home: const CalendarHomePage(),
    );
  }
}

class CalendarHomePage extends StatefulWidget {
  const CalendarHomePage({super.key});

  @override
  State<CalendarHomePage> createState() => _CalendarHomePageState();
}

class _CalendarHomePageState extends State<CalendarHomePage> {
  final DeviceCalendarPlugin _calendar = DeviceCalendarPlugin();
  bool _loading = false;
  List<_CalendarEvent> _events = [];
  String? _message;
  _MessageType _messageType = _MessageType.info;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  bool _hasConsulted = false;

  Future<void> _loadEvents() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _message = null;
      _hasConsulted = true;
    });

    try {
      final permission = await _calendar.requestPermissions();
      if (permission.data != true) {
        if (!mounted) return;
        setState(() {
          _events = [];
          _message = 'Acesso ao calendário negado. Autorize o acesso para consultar seus compromissos.';
          _messageType = _MessageType.warning;
        });
        return;
      }

      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final end = start.add(const Duration(days: 7));
      final calendarsResult = await _calendar.retrieveCalendars();
      if (calendarsResult.hasErrors || calendarsResult.data == null) {
        throw StateError(
          'Não foi possível acessar os calendários do dispositivo.',
        );
      }

      final eventLists = await Future.wait(
        calendarsResult.data!.map((calendar) async {
          final result = await _calendar.retrieveEvents(
            calendar.id,
            RetrieveEventsParams(startDate: start, endDate: end),
          );
          if (result.hasErrors) {
            throw StateError(
              'Falha ao consultar o calendário ${calendar.name ?? ''}.',
            );
          }
          return (result.data ?? []).map(
            (event) => _CalendarEvent(event, calendar.name ?? 'Calendário'),
          );
        }),
      );

      final events =
          eventLists
              .expand((items) => items)
              .where((item) => item.event.start != null)
              .toList()
            ..sort((a, b) => a.event.start!.compareTo(b.event.start!));
      if (!mounted) return;
      setState(() {
        _events = events;
        _rangeStart = start;
        _rangeEnd = end;
        _message = events.isEmpty
            ? 'Nenhum compromisso nos próximos sete dias.'
            : null;
        _messageType = _MessageType.info;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _events = [];
        _message =
            'Não foi possível consultar os compromissos. Tente novamente.';
        _messageType = _MessageType.error;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Minha agenda',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    sliver: SliverList.list(
                      children: [
                        _buildHeader(theme),
                        const SizedBox(height: 22),
                        SizedBox(
                          height: 54,
                          child: FilledButton.icon(
                            onPressed: _loading ? null : _loadEvents,
                            icon: _loading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.sync_rounded),
                            label: Text(
                              _loading
                                  ? 'Consultando…'
                                  : 'Consultar compromissos',
                            ),
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        if (_loading) ...[
                          const SizedBox(height: 24),
                          const LinearProgressIndicator(minHeight: 3),
                          const SizedBox(height: 12),
                          Text(
                            'Buscando em todos os calendários…',
                            style: theme.textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                        if (_message != null && !_loading) ...[
                          const SizedBox(height: 24),
                          _MessageCard(message: _message!, type: _messageType),
                        ],
                        if (_events.isNotEmpty && !_loading) ...[
                          const SizedBox(height: 26),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Compromissos',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                '${_events.length}',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          for (var i = 0; i < _events.length; i++) ...[
                            if (_startsNewDay(i))
                              _DayHeading(date: _events[i].event.start!),
                            _EventCard(item: _events[i]),
                            const SizedBox(height: 10),
                          ],
                        ],
                        if (!_hasConsulted && !_loading) ...[
                          const SizedBox(height: 38),
                          const _WelcomeCard(),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_rangeStart != null && _rangeEnd != null && _hasConsulted)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text(
                  'Período: ${_date(_rangeStart!)} a ${_date(_rangeEnd!.subtract(const Duration(days: 1)))}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final now = DateTime.now();
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFE4EEE9),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .75),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              _weekday(now).toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Sua semana,\nem um só lugar.',
            style: TextStyle(
              fontSize: 29,
              height: 1.12,
              fontWeight: FontWeight.w700,
              letterSpacing: -.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Veja os compromissos de hoje e dos próximos seis dias.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  bool _startsNewDay(int index) =>
      index == 0 ||
      !_sameDay(_events[index - 1].event.start!, _events[index].event.start!);
}

class _CalendarEvent {
  const _CalendarEvent(this.event, this.calendarName);
  final Event event;
  final String calendarName;
}

enum _MessageType { info, warning, error }

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, required this.type});
  final String message;
  final _MessageType type;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (type) {
      _MessageType.info => (
        Icons.event_available_rounded,
        const Color(0xFF42675D),
      ),
      _MessageType.warning => (
        Icons.lock_outline_rounded,
        const Color(0xFF9A6619),
      ),
      _MessageType.error => (
        Icons.error_outline_rounded,
        const Color(0xFFB33D35),
      ),
    };
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: TextStyle(color: color, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      children: [
        Icon(
          Icons.calendar_month_rounded,
          size: 38,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 12),
        const Text(
          'Pronto para organizar sua semana?',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          'Toque no botão para permitir o acesso e carregar sua agenda.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}

class _DayHeading extends StatelessWidget {
  const _DayHeading({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final today = _sameDay(date, DateTime.now());
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 10),
      child: Row(
        children: [
          Text(
            today ? 'HOJE' : _weekday(date).toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 9),
          Text(
            '${date.day} ${_month(date.month)}',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Divider(height: 1)),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.item});
  final _CalendarEvent item;

  @override
  Widget build(BuildContext context) {
    final event = item.event;
    final theme = Theme.of(context);
    final allDay = event.allDay ?? false;
    final start = event.start;
    final end = event.end;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9ECE8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 58,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title?.trim().isNotEmpty == true
                      ? event.title!
                      : 'Sem título',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 15,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      allDay
                          ? 'Dia inteiro · ${start == null ? '' : _date(start)}'
                          : '${_dateTime(start)} – ${_dateTime(end)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                _DetailLine(
                  icon: Icons.calendar_today_rounded,
                  text: item.calendarName,
                ),
                if (event.location?.trim().isNotEmpty == true)
                  _DetailLine(
                    icon: Icons.place_outlined,
                    text: event.location!,
                  ),
                if (event.description?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Text(
                    event.description!.trim(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      height: 1.35,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 5),
    child: Row(
      children: [
        Icon(
          icon,
          size: 15,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ),
  );
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
String _time(DateTime? date) => date == null
    ? '--:--'
    : '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
String _dateTime(DateTime? date) =>
    date == null ? '--' : '${_date(date)}, ${_time(date)}';
String _date(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
String _weekday(DateTime date) => const [
  'segunda-feira',
  'terça-feira',
  'quarta-feira',
  'quinta-feira',
  'sexta-feira',
  'sábado',
  'domingo',
][date.weekday - 1];
String _month(int month) => const [
  'jan',
  'fev',
  'mar',
  'abr',
  'mai',
  'jun',
  'jul',
  'ago',
  'set',
  'out',
  'nov',
  'dez',
][month - 1];
