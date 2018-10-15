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
@property (nonatomic, strong) NSMutableDictionary<NSString *,void (^)(void)> *upgrades;

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
 升级到最新版本,暂不支持更新进度的反馈
 
 依次使用步骤为:
 
 1. 设置所有版本号 self.versions = @[@"1",@"2",....];
 
 2. 设置每个版本号对应的升级操作 self.updates[@"2"] = ^(){ [self doSomeThing];};
 
 3. 调用本方法进行更新 -upgrade;
 
 */
- (void)upgrade;

/**
 从某个指定版本升级到最新版本,暂不支持更新进度的反馈

 @param version 指定从某个版本号开始升级; nil 不会执行任何更新操作(相当于全新安装). 
 */
- (void)upgradeFrom:(NSString *)version;

@end
