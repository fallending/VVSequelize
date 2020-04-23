//
//  VVOrmView.m
//  VVSequelize
//
//  Created by Valo on 2020/4/23.
//

#import "VVOrmView.h"
#import "NSObject+VVOrm.h"

@interface VVOrmView ()
@property (nonatomic, copy) NSString *sourceTable;
@end

@implementation VVOrmView

@synthesize tableName = _tableName;

+ (nullable instancetype)ormWithConfig:(VVOrmConfig *)config {
    return [self ormWithConfig:config tableName:nil dataBase:nil];
}

+ (nullable instancetype)ormWithConfig:(VVOrmConfig *)config
                             tableName:(nullable NSString *)tableName
                              dataBase:(nullable VVDatabase *)vvdb
{
    return [[VVOrmView alloc] initWithConfig:config tableName:tableName dataBase:vvdb];
}

- (instancetype)initWithName:(NSString *)name
                         orm:(VVOrm *)orm
                   condition:(VVExpr *)condition
                   temporary:(BOOL)temporary
                     columns:(nullable NSArray<NSString *> *)columns
{
    self = [super initWithConfig:orm.config tableName:orm.tableName dataBase:orm.vvdb];
    if (self) {
        _sourceTable = orm.tableName;
        _tableName = name;
        _condition = condition;
        _temporary = temporary;
        _columns = columns;
    }
    return self;
}

- (instancetype)initWithConfig:(VVOrmConfig *)config tableName:(NSString *)tableName dataBase:(VVDatabase *)vvdb
{
    self = [super initWithConfig:config tableName:tableName dataBase:vvdb];
    if (self) {
        _sourceTable = tableName;
        _tableName = nil;
    }
    return self;
}

//MARK: - public
- (BOOL)exist
{
    NSString *sql = [NSString stringWithFormat:@"SELECT count(*) as 'count' FROM sqlite_master WHERE type ='view' and tbl_name = %@", _tableName.quoted];
    return [[self.vvdb scalar:sql bind:nil] boolValue];
}

- (BOOL)createView
{
    NSString *where = [_condition sqlWhere];
    NSAssert(_tableName.length > 0 && where.length > 0, @"Please set viewName and condition first!");

    NSArray *cols = nil;
    if (_columns.count > 0) {
        NSSet *all = [NSSet setWithArray:self.config.columns];
        NSMutableSet *set = [NSMutableSet setWithArray:_columns];
        [set intersectSet:all];
        cols = set.allObjects;
    }

    NSString *sql = [NSString stringWithFormat:
                     @"CREATE %@ VIEW %@ AS "
                     "SELECT %@ "
                     "FROM %@"
                     "WHERE %@",
                     (_temporary ? @"TEMP" : @""), _tableName.quoted,
                     (cols.count > 0 ? cols.sqlJoin : @"*"),
                     _sourceTable.quoted,
                     where];

    return [self.vvdb run:sql];
}

- (BOOL)dropView
{
    NSString *sql = [NSString stringWithFormat:@"DROP VIEW %@", _tableName.quoted];
    return [self.vvdb run:sql];
}

- (BOOL)recreateView
{
    BOOL ret = YES;
    if (self.exist) {
        ret = [self dropView];
    }
    if (ret) {
        ret = [self createView];
    }
    return ret;
}

//MAKR: - UNAVAILABLE
- (VVOrmInspection)inspectExistingTable
{
    return 0;
}

- (void)setupTableWith:(VVOrmInspection)inspection
{
}

- (void)createTable
{
}

@end
