//
//  VVOrmFtsConfig.h
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/13.
//

#import "VVOrmConfig.h"

@interface VVOrmFtsConfig : VVOrmConfig
@property (nonatomic, copy  ) NSString *module;     ///< FTS模块:fts3,fts4,fts5.默认为fts4.
@property (nonatomic, copy  ) NSString *tokenizer;  ///< FTS分词器:porter,unicode61,icu,...
@property (nonatomic, strong) NSArray  *notindexed; ///< 不索引的的字段

/**
 设置FTS模块
 
 @param module FTS模块名,fts3,fts4,fts5
 @return ORM配置
 */
- (instancetype)module:(NSString *)module;

/**
 设置FTS分词器,必须是当前sqlite3库支持的.
 
 @param tokenizer FTS分词器名,porter,unicode61,icu,...
 @return ORM配置
 */
- (instancetype)tokenizer:(NSString *)tokenizer;

/**
 设置不索引的字段.
 
 @param notindexed 不索引的字段
 @return ORM配置
 */
- (instancetype)notindexed:(NSArray<NSString *> *)notindexed;

@end
