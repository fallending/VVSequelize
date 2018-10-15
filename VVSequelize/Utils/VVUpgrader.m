//
//  VVUpgrader.m
//  VVSequelize
//
//  Created by Jinbo Li on 2018/8/11.
//

#import "VVUpgrader.h"

NSString * const VVUpgraderLastVersionKey = @"VVUpgraderLastVersionKey";

@implementation VVUpgrader

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.versions = [NSArray array];
        self.upgrades = [NSMutableDictionary dictionaryWithCapacity:0];
        [self setLastVersionGetter:^NSString *{
            return [[NSUserDefaults standardUserDefaults] stringForKey:VVUpgraderLastVersionKey];
        }];
        [self setLastVersionSetter:^(NSString *version) {
            if(version.length > 0){
                [[NSUserDefaults standardUserDefaults] setObject:version forKey:VVUpgraderLastVersionKey];
            }
            else{
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:VVUpgraderLastVersionKey];
            }
            [[NSUserDefaults standardUserDefaults] synchronize];
        }];
    }
    return self;
}

- (void)upgrade{
    NSString *last = self.lastVersionGetter();
    [self upgradeFrom:last];
    self.lastVersionSetter(self.versions.lastObject);
}

- (void)upgradeFrom:(NSString *)version{
    if (self.versions.count == 0) return;
    
    // 取得version在所有版本中的位置
    NSUInteger idx = NSNotFound;
    if (version.length > 0){
        idx = [self.versions indexOfObject:version];
        if (idx == NSNotFound) {
            NSUInteger i = 0;
            NSComparisonResult ret = NSOrderedDescending;
            while (ret != NSOrderedAscending && i < self.versions.count) {
                NSString *ver = self.versions[i];
                ret = [self compareVersion:version with:ver];
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
        for (NSUInteger i = idx; i < self.versions.count; i ++) {
            NSString *ver = self.versions[i];
            void(^upgradeBlock)(void) = self.upgrades[ver];
            !upgradeBlock ? : upgradeBlock();
        }
    }
}

- (NSComparisonResult)compareVersion:(NSString *)version1 with:(NSString *)version2{
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
