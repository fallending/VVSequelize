//
//  VVSelect.m
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/14.
//

#import "VVSelect.h"
#import "VVClause.h"
#import "VVOrm.h"
#import "NSObject+VVKeyValue.h"
#import "NSArray+VVClause.h"
#import "NSString+VVOrm.h"

@interface VVSelect ()

@property (nonatomic, copy  ) NSString *table;   //表名
@property (nonatomic, copy  ) id       fields;   //要查询的字段: NSString, NSArray
@property (nonatomic, assign) BOOL     distinct; //是否消除重复记录
@property (nonatomic, strong) id       where;    //查询条件: NSString, NSDictionary, NSArray
@property (nonatomic, assign) NSRange  limit;    //范围,用于生成limit,offset
@property (nonatomic, strong) id       orderBy;  //排序: NSString, NSArray
@property (nonatomic, strong) id       groupBy;  //分组:NSString, NSArray
@property (nonatomic, strong) id       having;   //分组的过滤条件: NSString, NSDictionary, NSArray

@property (nonatomic, strong) VVOrm    *orm;     //数据表模型

@property (nonatomic, copy  ) NSString *fieldsString;   //字段列表字符串

@end

@implementation VVSelect

+ (instancetype)prepare{
    return [[VVSelect alloc] init];
}

+ (instancetype)prepareWithOrm:(VVOrm *)orm{
    VVSelect *select = [[VVSelect alloc] init];
    select.orm   = orm;
    select.table = orm.tableName;
    return select;
}

- (NSArray *)findAll:(BOOL)useJson{
    NSAssert(self.orm, @"请使用`+prepareWithOrm:`创建VVSelect对象!");
    NSString *sql = self.sql;
    NSArray *results = [self.orm.cache objectForKey:sql];
    if(!results){
        NSArray *jsonArray = [self.orm.vvdb executeQuery:sql];
        results = jsonArray;
        if(!useJson && [self.fieldsString isEqualToString:@"*"]){
            results = [self.orm.config.cls vv_objectsWithKeyValuesArray:jsonArray];
        }
        [self.orm.cache setObject:results forKey:sql];
    }
    return results;
}

//MARK: - 链式调用
- (instancetype)table:(NSString *)table{
    self.table = table;
    return self;
}

- (instancetype)fields:(id)fields{
    self.fields = fields;
    return self;
}

- (instancetype)distinct:(BOOL)distinct{
    self.distinct = distinct;
    return self;
}

- (instancetype)where:(id)where{
    self.where = where;
    return self;
}

- (instancetype)limit:(NSRange)limit{
    self.limit = limit;
    return self;
}

- (instancetype)orderBy:(id)orderBy{
    self.orderBy = orderBy;
    return self;
}

- (instancetype)groupBy:(id)groupBy{
    self.groupBy = groupBy;
    return self;
}

- (instancetype)having:(id)having{
    self.having = having;
    return self;
}

- (NSString *)limitClause{
    if(_limit.location != NSNotFound && _limit.length > 0) {
        return [NSString stringWithFormat:@" LIMIT %@ OFFSET %@", @(_limit.length), @(_limit.location)];
    }
    return @"";
}

- (NSString *)fieldsString{
    if(!_fieldsString){
        if([_fields isKindOfClass:NSString.class]) {_fieldsString = _fields;}
        else if([_fields isKindOfClass:NSArray.class] && [_fields count] > 0) {_fieldsString = [_fields sqlJoin:YES];}
        else { _fieldsString = @"*"; }
    }
    return _fieldsString;
}

//MARK: - 生成查询语句
- (NSString *)sql{
    NSAssert(_table.length > 0, @"请先设置表名!");
    _fieldsString     = nil; // 重置fieldsString
    NSString *where   = [[VVClause prepare:_where] where];
    NSString *groupBy = [[VVClause prepare:_groupBy] groupBy];
    NSString *having  = groupBy.length == 0 ? @"" : [[VVClause prepare:_having] having];
    NSString *orderBy = [[VVClause prepare:_orderBy] orderBy];
    NSString *limit   = [self limitClause];
    NSString *sql     = [NSMutableString stringWithFormat:@"SELECT %@ %@ FROM \"%@\" %@ %@ %@ %@ %@",
                         _distinct ? @"DISTINCT": @"", self.fieldsString, _table,
                         where, groupBy, having, orderBy, limit].strip;
    return sql;
}

@end
