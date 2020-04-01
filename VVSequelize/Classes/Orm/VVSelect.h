//
//  VVSelect.h
//  VVSequelize
//
//  Created by Valo on 2018/9/14.
//

#import "VVOrm.h"

@interface VVSelect : NSObject
/// generate sql statement
@property (nonatomic, copy, readonly) NSString *sql;

/// query results
/// @note must set orm
- (NSArray *)allObjects;

/// query results
/// @note must set orm
- (NSArray *)allKeyValues;

//MARK: - chain
/// create chain
+ (instancetype)makeSelect:(void (^)(VVSelect *make))block;

- (VVSelect *(^)(VVOrm *orm))orm;

- (VVSelect *(^)(NSString *table))table;

- (VVSelect *(^)(BOOL distinct))distinct;

- (VVSelect *(^)(VVFields *fields))fields;

- (VVSelect *(^)(VVExpr *where))where;

- (VVSelect *(^)(VVOrderBy *orderBy))orderBy;

- (VVSelect *(^)(VVGroupBy *groupBy))groupBy;

- (VVSelect *(^)(VVExpr *having))having;

- (VVSelect *(^)(NSUInteger offset))offset;

- (VVSelect *(^)(NSUInteger limit))limit;

@end
