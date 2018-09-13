//
//  VVOrmCommonConfig.h
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/13.
//

#import "VVOrmConfig.h"

@interface VVOrmCommonConfig : VVOrmConfig
@property (nonatomic, strong) NSArray<NSString *> *uniques;    ///< 具有唯一性约束的字段

/**
 设置唯一性约束的字段
 
 @param uniques 唯一性约束的字段
 @return ORM配置
 */
- (instancetype)uniques:(NSArray<NSString *> *)uniques;
@end
