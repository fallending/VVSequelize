
#import <Foundation/Foundation.h>

//MARK: - defines
#ifndef   UNUSED_PARAM
#define   UNUSED_PARAM(v) (void)(v)
#endif

#ifndef TOKEN_PINYIN_MAX_LENGTH
#define TOKEN_PINYIN_MAX_LENGTH 15
#endif

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS (NSUInteger, VVTokenMask) {
    VVTokenMaskTransform    = 1 << 0,
    VVTokenMaskPinyin       = 1 << 1, ///< placeholder, it will be executed without setting
    VVTokenMaskAbbreviation = 1 << 2, ///< pinyin abbreviation. not recommended, many invalid results will be found
    VVTokenMaskSyllable     = 1 << 3, ///< pinyin segmentation

    VVTokenMaskDefault      = VVTokenMaskTransform,
    VVTokenMaskAll          = 0xFFFFFF,
    VVTokenMaskAllPinYin    = (VVTokenMaskPinyin | VVTokenMaskAbbreviation),
};

//MARK: - VVTokenizerName
typedef NSString *VVTokenizerName NS_EXTENSIBLE_STRING_ENUM;

FOUNDATION_EXPORT VVTokenizerName const VVTokenTokenizerSequelize;
FOUNDATION_EXPORT VVTokenizerName const VVTokenTokenizerApple;
FOUNDATION_EXPORT VVTokenizerName const VVTokenTokenizerNatual;

//MARK: - VVToken

@interface VVToken : NSObject <NSCopying>
@property (nonatomic, assign) char *word;
@property (nonatomic, assign) int len;
@property (nonatomic, assign) int start;
@property (nonatomic, assign) int end;

@property (nonatomic, copy, readonly) NSString *token;

+ (instancetype)token:(const char *)word len:(int)len start:(int)start end:(int)end;

+ (NSArray<VVToken *> *)sortedTokens:(NSArray<VVToken *> *)tokens;
@end

@protocol VVTokenEnumerator <NSObject>

+ (NSArray<VVToken *> *)enumerate:(const char *)input mask:(VVTokenMask)mask;

@end

@interface VVTokenAppleEnumerator : NSObject <VVTokenEnumerator>

@end

@interface VVTokenNatualEnumerator : NSObject <VVTokenEnumerator>

@end

@interface VVTokenSequelizeEnumerator : NSObject <VVTokenEnumerator>

@end

NS_ASSUME_NONNULL_END
