//
//  VVFtsJiebaTokenizer.m
//  VVSequelize
//
//  Created by Valo on 2019/3/19.
//

#import "VVFtsJiebaTokenizer.h"
#import "VVJieba.h"
#import "NSString+Tokenizer.h"

@implementation VVFtsJiebaTokenizer

+ (void)enumerateTokens:(const char *)pText
                    len:(int)nText
                 locale:(const char *)locale
                 pinyin:(BOOL)pinyin
             usingBlock:(void (^)(const char *token, int len, int start, int end, BOOL *stop))block
{
    UNUSED_PARAM(locale);
    [VVJieba enumerateTokens:pText usingBlock:^(const char *token, uint32_t offset, uint32_t len, BOOL *stop) {
        uint32_t end = offset + len;
        block(token, (int)len, (int)offset, (int)end, stop);
        if (pinyin) {
            NSString *tk = [NSString stringWithUTF8String:token];
            NSArray<NSString *> *pinyins = [tk pinyinsForTokenize];
            for (NSString *py in pinyins) {
                if (py.length == 0) continue;
                const char *pyToken = py.UTF8String;
                long pyLen = strlen(pyToken);
                block(pyToken, (int)pyLen, (int)offset, (int)end, stop);
            }
        }
    }];
}

@end
