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

@interface VVPinYinItem : NSObject
@property (nonatomic, strong) NSArray<NSString *> *firsts;
@property (nonatomic, strong) NSArray<NSString *> *fulls;

+ (instancetype)itemWithFirsts:(NSArray<NSString *> *)firsts fulls:(NSArray<NSString *> *)fulls;
@end

@interface NSString (Tokenizer)

/// pinyin token resource preloading
+ (void)preloadingForPinyin;

/// using utf8 or ascii encoding to generate objc string
+ (instancetype)ocStringWithCString:(const char *)cString;

/// using utf8 or ascii encoding to generate c string
- (const char *)cString;

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
- (VVPinYinItem *)pinyinsAtIndex:(NSUInteger)index;

/// get pinyin
/// @return two-dimensional array: [ [full pinyin],  [first letter] ]
- (VVPinYinItem *)pinyinsForMatch;

/// get pinyin
/// @return three-dimensional array: [ [[full pinyin]],  [[first letter]] ]
- (NSArray<NSArray<NSArray<NSString *> *> *> *)pinyinMatrix;

/// get number tokens
- (NSArray<NSString *> *)numberStringsForTokenize;

/// clean string after removing special characters
- (NSString *)cleanString;

/// split into pinyins
- (NSArray<NSArray<NSString *> *> *)splitIntoPinyins;

@end

NS_ASSUME_NONNULL_END
