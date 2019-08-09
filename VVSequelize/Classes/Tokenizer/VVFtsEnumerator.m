//
//  VVFtsEnumerator.m
//  VVSequelize
//
//  Created by Valo on 2019/8/9.
//

#import "VVFtsEnumerator.h"
#import "NSString+Tokenizer.h"

@implementation VVFtsEnumerator

+ (void)enumeratePinyins:(NSString *)fragment start:(int)start end:(int)end handler:(VVFtsXTokenHandler)handler
{
    BOOL stop = NO;
    NSArray<NSString *> *pinyins = [fragment pinyinsForTokenize];
    for (NSString *py in pinyins) {
        const char *token = py.UTF8String ? : "";
        int len = (int)strlen(token);
        if (len <= 0 || [py isEqualToString:fragment]) continue;
        handler(token, len, start, end, &stop);
        if (stop) break;
    }
}

+ (NSArray<VVFtsToken *> *)enumeratePinyins:(NSString *)fragment start:(int)start end:(int)end
{
    NSMutableArray *array = [NSMutableArray array];
    NSArray<NSString *> *pinyins = [fragment pinyinsForTokenize];
    for (NSString *py in pinyins) {
        const char *token = py.UTF8String ? : "";
        int len = (int)strlen(token);
        if (len <= 0 || [py isEqualToString:fragment]) continue;
        VVFtsToken *tk = [VVFtsToken new];
        tk.token = token;
        tk.len = len;
        tk.start = start;
        tk.end = end;
        [array addObject:tk];
    }
    return array;
}

+ (void)enumerateNumbers:(NSString *)whole handler:(VVFtsXTokenHandler)handler
{
    NSMutableArray *array = [NSMutableArray array];
    NSMutableString *s_num = [NSMutableString string];
    uint32_t offset = 0;

    for (int i = 0; i < whole.length; i++) {
        unichar ch = [whole characterAtIndex:i];
        if (ch >= '0' && ch <= '9') {
            if (s_num.length == 0) {
                offset = i;
            }
            [s_num appendFormat:@"%i", ch];
        } else if (s_num.length > 0) {
            switch (ch) {
                case ',':
                    [s_num appendString:@","];
                    break;
                default:
                    [array addObject:@[s_num, @(offset)]];
                    s_num = [NSMutableString string];
                    break;
            }
        }
    }
    if (s_num.length > 0) {
        [array addObject:@[s_num, @(offset)]];
        s_num = [NSMutableString string];
    }

    BOOL stop = NO;
    for (int i = 0; i < array.count; i++) {
        NSArray *sub = array[i];
        NSString *numstr = sub.firstObject;
        uint32_t offset = (uint32_t)[sub.lastObject unsignedIntegerValue];
        NSArray<NSString *> *numbers = [numstr numberStringsForTokenize];
        if (numbers.count >= 2) {
            for (NSString *num in numbers) {
                const char *token = num.UTF8String ? : "";
                int len = (int)strlen(token);
                if (len <= 0 || [num isEqualToString:numstr]) continue;
                NSString *sub = [whole substringToIndex:offset];
                int r_offset = (int)strlen(sub.UTF8String);
                handler(token, len, r_offset, r_offset + len, &stop);
                if (stop) break;
            }
        }
    }
}

@end
