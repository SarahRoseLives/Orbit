class TleLine {
  final String name;
  final String line1;
  final String line2;

  TleLine({required this.name, required this.line1, required this.line2});

  // Factory constructor for creating a new TleLine instance from a map.
  factory TleLine.fromJson(Map<String, dynamic> json) {
    return TleLine(
      name: json['name'] as String,
      line1: json['line1'] as String,
      line2: json['line2'] as String,
    );
  }

  // Method for converting a TleLine instance to a map.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'line1': line1,
      'line2': line2,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TleLine &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          line1 == other.line1 &&
          line2 == other.line2;

  @override
  int get hashCode => name.hashCode ^ line1.hashCode ^ line2.hashCode;
}