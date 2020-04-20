//
//  VVOrm.h
//  VVSequelize
//
//  Created by Valo on 2018/6/6.
//

#import <Foundation/Foundation.h>
#import "VVOrmDefs.h"
#import "VVDatabase.h"
#import "VVOrmConfig.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS (NSUInteger, VVOrmInspection) {
    VVOrmTableExist   = 1 << 0,
    VVOrmTableChanged = 1 << 1,
    VVOrmIndexChanged = 1 << 2,
};

/// Object Relational Mapping
@interface VVOrm : NSObject
/// orm configration
@property (nonatomic, strong, readonly) VVOrmConfig *config;
/// databse
@property (nonatomic, strong, readonly) VVDatabase *vvdb;
/// table name
@property (nonatomic, copy, readonly) NSString *tableName;

- (instancetype)init __attribute__((unavailable("use initWithConfig:tableName:dataBase: instead.")));
+ (instancetype)new __attribute__((unavailable("use initWithConfig:tableName:dataBase: instead.")));

/// Initialize orm, auto create/modify defalut table, use temporary db.
/// @param config orm configuration
+ (nullable instancetype)ormWithConfig:(VVOrmConfig *)config;

/// Initialize orm, auto create/modify table and indexes
/// @param config orm configuration
/// @param tableName table name, nil means to use class name
/// @param vvdb db, nil means to use temporary db
+ (nullable instancetype)ormWithConfig:(VVOrmConfig *)config
                             tableName:(nullable NSString *)tableName
                              dataBase:(nullable VVDatabase *)vvdb;

/// Initialize orm, do not create/modify table and indexes
/// @param config orm configuration
/// @param tableName table name, nil means to use class name
/// @param vvdb db, nil means to use temporary db
/// @attention call `inspectExistingTable` and `setupTableWith:` in turns to create/modify table and indexes.
- (nullable instancetype)initWithConfig:(VVOrmConfig *)config
                              tableName:(nullable NSString *)tableName
                               dataBase:(nullable VVDatabase *)vvdb NS_DESIGNATED_INITIALIZER;

/// inspect table
- (VVOrmInspection)inspectExistingTable;

/// create/modify table and indexes with inspect results
- (void)setupTableWith:(VVOrmInspection)inspection;

/// create table manually
- (void)createTable;

/// get unique condition, use to update/delete
- (nullable NSDictionary *)uniqueConditionForObject:(id)object;
@end

NS_ASSUME_NONNULL_END
