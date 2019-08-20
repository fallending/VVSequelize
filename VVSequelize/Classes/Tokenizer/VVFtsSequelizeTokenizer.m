//
//  VVFtsSequelizeTokenizer.m
//  VVSequelize
//
//  Created by Valo on 2019/8/19.
//

#import "VVFtsSequelizeTokenizer.h"
#import "NSString+Tokenizer.h"

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

static bool isSymbol(unichar ch)
{
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

static void sequelizeEnumerator(const char *pText, int nText, const char *locale, VVFtsXTokenHandler handler)
{
    if (!handler) return;
    NSString *input = [NSString stringWithUTF8String:pText];
    if (input.length <= 0) return;
    NSString *source = input.lowercaseString.simplifiedChineseString;
    const char *cSource = source.UTF8String ? : "";
    NSUInteger inputLen = strlen(cSource);
    if (inputLen == 0) return;

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
                    type = isSymbol(ch) ? VVTokenMultilingualPlaneSymbol : VVTokenMultilingualPlaneOther;
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
                    type = isSymbol(unicode) ? VVTokenMultilingualPlaneSymbol : VVTokenMultilingualPlaneOther;
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

    VVTokenType lastType = VVTokenTypeNone;
    u_long partOffset = 0;
    u_long partLength = 0;
    BOOL stop = NO;
    for (VVTokenCursor *cursor in cursors) {
        @autoreleasepool {
            BOOL change = cursor.type != lastType;
            if (change) {
                if (partLength > 0) {
                    switch (lastType) {
                        case VVTokenMultilingualPlaneLetter:
                        case VVTokenMultilingualPlaneDigit: {
                            NSString *string = [[NSString alloc] initWithBytes:cSource + partOffset length:partLength encoding:NSASCIIStringEncoding];
                            handler(string.UTF8String ? : "", (int)partLength, (int)partOffset, (int)(partOffset + partLength), &stop);
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
                            handler(string.UTF8String ? : "", (int)cursor.len, (int)cursor.offset, (int)(cursor.offset + cursor.len), &stop);
                        }
                    }
                } break;

                default:
                    break;
            }
        }
        lastType = cursor.type;
        if (stop) break;
    }
}

// MARK: -
@implementation VVFtsSequelizeTokenizer

+ (nonnull VVFtsXEnumerator)enumerator
{
    return sequelizeEnumerator;
}

@end
