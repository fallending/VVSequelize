//
//  VVOrm+FTS.h
//  VVSequelize
//
//  Created by Valo on 2018/9/15.
//

#import "VVOrm.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const VVOrmFtsCount;

@interface VVOrm (FTS)

/// full text search
/// @param condition match expression, such as: "name:zhan*","zhan*", refer to: https://sqlite.org/fts5.html
/// @param orderBy sort method
/// @param limit limit of results, 0 without limit
/// @param offset start position
/// @return [object]
- (NSArray *)match:(nullable VVExpr *)condition
           orderBy:(nullable VVOrderBy *)orderBy
             limit:(NSUInteger)limit
            offset:(NSUInteger)offset;

/// grouped full text search
/// @param groupBy group method
/// @return [{field1:value1, field2: value2, ..., vvdb_fts_count: group_count}]
- (NSArray *)match:(nullable VVExpr *)condition
           groupBy:(nullable VVGroupBy *)groupBy
             limit:(NSUInteger)limit
            offset:(NSUInteger)offset;

/// get match count
- (NSUInteger)matchCount:(nullable VVExpr *)condition;

/// full text search
/// @return {"count":100,list:[object]}
- (NSDictionary *)matchAndCount:(nullable VVExpr *)condition
                        orderBy:(nullable VVOrderBy *)orderBy
                          limit:(NSUInteger)limit
                         offset:(NSUInteger)offset;

@end

NS_ASSUME_NONNULL_END
