// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_item_local.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetProjectItemLocalCollection on Isar {
  IsarCollection<ProjectItemLocal> get projectItemLocals => this.collection();
}

const ProjectItemLocalSchema = CollectionSchema(
  name: r'ProjectItemLocal',
  id: 4340536258635372694,
  properties: {
    r'itemId': PropertySchema(
      id: 0,
      name: r'itemId',
      type: IsarType.string,
    ),
    r'note': PropertySchema(
      id: 1,
      name: r'note',
      type: IsarType.string,
    ),
    r'productId': PropertySchema(
      id: 2,
      name: r'productId',
      type: IsarType.string,
    ),
    r'projectId': PropertySchema(
      id: 3,
      name: r'projectId',
      type: IsarType.string,
    ),
    r'qty': PropertySchema(
      id: 4,
      name: r'qty',
      type: IsarType.double,
    ),
    r'serverVersion': PropertySchema(
      id: 5,
      name: r'serverVersion',
      type: IsarType.long,
    ),
    r'syncState': PropertySchema(
      id: 6,
      name: r'syncState',
      type: IsarType.byte,
      enumMap: _ProjectItemLocalsyncStateEnumValueMap,
    ),
    r'updatedAtLocal': PropertySchema(
      id: 7,
      name: r'updatedAtLocal',
      type: IsarType.dateTime,
    ),
    r'updatedAtServer': PropertySchema(
      id: 8,
      name: r'updatedAtServer',
      type: IsarType.dateTime,
    )
  },
  estimateSize: _projectItemLocalEstimateSize,
  serialize: _projectItemLocalSerialize,
  deserialize: _projectItemLocalDeserialize,
  deserializeProp: _projectItemLocalDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _projectItemLocalGetId,
  getLinks: _projectItemLocalGetLinks,
  attach: _projectItemLocalAttach,
  version: '3.1.0+1',
);

int _projectItemLocalEstimateSize(
  ProjectItemLocal object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.itemId.length * 3;
  {
    final value = object.note;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.productId.length * 3;
  bytesCount += 3 + object.projectId.length * 3;
  return bytesCount;
}

void _projectItemLocalSerialize(
  ProjectItemLocal object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.itemId);
  writer.writeString(offsets[1], object.note);
  writer.writeString(offsets[2], object.productId);
  writer.writeString(offsets[3], object.projectId);
  writer.writeDouble(offsets[4], object.qty);
  writer.writeLong(offsets[5], object.serverVersion);
  writer.writeByte(offsets[6], object.syncState.index);
  writer.writeDateTime(offsets[7], object.updatedAtLocal);
  writer.writeDateTime(offsets[8], object.updatedAtServer);
}

ProjectItemLocal _projectItemLocalDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ProjectItemLocal(
    id: id,
    itemId: reader.readString(offsets[0]),
    note: reader.readStringOrNull(offsets[1]),
    productId: reader.readString(offsets[2]),
    projectId: reader.readString(offsets[3]),
    qty: reader.readDouble(offsets[4]),
    serverVersion: reader.readLongOrNull(offsets[5]) ?? 0,
    syncState: _ProjectItemLocalsyncStateValueEnumMap[
            reader.readByteOrNull(offsets[6])] ??
        SyncState.synced,
    updatedAtServer: reader.readDateTimeOrNull(offsets[8]),
  );
  object.updatedAtLocal = reader.readDateTime(offsets[7]);
  return object;
}

P _projectItemLocalDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readDouble(offset)) as P;
    case 5:
      return (reader.readLongOrNull(offset) ?? 0) as P;
    case 6:
      return (_ProjectItemLocalsyncStateValueEnumMap[
              reader.readByteOrNull(offset)] ??
          SyncState.synced) as P;
    case 7:
      return (reader.readDateTime(offset)) as P;
    case 8:
      return (reader.readDateTimeOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _ProjectItemLocalsyncStateEnumValueMap = {
  'localOnly': 0,
  'pending': 1,
  'synced': 2,
  'needsAttention': 3,
};
const _ProjectItemLocalsyncStateValueEnumMap = {
  0: SyncState.localOnly,
  1: SyncState.pending,
  2: SyncState.synced,
  3: SyncState.needsAttention,
};

Id _projectItemLocalGetId(ProjectItemLocal object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _projectItemLocalGetLinks(ProjectItemLocal object) {
  return [];
}

void _projectItemLocalAttach(
    IsarCollection<dynamic> col, Id id, ProjectItemLocal object) {
  object.id = id;
}

extension ProjectItemLocalQueryWhereSort
    on QueryBuilder<ProjectItemLocal, ProjectItemLocal, QWhere> {
  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension ProjectItemLocalQueryWhere
    on QueryBuilder<ProjectItemLocal, ProjectItemLocal, QWhereClause> {
  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterWhereClause>
      idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension ProjectItemLocalQueryFilter
    on QueryBuilder<ProjectItemLocal, ProjectItemLocal, QFilterCondition> {
  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      itemIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'itemId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      itemIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'itemId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      itemIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'itemId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      itemIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'itemId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      itemIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'itemId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      itemIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'itemId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      itemIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'itemId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      itemIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'itemId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      itemIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'itemId',
        value: '',
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      itemIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'itemId',
        value: '',
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      noteIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'note',
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      noteIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'note',
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      noteEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      noteGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      noteLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      noteBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'note',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      noteStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      noteEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      noteContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      noteMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'note',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      noteIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'note',
        value: '',
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      noteIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'note',
        value: '',
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
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

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
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

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
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

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
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

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
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

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
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

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      productIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'productId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      productIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'productId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      productIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'productId',
        value: '',
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      productIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'productId',
        value: '',
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      projectIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'projectId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      projectIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'projectId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      projectIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'projectId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      projectIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'projectId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      projectIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'projectId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      projectIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'projectId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      projectIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'projectId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      projectIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'projectId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      projectIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'projectId',
        value: '',
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      projectIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'projectId',
        value: '',
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      qtyEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'qty',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      qtyGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'qty',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      qtyLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'qty',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      qtyBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'qty',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      serverVersionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'serverVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      serverVersionGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'serverVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      serverVersionLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'serverVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      serverVersionBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'serverVersion',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      syncStateEqualTo(SyncState value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'syncState',
        value: value,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      syncStateGreaterThan(
    SyncState value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'syncState',
        value: value,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      syncStateLessThan(
    SyncState value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'syncState',
        value: value,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      syncStateBetween(
    SyncState lower,
    SyncState upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'syncState',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      updatedAtLocalEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAtLocal',
        value: value,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      updatedAtLocalGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'updatedAtLocal',
        value: value,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      updatedAtLocalLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'updatedAtLocal',
        value: value,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      updatedAtLocalBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'updatedAtLocal',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      updatedAtServerIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'updatedAtServer',
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      updatedAtServerIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'updatedAtServer',
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      updatedAtServerEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAtServer',
        value: value,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      updatedAtServerGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'updatedAtServer',
        value: value,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      updatedAtServerLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'updatedAtServer',
        value: value,
      ));
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterFilterCondition>
      updatedAtServerBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'updatedAtServer',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension ProjectItemLocalQueryObject
    on QueryBuilder<ProjectItemLocal, ProjectItemLocal, QFilterCondition> {}

extension ProjectItemLocalQueryLinks
    on QueryBuilder<ProjectItemLocal, ProjectItemLocal, QFilterCondition> {}

extension ProjectItemLocalQuerySortBy
    on QueryBuilder<ProjectItemLocal, ProjectItemLocal, QSortBy> {
  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterSortBy>
      sortByItemId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'itemId', Sort.asc);
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterSortBy>
      sortByItemIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'itemId', Sort.desc);
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterSortBy> sortByNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.asc);
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterSortBy>
      sortByNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.desc);
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterSortBy>
      sortByProductId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'productId', Sort.asc);
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterSortBy>
      sortByProductIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'productId', Sort.desc);
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterSortBy>
      sortByProjectId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'projectId', Sort.asc);
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterSortBy>
      sortByProjectIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'projectId', Sort.desc);
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterSortBy> sortByQty() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'qty', Sort.asc);
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterSortBy>
      sortByQtyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'qty', Sort.desc);
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterSortBy>
      sortByServerVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serverVersion', Sort.asc);
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterSortBy>
      sortByServerVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serverVersion', Sort.desc);
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterSortBy>
      sortBySyncState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncState', Sort.asc);
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterSortBy>
      sortBySyncStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncState', Sort.desc);
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterSortBy>
      sortByUpdatedAtLocal() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAtLocal', Sort.asc);
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterSortBy>
      sortByUpdatedAtLocalDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAtLocal', Sort.desc);
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterSortBy>
      sortByUpdatedAtServer() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAtServer', Sort.asc);
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterSortBy>
      sortByUpdatedAtServerDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAtServer', Sort.desc);
    });
  }
}

extension ProjectItemLocalQuerySortThenBy
    on QueryBuilder<ProjectItemLocal, ProjectItemLocal, QSortThenBy> {
  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterSortBy>
      thenByItemId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'itemId', Sort.asc);
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterSortBy>
      thenByItemIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'itemId', Sort.desc);
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterSortBy> thenByNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.asc);
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterSortBy>
      thenByNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.desc);
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterSortBy>
      thenByProductId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'productId', Sort.asc);
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterSortBy>
      thenByProductIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'productId', Sort.desc);
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterSortBy>
      thenByProjectId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'projectId', Sort.asc);
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterSortBy>
      thenByProjectIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'projectId', Sort.desc);
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterSortBy> thenByQty() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'qty', Sort.asc);
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterSortBy>
      thenByQtyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'qty', Sort.desc);
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterSortBy>
      thenByServerVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serverVersion', Sort.asc);
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterSortBy>
      thenByServerVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serverVersion', Sort.desc);
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterSortBy>
      thenBySyncState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncState', Sort.asc);
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterSortBy>
      thenBySyncStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncState', Sort.desc);
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterSortBy>
      thenByUpdatedAtLocal() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAtLocal', Sort.asc);
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterSortBy>
      thenByUpdatedAtLocalDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAtLocal', Sort.desc);
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterSortBy>
      thenByUpdatedAtServer() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAtServer', Sort.asc);
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QAfterSortBy>
      thenByUpdatedAtServerDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAtServer', Sort.desc);
    });
  }
}

extension ProjectItemLocalQueryWhereDistinct
    on QueryBuilder<ProjectItemLocal, ProjectItemLocal, QDistinct> {
  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QDistinct> distinctByItemId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'itemId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QDistinct> distinctByNote(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'note', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QDistinct>
      distinctByProductId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'productId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QDistinct>
      distinctByProjectId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'projectId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QDistinct> distinctByQty() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'qty');
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QDistinct>
      distinctByServerVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'serverVersion');
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QDistinct>
      distinctBySyncState() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'syncState');
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QDistinct>
      distinctByUpdatedAtLocal() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAtLocal');
    });
  }

  QueryBuilder<ProjectItemLocal, ProjectItemLocal, QDistinct>
      distinctByUpdatedAtServer() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAtServer');
    });
  }
}

extension ProjectItemLocalQueryProperty
    on QueryBuilder<ProjectItemLocal, ProjectItemLocal, QQueryProperty> {
  QueryBuilder<ProjectItemLocal, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ProjectItemLocal, String, QQueryOperations> itemIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'itemId');
    });
  }

  QueryBuilder<ProjectItemLocal, String?, QQueryOperations> noteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'note');
    });
  }

  QueryBuilder<ProjectItemLocal, String, QQueryOperations> productIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'productId');
    });
  }

  QueryBuilder<ProjectItemLocal, String, QQueryOperations> projectIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'projectId');
    });
  }

  QueryBuilder<ProjectItemLocal, double, QQueryOperations> qtyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'qty');
    });
  }

  QueryBuilder<ProjectItemLocal, int, QQueryOperations>
      serverVersionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'serverVersion');
    });
  }

  QueryBuilder<ProjectItemLocal, SyncState, QQueryOperations>
      syncStateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'syncState');
    });
  }

  QueryBuilder<ProjectItemLocal, DateTime, QQueryOperations>
      updatedAtLocalProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAtLocal');
    });
  }

  QueryBuilder<ProjectItemLocal, DateTime?, QQueryOperations>
      updatedAtServerProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAtServer');
    });
  }
}
