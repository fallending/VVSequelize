//
//  VVFtsNLTokenizer.m
//  VVSequelize
//
//  Created by Valo on 2019/3/18.
//

#import "VVFtsNLTokenizer.h"
#import "NSString+Tokenizer.h"
#import <NaturalLanguage/NaturalLanguage.h>

// MARK: -
@implementation VVFtsNLTokenizer

+ (void)enumerateTokens:(const char *)pText
                    len:(int)nText
                 locale:(const char *)locale
                 pinyin:(BOOL)pinyin
             usingBlock:(void (^)(const char *token, int len, int start, int end, BOOL *stop))block
{
    if (@available(iOS 12.0, *)) {
        NLTokenizer *tokenizer = [[NLTokenizer alloc] initWithUnit:NLTokenUnitWord];
        tokenizer.string = [NSString stringWithUTF8String:pText];
        if (locale != 0 && strlen(locale) > 0) {
            [tokenizer setLanguage:[NSString stringWithUTF8String:locale]];
        }
        
        NSRange range = NSMakeRange(0, tokenizer.string.length);
        [tokenizer enumerateTokensInRange:range usingBlock:^(NSRange tokenRange, NLTokenizerAttributes flags, BOOL *stop) {
            @autoreleasepool {
                NSString *sub = [tokenizer.string substringWithRange:tokenRange];
                const char *pre = [tokenizer.string substringToIndex:tokenRange.location].UTF8String;
                const char *token = sub.UTF8String;
                int start = (int)strlen(pre);
                int len   = (int)strlen(token);
                int end   = (int)(start + len);
                block(token, len, start, end, stop);
                if (pinyin && (len % 3 == 0)) {
                    NSArray<NSString *> *pinyins = [sub pinyinsForTokenize];
                    for (NSString *pinyin in pinyins) {
                        if (pinyin.length == 0) continue;
                        const char *pinyinToken = pinyin.UTF8String;
                        int pinyinLen = (int)strlen(pinyinToken);
                        block(pinyinToken, pinyinLen, start, end, stop);
                    }
                }
            }
        }];
    } else {
        block(pText, nText, 0, nText, nil);
    }
}

@end
