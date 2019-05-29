//
//  VVFtsNLTokenizer.m
//  VVSequelize
//
//  Created by Valo on 2019/3/18.
//

#import "VVFtsNLTokenizer.h"
#import "NSString+Tokenizer.h"
#import <NaturalLanguage/NaturalLanguage.h>

static void nlEnumerator(const char *pText, int nText, const char *locale, BOOL pinyin, VVFtsXTokenHandler handler)
{
    if (!handler) return;

    if (@available(iOS 12.0, *)) {
        NLTokenizer *tokenizer = [[NLTokenizer alloc] initWithUnit:NLTokenUnitWord];
        tokenizer.string = [NSString stringWithUTF8String:pText];
        if (locale != 0 && strlen(locale) > 0) {
            [tokenizer setLanguage:[NSString stringWithUTF8String:locale]];
        }

        NSRange range = NSMakeRange(0, tokenizer.string.length);
        [tokenizer enumerateTokensInRange:range usingBlock:^(NSRange tokenRange, NLTokenizerAttributes flags, BOOL *stop) {
            @autoreleasepool {
                NSString *tk = [tokenizer.string substringWithRange:tokenRange];
                const char *pre = [tokenizer.string substringToIndex:tokenRange.location].UTF8String;
                const char *token = tk.UTF8String;
                int start = (int)strlen(pre);
                int len   = (int)strlen(token);
                int end   = (int)(start + len);
                handler(token, len, start, end, stop);

                if (*stop) return;
                if (!pinyin) return;

                NSArray<NSString *> *pinyins = [tk pinyinsForTokenize];
                for (NSString *py in pinyins) {
                    if (py.length == 0) continue;
                    const char *pyToken = py.UTF8String;
                    int pyLen = (int)strlen(pyToken);
                    handler(pyToken, pyLen, start, end, stop);
                    if (*stop) return;
                }
            }
        }];
    } else {
        handler(pText, nText, 0, nText, nil);
    }
}

// MARK: -
@implementation VVFtsNLTokenizer

+ (nonnull VVFtsXEnumerator)enumerator
{
    return nlEnumerator;
}

@end
