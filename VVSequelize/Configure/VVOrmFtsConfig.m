//
//  VVOrmFtsConfig.m
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/13.
//

#import "VVOrmFtsConfig.h"
#import "VVDataBase.h"
#import "NSString+VVOrmModel.h"

@implementation VVOrmFtsConfig

- (instancetype)init{
    self = [super init];
    if (self) {
        self.module = @"fts4";
    }
    return self;
}

- (instancetype)module:(NSString *)module{
    self.module = module;
    return self;
}

- (instancetype)tokenizer:(NSString *)tokenizer{
    self.tokenizer = tokenizer;
    return self;
}

- (instancetype)notindexed:(NSArray<NSString *> *)notindexed{
    self.notindexed = notindexed;
    return self;
}

- (BOOL)isEqualToConfig:(VVOrmConfig *)config indexChanged:(BOOL *)indexChanged{
    *indexChanged = NO;
    if([config isKindOfClass:VVOrmFtsConfig.class]) return NO;
    
    VVOrmFtsConfig *ftsConfig = (VVOrmFtsConfig *)config;
    if(self.fields.count != ftsConfig.fields.count ||
       ![self.module isEqualToString:ftsConfig.module] ||
       ![self.tokenizer isEqualToString:ftsConfig.tokenizer]){
        return NO;
    }
    NSMutableArray *compared = [NSMutableArray arrayWithCapacity:0];
    for (NSString *name in self.fields) {
        VVOrmFtsField *field1 = self.fields[name];
        VVOrmFtsField *field2 = config.fields[name];
        if(field1.notindexed != field2.notindexed ) { return NO; }
        [compared addObject:name];
    }
    NSMutableDictionary *remained = config.fields.mutableCopy;
    [remained removeObjectsForKeys:compared];
    return remained.count == 0;
}

+ (instancetype)configWithTable:(NSString *)tableName database:(VVDataBase *)vvdb{
    NSString *sql = [NSString stringWithFormat:@"SELECT * as count FROM sqlite_master WHERE tbl_name = \"%@\" AND type = \"table\"",tableName];
    NSArray *cols = [vvdb executeQuery:sql];
    if(cols.count != 1) return nil;
    NSDictionary *dic = cols.firstObject;
    NSString *tableSQL = dic[@"sql"];
    
    NSInteger ftsType = 3;
    if([tableSQL isMatchRegex:@" +fts4"]) ftsType = 4;
    if([tableSQL isMatchRegex:@" +fts5"]) ftsType = 5;

    VVOrmFtsConfig *config = [[VVOrmFtsConfig alloc] init];
    
    // 获取表的每个字段配置
    NSString *tableInfoSql      = [NSString stringWithFormat:@"PRAGMA table_info(\"%@\");",tableName];
    NSArray *infos              = [vvdb executeQuery:tableInfoSql];
    NSMutableDictionary *fields = [NSMutableDictionary dictionaryWithCapacity:0];
    for (NSDictionary *dic in infos) {
        VVOrmFtsField *field = [VVOrmFtsField fieldWithDictionary:dic];
        fields[field.name] = field;
        NSString *regex = ftsType == 5 ? [NSString stringWithFormat:@"%@ +UNINDEXED",field.name] : [NSString stringWithFormat:@"UNINDEXED +%@",field.name];
        if([tableSQL isMatchRegex:regex]) field.notindexed = NO;
    }
    return config;
}

@end
