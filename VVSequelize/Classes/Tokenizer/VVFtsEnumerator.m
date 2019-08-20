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
        [array addObject:[VVFtsToken token:py len:len start:start end:end]];
    }
    return array;
}

+ (void)enumerateNumbers:(NSString *)whole handler:(VVFtsXTokenHandler)handler
{
    const char * cString = whole.UTF8String ? : "";
    unsigned long len = strlen(cString);
    if(len == 0) return;
    
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

    BOOL stop = NO;
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
                handler(token, len, offset, offset + len, &stop);
                if (stop) break;
            }
        }
    }
}

@end
