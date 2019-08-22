//
//  VVTokenEnumerator.h
//  VVSequelize
//
//  Created by Valo on 2019/8/20.
//

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

@interface VVTokenEnumerator : NSObject

+ (NSArray<VVToken *> *)enumerate:(NSString *)input method:(VVTokenMethod)method;

+ (NSArray<VVToken *> *)enumerateCString:(const char *)input method:(VVTokenMethod)method;

+ (NSArray<VVToken *> *)enumeratePinyins:(NSString *)fragment start:(int)start end:(int)end;

+ (NSArray<VVToken *> *)enumerateNumbers:(NSString *)whole;

@end

NS_ASSUME_NONNULL_END
