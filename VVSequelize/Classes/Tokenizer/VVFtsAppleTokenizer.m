//
//  VVFtsAppleTokenizer.m
//  VVSequelize
//
//  Created by Valo on 2019/3/16.
//

#import "VVFtsAppleTokenizer.h"
#import "NSString+Tokenizer.h"

// MARK: -
@implementation VVFtsAppleTokenizer
+ (void)enumerateTokens:(const char *)pText
                    len:(int)nText
                 locale:(const char *)locale
                 pinyin:(BOOL)pinyin
             usingBlock:(void (^)(const char *token, int len, int start, int end, BOOL *stop))block
{
    NSString *text = [NSString stringWithUTF8String:pText];
    if (!text.length) return;
    
    CFRange range = CFRangeMake(0, [text length]); //使用范围
    CFLocaleRef cfLocale = NULL; //要CFRelease!
    if (locale != 0 && strlen(locale) > 0) {
        NSString *identifer = [NSString stringWithUTF8String:locale];
        NSLocale *nsLocale = [[NSLocale alloc] initWithLocaleIdentifier:identifer];
        cfLocale = (__bridge CFLocaleRef)nsLocale;
    }
    if (!locale) {
        cfLocale = CFLocaleCopyCurrent();
    }
    
    // token解析,初始化 (要CFRelease!)
    CFStringTokenizerRef tokenizer = CFStringTokenizerCreate(kCFAllocatorDefault, (CFStringRef)text, range, kCFStringTokenizerUnitWordBoundary, cfLocale);
    
    //token状态(监听分词进程)
    CFStringTokenizerTokenType tokenType = CFStringTokenizerGoToTokenAtIndex(tokenizer, 0);
    
    BOOL stop = NO;
    while (tokenType != kCFStringTokenizerTokenNone && !stop) {
        //获取当前使用范围
        range = CFStringTokenizerGetCurrentTokenRange(tokenizer);
        NSString *sub = [text substringWithRange:NSMakeRange(range.location, range.length)];
        const char *pre = [text substringWithRange:NSMakeRange(0, range.location)].UTF8String;
        const char *token = sub.UTF8String;
        int start = (int)strlen(pre);
        int len = (int)strlen(token);
        int end = (int)(start + len);
        block(token, len, start, end, &stop);
        if (pinyin && (len % 3 == 0)) {
            NSString *sub = [NSString stringWithUTF8String:token];
            NSArray<NSString *> *pinyins = [sub pinyinsForTokenize];
            for (NSString *pinyin in pinyins) {
                if (pinyin.length == 0) continue;
                const char *pinyinToken = pinyin.UTF8String;
                int pinyinLen = (int)strlen(pinyinToken);
                block(pinyinToken, pinyinLen, start, end, &stop);
            }
        }
        //获取当前进程
        tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer);
    }
    
    //释放
    if(cfLocale != NULL) CFRelease(cfLocale);
    CFRelease(tokenizer);
}

@end