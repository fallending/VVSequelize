//
//  VVJieba.h
//  VVSequelize
//
//  Created by Valo on 2019/3/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface VVJieba : NSObject
/**
 预加载结巴分词资源
 */
+ (void)preloading;

/**
 分词

 @param string 要分词的字符串
 @param block 处理分词结果
 */
+ (void)enumerateTokens:(const char *)string usingBlock:(void (^)(const char *token, uint32_t offset, uint32_t len, BOOL *stop))block;
@end

NS_ASSUME_NONNULL_END
