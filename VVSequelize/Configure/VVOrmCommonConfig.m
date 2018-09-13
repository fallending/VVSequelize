//
//  VVOrmCommonConfig.m
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/13.
//

#import "VVOrmCommonConfig.h"
#import "VVDataBase.h"

@implementation VVOrmCommonConfig
- (instancetype)init{
    self = [super init];
    if (self) {
        self.logAt = YES;
    }
    return self;
}

- (instancetype)uniques:(NSArray<NSString *> *)uniques{
    self.uniques = uniques;
    return self;
}

- (BOOL)isEqualToConfig:(VVOrmConfig *)config indexChanged:(BOOL *)indexChanged{
    if(![config isKindOfClass:VVOrmCommonConfig.class] ||
       self.fields.count != config.fields.count || self.logAt != config.logAt ){
        *indexChanged = YES;
        return NO;
    }
    
    NSMutableArray *compared = [NSMutableArray arrayWithCapacity:0];
    for (NSString *name in self.fields) {
        VVOrmCommonField *field1 = self.fields[name];
        VVOrmCommonField *field2 = config.fields[name];
        if(![field1 isEqualToField:field2]) { return NO; }
        if(field1.indexed != field2.indexed) { *indexChanged = YES; }
        [compared addObject:name];
    }
    NSMutableDictionary *remained = config.fields.mutableCopy;
    [remained removeObjectsForKeys:compared];
    return remained.count == 0;
}

+ (instancetype)configWithTable:(NSString *)tableName
                       database:(VVDataBase *)vvdb{
    if(!([vvdb isTableExist:tableName])) return nil;
    VVOrmCommonConfig *config = [[VVOrmCommonConfig alloc] init];
    
    // count > 1 时,表示主键为自增类型主键
    NSInteger count = 0;
    if([vvdb isTableExist:@"sqlite_sequence"]){
        NSString *sql   = [NSString stringWithFormat:@"SELECT count(*) as count FROM sqlite_sequence WHERE name = \"%@\"",tableName];
        NSArray *cols   = [vvdb executeQuery:sql];
        if (cols.count > 0) {
            NSDictionary *dic = cols.firstObject;
            count = [dic[@"count"] integerValue];
        }
    }
    
    // 获取表的每个字段配置
    NSString *tableInfoSql      = [NSString stringWithFormat:@"PRAGMA table_info(\"%@\");",tableName];
    NSArray *infos              = [vvdb executeQuery:tableInfoSql];
    NSMutableDictionary *fields = [NSMutableDictionary dictionaryWithCapacity:0];
    NSMutableArray *uniques     = [NSMutableArray arrayWithCapacity:0];
    for (NSDictionary *dic in infos) {
        VVOrmCommonField *field = [VVOrmCommonField fieldWithDictionary:dic];
        if(field.pk) {
            config.primaryKey = field.name;
            if(count == 1) { field.pk = VVOrmPkAutoincrement; } // 自增主键
        }
        fields[field.name] = field;
    }
    // 获取表的索引字段
    NSString *indexListSql = [NSString stringWithFormat:@"PRAGMA index_list(\"%@\");",tableName];
    NSArray *indexList = [vvdb executeQuery:indexListSql];
    for (NSDictionary *indexDic in indexList) {
        NSString *indexName    = indexDic[@"name"];
        NSString *indexInfoSql = [NSString stringWithFormat:@"PRAGMA index_info(\"%@\");",indexName];
        NSArray *indexInfos    = [vvdb executeQuery:indexInfoSql];
        for (NSDictionary *indexInfo in indexInfos) {
            NSString *name     = indexInfo[@"name"];
            VVOrmCommonField *field  = fields[name];
            field.unique       = [indexDic[@"unique"] boolValue];
            field.indexed      = [indexName hasPrefix:@"sqlite_autoindex_"] ? NO : YES;
            if(field.unique) {[uniques addObject:field.name];}
        }
    }
    config.uniques = uniques.copy;
    return config;
}

@end
