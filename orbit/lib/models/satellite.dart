class Satellite {
  final String name;
  final String catnum; // NORAD Catalog Number

  Satellite(this.name, this.catnum);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Satellite &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          catnum == other.catnum;

  @override
  int get hashCode => name.hashCode ^ catnum.hashCode;
}