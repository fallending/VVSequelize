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
@property (nonatomic, strong, readonly) NSDictionary *hanzi2pinyins;
@property (nonatomic, strong, readonly) NSDictionary *pinyins;
@property (nonatomic, strong, readonly) NSDictionary *gb2big5Map;
@property (nonatomic, strong, readonly) NSDictionary *big52gbMap;
@property (nonatomic, strong, readonly) NSDictionary *syllables;

+ (instancetype)shared;

@end

@interface VVPinYinFruit<__covariant Element> : NSObject
@property (nonatomic, strong) NSArray<Element> *abbrs;
@property (nonatomic, strong) NSArray<Element> *fulls;

+ (instancetype)fruitWithAbbrs:(NSArray<Element> *)abbrs fulls:(NSArray<Element> *)fulls;
@end

@interface NSString (Tokenizer)

/// pinyin token resource preloading
+ (void)preloadingForPinyin;

/// using utf8 or ascii encoding to generate objc string
+ (instancetype)ocStringWithCString:(const char *)cString;

/// using utf8 or ascii encoding to generate c string
- (const char *)cLangString;

/// convert to simplified chinese string
- (NSString *)simplifiedChineseString;

/// convert to traditional chinese string
- (NSString *)traditionalChineseString;

/// check whether the string contains chinese
- (BOOL)hasChinese;

/// get chinese pinyin
- (NSString *)pinyin;

/// get pinyin
/// @return abbrs:[abbreviation], fulls:[full pinyin],
- (VVPinYinFruit<NSString *> *)pinyins;

/// get pinyin
/// @return abbrs:[abbreviation], fulls:[full pinyin],
- (VVPinYinFruit<NSString *> *)pinyinsAtIndex:(NSUInteger)index;

/// get pinyin
/// @return abbrs:[[abbreviation]], fulls:[[full pinyin]],
- (VVPinYinFruit<NSArray<NSString *> *> *)pinyinMatrix;

/// get number without separator
- (NSString *)numberWithoutSeparator;

/// clean string after removing special characters
- (NSString *)cleanString;

/// convert white space characters (\t \n \f \r \p{Z}) to whtie space
- (NSString *)singleLine;

/// string use to match
- (NSString *)matchingPattern;

/// regular expression of keyword
- (NSString *)regexPattern;

/// transform special characters for fts5 search
- (NSString *)fts5KeywordPattern;

/// fast pinyin segmentation
- (NSArray<NSString *> *)fastPinyinSegmentation;

/// all pinyin segmentation
- (NSArray<NSArray<NSString *> *> *)pinyinSegmentation;

@end

@interface NSArray (Tokenizer)

- (NSUInteger)maxTiledCount;

- (NSArray<NSArray *> *)tiledArray;

- (NSArray<NSArray *> *)tiledArray:(NSUInteger)limit;

@end

@interface NSAttributedString (Highlighter)

/// trim the text to the specified length, and use ellipsis to replace the excess part
- (NSAttributedString *)attributedStringByTrimmingToLength:(NSUInteger)maxLen withAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes;

@end

NS_ASSUME_NONNULL_END
