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
    VVOrm *_orm;           ///< 数据表模型
    
    NSString *_table;      ///< 表名
    BOOL _distinct;        ///< 是否消除重复记录
    VVFields *_fields;     ///< 要查询的字段: NSString, NSArray
    VVExpr *_where;        ///< 查询条件: NSString, NSDictionary, NSArray
    VVOrderBy *_orderBy;   ///< 排序: NSString, NSArray
    VVGroupBy *_groupBy;   ///< 分组: NSString, NSArray
    VVExpr *_having;       ///< 分组的过滤条件: NSString, NSDictionary, NSArray
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
        return [_orm.config.cls vv_objectsWithKeyValuesArray:keyValuesArray];
    }
    return keyValuesArray;
}

//MARK: - 链式调用
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
        self->_table = orm.tableName;
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

- (NSString *)offsetClause
{
    if (_offset > 0) {
        return [NSString stringWithFormat:@" OFFSET %@", @(_offset)];
    }
    return @"";
}

- (NSString *)limitClause
{
    if (_limit > 0) {
        return [NSString stringWithFormat:@" LIMIT %@", @(_limit)];
    }
    return @"";
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
    NSString *where = [NSString sqlWhere:_where];
    NSString *groupBy = [NSString sqlGroupBy:_groupBy];
    NSString *having = groupBy.length == 0 ? @"" : [NSString sqlHaving:_having];
    NSString *orderBy = [NSString sqlOrderBy:_orderBy];
    NSString *limit = [self limitClause];
    NSString *offset = [self offsetClause];
    NSString *sql = [NSMutableString stringWithFormat:@"SELECT %@ %@ FROM \"%@\" %@ %@ %@ %@ %@ %@",
                     _distinct ? @"DISTINCT" : @"", self.fieldsString, _table,
                     where, groupBy, having, orderBy, limit, offset].strip;
    return sql;
}

@end
