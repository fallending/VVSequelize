
#import <Foundation/Foundation.h>

#ifndef   UNUSED_PARAM
#define   UNUSED_PARAM(v) (void)(v)
#endif

#ifndef TOKEN_PINYIN_MAX_LENGTH
#define TOKEN_PINYIN_MAX_LENGTH 15
#endif

NS_ASSUME_NONNULL_BEGIN

@interface VVToken : NSObject
@property (nonatomic, copy) NSString *token;
@property (nonatomic, assign) int len;
@property (nonatomic, assign) int start;
@property (nonatomic, assign) int end;

+ (instancetype)token:(NSString *)token len:(int)len start:(int)start end:(int)end;
@end

typedef NS_ENUM (NSUInteger, VVTokenMethod) {
    VVTokenMethodApple,
    VVTokenMethodSequelize,
    VVTokenMethodNatual,

    VVTokenMethodUnknown = 0xFFFFFFFF
};

typedef NS_OPTIONS (NSUInteger, VVTokenMask) {
    VVTokenMaskPinyin       = 0xFFFF,  ///< placeholder, it will be executed without setting
    VVTokenMaskAbbreviation = 1 << 16, ///< pinyin abbreviation. not recommended, many invalid results will be found
    VVTokenMaskSyllable     = 1 << 17, ///< pinyin segmentation
    VVTokenMaskNumber       = 1 << 18,
    VVTokenMaskTransform    = 1 << 19,

    VVTokenMaskDefault      = (VVTokenMaskNumber | VVTokenMaskTransform),
    VVTokenMaskAll          = 0xFFFFFFFF,
    VVTokenMaskAllPinYin    = (VVTokenMaskPinyin | VVTokenMaskAbbreviation),
};

@protocol VVTokenEnumeratorProtocol <NSObject>

+ (NSArray<VVToken *> *)enumerate:(NSString *)input method:(VVTokenMethod)method mask:(VVTokenMask)mask;

@end

@interface VVTokenEnumerator : NSObject

+ (void)registerEnumerator:(Class<VVTokenEnumeratorProtocol>)cls forMethod:(VVTokenMethod)method;

+ (NSArray<VVToken *> *)enumerate:(NSString *)input method:(VVTokenMethod)method mask:(VVTokenMask)mask;

+ (NSArray<VVToken *> *)enumerateCString:(const char *)input method:(VVTokenMethod)method mask:(VVTokenMask)mask;

+ (NSArray<VVToken *> *)extraTokens:(const char *)cSource mask:(VVTokenMask)mask;

@end

NS_ASSUME_NONNULL_END
