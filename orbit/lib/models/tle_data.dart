class TleLine {
  final String name;
  final String line1;
  final String line2;

  TleLine({required this.name, required this.line1, required this.line2});

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