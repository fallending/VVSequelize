//
//  VVSelect.m
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/14.
//

#import "VVSelect.h"
#import "VVWhere.h"

typedef NS_ENUM(NSUInteger, VVSelectValType) {
    VVSelectValTypeString,
    VVSelectValTypeDictionary,
    VVSelectValTypeArray,
    VVSelectValTypeUnkown,
};

@interface VVSelect ()

@end

@implementation VVSelect

- (instancetype)init{
    self = [super init];
    if (self) {
        _fields = @"*";
        _limit  = NSMakeRange(NSNotFound, 0);
    }
    return self;
}

- (instancetype)table:(NSString *)table{
    self.table = table;
    return self;
}

- (instancetype)fields:(NSString *)fields{
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

- (NSString *)whereClause{
    if(!_where) return @"";
    NSString *sub = nil;
    VVSelectValType type = [self valTypeOf:_where];
    switch (type) {
            case VVSelectValTypeString:     if([_where length] > 0) sub = _where; break;
            case VVSelectValTypeDictionary: if([_where count] > 0)  sub = [_where where]; break;
            case VVSelectValTypeArray:      if([_where count] > 0)  sub = [_where where]; break;
        default: break;
    }
    if(sub.length == 0) return @"";
    return [NSString stringWithFormat:@" WHERE %@", sub];
}

- (NSString *)groupByClause{
    if(!_groupBy) return @"";
    NSString *sub = nil;
    VVSelectValType type = [self valTypeOf:_groupBy];
    switch (type) {
            case VVSelectValTypeString: if([_groupBy length] > 0) sub = _groupBy; break;
            case VVSelectValTypeArray:  if([_groupBy count] > 0)  sub = [_groupBy sqlJoin:YES]; break;
        default: break;
    }
    if(sub.length == 0) return @"";
    return [NSString stringWithFormat:@" GROUP BY %@%@", sub,[self havingClause]];
}

- (NSString *)havingClause{
    if(!_having) return @"";
    NSString *sub = nil;
    VVSelectValType type = [self valTypeOf:_having];
    switch (type) {
            case VVSelectValTypeString:     if([_having length] > 0) sub = _having; break;
            case VVSelectValTypeDictionary: if([_having count] > 0)  sub = [_having where]; break;
            case VVSelectValTypeArray:      if([_having count] > 0)  sub = [_having where]; break;
        default: break;
    }
    if(sub.length == 0) return @"";
    return [NSString stringWithFormat:@" HAVING %@", sub];
}

- (NSString *)orderByClause{
    if(!_orderBy) return @"";
    NSString *sub = nil;
    VVSelectValType type = [self valTypeOf:_orderBy];
    switch (type) {
            case VVSelectValTypeString: if([_orderBy length] > 0) sub = _orderBy; break;
            case VVSelectValTypeArray:  if([_orderBy count] > 0)  sub = [_orderBy sqlJoin:YES]; break;
        default: break;
    }
    if(sub.length == 0) return @"";
    return [NSString stringWithFormat:@" ORDER BY %@", sub];
}

- (NSString *)limitClause{
    if(_limit.location != NSNotFound && _limit.length > 0) {
        return [NSString stringWithFormat:@" LIMIT %@ OFFSET %@", @(_limit.length), @(_limit.location)];
    }
    return @"";
}

- (NSString *)sql{
    NSAssert(_table.length == 0, @"请先设置表名!");
    NSMutableString *sql = [NSMutableString stringWithFormat:@"SELECT %@ %@ FROM \"%@\"%@%@%@",
                            _distinct ? @"DISTINCT": @"", _fields, _table,
                            [self whereClause], [self groupByClause], [self limitClause]];
    return sql;
}

- (VVSelectValType)valTypeOf:(id)val{
    if([val isKindOfClass:NSString.class])          return VVSelectValTypeString;
    else if([val isKindOfClass:NSDictionary.class]) return VVSelectValTypeDictionary;
    else if([val isKindOfClass:NSArray.class])      return VVSelectValTypeArray;
    return VVSelectValTypeUnkown;
}

@end
