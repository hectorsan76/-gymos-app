class Member {
  final String id;

  String firstName;
  String lastName;
  String phone;
  String email;

  String? photoUrl;
  String? address;
  String? country;
  String? instagram;
  String? notes;

  DateTime expiryDate;
  DateTime? pausedUntil;
  int? remainingDaysOnPause;
  bool isCancelled;

  // ✅ NEW
  String? membershipType;

  // ✅ CHECK-INS LIVE HERE
  List<DateTime> checkIns;

  Member({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.email,
    required this.expiryDate,
    this.photoUrl,
    this.address,
    this.country,
    this.instagram,
    this.notes,
    this.pausedUntil,
    this.remainingDaysOnPause,
    this.isCancelled = false,
    this.membershipType, // ✅ NEW
    List<DateTime>? checkIns,
  }) : checkIns = checkIns ?? [];

  String get fullName => "$firstName $lastName";

  String get statusLabel {
    if (isCancelled) return "CANCELLED";
    if (pausedUntil != null && pausedUntil!.isAfter(DateTime.now())) {
      return "PAUSED";
    }
    return isActive ? "ACTIVE" : "EXPIRED";
  }

  bool get isActive {
    if (isCancelled) return false;

    if (pausedUntil != null && pausedUntil!.isAfter(DateTime.now())) {
      return false;
    }

    final endOfDay = DateTime(
      expiryDate.year,
      expiryDate.month,
      expiryDate.day,
      23,
      59,
      59,
    );

    return endOfDay.isAfter(DateTime.now());
  }

  int? get daysSinceLastVisit {
    if (checkIns.isEmpty) return null;
    return DateTime.now().difference(checkIns.last).inDays;
  }

  bool get isInactive {
    final days = daysSinceLastVisit;
    if (days == null) return true;
    return days >= 7;
  }

  void renewMembership(int durationDays) {
    final now = DateTime.now();

    if (expiryDate.isAfter(now)) {
      expiryDate = expiryDate.add(Duration(days: durationDays));
    } else {
      expiryDate = now.add(Duration(days: durationDays));
    }

    isCancelled = false;
    pausedUntil = null;
    remainingDaysOnPause = null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'email': email,
      'photo_url': photoUrl,
      'address': address,
      'country': country,
      'instagram': instagram,
      'notes': notes,
      'expiry_date': expiryDate.toIso8601String(),
      'paused_until': pausedUntil?.toIso8601String(),
      'remaining_days_on_pause': remainingDaysOnPause,
      'is_cancelled': isCancelled,
      'membership_type': membershipType, // ✅ NEW
    };
  }

  // 🔥 FULL FIXED PARSER WITH CHECK-INS
  factory Member.fromJson(Map<String, dynamic> json) {
    DateTime safeParse(dynamic value) {
      if (value == null) return DateTime.now();
      try {
        return DateTime.parse(value.toString());
      } catch (_) {
        return DateTime.now();
      }
    }

    DateTime? safeParseNullable(dynamic value) {
      if (value == null) return null;
      try {
        return DateTime.parse(value.toString());
      } catch (_) {
        return null;
      }
    }

    // ✅ PARSE CHECK-INS
    List<DateTime> parsedCheckIns = [];

    if (json['check_ins'] != null && json['check_ins'] is List) {
      parsedCheckIns = (json['check_ins'] as List)
          .map((e) {
            try {
              return DateTime.parse(e['created_at']);
            } catch (_) {
              return null;
            }
          })
          .whereType<DateTime>()
          .toList()
        ..sort();
    }

    final rawId = json['id']?.toString() ?? "";

    final isUuid = rawId.contains("-") && rawId.length > 30;

    if (!isUuid) {
      print("⚠️ INVALID MEMBER ID DETECTED: $rawId");
    }

    return Member(
      id: rawId,
      firstName: json['first_name']?.toString() ?? "",
      lastName: json['last_name']?.toString() ?? "",
      phone: json['phone']?.toString() ?? "",
      email: json['email']?.toString() ?? "",
      photoUrl: json['photo_url']?.toString(),
      address: json['address']?.toString(),
      country: json['country']?.toString(),
      instagram: json['instagram']?.toString(),
      notes: json['notes']?.toString(),
      expiryDate: safeParse(json['expiry_date']),
      pausedUntil: safeParseNullable(json['paused_until']),
      remainingDaysOnPause: json['remaining_days_on_pause'] is int
          ? json['remaining_days_on_pause']
          : null,
      isCancelled: json['is_cancelled'] ?? false,
      membershipType: json['membership_type']?.toString(), // ✅ NEW
      checkIns: parsedCheckIns,
    );
  }
}