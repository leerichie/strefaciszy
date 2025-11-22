import 'package:isar/isar.dart';

part 'product_local.g.dart';

/// Slim, searchable product slice stored on-device for offline use.
@collection
class ProductLocal {
  Id isarId = Isar.autoIncrement; // local Isar id

  /// Server/API id as string (unique).
  @Index(unique: true, replace: true, caseSensitive: false)
  late String productId;

  /// SKU / index
  @Index(caseSensitive: false)
  String? reference;

  /// Barcode
  @Index(caseSensitive: false)
  String? ean13;

  /// Display name
  @Index(caseSensitive: false)
  String name = '';

  /// Optional brand
  @Index(caseSensitive: false)
  String? brand;

  /// Last known values for quick display while offline
  double? price;
  double? qtyCached;

  /// For delta syncs
  @Index()
  DateTime? updatedAt;

  // Precomputed lowercase fields for fast contains() filters
  @Index(type: IndexType.hash, caseSensitive: false)
  late String nameLc;

  @Index(type: IndexType.hash, caseSensitive: false)
  String? refLc;

  @Index(type: IndexType.hash, caseSensitive: false)
  String? eanLc;

  void normalize() {
    nameLc = name.toLowerCase();
    refLc = reference?.toLowerCase();
    eanLc = ean13?.toLowerCase();
  }
}
