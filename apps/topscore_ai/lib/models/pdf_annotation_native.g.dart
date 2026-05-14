// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pdf_annotation_native.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetPdfAnnotationRecordCollection on Isar {
  IsarCollection<PdfAnnotationRecord> get pdfAnnotationRecords =>
      this.collection();
}

const PdfAnnotationRecordSchema = CollectionSchema(
  name: r'PdfAnnotationRecord',
  id: 1842469924708216774,
  properties: {
    r'annotationsJson': PropertySchema(
      id: 0,
      name: r'annotationsJson',
      type: IsarType.string,
    ),
    r'docId': PropertySchema(
      id: 1,
      name: r'docId',
      type: IsarType.string,
    ),
    r'lastModified': PropertySchema(
      id: 2,
      name: r'lastModified',
      type: IsarType.dateTime,
    )
  },
  estimateSize: _pdfAnnotationRecordEstimateSize,
  serialize: _pdfAnnotationRecordSerialize,
  deserialize: _pdfAnnotationRecordDeserialize,
  deserializeProp: _pdfAnnotationRecordDeserializeProp,
  idName: r'id',
  indexes: {
    r'docId': IndexSchema(
      id: -9164048795576814174,
      name: r'docId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'docId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _pdfAnnotationRecordGetId,
  getLinks: _pdfAnnotationRecordGetLinks,
  attach: _pdfAnnotationRecordAttach,
  version: '3.3.2',
);

int _pdfAnnotationRecordEstimateSize(
  PdfAnnotationRecord object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.annotationsJson.length * 3;
  bytesCount += 3 + object.docId.length * 3;
  return bytesCount;
}

void _pdfAnnotationRecordSerialize(
  PdfAnnotationRecord object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.annotationsJson);
  writer.writeString(offsets[1], object.docId);
  writer.writeDateTime(offsets[2], object.lastModified);
}

PdfAnnotationRecord _pdfAnnotationRecordDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = PdfAnnotationRecord();
  object.annotationsJson = reader.readString(offsets[0]);
  object.docId = reader.readString(offsets[1]);
  object.id = id;
  object.lastModified = reader.readDateTime(offsets[2]);
  return object;
}

P _pdfAnnotationRecordDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readDateTime(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _pdfAnnotationRecordGetId(PdfAnnotationRecord object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _pdfAnnotationRecordGetLinks(
    PdfAnnotationRecord object) {
  return [];
}

void _pdfAnnotationRecordAttach(
    IsarCollection<dynamic> col, Id id, PdfAnnotationRecord object) {
  object.id = id;
}

extension PdfAnnotationRecordByIndex on IsarCollection<PdfAnnotationRecord> {
  Future<PdfAnnotationRecord?> getByDocId(String docId) {
    return getByIndex(r'docId', [docId]);
  }

  PdfAnnotationRecord? getByDocIdSync(String docId) {
    return getByIndexSync(r'docId', [docId]);
  }

  Future<bool> deleteByDocId(String docId) {
    return deleteByIndex(r'docId', [docId]);
  }

  bool deleteByDocIdSync(String docId) {
    return deleteByIndexSync(r'docId', [docId]);
  }

  Future<List<PdfAnnotationRecord?>> getAllByDocId(List<String> docIdValues) {
    final values = docIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'docId', values);
  }

  List<PdfAnnotationRecord?> getAllByDocIdSync(List<String> docIdValues) {
    final values = docIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'docId', values);
  }

  Future<int> deleteAllByDocId(List<String> docIdValues) {
    final values = docIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'docId', values);
  }

  int deleteAllByDocIdSync(List<String> docIdValues) {
    final values = docIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'docId', values);
  }

  Future<Id> putByDocId(PdfAnnotationRecord object) {
    return putByIndex(r'docId', object);
  }

  Id putByDocIdSync(PdfAnnotationRecord object, {bool saveLinks = true}) {
    return putByIndexSync(r'docId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByDocId(List<PdfAnnotationRecord> objects) {
    return putAllByIndex(r'docId', objects);
  }

  List<Id> putAllByDocIdSync(List<PdfAnnotationRecord> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'docId', objects, saveLinks: saveLinks);
  }
}

extension PdfAnnotationRecordQueryWhereSort
    on QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QWhere> {
  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension PdfAnnotationRecordQueryWhere
    on QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QWhereClause> {
  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterWhereClause>
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

  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterWhereClause>
      idBetween(
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

  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterWhereClause>
      docIdEqualTo(String docId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'docId',
        value: [docId],
      ));
    });
  }

  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterWhereClause>
      docIdNotEqualTo(String docId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'docId',
              lower: [],
              upper: [docId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'docId',
              lower: [docId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'docId',
              lower: [docId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'docId',
              lower: [],
              upper: [docId],
              includeUpper: false,
            ));
      }
    });
  }
}

extension PdfAnnotationRecordQueryFilter on QueryBuilder<PdfAnnotationRecord,
    PdfAnnotationRecord, QFilterCondition> {
  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterFilterCondition>
      annotationsJsonEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'annotationsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterFilterCondition>
      annotationsJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'annotationsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterFilterCondition>
      annotationsJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'annotationsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterFilterCondition>
      annotationsJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'annotationsJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterFilterCondition>
      annotationsJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'annotationsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterFilterCondition>
      annotationsJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'annotationsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterFilterCondition>
      annotationsJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'annotationsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterFilterCondition>
      annotationsJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'annotationsJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterFilterCondition>
      annotationsJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'annotationsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterFilterCondition>
      annotationsJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'annotationsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterFilterCondition>
      docIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'docId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterFilterCondition>
      docIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'docId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterFilterCondition>
      docIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'docId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterFilterCondition>
      docIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'docId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterFilterCondition>
      docIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'docId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterFilterCondition>
      docIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'docId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterFilterCondition>
      docIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'docId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterFilterCondition>
      docIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'docId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterFilterCondition>
      docIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'docId',
        value: '',
      ));
    });
  }

  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterFilterCondition>
      docIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'docId',
        value: '',
      ));
    });
  }

  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterFilterCondition>
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

  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterFilterCondition>
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

  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterFilterCondition>
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

  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterFilterCondition>
      lastModifiedEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastModified',
        value: value,
      ));
    });
  }

  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterFilterCondition>
      lastModifiedGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastModified',
        value: value,
      ));
    });
  }

  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterFilterCondition>
      lastModifiedLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastModified',
        value: value,
      ));
    });
  }

  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterFilterCondition>
      lastModifiedBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastModified',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension PdfAnnotationRecordQueryObject on QueryBuilder<PdfAnnotationRecord,
    PdfAnnotationRecord, QFilterCondition> {}

extension PdfAnnotationRecordQueryLinks on QueryBuilder<PdfAnnotationRecord,
    PdfAnnotationRecord, QFilterCondition> {}

extension PdfAnnotationRecordQuerySortBy
    on QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QSortBy> {
  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterSortBy>
      sortByAnnotationsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'annotationsJson', Sort.asc);
    });
  }

  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterSortBy>
      sortByAnnotationsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'annotationsJson', Sort.desc);
    });
  }

  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterSortBy>
      sortByDocId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'docId', Sort.asc);
    });
  }

  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterSortBy>
      sortByDocIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'docId', Sort.desc);
    });
  }

  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterSortBy>
      sortByLastModified() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastModified', Sort.asc);
    });
  }

  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterSortBy>
      sortByLastModifiedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastModified', Sort.desc);
    });
  }
}

extension PdfAnnotationRecordQuerySortThenBy
    on QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QSortThenBy> {
  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterSortBy>
      thenByAnnotationsJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'annotationsJson', Sort.asc);
    });
  }

  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterSortBy>
      thenByAnnotationsJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'annotationsJson', Sort.desc);
    });
  }

  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterSortBy>
      thenByDocId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'docId', Sort.asc);
    });
  }

  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterSortBy>
      thenByDocIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'docId', Sort.desc);
    });
  }

  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterSortBy>
      thenByLastModified() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastModified', Sort.asc);
    });
  }

  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QAfterSortBy>
      thenByLastModifiedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastModified', Sort.desc);
    });
  }
}

extension PdfAnnotationRecordQueryWhereDistinct
    on QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QDistinct> {
  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QDistinct>
      distinctByAnnotationsJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'annotationsJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QDistinct>
      distinctByDocId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'docId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QDistinct>
      distinctByLastModified() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastModified');
    });
  }
}

extension PdfAnnotationRecordQueryProperty
    on QueryBuilder<PdfAnnotationRecord, PdfAnnotationRecord, QQueryProperty> {
  QueryBuilder<PdfAnnotationRecord, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<PdfAnnotationRecord, String, QQueryOperations>
      annotationsJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'annotationsJson');
    });
  }

  QueryBuilder<PdfAnnotationRecord, String, QQueryOperations> docIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'docId');
    });
  }

  QueryBuilder<PdfAnnotationRecord, DateTime, QQueryOperations>
      lastModifiedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastModified');
    });
  }
}
