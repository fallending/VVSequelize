//
//  VVOrmFtsField.h
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/13.
//

#import "VVOrmField.h"

// 使用宏定义字段配置
#define VVFIELD_FTS_UNINDEXED(name)    [[VVOrmFtsField alloc] initWithName:(name) fts_notindexed:NO]

@interface VVOrmFtsField : VVOrmField
@property (nonatomic, assign) BOOL notindexed; ///< 在FTS表中不进行索引,仅在FTS表中有效,默认为YES

/**
 生成FTS表字段配置
 
 @param name 字段名
 @param notindexed 是否不进行FTS分词索引
 @return 字段配置
 */
- (instancetype)initWithName:(NSString *)name
                  notindexed:(BOOL)notindexed;

@end
