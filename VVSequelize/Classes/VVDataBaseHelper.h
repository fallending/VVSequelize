//
//  VVDBVersionManager.h
//  VVSequelize
//
//  Created by Jinbo Li on 2018/8/11.
//

#import <Foundation/Foundation.h>

@interface VVDataBaseHelper : NSObject

//MAKR: - 版本管理
/**
 设置数据库版本列表,可只设置需要更新操作的数据库版本

 @param versions 数据库版本列表
 */
+ (void)setVersions:(NSArray *)versions;

/**
 设置某个版本相对于版本列表中上一个版本更新数据库的操作

 @param block 更新数据库的操作
 @param version 版本号
 */
+ (void)setUpdateBlock:(void (^)(void))block
            forVersion:(NSString *)version;

/**
 更新数据库,暂不支持更新进度的反馈
 
 依次使用步骤为:
 
 1. 设置所有数据库版本号 +setVersions:
 
 2. 设置某些版本相对上个版本需要进行的数据库操作 +setUpdateBlock:forVersion:
 
 3. 调用本方法进行更新 +updateDataBases
 
 @attention 本方法仅会执行一次(单例方式),切执行后会清空versions和updateBlocks,避免内存占用.
 */
+ (void)updateDataBases;


/**
 更新数据库,主要用于开发过程中的调试,暂不支持更新进度的反馈
 
 依次使用步骤为:
 
 1. 设置所有数据库版本号 +setVersions:
 
 2. 设置某些版本相对上个版本需要进行的数据库操作 +setUpdateBlock:forVersion:
 
 3. 调用本方法进行更新 +updateDataBases

 @param version 指定从某个数据库版本开始更新,若不传值(相当于全新安装),不会执行任何更新操作.
 
 @attention 本方法可重复执行
 */
+ (void)updateDataBasesFromVersion:(NSString *)version;

@end
