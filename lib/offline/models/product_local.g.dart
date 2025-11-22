// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_local.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetProductLocalCollection on Isar {
  IsarCollection<ProductLocal> get productLocals => this.collection();
}

const ProductLocalSchema = CollectionSchema(
  name: r'ProductLocal',
  id: 5378941427168448430,
  properties: {
    r'brand': PropertySchema(
      id: 0,
      name: r'brand',
      type: IsarType.string,
    ),
    r'ean13': PropertySchema(
      id: 1,
      name: r'ean13',
      type: IsarType.string,
    ),
    r'eanLc': PropertySchema(
      id: 2,
      name: r'eanLc',
      type: IsarType.string,
    ),
    r'name': PropertySchema(
      id: 3,
      name: r'name',
      type: IsarType.string,
    ),
    r'nameLc': PropertySchema(
      id: 4,
      name: r'nameLc',
      type: IsarType.string,
    ),
    r'price': PropertySchema(
      id: 5,
      name: r'price',
      type: IsarType.double,
    ),
    r'productId': PropertySchema(
      id: 6,
      name: r'productId',
      type: IsarType.string,
    ),
    r'qtyCached': PropertySchema(
      id: 7,
      name: r'qtyCached',
      type: IsarType.double,
    ),
    r'refLc': PropertySchema(
      id: 8,
      name: r'refLc',
      type: IsarType.string,
    ),
    r'reference': PropertySchema(
      id: 9,
      name: r'reference',
      type: IsarType.string,
    ),
    r'updatedAt': PropertySchema(
      id: 10,
      name: r'updatedAt',
      type: IsarType.dateTime,
    )
  },
  estimateSize: _productLocalEstimateSize,
  serialize: _productLocalSerialize,
  deserialize: _productLocalDeserialize,
  deserializeProp: _productLocalDeserializeProp,
  idName: r'isarId',
  indexes: {
    r'productId': IndexSchema(
      id: 5580769080710688203,
      name: r'productId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'productId',
          type: IndexType.hash,
          caseSensitive: false,
        )
      ],
    ),
    r'reference': IndexSchema(
      id: -1595278990251664236,
      name: r'reference',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'reference',
          type: IndexType.hash,
          caseSensitive: false,
        )
      ],
    ),
    r'ean13': IndexSchema(
      id: 5888549713432384916,
      name: r'ean13',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'ean13',
          type: IndexType.hash,
          caseSensitive: false,
        )
      ],
    ),
    r'name': IndexSchema(
      id: 879695947855722453,
      name: r'name',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'name',
          type: IndexType.hash,
          caseSensitive: false,
        )
      ],
    ),
    r'brand': IndexSchema(
      id: 6145529221080171523,
      name: r'brand',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'brand',
          type: IndexType.hash,
          caseSensitive: false,
        )
      ],
    ),
    r'updatedAt': IndexSchema(
      id: -6238191080293565125,
      name: r'updatedAt',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'updatedAt',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'nameLc': IndexSchema(
      id: -8104129344973243864,
      name: r'nameLc',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'nameLc',
          type: IndexType.hash,
          caseSensitive: false,
        )
      ],
    ),
    r'refLc': IndexSchema(
      id: -6767199342805315007,
      name: r'refLc',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'refLc',
          type: IndexType.hash,
          caseSensitive: false,
        )
      ],
    ),
    r'eanLc': IndexSchema(
      id: -6239558241681537106,
      name: r'eanLc',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'eanLc',
          type: IndexType.hash,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _productLocalGetId,
  getLinks: _productLocalGetLinks,
  attach: _productLocalAttach,
  version: '3.1.0+1',
);

int _productLocalEstimateSize(
  ProductLocal object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.brand;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.ean13;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.eanLc;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.name.length * 3;
  bytesCount += 3 + object.nameLc.length * 3;
  bytesCount += 3 + object.productId.length * 3;
  {
    final value = object.refLc;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.reference;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _productLocalSerialize(
  ProductLocal object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.brand);
  writer.writeString(offsets[1], object.ean13);
  writer.writeString(offsets[2], object.eanLc);
  writer.writeString(offsets[3], object.name);
  writer.writeString(offsets[4], object.nameLc);
  writer.writeDouble(offsets[5], object.price);
  writer.writeString(offsets[6], object.productId);
  writer.writeDouble(offsets[7], object.qtyCached);
  writer.writeString(offsets[8], object.refLc);
  writer.writeString(offsets[9], object.reference);
  writer.writeDateTime(offsets[10], object.updatedAt);
}

ProductLocal _productLocalDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ProductLocal();
  object.brand = reader.readStringOrNull(offsets[0]);
  object.ean13 = reader.readStringOrNull(offsets[1]);
  object.eanLc = reader.readStringOrNull(offsets[2]);
  object.isarId = id;
  object.name = reader.readString(offsets[3]);
  object.nameLc = reader.readString(offsets[4]);
  object.price = reader.readDoubleOrNull(offsets[5]);
  object.productId = reader.readString(offsets[6]);
  object.qtyCached = reader.readDoubleOrNull(offsets[7]);
  object.refLc = reader.readStringOrNull(offsets[8]);
  object.reference = reader.readStringOrNull(offsets[9]);
  object.updatedAt = reader.readDateTimeOrNull(offsets[10]);
  return object;
}

P _productLocalDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readDoubleOrNull(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readDoubleOrNull(offset)) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (reader.readStringOrNull(offset)) as P;
    case 10:
      return (reader.readDateTimeOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _productLocalGetId(ProductLocal object) {
  return object.isarId;
}

List<IsarLinkBase<dynamic>> _productLocalGetLinks(ProductLocal object) {
  return [];
}

void _productLocalAttach(
    IsarCollection<dynamic> col, Id id, ProductLocal object) {
  object.isarId = id;
}

extension ProductLocalByIndex on IsarCollection<ProductLocal> {
  Future<ProductLocal?> getByProductId(String productId) {
    return getByIndex(r'productId', [productId]);
  }

  ProductLocal? getByProductIdSync(String productId) {
    return getByIndexSync(r'productId', [productId]);
  }

  Future<bool> deleteByProductId(String productId) {
    return deleteByIndex(r'productId', [productId]);
  }

  bool deleteByProductIdSync(String productId) {
    return deleteByIndexSync(r'productId', [productId]);
  }

  Future<List<ProductLocal?>> getAllByProductId(List<String> productIdValues) {
    final values = productIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'productId', values);
  }

  List<ProductLocal?> getAllByProductIdSync(List<String> productIdValues) {
    final values = productIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'productId', values);
  }

  Future<int> deleteAllByProductId(List<String> productIdValues) {
    final values = productIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'productId', values);
  }

  int deleteAllByProductIdSync(List<String> productIdValues) {
    final values = productIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'productId', values);
  }

  Future<Id> putByProductId(ProductLocal object) {
    return putByIndex(r'productId', object);
  }

  Id putByProductIdSync(ProductLocal object, {bool saveLinks = true}) {
    return putByIndexSync(r'productId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByProductId(List<ProductLocal> objects) {
    return putAllByIndex(r'productId', objects);
  }

  List<Id> putAllByProductIdSync(List<ProductLocal> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'productId', objects, saveLinks: saveLinks);
  }
}

extension ProductLocalQueryWhereSort
    on QueryBuilder<ProductLocal, ProductLocal, QWhere> {
  QueryBuilder<ProductLocal, ProductLocal, QAfterWhere> anyIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterWhere> anyUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'updatedAt'),
      );
    });
  }
}

extension ProductLocalQueryWhere
    on QueryBuilder<ProductLocal, ProductLocal, QWhereClause> {
  QueryBuilder<ProductLocal, ProductLocal, QAfterWhereClause> isarIdEqualTo(
      Id isarId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: isarId,
        upper: isarId,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterWhereClause> isarIdNotEqualTo(
      Id isarId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: isarId, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: isarId, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: isarId, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: isarId, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterWhereClause> isarIdGreaterThan(
      Id isarId,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: isarId, includeLower: include),
      );
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterWhereClause> isarIdLessThan(
      Id isarId,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: isarId, includeUpper: include),
      );
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterWhereClause> isarIdBetween(
    Id lowerIsarId,
    Id upperIsarId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerIsarId,
        includeLower: includeLower,
        upper: upperIsarId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterWhereClause> productIdEqualTo(
      String productId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'productId',
        value: [productId],
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterWhereClause>
      productIdNotEqualTo(String productId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'productId',
              lower: [],
              upper: [productId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'productId',
              lower: [productId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'productId',
              lower: [productId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'productId',
              lower: [],
              upper: [productId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterWhereClause>
      referenceIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'reference',
        value: [null],
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterWhereClause>
      referenceIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'reference',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterWhereClause> referenceEqualTo(
      String? reference) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'reference',
        value: [reference],
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterWhereClause>
      referenceNotEqualTo(String? reference) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'reference',
              lower: [],
              upper: [reference],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'reference',
              lower: [reference],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'reference',
              lower: [reference],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'reference',
              lower: [],
              upper: [reference],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterWhereClause> ean13IsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'ean13',
        value: [null],
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterWhereClause> ean13IsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'ean13',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterWhereClause> ean13EqualTo(
      String? ean13) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'ean13',
        value: [ean13],
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterWhereClause> ean13NotEqualTo(
      String? ean13) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ean13',
              lower: [],
              upper: [ean13],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ean13',
              lower: [ean13],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ean13',
              lower: [ean13],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ean13',
              lower: [],
              upper: [ean13],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterWhereClause> nameEqualTo(
      String name) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'name',
        value: [name],
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterWhereClause> nameNotEqualTo(
      String name) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'name',
              lower: [],
              upper: [name],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'name',
              lower: [name],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'name',
              lower: [name],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'name',
              lower: [],
              upper: [name],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterWhereClause> brandIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'brand',
        value: [null],
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterWhereClause> brandIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'brand',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterWhereClause> brandEqualTo(
      String? brand) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'brand',
        value: [brand],
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterWhereClause> brandNotEqualTo(
      String? brand) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'brand',
              lower: [],
              upper: [brand],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'brand',
              lower: [brand],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'brand',
              lower: [brand],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'brand',
              lower: [],
              upper: [brand],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterWhereClause>
      updatedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'updatedAt',
        value: [null],
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterWhereClause>
      updatedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'updatedAt',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterWhereClause> updatedAtEqualTo(
      DateTime? updatedAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'updatedAt',
        value: [updatedAt],
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterWhereClause>
      updatedAtNotEqualTo(DateTime? updatedAt) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'updatedAt',
              lower: [],
              upper: [updatedAt],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'updatedAt',
              lower: [updatedAt],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'updatedAt',
              lower: [updatedAt],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'updatedAt',
              lower: [],
              upper: [updatedAt],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterWhereClause>
      updatedAtGreaterThan(
    DateTime? updatedAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'updatedAt',
        lower: [updatedAt],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterWhereClause> updatedAtLessThan(
    DateTime? updatedAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'updatedAt',
        lower: [],
        upper: [updatedAt],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterWhereClause> updatedAtBetween(
    DateTime? lowerUpdatedAt,
    DateTime? upperUpdatedAt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'updatedAt',
        lower: [lowerUpdatedAt],
        includeLower: includeLower,
        upper: [upperUpdatedAt],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterWhereClause> nameLcEqualTo(
      String nameLc) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'nameLc',
        value: [nameLc],
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterWhereClause> nameLcNotEqualTo(
      String nameLc) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'nameLc',
              lower: [],
              upper: [nameLc],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'nameLc',
              lower: [nameLc],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'nameLc',
              lower: [nameLc],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'nameLc',
              lower: [],
              upper: [nameLc],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterWhereClause> refLcIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'refLc',
        value: [null],
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterWhereClause> refLcIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'refLc',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterWhereClause> refLcEqualTo(
      String? refLc) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'refLc',
        value: [refLc],
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterWhereClause> refLcNotEqualTo(
      String? refLc) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'refLc',
              lower: [],
              upper: [refLc],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'refLc',
              lower: [refLc],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'refLc',
              lower: [refLc],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'refLc',
              lower: [],
              upper: [refLc],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterWhereClause> eanLcIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'eanLc',
        value: [null],
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterWhereClause> eanLcIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'eanLc',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterWhereClause> eanLcEqualTo(
      String? eanLc) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'eanLc',
        value: [eanLc],
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterWhereClause> eanLcNotEqualTo(
      String? eanLc) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'eanLc',
              lower: [],
              upper: [eanLc],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'eanLc',
              lower: [eanLc],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'eanLc',
              lower: [eanLc],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'eanLc',
              lower: [],
              upper: [eanLc],
              includeUpper: false,
            ));
      }
    });
  }
}

extension ProductLocalQueryFilter
    on QueryBuilder<ProductLocal, ProductLocal, QFilterCondition> {
  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      brandIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'brand',
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      brandIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'brand',
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition> brandEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'brand',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      brandGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'brand',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition> brandLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'brand',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition> brandBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'brand',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      brandStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'brand',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition> brandEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'brand',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition> brandContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'brand',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition> brandMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'brand',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      brandIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'brand',
        value: '',
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      brandIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'brand',
        value: '',
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      ean13IsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'ean13',
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      ean13IsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'ean13',
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition> ean13EqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ean13',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      ean13GreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'ean13',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition> ean13LessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'ean13',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition> ean13Between(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'ean13',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      ean13StartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'ean13',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition> ean13EndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'ean13',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition> ean13Contains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'ean13',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition> ean13Matches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'ean13',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      ean13IsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ean13',
        value: '',
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      ean13IsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'ean13',
        value: '',
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      eanLcIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'eanLc',
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      eanLcIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'eanLc',
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition> eanLcEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'eanLc',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      eanLcGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'eanLc',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition> eanLcLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'eanLc',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition> eanLcBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'eanLc',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      eanLcStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'eanLc',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition> eanLcEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'eanLc',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition> eanLcContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'eanLc',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition> eanLcMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'eanLc',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      eanLcIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'eanLc',
        value: '',
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      eanLcIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'eanLc',
        value: '',
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition> isarIdEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isarId',
        value: value,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      isarIdGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'isarId',
        value: value,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      isarIdLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'isarId',
        value: value,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition> isarIdBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'isarId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition> nameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      nameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition> nameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition> nameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'name',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      nameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition> nameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition> nameContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition> nameMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'name',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'name',
        value: '',
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'name',
        value: '',
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition> nameLcEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'nameLc',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      nameLcGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'nameLc',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      nameLcLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'nameLc',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition> nameLcBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'nameLc',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      nameLcStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'nameLc',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      nameLcEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'nameLc',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      nameLcContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'nameLc',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition> nameLcMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'nameLc',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      nameLcIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'nameLc',
        value: '',
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      nameLcIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'nameLc',
        value: '',
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      priceIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'price',
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      priceIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'price',
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition> priceEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'price',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      priceGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'price',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition> priceLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'price',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition> priceBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'price',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      productIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'productId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      productIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'productId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      productIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'productId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      productIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'productId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      productIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'productId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      productIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'productId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      productIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'productId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      productIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'productId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      productIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'productId',
        value: '',
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      productIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'productId',
        value: '',
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      qtyCachedIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'qtyCached',
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      qtyCachedIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'qtyCached',
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      qtyCachedEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'qtyCached',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      qtyCachedGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'qtyCached',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      qtyCachedLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'qtyCached',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      qtyCachedBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'qtyCached',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      refLcIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'refLc',
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      refLcIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'refLc',
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition> refLcEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'refLc',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      refLcGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'refLc',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition> refLcLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'refLc',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition> refLcBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'refLc',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      refLcStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'refLc',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition> refLcEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'refLc',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition> refLcContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'refLc',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition> refLcMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'refLc',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      refLcIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'refLc',
        value: '',
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      refLcIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'refLc',
        value: '',
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      referenceIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'reference',
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      referenceIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'reference',
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      referenceEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'reference',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      referenceGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'reference',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      referenceLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'reference',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      referenceBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'reference',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      referenceStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'reference',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      referenceEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'reference',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      referenceContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'reference',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      referenceMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'reference',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      referenceIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'reference',
        value: '',
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      referenceIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'reference',
        value: '',
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      updatedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'updatedAt',
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      updatedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'updatedAt',
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      updatedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      updatedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      updatedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterFilterCondition>
      updatedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'updatedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension ProductLocalQueryObject
    on QueryBuilder<ProductLocal, ProductLocal, QFilterCondition> {}

extension ProductLocalQueryLinks
    on QueryBuilder<ProductLocal, ProductLocal, QFilterCondition> {}

extension ProductLocalQuerySortBy
    on QueryBuilder<ProductLocal, ProductLocal, QSortBy> {
  QueryBuilder<ProductLocal, ProductLocal, QAfterSortBy> sortByBrand() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'brand', Sort.asc);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterSortBy> sortByBrandDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'brand', Sort.desc);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterSortBy> sortByEan13() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ean13', Sort.asc);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterSortBy> sortByEan13Desc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ean13', Sort.desc);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterSortBy> sortByEanLc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'eanLc', Sort.asc);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterSortBy> sortByEanLcDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'eanLc', Sort.desc);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterSortBy> sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterSortBy> sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterSortBy> sortByNameLc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nameLc', Sort.asc);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterSortBy> sortByNameLcDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nameLc', Sort.desc);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterSortBy> sortByPrice() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'price', Sort.asc);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterSortBy> sortByPriceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'price', Sort.desc);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterSortBy> sortByProductId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'productId', Sort.asc);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterSortBy> sortByProductIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'productId', Sort.desc);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterSortBy> sortByQtyCached() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'qtyCached', Sort.asc);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterSortBy> sortByQtyCachedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'qtyCached', Sort.desc);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterSortBy> sortByRefLc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'refLc', Sort.asc);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterSortBy> sortByRefLcDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'refLc', Sort.desc);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterSortBy> sortByReference() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reference', Sort.asc);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterSortBy> sortByReferenceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reference', Sort.desc);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterSortBy> sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension ProductLocalQuerySortThenBy
    on QueryBuilder<ProductLocal, ProductLocal, QSortThenBy> {
  QueryBuilder<ProductLocal, ProductLocal, QAfterSortBy> thenByBrand() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'brand', Sort.asc);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterSortBy> thenByBrandDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'brand', Sort.desc);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterSortBy> thenByEan13() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ean13', Sort.asc);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterSortBy> thenByEan13Desc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ean13', Sort.desc);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterSortBy> thenByEanLc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'eanLc', Sort.asc);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterSortBy> thenByEanLcDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'eanLc', Sort.desc);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterSortBy> thenByIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isarId', Sort.asc);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterSortBy> thenByIsarIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isarId', Sort.desc);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterSortBy> thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterSortBy> thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterSortBy> thenByNameLc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nameLc', Sort.asc);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterSortBy> thenByNameLcDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nameLc', Sort.desc);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterSortBy> thenByPrice() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'price', Sort.asc);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterSortBy> thenByPriceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'price', Sort.desc);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterSortBy> thenByProductId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'productId', Sort.asc);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterSortBy> thenByProductIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'productId', Sort.desc);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterSortBy> thenByQtyCached() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'qtyCached', Sort.asc);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterSortBy> thenByQtyCachedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'qtyCached', Sort.desc);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterSortBy> thenByRefLc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'refLc', Sort.asc);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterSortBy> thenByRefLcDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'refLc', Sort.desc);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterSortBy> thenByReference() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reference', Sort.asc);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterSortBy> thenByReferenceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reference', Sort.desc);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QAfterSortBy> thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension ProductLocalQueryWhereDistinct
    on QueryBuilder<ProductLocal, ProductLocal, QDistinct> {
  QueryBuilder<ProductLocal, ProductLocal, QDistinct> distinctByBrand(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'brand', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QDistinct> distinctByEan13(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'ean13', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QDistinct> distinctByEanLc(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'eanLc', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QDistinct> distinctByName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QDistinct> distinctByNameLc(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'nameLc', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QDistinct> distinctByPrice() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'price');
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QDistinct> distinctByProductId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'productId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QDistinct> distinctByQtyCached() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'qtyCached');
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QDistinct> distinctByRefLc(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'refLc', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QDistinct> distinctByReference(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'reference', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ProductLocal, ProductLocal, QDistinct> distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }
}

extension ProductLocalQueryProperty
    on QueryBuilder<ProductLocal, ProductLocal, QQueryProperty> {
  QueryBuilder<ProductLocal, int, QQueryOperations> isarIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isarId');
    });
  }

  QueryBuilder<ProductLocal, String?, QQueryOperations> brandProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'brand');
    });
  }

  QueryBuilder<ProductLocal, String?, QQueryOperations> ean13Property() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'ean13');
    });
  }

  QueryBuilder<ProductLocal, String?, QQueryOperations> eanLcProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'eanLc');
    });
  }

  QueryBuilder<ProductLocal, String, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<ProductLocal, String, QQueryOperations> nameLcProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'nameLc');
    });
  }

  QueryBuilder<ProductLocal, double?, QQueryOperations> priceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'price');
    });
  }

  QueryBuilder<ProductLocal, String, QQueryOperations> productIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'productId');
    });
  }

  QueryBuilder<ProductLocal, double?, QQueryOperations> qtyCachedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'qtyCached');
    });
  }

  QueryBuilder<ProductLocal, String?, QQueryOperations> refLcProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'refLc');
    });
  }

  QueryBuilder<ProductLocal, String?, QQueryOperations> referenceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'reference');
    });
  }

  QueryBuilder<ProductLocal, DateTime?, QQueryOperations> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }
}
