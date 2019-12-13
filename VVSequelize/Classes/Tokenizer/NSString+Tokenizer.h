//
//  NSString+Tokenizer.h
//  VVSequelize
//
//  Created by Valo on 2019/3/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface VVPinYin : NSObject
@property (nonatomic, strong, readonly) NSCharacterSet *trimmingSet;
@property (nonatomic, strong, readonly) NSCharacterSet *cleanSet;
@property (nonatomic, strong, readonly) NSCharacterSet *symbolSet;

+ (instancetype)shared;

@end

@interface NSString (Tokenizer)

/// pinyin token resource preloading
+ (void)preloadingForPinyin;

/// convert to simplified chinese string
- (NSString *)simplifiedChineseString;

/// convert to traditional chinese string
- (NSString *)traditionalChineseString;

/// check whether the string contains chinese
- (BOOL)hasChinese;

/// get chinese pinyin
- (NSString *)pinyin;

/// get pinyin
/// @return two-dimensional array: [ [full pinyin],  [first letter] ]
- (NSArray<NSArray<NSString *> *> *)pinyinsAtIndex:(NSUInteger)index;

- (NSArray<NSArray<NSString *> *> *)pinyinsForMatch;

- (NSArray<NSArray<NSArray<NSString *> *> *> *)pinyinMatrix;

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
