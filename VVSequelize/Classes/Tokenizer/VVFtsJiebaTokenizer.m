//
//  VVFtsJiebaTokenizer.m
//  VVSequelize
//
//  Created by Valo on 2019/3/19.
//

#import "VVFtsJiebaTokenizer.h"
#import "VVJieba.h"
#import "NSString+Tokenizer.h"

static void jiebaEnumerator(const char *pText, int nText, const char *locale, BOOL pinyin, VVFtsXTokenHandler handler)
{
    if (!handler) return;

    UNUSED_PARAM(locale);
    [VVJieba enumerateTokens:pText usingBlock:^(const char *token, uint32_t offset, uint32_t len, BOOL *stop) {
        uint32_t end = offset + len;
        handler(token, (int)len, (int)offset, (int)end, stop);

        if (*stop) return;
        if (!pinyin) return;

        NSString *tk = [NSString stringWithUTF8String:token];
        NSArray<NSString *> *pinyins = [tk pinyinsForTokenize];
        for (NSString *py in pinyins) {
            if (py.length == 0) continue;
            const char *pyToken = py.UTF8String;
            long pyLen = strlen(pyToken);
            handler(pyToken, (int)pyLen, (int)offset, (int)end, stop);
            if (*stop) return;
        }
    }];
}

@implementation VVFtsJiebaTokenizer

+ (nonnull VVFtsXEnumerator)enumerator {
    return jiebaEnumerator;
}

@end
