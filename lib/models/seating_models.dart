part of 'models.dart';

// --- Seat maps (SRS 4.3.1) ---------------------------------------------------

/// Most seats the server accepts in one order, and in one block request.
const maxSeatsPerOrder = 50;
const maxSeatsPerBlock = 1000;

int? _optInt(dynamic v) => v == null ? null : _num(v).toInt();

/// "Sector N1 · row 3, seat 12"; the section alone for standing tickets, and
/// null for general admission.
String? seatDescription(
    String? section, String? row, int? number, String? label) {
  if (row != null && row.isNotEmpty && number != null) {
    final seat = tr('seat.rowSeat', {'row': row, 'n': number});
    return section == null || section.isEmpty ? seat : '$section · $seat';
  }
  if (section != null && section.isNotEmpty) return section;
  return label == null || label.isEmpty ? null : label;
}

/// A rectangle in the coordinates of the hall plan.
class SeatArea {
  final String label;
  final double x;
  final double y;
  final double width;
  final double height;
  const SeatArea(this.label, this.x, this.y, this.width, this.height);

  factory SeatArea.fromJson(Map<String, dynamic> j) => SeatArea(
        (j['label'] ?? '') as String,
        _num(j['x']).toDouble(),
        _num(j['y']).toDouble(),
        _num(j['width']).toDouble(),
        _num(j['height']).toDouble(),
      );
}

class SeatSection {
  final int id;
  final String key;
  final String name;
  final bool seated; // false: a standing zone, sold by count
  final SeatArea area;
  final int capacity;
  final bool onSale;
  final int? ticketTypeId;
  final String? ticketTypeName;
  final num? price;
  final int available;
  final int blocked;

  const SeatSection({
    required this.id,
    required this.key,
    required this.name,
    required this.seated,
    required this.area,
    this.capacity = 0,
    this.onSale = false,
    this.ticketTypeId,
    this.ticketTypeName,
    this.price,
    this.available = 0,
    this.blocked = 0,
  });

  /// Whether an attendee can pick seats here.
  bool get selectable =>
      seated && onSale && ticketTypeId != null && available > 0;

  factory SeatSection.fromJson(Map<String, dynamic> j) => SeatSection(
        id: _num(j['id']).toInt(),
        key: (j['key'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        seated: j['kind'] != 'STANDING',
        area: SeatArea.fromJson(j),
        capacity: _num(j['capacity']).toInt(),
        onSale: (j['onSale'] ?? false) as bool,
        ticketTypeId: _optInt(j['ticketTypeId']),
        ticketTypeName: j['ticketTypeName'] as String?,
        price: j['price'] == null ? null : _num(j['price']),
        available: _num(j['available']).toInt(),
        blocked: _num(j['blocked']).toInt(),
      );
}

class SeatMap {
  final bool assigned;
  final String layoutName;
  final double width;
  final double height;
  final SeatArea? stage;
  final List<SeatSection> sections;
  const SeatMap({
    required this.assigned,
    this.layoutName = '',
    required this.width,
    required this.height,
    this.stage,
    this.sections = const [],
  });

  Iterable<SeatSection> sectionsOf(int ticketTypeId) =>
      sections.where((s) => s.ticketTypeId == ticketTypeId);

  factory SeatMap.fromJson(Map<String, dynamic> j) {
    final sections = (j['sections'] as List? ?? [])
        .map((e) => SeatSection.fromJson(e as Map<String, dynamic>))
        .toList();
    double extent(double Function(SeatArea) end) => sections.fold(
        1, (m, s) => end(s.area) > m ? end(s.area) : m);
    return SeatMap(
      assigned: j['seatingMode'] == 'ASSIGNED',
      layoutName: (j['layoutName'] ?? '') as String,
      width: j['width'] == null
          ? extent((a) => a.x + a.width)
          : _num(j['width']).toDouble(),
      height: j['height'] == null
          ? extent((a) => a.y + a.height)
          : _num(j['height']).toDouble(),
      stage: j['stage'] == null
          ? null
          : SeatArea.fromJson(j['stage'] as Map<String, dynamic>),
      sections: sections,
    );
  }
}

enum SeatStatus { available, held, yours, sold, unavailable }

class Seat {
  final int id;
  final String row;
  final int number;
  final double x;
  final double y;
  final bool accessible;
  final SeatStatus status;
  const Seat({
    required this.id,
    required this.row,
    required this.number,
    required this.x,
    required this.y,
    this.accessible = false,
    this.status = SeatStatus.available,
  });

  factory Seat.fromJson(Map<String, dynamic> j) => Seat(
        id: _num(j['id']).toInt(),
        row: '${j['row'] ?? ''}',
        number: _num(j['number']).toInt(),
        x: _num(j['x']).toDouble(),
        y: _num(j['y']).toDouble(),
        accessible: (j['accessible'] ?? false) as bool,
        // A status this version does not know is never offered for sale.
        status: SeatStatus.values.firstWhere(
          (s) => s.name.toUpperCase() == j['status'],
          orElse: () => SeatStatus.unavailable,
        ),
      );
}

/// A seat the attendee has picked but not yet ordered.
class SelectedSeat {
  final int id;
  final int sectionId;
  final String sectionName;
  final String row;
  final int number;
  final int ticketTypeId;
  const SelectedSeat({
    required this.id,
    required this.sectionId,
    required this.sectionName,
    required this.row,
    required this.number,
    required this.ticketTypeId,
  });

  String get label => seatDescription(sectionName, row, number, null)!;
}

/// A ready-made seating plan that can be given to a venue.
class SeatingLayout {
  final String key;
  final String name;
  final int capacity;
  const SeatingLayout(this.key, this.name, this.capacity);

  factory SeatingLayout.fromJson(Map<String, dynamic> j) => SeatingLayout(
        (j['key'] ?? '') as String,
        (j['name'] ?? '') as String,
        _num(j['capacity']).toInt(),
      );
}

// --- Calendar export (SRS 4.11) -----------------------------------------------

class CalendarLinks {
  final bool cancelled;
  final String? google;
  final String? outlook;
  final String? office365;
  const CalendarLinks(
      {this.cancelled = false, this.google, this.outlook, this.office365});

  factory CalendarLinks.fromJson(Map<String, dynamic> j) => CalendarLinks(
        cancelled: (j['cancelled'] ?? false) as bool,
        google: j['googleCalendarUrl'] as String?,
        outlook: j['outlookUrl'] as String?,
        office365: j['office365Url'] as String?,
      );
}
