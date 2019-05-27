//
//  VVFtsTokenizer.h
//  VVSequelize
//
//  Created by Valo on 2019/4/1.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#ifndef   UNUSED_PARAM
#define   UNUSED_PARAM(v) (void)(v)
#endif

#ifndef TOKEN_PINYIN_MAX_LENGTH
#define TOKEN_PINYIN_MAX_LENGTH 15
#endif

/**
 FTS处理分词的函数

 @param token 分词字符串
 @param len 分词字符串的长度
 @param start 源字符串的起始位置
 @param end 源字符串的结束位置
 @param stop 是否终止分词
 */
typedef void (^VVFtsXTokenHandler)(const char *token, int len, int start, int end, BOOL *_Nullable stop);

/**
 FTS分词器核心函数

 @param pText 要分词的字符串,c string
 @param nText 要分词字符串的长度
 @param locale 是否需要进行本地化处理
 @param pinyin 是否要进行拼音分词
 @param handler 分词后的回调
 */
typedef void (*VVFtsXEnumerator)(const char *pText, int nText, const char *_Nullable locale, BOOL pinyin, VVFtsXTokenHandler handler);

// MARK: -
@protocol VVFtsTokenizer <NSObject>

@required

/**
 FTS分词器核心函数

 @return FTS分词器核心函数
 */
+ (VVFtsXEnumerator)enumerator;

@end

/**
 分词对象
 */
@interface VVFtsToken : NSObject
@property (nonatomic, assign) const char *token;  ///< 分词
@property (nonatomic, assign) int len;  ///< 分词长度
@property (nonatomic, assign) int start; ///< 分词对应原始字符串的起始位置
@property (nonatomic, assign) int end; ///< 分词对应原始字符串的结束位置
@end

NS_ASSUME_NONNULL_END
