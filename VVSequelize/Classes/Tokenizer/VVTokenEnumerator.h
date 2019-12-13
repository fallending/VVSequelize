
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
    VVTokenMaskPinyin      = 0xFFFF, ///< placeholder, it will be executed without setting
    VVTokenMaskFirstLetter = 1 << 16,
    VVTokenMaskCharacter   = 1 << 17,
    VVTokenMaskNumber      = 1 << 18,
    VVTokenMaskSplitPinyin = 1 << 19,
    VVTokenMaskTransform   = 1 << 20,

    VVTokenMaskDeault      = 0,
    VVTokenMaskManual      = VVTokenMaskNumber | VVTokenMaskTransform,
    VVTokenMaskExtra       = VVTokenMaskPinyin | VVTokenMaskFirstLetter | VVTokenMaskNumber,
    VVTokenMaskAll         = 0xFFFFFFFF,
};

@interface VVTokenEnumerator : NSObject

+ (NSArray<VVToken *> *)enumerate:(NSString *)input method:(VVTokenMethod)method mask:(VVTokenMask)mask;

+ (NSArray<VVToken *> *)enumerateCString:(const char *)input method:(VVTokenMethod)method mask:(VVTokenMask)mask;

@end

NS_ASSUME_NONNULL_END
