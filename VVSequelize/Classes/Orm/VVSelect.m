//
//  VVSelect.m
//  VVSequelize
//
//  Created by Valo on 2018/9/14.
//

#import "VVSelect.h"
#import "NSObject+VVKeyValue.h"
#import "NSObject+VVOrm.h"

@interface VVSelect ()
@property (nonatomic, copy) NSString *fieldsString;     ///< 字段列表字符串
@end

@implementation VVSelect
{
    VVOrm *_orm;           ///< orm model
    
    NSString *_table;      ///< table name
    BOOL _distinct;        ///< clear duplicate records or not
    VVFields *_fields;     ///< query fields: NSString, NSArray
    VVExpr *_where;        ///< query condition: NSString, NSDictionary, NSArray
    VVOrderBy *_orderBy;   ///< sort: NSString, NSArray
    VVGroupBy *_groupBy;   ///< group: NSString, NSArray
    VVExpr *_having;       ///< group filter: NSString, NSDictionary, NSArray
    NSUInteger _offset;    ///< offset
    NSUInteger _limit;     ///< limit
}

- (NSArray *)allObjects
{
    return [self allResults:YES];
}

- (NSArray *)allKeyValues
{
    return [self allResults:NO];
}

- (NSArray *)allResults:(BOOL)useObjects
{
    NSAssert(_orm, @"set orm first!");
    NSArray *keyValuesArray = [_orm.vvdb query:self.sql];
    if (useObjects) {
        Class cls = _orm.metaClass ? : _orm.config.cls;
        return [cls vv_objectsWithKeyValuesArray:keyValuesArray];
    }
    return keyValuesArray;
}

//MARK: - chain
+ (instancetype)makeSelect:(void (^)(VVSelect *make))block
{
    VVSelect *select = [[VVSelect alloc] init];
    if (block) block(select);
    return select;
}

- (VVSelect *(^)(VVOrm *orm))orm
{
    return ^(VVOrm *orm) {
        self->_orm = orm;
        self->_table = orm.name;
        return self;
    };
}

- (VVSelect *(^)(NSString *table))table
{
    return ^(NSString *table) {
        self->_table = table;
        return self;
    };
}

- (VVSelect *(^)(BOOL distinct))distinct
{
    return ^(BOOL distinct) {
        self->_distinct = distinct;
        return self;
    };
}

- (VVSelect *(^)(VVFields *fields))fields
{
    return ^(VVFields *fields) {
        self->_fields = fields;
        return self;
    };
}

- (VVSelect *(^)(VVExpr *where))where
{
    return ^(VVExpr *where) {
        self->_where = where;
        return self;
    };
}

- (VVSelect *(^)(VVOrderBy *orderBy))orderBy
{
    return ^(VVOrderBy *orderBy) {
        self->_orderBy = orderBy;
        return self;
    };
}

- (VVSelect *(^)(VVGroupBy *groupBy))groupBy
{
    return ^(VVGroupBy *groupBy) {
        self->_groupBy = groupBy;
        return self;
    };
}

- (VVSelect *(^)(VVExpr *having))having
{
    return ^(VVExpr *having) {
        self->_having = having;
        return self;
    };
}

- (VVSelect *(^)(NSUInteger offset))offset
{
    return ^(NSUInteger offset) {
        self->_offset = offset;
        return self;
    };
}

- (VVSelect *(^)(NSUInteger limit))limit
{
    return ^(NSUInteger limit) {
        self->_limit = limit;
        return self;
    };
}

- (NSString *)fieldsString
{
    if (!_fieldsString) {
        if ([_fields isKindOfClass:NSString.class]) {
            _fieldsString = (NSString *)_fields;
        } else if ([_fields isKindOfClass:NSArray.class] && [(NSArray *)_fields count] > 0) {
            _fieldsString = [(NSArray *)_fields sqlJoin];
        } else {
            _fieldsString = @"*";
        }
    }
    return _fieldsString;
}

//MARK: - 生成查询语句
- (NSString *)sql
{
    NSAssert(_table.length > 0, @"set table or orm first!");
    _fieldsString = nil;     // 重置fieldsString
    
    NSString *where = [_where sqlWhere] ? : @"";
    if (where.length > 0) where =  [NSString stringWithFormat:@" WHERE %@", where];
    
    NSString *groupBy = [_groupBy sqlJoin] ? : @"";
    if (groupBy.length > 0) groupBy = [NSString stringWithFormat:@" GROUP BY %@", groupBy];
    
    NSString *having = groupBy.length > 0 ? ([_having sqlWhere] ? : @"") : @"";
    if (having.length > 0) having = [NSString stringWithFormat:@" HAVING %@", having];
    
    NSString *orderBy = [_orderBy sqlJoin] ? : @"";
    if (orderBy.length > 0) {
        if (![orderBy isMatch:@"( +ASC *$)|( +DESC *$)"]) orderBy = orderBy.asc;
        orderBy = [NSString stringWithFormat:@" ORDER BY %@", orderBy];
    }
    
    if (_offset > 0 && _limit <= 0) _limit = NSUIntegerMax;
    
    NSString *limit = _limit > 0 ? [NSString stringWithFormat:@" LIMIT %@", @(_limit)] : @"";
    
    NSString *offset = _offset > 0 ? [NSString stringWithFormat:@" OFFSET %@", @(_offset)] : @"";
    
    NSString *sql = [NSMutableString stringWithFormat:@"SELECT %@ %@ FROM %@ %@ %@ %@ %@ %@ %@",
                     _distinct ? @"DISTINCT" : @"", self.fieldsString, _table,
                     where, groupBy, having, orderBy, limit, offset].strip;
    return sql;
}

@end
