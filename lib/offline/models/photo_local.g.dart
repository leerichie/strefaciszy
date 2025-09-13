// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'photo_local.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetPhotoLocalCollection on Isar {
  IsarCollection<PhotoLocal> get photoLocals => this.collection();
}

const PhotoLocalSchema = CollectionSchema(
  name: r'PhotoLocal',
  id: 1590527549657343706,
  properties: {
    r'cloudUrl': PropertySchema(
      id: 0,
      name: r'cloudUrl',
      type: IsarType.string,
    ),
    r'createdAtLocal': PropertySchema(
      id: 1,
      name: r'createdAtLocal',
      type: IsarType.dateTime,
    ),
    r'localPath': PropertySchema(
      id: 2,
      name: r'localPath',
      type: IsarType.string,
    ),
    r'photoId': PropertySchema(
      id: 3,
      name: r'photoId',
      type: IsarType.string,
    ),
    r'projectId': PropertySchema(
      id: 4,
      name: r'projectId',
      type: IsarType.string,
    ),
    r'syncState': PropertySchema(
      id: 5,
      name: r'syncState',
      type: IsarType.byte,
      enumMap: _PhotoLocalsyncStateEnumValueMap,
    ),
    r'thumbPath': PropertySchema(
      id: 6,
      name: r'thumbPath',
      type: IsarType.string,
    )
  },
  estimateSize: _photoLocalEstimateSize,
  serialize: _photoLocalSerialize,
  deserialize: _photoLocalDeserialize,
  deserializeProp: _photoLocalDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _photoLocalGetId,
  getLinks: _photoLocalGetLinks,
  attach: _photoLocalAttach,
  version: '3.1.0+1',
);

int _photoLocalEstimateSize(
  PhotoLocal object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.cloudUrl;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.localPath.length * 3;
  bytesCount += 3 + object.photoId.length * 3;
  bytesCount += 3 + object.projectId.length * 3;
  {
    final value = object.thumbPath;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _photoLocalSerialize(
  PhotoLocal object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.cloudUrl);
  writer.writeDateTime(offsets[1], object.createdAtLocal);
  writer.writeString(offsets[2], object.localPath);
  writer.writeString(offsets[3], object.photoId);
  writer.writeString(offsets[4], object.projectId);
  writer.writeByte(offsets[5], object.syncState.index);
  writer.writeString(offsets[6], object.thumbPath);
}

PhotoLocal _photoLocalDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = PhotoLocal(
    cloudUrl: reader.readStringOrNull(offsets[0]),
    id: id,
    localPath: reader.readString(offsets[2]),
    photoId: reader.readString(offsets[3]),
    projectId: reader.readString(offsets[4]),
    syncState:
        _PhotoLocalsyncStateValueEnumMap[reader.readByteOrNull(offsets[5])] ??
            SyncState.localOnly,
    thumbPath: reader.readStringOrNull(offsets[6]),
  );
  object.createdAtLocal = reader.readDateTime(offsets[1]);
  return object;
}

P _photoLocalDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readDateTime(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (_PhotoLocalsyncStateValueEnumMap[reader.readByteOrNull(offset)] ??
          SyncState.localOnly) as P;
    case 6:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _PhotoLocalsyncStateEnumValueMap = {
  'localOnly': 0,
  'pending': 1,
  'synced': 2,
  'needsAttention': 3,
};
const _PhotoLocalsyncStateValueEnumMap = {
  0: SyncState.localOnly,
  1: SyncState.pending,
  2: SyncState.synced,
  3: SyncState.needsAttention,
};

Id _photoLocalGetId(PhotoLocal object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _photoLocalGetLinks(PhotoLocal object) {
  return [];
}

void _photoLocalAttach(IsarCollection<dynamic> col, Id id, PhotoLocal object) {
  object.id = id;
}

extension PhotoLocalQueryWhereSort
    on QueryBuilder<PhotoLocal, PhotoLocal, QWhere> {
  QueryBuilder<PhotoLocal, PhotoLocal, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension PhotoLocalQueryWhere
    on QueryBuilder<PhotoLocal, PhotoLocal, QWhereClause> {
  QueryBuilder<PhotoLocal, PhotoLocal, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterWhereClause> idBetween(
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

extension PhotoLocalQueryFilter
    on QueryBuilder<PhotoLocal, PhotoLocal, QFilterCondition> {
  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition> cloudUrlIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'cloudUrl',
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition>
      cloudUrlIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'cloudUrl',
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition> cloudUrlEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cloudUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition>
      cloudUrlGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'cloudUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition> cloudUrlLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'cloudUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition> cloudUrlBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'cloudUrl',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition>
      cloudUrlStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'cloudUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition> cloudUrlEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'cloudUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition> cloudUrlContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'cloudUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition> cloudUrlMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'cloudUrl',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition>
      cloudUrlIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'cloudUrl',
        value: '',
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition>
      cloudUrlIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'cloudUrl',
        value: '',
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition>
      createdAtLocalEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAtLocal',
        value: value,
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition>
      createdAtLocalGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAtLocal',
        value: value,
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition>
      createdAtLocalLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAtLocal',
        value: value,
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition>
      createdAtLocalBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAtLocal',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition> idBetween(
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

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition> localPathEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'localPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition>
      localPathGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'localPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition> localPathLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'localPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition> localPathBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'localPath',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition>
      localPathStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'localPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition> localPathEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'localPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition> localPathContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'localPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition> localPathMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'localPath',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition>
      localPathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'localPath',
        value: '',
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition>
      localPathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'localPath',
        value: '',
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition> photoIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'photoId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition>
      photoIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'photoId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition> photoIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'photoId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition> photoIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'photoId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition> photoIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'photoId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition> photoIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'photoId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition> photoIdContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'photoId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition> photoIdMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'photoId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition> photoIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'photoId',
        value: '',
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition>
      photoIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'photoId',
        value: '',
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition> projectIdEqualTo(
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

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition>
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

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition> projectIdLessThan(
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

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition> projectIdBetween(
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

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition>
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

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition> projectIdEndsWith(
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

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition> projectIdContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'projectId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition> projectIdMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'projectId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition>
      projectIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'projectId',
        value: '',
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition>
      projectIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'projectId',
        value: '',
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition> syncStateEqualTo(
      SyncState value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'syncState',
        value: value,
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition>
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

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition> syncStateLessThan(
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

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition> syncStateBetween(
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

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition>
      thumbPathIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'thumbPath',
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition>
      thumbPathIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'thumbPath',
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition> thumbPathEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'thumbPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition>
      thumbPathGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'thumbPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition> thumbPathLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'thumbPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition> thumbPathBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'thumbPath',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition>
      thumbPathStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'thumbPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition> thumbPathEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'thumbPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition> thumbPathContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'thumbPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition> thumbPathMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'thumbPath',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition>
      thumbPathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'thumbPath',
        value: '',
      ));
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterFilterCondition>
      thumbPathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'thumbPath',
        value: '',
      ));
    });
  }
}

extension PhotoLocalQueryObject
    on QueryBuilder<PhotoLocal, PhotoLocal, QFilterCondition> {}

extension PhotoLocalQueryLinks
    on QueryBuilder<PhotoLocal, PhotoLocal, QFilterCondition> {}

extension PhotoLocalQuerySortBy
    on QueryBuilder<PhotoLocal, PhotoLocal, QSortBy> {
  QueryBuilder<PhotoLocal, PhotoLocal, QAfterSortBy> sortByCloudUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cloudUrl', Sort.asc);
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterSortBy> sortByCloudUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cloudUrl', Sort.desc);
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterSortBy> sortByCreatedAtLocal() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtLocal', Sort.asc);
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterSortBy>
      sortByCreatedAtLocalDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtLocal', Sort.desc);
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterSortBy> sortByLocalPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localPath', Sort.asc);
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterSortBy> sortByLocalPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localPath', Sort.desc);
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterSortBy> sortByPhotoId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'photoId', Sort.asc);
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterSortBy> sortByPhotoIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'photoId', Sort.desc);
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterSortBy> sortByProjectId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'projectId', Sort.asc);
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterSortBy> sortByProjectIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'projectId', Sort.desc);
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterSortBy> sortBySyncState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncState', Sort.asc);
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterSortBy> sortBySyncStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncState', Sort.desc);
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterSortBy> sortByThumbPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'thumbPath', Sort.asc);
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterSortBy> sortByThumbPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'thumbPath', Sort.desc);
    });
  }
}

extension PhotoLocalQuerySortThenBy
    on QueryBuilder<PhotoLocal, PhotoLocal, QSortThenBy> {
  QueryBuilder<PhotoLocal, PhotoLocal, QAfterSortBy> thenByCloudUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cloudUrl', Sort.asc);
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterSortBy> thenByCloudUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'cloudUrl', Sort.desc);
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterSortBy> thenByCreatedAtLocal() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtLocal', Sort.asc);
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterSortBy>
      thenByCreatedAtLocalDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAtLocal', Sort.desc);
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterSortBy> thenByLocalPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localPath', Sort.asc);
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterSortBy> thenByLocalPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'localPath', Sort.desc);
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterSortBy> thenByPhotoId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'photoId', Sort.asc);
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterSortBy> thenByPhotoIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'photoId', Sort.desc);
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterSortBy> thenByProjectId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'projectId', Sort.asc);
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterSortBy> thenByProjectIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'projectId', Sort.desc);
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterSortBy> thenBySyncState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncState', Sort.asc);
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterSortBy> thenBySyncStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncState', Sort.desc);
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterSortBy> thenByThumbPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'thumbPath', Sort.asc);
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QAfterSortBy> thenByThumbPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'thumbPath', Sort.desc);
    });
  }
}

extension PhotoLocalQueryWhereDistinct
    on QueryBuilder<PhotoLocal, PhotoLocal, QDistinct> {
  QueryBuilder<PhotoLocal, PhotoLocal, QDistinct> distinctByCloudUrl(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'cloudUrl', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QDistinct> distinctByCreatedAtLocal() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAtLocal');
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QDistinct> distinctByLocalPath(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'localPath', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QDistinct> distinctByPhotoId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'photoId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QDistinct> distinctByProjectId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'projectId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QDistinct> distinctBySyncState() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'syncState');
    });
  }

  QueryBuilder<PhotoLocal, PhotoLocal, QDistinct> distinctByThumbPath(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'thumbPath', caseSensitive: caseSensitive);
    });
  }
}

extension PhotoLocalQueryProperty
    on QueryBuilder<PhotoLocal, PhotoLocal, QQueryProperty> {
  QueryBuilder<PhotoLocal, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<PhotoLocal, String?, QQueryOperations> cloudUrlProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'cloudUrl');
    });
  }

  QueryBuilder<PhotoLocal, DateTime, QQueryOperations>
      createdAtLocalProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAtLocal');
    });
  }

  QueryBuilder<PhotoLocal, String, QQueryOperations> localPathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'localPath');
    });
  }

  QueryBuilder<PhotoLocal, String, QQueryOperations> photoIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'photoId');
    });
  }

  QueryBuilder<PhotoLocal, String, QQueryOperations> projectIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'projectId');
    });
  }

  QueryBuilder<PhotoLocal, SyncState, QQueryOperations> syncStateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'syncState');
    });
  }

  QueryBuilder<PhotoLocal, String?, QQueryOperations> thumbPathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'thumbPath');
    });
  }
}
