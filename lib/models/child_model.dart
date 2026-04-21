class ChildModel {
  final String id;
  final String householdId;
  final String name;
  final String? schoolName;
  final String? className;
  final String? dropoffTime;
  final String? pickupTime;
  final bool snackRequired;
  final String? specialDayNotes;
  final String? notes;

  ChildModel({
    required this.id,
    required this.householdId,
    required this.name,
    this.schoolName,
    this.className,
    this.dropoffTime,
    this.pickupTime,
    this.snackRequired = false,
    this.specialDayNotes,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'householdId': householdId,
        'name': name,
        'schoolName': schoolName,
        'className': className,
        'dropoffTime': dropoffTime,
        'pickupTime': pickupTime,
        'snackRequired': snackRequired,
        'specialDayNotes': specialDayNotes,
        'notes': notes,
      };

  factory ChildModel.fromJson(Map<String, dynamic> json) => ChildModel(
        id: json['id'],
        householdId: json['householdId'],
        name: json['name'],
        schoolName: json['schoolName'],
        className: json['className'],
        dropoffTime: json['dropoffTime'],
        pickupTime: json['pickupTime'],
        snackRequired: json['snackRequired'] ?? false,
        specialDayNotes: json['specialDayNotes'],
        notes: json['notes'],
      );

  ChildModel copyWith({
    String? name,
    String? schoolName,
    String? className,
    String? dropoffTime,
    String? pickupTime,
    bool? snackRequired,
    String? specialDayNotes,
    String? notes,
  }) =>
      ChildModel(
        id: id,
        householdId: householdId,
        name: name ?? this.name,
        schoolName: schoolName ?? this.schoolName,
        className: className ?? this.className,
        dropoffTime: dropoffTime ?? this.dropoffTime,
        pickupTime: pickupTime ?? this.pickupTime,
        snackRequired: snackRequired ?? this.snackRequired,
        specialDayNotes: specialDayNotes ?? this.specialDayNotes,
        notes: notes ?? this.notes,
      );
}

class ChildRoutineLog {
  final String id;
  final String childId;
  final DateTime date;
  bool uniformReady;
  bool shoesReady;
  bool lunchPacked;
  bool snackPacked;
  bool swimwearReady;
  bool droppedOff;
  bool pickedUp;
  final String? notes;
  final String updatedByUserId;

  ChildRoutineLog({
    required this.id,
    required this.childId,
    required this.date,
    this.uniformReady = false,
    this.shoesReady = false,
    this.lunchPacked = false,
    this.snackPacked = false,
    this.swimwearReady = false,
    this.droppedOff = false,
    this.pickedUp = false,
    this.notes,
    required this.updatedByUserId,
  });

  int get checkedCount {
    int count = 0;
    if (uniformReady) count++;
    if (shoesReady) count++;
    if (lunchPacked) count++;
    if (snackPacked) count++;
    if (swimwearReady) count++;
    if (droppedOff) count++;
    if (pickedUp) count++;
    return count;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'childId': childId,
        'date': date.toIso8601String(),
        'uniformReady': uniformReady,
        'shoesReady': shoesReady,
        'lunchPacked': lunchPacked,
        'snackPacked': snackPacked,
        'swimwearReady': swimwearReady,
        'droppedOff': droppedOff,
        'pickedUp': pickedUp,
        'notes': notes,
        'updatedByUserId': updatedByUserId,
      };

  factory ChildRoutineLog.fromJson(Map<String, dynamic> json) =>
      ChildRoutineLog(
        id: json['id'],
        childId: json['childId'],
        date: DateTime.parse(json['date']),
        uniformReady: json['uniformReady'] ?? false,
        shoesReady: json['shoesReady'] ?? false,
        lunchPacked: json['lunchPacked'] ?? false,
        snackPacked: json['snackPacked'] ?? false,
        swimwearReady: json['swimwearReady'] ?? false,
        droppedOff: json['droppedOff'] ?? false,
        pickedUp: json['pickedUp'] ?? false,
        notes: json['notes'],
        updatedByUserId: json['updatedByUserId'],
      );
}
