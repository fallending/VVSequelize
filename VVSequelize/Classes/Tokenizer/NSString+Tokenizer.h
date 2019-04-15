//
//  NSString+Tokenizer.h
//  VVSequelize
//
//  Created by Valo on 2019/3/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (Tokenizer)

/**
 判断字符串是否含有中文
 
 @note 不建议在分词步骤中判断是否含中文,正则表达式效率较低.
 @return 是否含有中文
 */
- (BOOL)hasChinese;

- (NSString *)pinyin;

- (NSArray<NSString *> *)pinyinsForTokenize;

@end

NS_ASSUME_NONNULL_END
