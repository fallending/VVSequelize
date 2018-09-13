//
//  VVDBVersionManager.m
//  VVSequelize
//
//  Created by Jinbo Li on 2018/8/11.
//

#import "VVDataBaseHelper.h"

static VVDataBaseHelper *_defaultHelper;

NSString * const VVDataBaseLastVersionKey = @"VVDataBaseLastVersionKey";

@interface VVDataBaseHelper ()
@property (nonatomic, strong) NSArray<NSString *> *versions; ///< 数据库版本列表
@property (nonatomic, strong) NSMutableDictionary<NSString *,void (^)(void)> *updates; ///< 所有更新操作
@end

@implementation VVDataBaseHelper

+ (instancetype)defaultHelper{
    if (!_defaultHelper) {
        _defaultHelper = [[VVDataBaseHelper alloc] init];
        _defaultHelper.updates = [NSMutableDictionary dictionaryWithCapacity:0];
    }
    return _defaultHelper;
}

+ (void)setVersions:(NSArray *)versions{
    [VVDataBaseHelper defaultHelper].versions = versions;
}

+ (void)setUpdateBlock:(void (^)(void))block forVersion:(NSString *)version{
    [VVDataBaseHelper defaultHelper].updates[version] = block;
}

+ (void)updateDataBases{
    // 每次打开App只能运行一次
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *startVersion = [[NSUserDefaults standardUserDefaults] stringForKey:VVDataBaseLastVersionKey];
        [self updateDataBasesFromVersion:startVersion];
        // 更新LastVersion
        NSArray *versions = [VVDataBaseHelper defaultHelper].versions;
        if (versions.count > 0) {
            [[NSUserDefaults standardUserDefaults] setObject:versions.lastObject forKey:VVDataBaseLastVersionKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
        // 清理缓存数据
        _defaultHelper = nil;
    });
}

+ (void)updateDataBasesFromVersion:(NSString *)startVersion{
    NSArray *versions = [VVDataBaseHelper defaultHelper].versions;
    NSDictionary *updateBlocks = [VVDataBaseHelper defaultHelper].updates;
    if (versions.count == 0) return;
    
    // 取得LastVersion在所有版本中的位置
    NSUInteger idx = NSNotFound;
    if (startVersion.length > 0){
        idx = [versions indexOfObject:startVersion];
        if (idx == NSNotFound) {
            NSUInteger i = 0;
            NSComparisonResult ret = NSOrderedDescending;
            while (ret != NSOrderedAscending && i < versions.count) {
                NSString *version = versions[i];
                ret = [self compareVersion1:startVersion version2:version];
                i ++;
            }
            if(ret == NSOrderedAscending) idx = i - 1;
        }
        else{
            idx = idx + 1;
        }
    }
    
    // 进行更新操作
    if (idx != NSNotFound) {
        for (NSUInteger i = idx; i < versions.count; i ++) {
            NSString *version = versions[i];
            void(^updateBlock)(void) = updateBlocks[version];
            !updateBlock ? : updateBlock();
        }
    }
}

+ (NSComparisonResult)compareVersion1:(NSString *)version1 version2:(NSString *)version2{
    NSCharacterSet *chset = [NSCharacterSet characterSetWithCharactersInString:@".-_"];
    NSArray *array1 = [version1 componentsSeparatedByCharactersInSet:chset];
    NSArray *array2 = [version2 componentsSeparatedByCharactersInSet:chset];
    NSUInteger count = MIN(array1.count, array2.count);
    for (NSUInteger i = 0; i < count; i ++) {
        NSString *str1 = array1[i];
        NSString *str2 = array2[i];
        NSComparisonResult ret = [str1 compare:str2];
        if(ret != NSOrderedSame) {
            return ret;
        }
    }
    return array1.count < array2.count ? NSOrderedAscending :
    array1.count == array2.count ? NSOrderedSame : NSOrderedDescending;
}

@end
