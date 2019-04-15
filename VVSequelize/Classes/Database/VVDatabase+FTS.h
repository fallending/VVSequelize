//
//  VVDataBase+FTS.h
//  VVSequelize
//
//  Created by Valo on 2019/3/20.
//

#import "VVDatabase.h"

NS_ASSUME_NONNULL_BEGIN

@protocol VVFtsTokenizer;
@interface VVDatabase (FTS)

/**
 分词器懒加载,处理一些耗时操作,比如加载多音字数据,结巴分词数据,中文转拼音数据等.
 
 @note 建议在app初始化时异步调用一次
 */
+ (void)lazyLoadTokenizers;

/**
 注册ft3/fts4的分词器
 
 @param cls 分词器核心类
 @param name 分词器名称
 @return 是否注册成功
 */
- (BOOL)registerFtsThreeFourTokenizer:(Class<VVFtsTokenizer>)cls forName:(NSString *)name;

/**
 注册fts5的分词器
 
 @param cls 分词器核心类
 @param name 分词器名称
 @return 是否注册成功
 */
- (BOOL)registerFtsFiveTokenizer:(Class<VVFtsTokenizer>)cls forName:(NSString *)name;

/**
 根据分词器名称获取fts3/fts4核心类
 
 @param name 分词器名称
 @return 分词器核心类
 */
- (nullable Class<VVFtsTokenizer>)ftsThreeFourTokenizerClassForName:(NSString *)name;

/**
 根据分词器名称获取fts5核心类
 
 @param name 分词器名称
 @return 分词器核心类
 */
- (nullable Class<VVFtsTokenizer>)ftsFiveTokenizerClassForName:(NSString *)name;

@end

NS_ASSUME_NONNULL_END
