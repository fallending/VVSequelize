//
//  VVFtsable.m
//  VVSequelize
//
//  Created by Valo on 2020/7/29.
//

#import "VVFtsable.h"
#import "VVTokenEnumerator.h"

@implementation VVOrmConfig (VVFtsable)

+ (instancetype)configWithFtsable:(Class<VVFtsable>)cls
{
    VVOrmConfig *config = [VVOrmConfig configWithClass:cls];
    config.fts = YES;
    if ([cls respondsToSelector:@selector(whitelist)]) {
        config.whiteList = [cls whitelist] ? : @[];
    }
    if ([cls respondsToSelector:@selector(whitelist)]) {
        config.blackList = [cls whitelist] ? : @[];
    }
    if ([cls respondsToSelector:@selector(indexlist)]) {
        config.indexes = [cls indexlist] ? : @[];
    }
    if ([cls respondsToSelector:@selector(module)]) {
        config.ftsModule = [cls module] ? : @"fts5";
    }
    if ([cls respondsToSelector:@selector(tokenizer)]) {
        NSString *tokenizer = [NSString stringWithFormat:@"sequelize %@", @(VVTokenMaskDefault)];
        config.ftsTokenizer = [cls tokenizer] ? : tokenizer;
    }
    return config;
}

@end

@implementation VVOrm (VVFtsable)

+ (instancetype)ormWithFtsClass:(Class<VVFtsable>)clazz
{
    return [VVOrm ormWithFtsClass:clazz name:nil database:nil];
}

+ (instancetype)ormWithFtsClass:(Class<VVFtsable>)clazz name:(NSString *)name database:(VVDatabase *)vvdb
{
    return [VVOrm ormWithFtsClass:clazz name:name database:vvdb setup:YES];
}

+ (instancetype)ormWithFtsClass:(Class<VVFtsable>)clazz name:(NSString *)name database:(VVDatabase *)vvdb setup:(BOOL)setup
{
    VVOrmConfig *config = [VVOrmConfig configWithFtsable:clazz];
    return [VVOrm ormWithConfig:config name:name database:vvdb setup:setup];
}

@end
