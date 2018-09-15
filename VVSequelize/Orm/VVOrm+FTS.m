//
//  VVOrm+FTS.m
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/15.
//

#import "VVOrm+FTS.h"
#import "VVSelect.h"
#import "VVClause.h"
#import "VVOrm+Retrieve.h"
#import "NSString+VVClause.h"
#import "NSArray+VVClause.h"
#import "NSDictionary+VVClause.h"

@implementation VVOrm (FTS)

- (NSString *)clauseOf:(id)condition
                 match:(NSString *)keyword{
    NSAssert(self.config.fts, @"仅支持FTS数据表");
    NSString *where = [[VVClause prepare:condition] condition];
    NSString *match = [self.tableName match:keyword];
    where = where.length > 0 ? [where and:match] : match;
    return where;
}

- (NSArray *)findAll:(id)condition
               match:(NSString *)keyword
             orderBy:(id)orderBy
               range:(NSRange)range{
    NSString *where = [self clauseOf:condition match:keyword];
    return [[[[[VVSelect prepareWithOrm:self] where:where] orderBy:orderBy] limit:range] allObjects];
}

- (NSArray *)findAll:(id)condition
               match:(NSString *)keyword
             groupBy:(id)groupBy
               range:(NSRange)range{
    NSString *where = [self clauseOf:condition match:keyword];
    return [[[[[VVSelect prepareWithOrm:self] where:where] groupBy:groupBy] limit:range] allObjects];;
}

- (NSUInteger)count:(id)condition
              match:(NSString *)keyword{
    NSString *where  = [self clauseOf:condition match:keyword];
    NSString *fields = @"count(*) as count";
    NSArray *array = [[[[VVSelect prepareWithOrm:self] where:where] fields:fields] allJsons];
    NSDictionary *dic = array.firstObject;
    return [dic[@"count"] integerValue];
}

- (NSDictionary *)findAndCount:(id)condition
                         match:(NSString *)keyword
                       orderBy:(id)orderBy
                         range:(NSRange)range{
    NSUInteger count = [self count:condition match:keyword];
    NSArray *array   = [self findAll:condition match:keyword orderBy:orderBy range:range];
    return @{@"count":@(count), @"list":array};
}

- (NSArray *)findAll:(id)condition
               match:(NSString *)keyword
            distinct:(BOOL)distinct
              fields:(id)fields
             groupBy:(id)groupBy
              having:(id)having
             orderBy:(id)orderBy
               range:(NSRange)range{
    NSString *where = [self clauseOf:condition match:keyword];
    VVSelect *select = [[[[[[[[VVSelect prepareWithOrm:self] distinct:distinct] where:where] fields:fields] groupBy:groupBy] having:having] orderBy:orderBy] limit:range];
    return [select allObjects];
}

@end
