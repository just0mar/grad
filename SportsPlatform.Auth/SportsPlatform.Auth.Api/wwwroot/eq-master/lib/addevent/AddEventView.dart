import 'package:eqq/core/app_localizations.dart';
import 'package:flutter/material.dart';

import '../appbar/CustomAppBar.dart';
import '../core/animated_button.dart';
import '../core/animated_dropdown.dart';
import '../core/app_background.dart';
import '../core/responsive_system.dart';
import '../core/responsive_widgets.dart';
import '../core/smooth_keyboard_mixin.dart';
import '../event/EventModel.dart';
import '../location/location_point.dart';
import '../location/osm_map.dart';

class AddEventView extends StatefulWidget {
  /// Optional pre-filled date (e.g. when tapping a calendar day).
  final DateTime? initialDate;
  final Event? initialEvent;

  const AddEventView({super.key, this.initialDate, this.initialEvent});

  @override
  State<AddEventView> createState() => _AddEventViewState();
}

class _AddEventViewState extends State<AddEventView>
    with TickerProviderStateMixin, SmoothKeyboardMixin {
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  String? _selectedType;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  LocationPoint? _selectedLocationPoint;

  // ── recurring fields ──
  bool _isRecurring = false;
  int? _recurringWeekday; // 1=Mon … 7=Sun
  DateTime? _recurringStartDate;
  DateTime? _recurringEndDate;

  final List<String> _eventTypes = const [
    'Match',
    'Training',
    'Meeting',
    'Test',
  ];

  static const List<String> _weekDayLabels = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    final initialEvent = widget.initialEvent;
    if (initialEvent != null) {
      _selectedType = initialEvent.type;
      _selectedDate = initialEvent.date;
      _selectedTime = initialEvent.time;
      _descriptionController.text = initialEvent.description;
      _locationController.text = initialEvent.location ?? '';
      if (initialEvent.locationLatitude != null &&
          initialEvent.locationLongitude != null) {
        _selectedLocationPoint = LocationPoint(
          latitude: initialEvent.locationLatitude!,
          longitude: initialEvent.locationLongitude!,
          label: initialEvent.location,
        );
      }
      _isRecurring = initialEvent.recurrenceRule != null;
      _recurringStartDate = initialEvent.date;
      _recurringEndDate = initialEvent.recurrenceEndDate;
      _recurringWeekday =
          _weekdayFromRule(initialEvent.recurrenceRule) ??
              initialEvent.date.weekday;
    } else {
      _selectedDate = widget.initialDate;
      _recurringStartDate = widget.initialDate;
      _recurringWeekday = widget.initialDate?.weekday;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickLocation(BuildContext context) async {
    final result = await Navigator.push<LocationPoint>(
      context,
      MaterialPageRoute(
        builder: (_) => OsmLocationPicker(
          initialPoint: _selectedLocationPoint,
          initialLabel: _locationController.text,
        ),
      ),
    );
    if (result == null) return;
    setState(() {
      _selectedLocationPoint = result;
      _locationController.text = result.label?.trim().isNotEmpty == true
          ? result.label!.trim()
          : '${result.latitude.toStringAsFixed(6)}, ${result.longitude.toStringAsFixed(6)}';
    });
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _pickEndDate(BuildContext context) async {
    final now = DateTime.now();
    final minDate = _recurringStartDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: _recurringEndDate ?? minDate,
      firstDate: minDate,
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() => _recurringEndDate = picked);
    }
  }

  Future<void> _pickRecurringStartDate(BuildContext context) async {
    final now = DateTime.now();
    final initial = _recurringStartDate ?? _selectedDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() {
        _recurringStartDate = picked;
        _selectedDate = picked;
        _recurringWeekday ??= picked.weekday;
        if (_recurringEndDate != null &&
            _recurringEndDate!.isBefore(picked)) {
          _recurringEndDate = null;
        }
      });
    }
  }

  bool get _isReady {
    if (_selectedType == null || _selectedTime == null) return false;
    if (_isRecurring) {
      return _recurringWeekday != null &&
          _recurringStartDate != null &&
          _recurringEndDate != null;
    }
    return _selectedDate != null;
  }

  /// Build an RFC 5545 RRULE string, e.g. "FREQ=WEEKLY;BYDAY=SU"
  String? _buildRecurrenceRule() {
    if (!_isRecurring || _recurringWeekday == null) return null;
    const dayAbbr = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
    return 'FREQ=WEEKLY;BYDAY=${dayAbbr[_recurringWeekday! - 1]}';
  }

  int? _weekdayFromRule(String? rule) {
    if (rule == null) return null;
    final match = RegExp(r'BYDAY=([A-Z]{2})').firstMatch(rule);
    if (match == null) return null;
    const map = {
      'MO': 1,
      'TU': 2,
      'WE': 3,
      'TH': 4,
      'FR': 5,
      'SA': 6,
      'SU': 7,
    };
    return map[match.group(1)];
  }

  @override
  Widget build(BuildContext context) {
    updateKeyboardHeight(MediaQuery.viewInsetsOf(context).bottom);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldColor = isDark ? const Color(0xFF1B3A2D) : Colors.white;
    final labelColor = isDark ? Colors.white70 : null;
    final textColor = isDark ? Colors.white : Colors.black;
    final isEditing = widget.initialEvent != null;
    final pagePadding = ResponsiveSystem.pagePadding(context);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      extendBodyBehindAppBar: true,
      appBar: CustomAppBar(title: isEditing ? 'EDIT EVENT' : 'ADD EVENT', showTeamSwitcher: true),
      body: buildKeyboardDismissible(
        child: AppBackground(
        child: SafeArea(
          child: GestureDetector(
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            behavior: HitTestBehavior.translucent,
            child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: pagePadding.copyWith(
              bottom: pagePadding.bottom + smoothKeyboardHeight,
            ),
            child: Column(
              children: [
                // ── event type ──
                AnimatedDropdown(
                  child: DropdownButtonFormField<String>(
                  menuMaxHeight: 280,
                  borderRadius: BorderRadius.circular(16),
                  elevation: 8,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.green, size: 22),
                  value: _selectedType,
                  dropdownColor: fieldColor,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: fieldColor,
                    labelText: 'Event type',
                    labelStyle:
                        TextStyle(color: labelColor, fontFamily: 'SFPro'),
                    border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                  ),
                  style: TextStyle(color: textColor, fontFamily: 'SFPro'),
                  items: _eventTypes
                      .map((e) => DropdownMenuItem(
                            value: e,
                            child: Text(e,
                                style: const TextStyle(fontFamily: 'SFPro')),
                          ))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedType = val),
                ),
                ),
                const SizedBox(height: 16),

                // ── recurring toggle ──
                Container(
                  decoration: BoxDecoration(
                    color: fieldColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? Colors.white24 : Colors.grey.shade400,
                    ),
                  ),
                  child: SwitchListTile(
                    title: Text(
                      'Recurring event',
                      style: TextStyle(
                        color: textColor,
                        fontFamily: 'SFPro',
                        fontSize: 15,
                      ),
                    ),
                    subtitle: Text(
                      'Repeats weekly on a chosen day',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontFamily: 'SFPro',
                        fontSize: 12,
                      ),
                    ),
                    value: _isRecurring,
                    activeColor: Colors.green,
                    onChanged: (val) => setState(() {
                      _isRecurring = val;
                      if (!val) {
                        if (_recurringStartDate != null) {
                          _selectedDate = _recurringStartDate;
                        }
                        _recurringWeekday = null;
                        _recurringStartDate = null;
                        _recurringEndDate = null;
                      } else if (_recurringStartDate == null &&
                          _selectedDate != null) {
                        _recurringStartDate = _selectedDate;
                        _recurringWeekday ??= _selectedDate!.weekday;
                      }
                    }),
                  ),
                ),
                const SizedBox(height: 16),

                // ── recurring: start date + day of week + end date ──
                if (_isRecurring) ...[
                  TextFormField(
                    readOnly: true,
                    style: TextStyle(color: textColor, fontFamily: 'SFPro'),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: fieldColor,
                      labelText: _recurringStartDate == null
                          ? 'Start date'
                          : '${_recurringStartDate!.month}/${_recurringStartDate!.day}/${_recurringStartDate!.year}',
                      labelStyle:
                          TextStyle(color: labelColor, fontFamily: 'SFPro'),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.calendar_today,
                            color: isDark ? Colors.white70 : Colors.black54),
                        onPressed: () => _pickRecurringStartDate(context),
                      ),
                      border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AnimatedDropdown(
                    child: DropdownButtonFormField<int>(
                    borderRadius: BorderRadius.circular(16),
                    elevation: 8,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.green, size: 22),
                    value: _recurringWeekday,
                    dropdownColor: fieldColor,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: fieldColor,
                      labelText: 'Repeat every',
                      labelStyle:
                          TextStyle(color: labelColor, fontFamily: 'SFPro'),
                      border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                    ),
                    style: TextStyle(color: textColor, fontFamily: 'SFPro'),
                    items: List.generate(
                      7,
                      (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text(_weekDayLabels[i],
                            style: const TextStyle(fontFamily: 'SFPro')),
                      ),
                    ),
                    onChanged: (val) =>
                      setState(() => _recurringWeekday = val),
                  ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    readOnly: true,
                    style: TextStyle(color: textColor, fontFamily: 'SFPro'),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: fieldColor,
                      labelText: _recurringEndDate == null
                          ? 'End date'
                          : '${_recurringEndDate!.month}/${_recurringEndDate!.day}/${_recurringEndDate!.year}',
                      labelStyle:
                          TextStyle(color: labelColor, fontFamily: 'SFPro'),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.calendar_today,
                            color: isDark ? Colors.white70 : Colors.black54),
                        onPressed: () => _pickEndDate(context),
                      ),
                      border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  // ── single event date ──
                  TextFormField(
                    readOnly: true,
                    style: TextStyle(color: textColor, fontFamily: 'SFPro'),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: fieldColor,
                      labelText: _selectedDate == null
                          ? 'MM/DD/YYYY'
                          : '${_selectedDate!.month}/${_selectedDate!.day}/${_selectedDate!.year}',
                      labelStyle:
                          TextStyle(color: labelColor, fontFamily: 'SFPro'),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.calendar_today,
                            color: isDark ? Colors.white70 : Colors.black54),
                        onPressed: () => _pickDate(context),
                      ),
                      border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── time ──
                TextFormField(
                  readOnly: true,
                  style: TextStyle(color: textColor, fontFamily: 'SFPro'),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: fieldColor,
                    labelText: _selectedTime == null
                        ? 'Select Time'
                        : _selectedTime!.format(context),
                    labelStyle:
                        TextStyle(color: labelColor, fontFamily: 'SFPro'),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.access_time,
                          color: isDark ? Colors.white70 : Colors.black54),
                      onPressed: () => _pickTime(context),
                    ),
                    border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── description ──
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  style: TextStyle(color: textColor, fontFamily: 'SFPro'),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: fieldColor,
                    labelText: 'Event description',
                    labelStyle:
                        TextStyle(color: labelColor, fontFamily: 'SFPro'),
                    border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── submit ──
                TextFormField(
                  controller: _locationController,
                  style: TextStyle(color: textColor, fontFamily: 'SFPro'),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: fieldColor,
                    labelText: 'Location',
                    hintText: 'Venue, address, or coordinates',
                    labelStyle:
                        TextStyle(color: labelColor, fontFamily: 'SFPro'),
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        Icons.map_outlined,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                      onPressed: () => _pickLocation(context),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onChanged: (value) {
                    if (_selectedLocationPoint == null) return;
                    setState(() {
                      _selectedLocationPoint = LocationPoint(
                        latitude: _selectedLocationPoint!.latitude,
                        longitude: _selectedLocationPoint!.longitude,
                        label: value.trim().isEmpty ? null : value.trim(),
                      );
                    });
                  },
                ),
                const SizedBox(height: 12),
                if (_selectedLocationPoint == null)
                  OutlinedButton.icon(
                    onPressed: () => _pickLocation(context),
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: Text(AppLocalizations.of(context).addMapPin),
                  )
                else
                  OsmMapPreview(
                    point: _selectedLocationPoint!,
                    height: 150,
                    onTap: () => _pickLocation(context),
                  ),
                const SizedBox(height: 24),

                AnimatedButton.primary(
                  child: ResponsivePrimaryButton(
                    context: context,
                    label: isEditing
                        ? 'Save changes'
                        : (_isRecurring ? 'Add recurring event' : 'Add event'),
                    onPressed: () {
                      if (!_isReady) return;

                      final DateTime eventDate =
                          _isRecurring ? _recurringStartDate! : _selectedDate!;

                      final base = widget.initialEvent;
                      final Event event = Event(
                        eventId: base?.eventId ?? '',
                        teamId: base?.teamId ?? '',
                        seasonId: base?.seasonId ?? '',
                        type: _selectedType!,
                        date: eventDate,
                        time: _selectedTime!,
                        description: _descriptionController.text.trim(),
                        location: _locationController.text.trim().isEmpty
                            ? null
                            : _locationController.text.trim(),
                        locationLatitude: _selectedLocationPoint?.latitude,
                        locationLongitude: _selectedLocationPoint?.longitude,
                        recurrenceRule: _buildRecurrenceRule(),
                        recurrenceEndDate: _recurringEndDate,
                      );
                      Navigator.pop(context, event);
                    },
                  ),
                ),
              ],
            ),
          ),
          ),
        ),
      ),
      ),
    );
  }


}
