//
//  NSString+Tokenizer.h
//  VVSequelize
//
//  Created by Valo on 2019/3/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (Tokenizer)

/// pinyin token resource preloading
+ (void)preloadingForPinyin;

/// set the maximum length of generate polyphone pinyin, default is 5
+ (void)setMaxSupportLengthOfPolyphone:(NSUInteger)maxSupportLength;

/// convert to simplified chinese string
- (NSString *)simplifiedChineseString;

/// convert to traditional chinese string
- (NSString *)traditionalChineseString;

/// check whether the string contains chinese
- (BOOL)hasChinese;

- (NSArray<NSString *> *)pinyinTokensOfChineseCharacter;

/// get chinese pinyin
- (NSString *)pinyin;

/// get pinyin tokens
- (NSArray<NSString *> *)pinyinsForTokenize;

/// get number tokens
- (NSArray<NSString *> *)numberStringsForTokenize;

/// clean string after removing special characters
- (NSString *)cleanString;

- (NSArray<NSArray<NSString *> *> *)splitIntoPinyins;

@end

@interface NSArray (Tokenizer)

- (NSArray *)filteredArrayUsingKeyword:(NSString *)keyword;

- (NSArray *)filteredArrayUsingKeyword:(NSString *)keyword pinyin:(BOOL)pinyin;

@end

NS_ASSUME_NONNULL_END
