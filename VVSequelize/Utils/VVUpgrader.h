//
//  VVUpgrader.h
//  VVSequelize
//
//  Created by Jinbo Li on 2018/8/11.
//

#import <Foundation/Foundation.h>

@interface VVUpgrader : NSObject

/**
 版本号列表
 @note: 请依次存放,例如 @[@"1.0.1",@"1.0.3", @"2.0",...]
 */
@property (nonatomic, strong) NSArray<NSString *> *versions;

/**
 每个版本号对应的升级操作
 */
@property (nonatomic, strong) NSMutableDictionary<NSString *,void (^)(NSProgress *)> *upgrades;

/**
 获取最后版本号的方法,不设置则默认使用NSUserDefaults
 */
@property (nonatomic, copy) void (^lastVersionSetter)(NSString *);

/**
 设置最后版本号的方法,不设置则默认使用NSUserDefaults
 */
@property (nonatomic, copy) NSString * (^lastVersionGetter)(void);

//MAKR: - 升级管理
/**
 升级到最新版本
 
 依次使用步骤为:
 
 1. 设置所有版本号 self.versions = @[@"1",@"2",....];
 
 2. 设置每个版本号对应的升级操作 self.updates[@"2"] = ^(NSProgress *){ [self doSomeThing];};
 
 3. 调用本方法进行更新 -upgrade;
 
 @param progress 升级进度

 */
- (void)upgrade:(NSProgress *)progress;

/**
 从某个指定版本升级到最新版本

 @param version 指定从某个版本号开始升级; nil 会执行所有更新操作(全新安装或第一次使用更新).
 @param progress 升级进度
 */
- (void)upgradeFrom:(NSString *)version
           progress:(NSProgress *)progress;

@end
