import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

enum CalendarViewMode { month, week, day }

class CompromissosCalendar extends StatefulWidget {
  final List<Map<String, dynamic>> compromissos;
  final Function(Map<String, dynamic>)? onCompromissoTap;
  final Function(DateTime)? onDaySelected;

  const CompromissosCalendar({
    super.key,
    required this.compromissos,
    this.onCompromissoTap,
    this.onDaySelected,
  });

  @override
  State<CompromissosCalendar> createState() => _CompromissosCalendarState();
}

class _CompromissosCalendarState extends State<CompromissosCalendar> {
  late ValueNotifier<List<Map<String, dynamic>>> _selectedEvents;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarViewMode _viewMode = CalendarViewMode.month;

  @override
  void initState() {
    super.initState();
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay));
  }

  @override
  void dispose() {
    _selectedEvents.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    return widget.compromissos.where((compromisso) {
      if (compromisso['data_hora'] == null) return false;
      final dataHora = DateTime.parse(compromisso['data_hora'] as String);
      return isSameDay(dataHora, day);
    }).toList();
  }

  Map<DateTime, List<Map<String, dynamic>>> _getEventsMap() {
    final Map<DateTime, List<Map<String, dynamic>>> events = {};
    
    for (var compromisso in widget.compromissos) {
      if (compromisso['data_hora'] == null) continue;
      final dataHora = DateTime.parse(compromisso['data_hora'] as String);
      final day = DateTime(dataHora.year, dataHora.month, dataHora.day);
      
      if (events[day] == null) {
        events[day] = [];
      }
      events[day]!.add(compromisso);
    }
    
    return events;
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });

      _selectedEvents.value = _getEventsForDay(selectedDay);
      widget.onDaySelected?.call(selectedDay);
      
      // Se estiver no modo mês, mudar para modo dia ao clicar
      if (_viewMode == CalendarViewMode.month) {
        setState(() {
          _viewMode = CalendarViewMode.day;
        });
      }
    }
  }

  void _navigateDate(int days) {
    setState(() {
      _focusedDay = _focusedDay.add(Duration(days: days));
      _selectedDay = _selectedDay.add(Duration(days: days));
      _selectedEvents.value = _getEventsForDay(_selectedDay);
    });
  }

  void _navigateWeek(int weeks) {
    setState(() {
      _focusedDay = _focusedDay.add(Duration(days: 7 * weeks));
      _selectedDay = _selectedDay.add(Duration(days: 7 * weeks));
      _selectedEvents.value = _getEventsForDay(_selectedDay);
    });
  }

  List<DateTime> _getWeekDays(DateTime weekStart) {
    return List.generate(7, (index) => weekStart.add(Duration(days: index)));
  }

  DateTime _getWeekStart(DateTime date) {
    final weekday = date.weekday;
    return date.subtract(Duration(days: weekday - 1));
  }

  @override
  Widget build(BuildContext context) {
    final eventsMap = _getEventsMap();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.25),
            Colors.white.withValues(alpha: 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0400B9).withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Toggle de visualização
          _buildViewToggle(),
          
          // Conteúdo baseado no modo
          Expanded(
            child: _viewMode == CalendarViewMode.day
                ? _buildDayView()
                : _viewMode == CalendarViewMode.week
                    ? _buildWeekView(eventsMap)
                    : _buildMonthView(eventsMap),
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggle() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          _buildViewToggleButton(CalendarViewMode.month, Icons.calendar_month, 'Mês'),
          _buildViewToggleButton(CalendarViewMode.week, Icons.view_week, 'Semana'),
          _buildViewToggleButton(CalendarViewMode.day, Icons.today, 'Dia'),
        ],
      ),
    );
  }

  Widget _buildViewToggleButton(CalendarViewMode mode, IconData icon, String label) {
    final isActive = _viewMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _viewMode = mode;
            _selectedEvents.value = _getEventsForDay(_selectedDay);
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            gradient: isActive
                ? const LinearGradient(
                    colors: [Color(0xFF0400B9), Color(0xFF0600E0)],
                  )
                : null,
            color: isActive ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.7),
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.leagueSpartan(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Navegação do dia
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => _navigateDate(-1),
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              Text(
                DateFormat('EEEE, d \'de\' MMMM \'de\' yyyy', 'pt_BR').format(_selectedDay),
                style: AppTextStyles.leagueSpartan(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              IconButton(
                onPressed: () => _navigateDate(1),
                icon: const Icon(Icons.chevron_right, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Lista de compromissos do dia
          ValueListenableBuilder<List<Map<String, dynamic>>>(
            valueListenable: _selectedEvents,
            builder: (context, compromissos, _) {
              if (compromissos.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Nenhum compromisso neste dia',
                      style: AppTextStyles.leagueSpartan(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              }

              return Column(
                children: compromissos
                    .map((compromisso) => _buildCompromissoCard(compromisso))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCompromissoCard(Map<String, dynamic> compromisso) {
    final dataHora = DateTime.parse(compromisso['data_hora'] as String);
    final concluido = compromisso['concluido'] as bool? ?? false;
    final isPassado = dataHora.isBefore(DateTime.now());
    
    return GestureDetector(
      onTap: () => widget.onCompromissoTap?.call(compromisso),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: concluido
              ? Colors.green.withValues(alpha: 0.25)
              : isPassado
                  ? Colors.red.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: concluido
                ? Colors.green.withValues(alpha: 0.5)
                : isPassado
                    ? Colors.red.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.35),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: concluido
                      ? [Colors.green.shade400, Colors.green.shade600]
                      : isPassado
                          ? [Colors.red.shade400, Colors.red.shade600]
                          : [const Color(0xFF0400B9), const Color(0xFF0600E0)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                concluido ? Icons.check_circle : Icons.calendar_today,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          compromisso['titulo'] as String? ?? 'Compromisso',
                          style: AppTextStyles.leagueSpartan(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            decoration: concluido ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                      if (concluido)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '✓',
                            style: AppTextStyles.leagueSpartan(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      if (isPassado && !concluido)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Atrasado',
                            style: AppTextStyles.leagueSpartan(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('HH:mm').format(dataHora),
                        style: AppTextStyles.leagueSpartan(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      if (compromisso['local'] != null && compromisso['local'].toString().isNotEmpty) ...[
                        const SizedBox(width: 16),
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            compromisso['local'] as String,
                            style: AppTextStyles.leagueSpartan(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (compromisso['descricao'] != null && compromisso['descricao'].toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      compromisso['descricao'] as String,
                      style: AppTextStyles.leagueSpartan(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekView(Map<DateTime, List<Map<String, dynamic>>> eventsMap) {
    final weekStart = _getWeekStart(_selectedDay);
    final weekDays = _getWeekDays(weekStart);

    return Column(
      children: [
        // Navegação da semana
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => _navigateWeek(-1),
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              Text(
                '${DateFormat('d MMM', 'pt_BR').format(weekDays.first)} - ${DateFormat('d MMM yyyy', 'pt_BR').format(weekDays.last)}',
                style: AppTextStyles.leagueSpartan(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              IconButton(
                onPressed: () => _navigateWeek(1),
                icon: const Icon(Icons.chevron_right, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                ),
              ),
            ],
          ),
        ),
        // Grid da semana
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: weekDays.map((day) {
                final dayEvents = _getEventsForDay(day);
                final isToday = isSameDay(day, DateTime.now());
                final isSelected = isSameDay(day, _selectedDay);

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDay = day;
                        _focusedDay = day;
                        _selectedEvents.value = dayEvents;
                      });
                      widget.onDaySelected?.call(day);
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.2)
                            : isToday
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Colors.white
                              : isToday
                                  ? Colors.white.withValues(alpha: 0.5)
                                  : Colors.white.withValues(alpha: 0.2),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            DateFormat('EEE', 'pt_BR').format(day),
                            style: AppTextStyles.leagueSpartan(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${day.day}',
                            style: AppTextStyles.leagueSpartan(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          if (dayEvents.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0400B9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${dayEvents.length}',
                                style: AppTextStyles.leagueSpartan(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          ...dayEvents.take(2).map((comp) {
                            final dataHora = DateTime.parse(comp['data_hora'] as String);
                            return GestureDetector(
                              onTap: () => widget.onCompromissoTap?.call(comp),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 4),
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: (comp['concluido'] as bool? ?? false)
                                      ? Colors.green.withValues(alpha: 0.35)
                                      : Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      DateFormat('HH:mm').format(dataHora),
                                      style: AppTextStyles.leagueSpartan(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      comp['titulo'] as String? ?? 'Compromisso',
                                      style: AppTextStyles.leagueSpartan(
                                        fontSize: 10,
                                        color: Colors.white.withValues(alpha: 0.9),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          if (dayEvents.length > 2)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '+${dayEvents.length - 2}',
                                style: AppTextStyles.leagueSpartan(
                                  fontSize: 10,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthView(Map<DateTime, List<Map<String, dynamic>>> eventsMap) {
    return Column(
      children: [
        // Calendário
        TableCalendar<Map<String, dynamic>>(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: (day) => eventsMap[DateTime(day.year, day.month, day.day)] ?? [],
            startingDayOfWeek: StartingDayOfWeek.monday,
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              weekendTextStyle: AppTextStyles.leagueSpartan(
                color: Colors.white.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
              ),
              defaultTextStyle: AppTextStyles.leagueSpartan(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              selectedTextStyle: AppTextStyles.leagueSpartan(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              todayTextStyle: AppTextStyles.leagueSpartan(
                color: const Color(0xFF0400BA),
                fontWeight: FontWeight.w700,
              ),
              todayDecoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: const Color(0xFF0400BA),
                shape: BoxShape.circle,
              ),
              markerDecoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                shape: BoxShape.circle,
              ),
              markersMaxCount: 3,
              markerSize: 6,
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: AppTextStyles.leagueSpartan(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              leftChevronIcon: Icon(
                Icons.chevron_left,
                color: Colors.white,
              ),
              rightChevronIcon: Icon(
                Icons.chevron_right,
                color: Colors.white,
              ),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: AppTextStyles.leagueSpartan(
                color: Colors.white.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              weekendStyle: AppTextStyles.leagueSpartan(
                color: Colors.white.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            onDaySelected: _onDaySelected,
            onPageChanged: (focusedDay) {
              setState(() {
                _focusedDay = focusedDay;
              });
            },
          ),
          
          // Lista de compromissos do dia selecionado
          ValueListenableBuilder<List<Map<String, dynamic>>>(
            valueListenable: _selectedEvents,
            builder: (context, compromissos, _) {
                if (compromissos.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Nenhum compromisso neste dia',
                      style: AppTextStyles.leagueSpartan(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 16,
                      ),
                    ),
                  );
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Compromissos do dia ${DateFormat('dd/MM/yyyy').format(_selectedDay)}',
                        style: AppTextStyles.leagueSpartan(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...compromissos.map((compromisso) {
                        final dataHora = DateTime.parse(compromisso['data_hora'] as String);
                        final concluido = compromisso['concluido'] as bool? ?? false;
                        final isPassado = dataHora.isBefore(DateTime.now());
                        
                        return GestureDetector(
                          onTap: () => widget.onCompromissoTap?.call(compromisso),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: concluido
                                  ? Colors.green.withValues(alpha: 0.25)
                                  : isPassado
                                      ? Colors.red.withValues(alpha: 0.25)
                                      : Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: concluido
                                    ? Colors.green.withValues(alpha: 0.5)
                                    : isPassado
                                        ? Colors.red.withValues(alpha: 0.5)
                                        : Colors.white.withValues(alpha: 0.35),
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: concluido
                                          ? [Colors.green.shade400, Colors.green.shade600]
                                          : isPassado
                                              ? [Colors.red.shade400, Colors.red.shade600]
                                              : [const Color(0xFF0400B9), const Color(0xFF0600E0)],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    concluido ? Icons.check_circle : Icons.calendar_today,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        compromisso['titulo'] as String? ?? 'Compromisso',
                                        style: AppTextStyles.leagueSpartan(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          decoration: concluido ? TextDecoration.lineThrough : null,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        DateFormat('HH:mm').format(dataHora),
                                        style: AppTextStyles.leagueSpartan(
                                          fontSize: 12,
                                          color: Colors.white.withValues(alpha: 0.8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (concluido)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '✓',
                                      style: AppTextStyles.leagueSpartan(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
            ),
      ],
    );
  }
}


