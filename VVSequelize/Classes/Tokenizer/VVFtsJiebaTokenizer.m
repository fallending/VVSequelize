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
        if (pinyin && (len % 3 == 0)) {
            NSString *sub = [NSString stringWithUTF8String:token];
            NSArray<NSString *> *pinyins = [sub pinyinsForTokenize];
            for (NSString *pinyin in pinyins) {
                if (pinyin.length == 0) continue;
                const char *pinyinToken = pinyin.UTF8String;
                long pinyinLen = strlen(pinyinToken);
                block(pinyinToken, (int)pinyinLen, (int)offset, (int)end, stop);
            }
        }
    }];
}

@end
