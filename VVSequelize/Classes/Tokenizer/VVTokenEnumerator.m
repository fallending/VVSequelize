//
//  VVTokenEnumerator.m
//  VVSequelize
//
//  Created by Valo on 2019/8/20.
//

#import "VVTokenEnumerator.h"
#import "NSString+Tokenizer.h"
#import <NaturalLanguage/NaturalLanguage.h>

typedef NS_ENUM (NSUInteger, VVTokenType) {
    VVTokenTypeNone                = 0,
    VVTokenMultilingualPlaneLetter = 0x00000001,
    VVTokenMultilingualPlaneDigit  = 0x00000002,
    VVTokenMultilingualPlaneSymbol = 0x00000003,
    VVTokenMultilingualPlaneOther  = 0x0000FFFF,
    VVTokenAuxiliaryPlaneOther     = 0xFFFFFFFF,
};

@interface VVTokenCursor : NSObject
@property (nonatomic, assign) VVTokenType type;
@property (nonatomic, assign) u_long offset;
@property (nonatomic, assign) u_long len;

+ (instancetype)cursor:(VVTokenType)type offset:(u_long)offset len:(u_long)len;
@end

@implementation VVTokenCursor
+ (instancetype)cursor:(VVTokenType)type offset:(u_long)offset len:(u_long)len
{
    VVTokenCursor *cursor = [VVTokenCursor new];
    cursor.type = type;
    cursor.offset = offset;
    cursor.len = len;
    return cursor;
}

@end

@implementation VVToken
+ (instancetype)token:(NSString *)token len:(int)len start:(int)start end:(int)end
{
    VVToken *tk = [VVToken new];
    tk.token = token;
    tk.start = start;
    tk.len = len;
    tk.end = end;
    return tk;
}

- (NSString *)description {
    return _token;
}

- (NSString *)debugDescription {
    return [NSString stringWithFormat:@"'%@',%@,%@,%@", _token, @(_len), @(_start), @(_end)];
}

@end

@implementation VVTokenEnumerator

+ (NSArray<VVToken *> *)enumerate:(NSString *)input method:(VVTokenMethod)method
{
    switch (method) {
        case VVTokenMethodApple:
            return [self enumerateWithApple:input];

        case VVTokenMethodSequelize:
            return [self enumerateWithSequelize:input];

        case VVTokenMethodNatual:
            return [self enumerateWithNatual:input];

        default:
            return @[];
    }
}

+ (NSArray<VVToken *> *)enumerateWithApple:(NSString *)input
{
    if (input.length <= 0) return @[];
    NSString *source = input.lowercaseString.simplifiedChineseString;

    NSMutableArray *results = [NSMutableArray array];

    CFRange range = CFRangeMake(0, source.length);
    CFLocaleRef locale = CFLocaleCopyCurrent(); //need CFRelease!

    // create tokenizer
    CFStringTokenizerRef tokenizer = CFStringTokenizerCreate(kCFAllocatorDefault, (CFStringRef)source, range, kCFStringTokenizerUnitWordBoundary, locale);

    //token status
    CFStringTokenizerTokenType tokenType = CFStringTokenizerGoToTokenAtIndex(tokenizer, 0);

    while (tokenType != kCFStringTokenizerTokenNone) {
        @autoreleasepool {
            // get current range
            range = CFStringTokenizerGetCurrentTokenRange(tokenizer);
            NSString *sub = [source substringWithRange:NSMakeRange(range.location, range.length)];
            const char *pre = [source substringWithRange:NSMakeRange(0, range.location)].UTF8String ? : "";
            const char *token = sub.UTF8String ? : "";
            int start = (int)strlen(pre);
            int len = (int)strlen(token);
            int end = start + len;

            if (len > 0 && (unsigned char)token[0] >= 0xFC) {
                int hzlen = 3;
                for (int i = 0; i < len; i += 3) {
                    NSString *hz = [[NSString alloc] initWithBytes:token + i length:hzlen encoding:NSUTF8StringEncoding];
                    if (!hz) continue;
                    VVToken *tk = [VVToken token:hz len:hzlen start:(int)(start + i) end:(int)(start + i + hzlen)];
                    [results addObject:tk];
                }
            } else {
                [results addObject:[VVToken token:sub len:len start:start end:end]];
            }
            // get next token
            tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer);
        }
    }

    // release
    if (locale != NULL) CFRelease(locale);
    if (tokenizer) CFRelease(tokenizer);

    return results;
}

+ (NSArray<VVToken *> *)enumerateWithNatual:(NSString *)input
{
    if (input.length <= 0) return @[];
    NSString *source = input.lowercaseString.simplifiedChineseString;

    __block NSMutableArray *results = [NSMutableArray array];
    if (@available(iOS 12.0, *)) {
        NLTokenizer *tokenizer = [[NLTokenizer alloc] initWithUnit:NLTokenUnitWord];
        tokenizer.string = source;

        NSRange range = NSMakeRange(0, tokenizer.string.length);
        [tokenizer enumerateTokensInRange:range usingBlock:^(NSRange tokenRange, NLTokenizerAttributes flags, BOOL *stop) {
            @autoreleasepool {
                NSString *tk = [tokenizer.string substringWithRange:tokenRange];
                const char *pre = [tokenizer.string substringToIndex:tokenRange.location].UTF8String;
                const char *token = tk.UTF8String;
                int start = (int)strlen(pre);
                int len   = (int)strlen(token);
                int end   = (int)(start + len);
                [results addObject:[VVToken token:tk len:len start:start end:end]];
                if (*stop) return;
            }
        }];
    }

    return results;
}

+ (BOOL)isSymbol:(unichar)ch {
    static NSCharacterSet *_symbolSet;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableCharacterSet *set = [NSMutableCharacterSet new];
        [set formUnionWithCharacterSet:[NSCharacterSet controlCharacterSet]];
        [set formUnionWithCharacterSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        [set formUnionWithCharacterSet:[NSCharacterSet nonBaseCharacterSet]];
        [set formUnionWithCharacterSet:[NSCharacterSet punctuationCharacterSet]];
        [set formUnionWithCharacterSet:[NSCharacterSet symbolCharacterSet]];
        [set formUnionWithCharacterSet:[NSCharacterSet illegalCharacterSet]];
        _symbolSet = set;
    });
    return [_symbolSet characterIsMember:ch];
}

+ (NSArray<VVToken *> *)enumerateWithSequelize:(NSString *)input
{
    if (input.length <= 0) return @[];
    NSString *source = input.lowercaseString.simplifiedChineseString;
    const char *cSource = source.UTF8String ? : "";
    NSUInteger inputLen = strlen(cSource);
    if (inputLen == 0) return @[];

    // generate cursors
    NSMutableArray *cursors = [NSMutableArray array];
    u_long len = 0;
    VVTokenType type = VVTokenTypeNone;
    BOOL end = NO;

    for (u_long offset = 0; offset < inputLen;) {
        @autoreleasepool {
            const unsigned char ch = cSource[offset];
            if (ch < 0xC0) {
                len = 1;
                if (ch >= 0x30 && ch <= 0x39) {
                    type = VVTokenMultilingualPlaneDigit;
                } else if ((ch >= 0x41 && ch <= 0x5a) || (ch >= 0x61 && ch <= 0x7a)) {
                    type = VVTokenMultilingualPlaneLetter;
                } else {
                    type = [self isSymbol:ch] ? VVTokenMultilingualPlaneSymbol : VVTokenMultilingualPlaneOther;
                }
            } else if (ch < 0xF0) {
                unichar unicode = 0;
                if (ch < 0xE0) {
                    len = 2;
                    unicode = ch & 0x1F;
                } else {
                    len = 3;
                    unicode = ch & 0x0F;
                }
                for (u_long j = offset + 1; j < offset + len; ++j) {
                    if (j < inputLen) {
                        unicode = (unicode << 6) | (cSource[j] & 0x3F);
                    } else {
                        type = VVTokenTypeNone;
                        len = inputLen - j;
                        end = YES;
                    }
                }
                if (!end) {
                    type = [self isSymbol:unicode] ? VVTokenMultilingualPlaneSymbol : VVTokenMultilingualPlaneOther;
                }
            } else {
                type = VVTokenAuxiliaryPlaneOther;
                if (ch < 0xF8) {
                    len = 4;
                } else if (ch < 0xFC) {
                    len = 5;
                } else {
                    len = 3; // split every chinese character
                    // len = 6; // split every two chinese characters
                }
            }

            if (end) break;

            VVTokenCursor *cursor = [VVTokenCursor cursor:type offset:offset len:len];
            [cursors addObject:cursor];
            offset += len;
        }
    }
    VVTokenCursor *cursor = [VVTokenCursor cursor:VVTokenTypeNone offset:inputLen len:0];
    [cursors addObject:cursor];

    NSMutableArray *results = [NSMutableArray array];
    VVTokenType lastType = VVTokenTypeNone;
    u_long partOffset = 0;
    u_long partLength = 0;
    for (VVTokenCursor *cursor in cursors) {
        @autoreleasepool {
            BOOL change = cursor.type != lastType;
            if (change) {
                if (partLength > 0) {
                    switch (lastType) {
                        case VVTokenMultilingualPlaneLetter:
                        case VVTokenMultilingualPlaneDigit: {
                            NSString *string = [[NSString alloc] initWithBytes:cSource + partOffset length:partLength encoding:NSASCIIStringEncoding];
                            VVToken *tk = [VVToken token:string len:(int)partLength start:(int)partOffset end:(int)(partOffset + partLength)];
                            [results addObject:tk];
                        } break;

                        default:
                            break;
                    }
                }

                switch (cursor.type) {
                    case VVTokenMultilingualPlaneLetter:
                    case VVTokenMultilingualPlaneDigit: {
                        partOffset = cursor.offset;
                        partLength = 0;
                    } break;

                    default:
                        break;
                }
            }

            switch (cursor.type) {
                case VVTokenMultilingualPlaneLetter:
                case VVTokenMultilingualPlaneDigit: {
                    partLength += cursor.len;
                } break;

                case VVTokenMultilingualPlaneSymbol:
                case VVTokenMultilingualPlaneOther:
                case VVTokenAuxiliaryPlaneOther: {
                    if (cursor.len > 0) {
                        NSString *string = [[NSString alloc] initWithBytes:cSource + cursor.offset length:cursor.len encoding:NSUTF8StringEncoding];
                        if (string.length > 0) {
                            VVToken *tk = [VVToken token:string len:(int)cursor.len start:(int)cursor.offset end:(int)(cursor.offset + cursor.len)];
                            [results addObject:tk];
                        }
                    }
                } break;

                default:
                    break;
            }
        }
        lastType = cursor.type;
    }

    return results;
}

+ (NSArray<VVToken *> *)enumerateCString:(const char *)input method:(VVTokenMethod)method
{
    const char *source = input ? : "";
    NSString *string = [NSString stringWithUTF8String:source];
    return [self enumerate:string method:method];
}

+ (NSArray<VVToken *> *)enumeratePinyins:(NSString *)fragment start:(int)start end:(int)end
{
    NSMutableArray *array = [NSMutableArray array];
    NSArray<NSString *> *pinyins = [fragment pinyinsForTokenize];
    for (NSString *py in pinyins) {
        const char *token = py.UTF8String ? : "";
        int len = (int)strlen(token);
        if (len <= 0 || [py isEqualToString:fragment]) continue;
        [array addObject:[VVToken token:py len:len start:start end:end]];
    }
    return array;
}

+ (NSArray<VVToken *> *)enumerateNumbers:(NSString *)whole
{
    const char *cString = whole.UTF8String ? : "";
    unsigned long len = strlen(cString);
    if (len == 0) return @[];

    NSMutableArray *array = [NSMutableArray array];
    NSMutableString *s_num = [NSMutableString string];
    int offset = -1;

    for (int i = 0; i < len; i++) {
        char ch = cString[i];
        if (ch >= '0' && ch <= '9') {
            if (ch > '0' && offset < 0) {
                offset = i;
            }
            if (offset >= 0) {
                [s_num appendFormat:@"%i", ch - '0'];
            }
        } else if (offset >= 0) {
            switch (ch) {
                case ',':
                    [s_num appendString:@","];
                    break;
                default:
                    [array addObject:@[s_num, @(offset)]];
                    s_num = [NSMutableString string];
                    offset = -1;
                    break;
            }
        }
    }
    if (offset >= 0) {
        [array addObject:@[s_num, @(offset)]];
        s_num = [NSMutableString string];
    }

    NSMutableArray *results = [NSMutableArray array];
    for (int i = 0; i < array.count; i++) {
        NSArray *sub = array[i];
        NSString *numstr = sub.firstObject;
        int offset = (int)[sub.lastObject unsignedIntegerValue];
        NSArray<NSString *> *numbers = [numstr numberStringsForTokenize];
        if (numbers.count >= 2) {
            for (NSString *num in numbers) {
                const char *token = num.UTF8String ? : "";
                int len = (int)strlen(token);
                if (len <= 0) continue;
                [results addObject:[VVToken token:num len:len start:offset end:offset + (int)numstr.length]];
            }
        }
    }
    return results;
}

@end
