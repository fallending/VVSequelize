//
//  VVJieba.m
//  VVSequelize
//
//  Created by Valo on 2019/3/19.
//

#import "VVJieba.h"
#include <string>
#include <vector>
#include "core/Jieba.hpp"

using namespace cppjieba;

@implementation VVJieba

+ (cppjieba::Jieba *)tokenizer{
    static cppjieba::Jieba *_tokenizer;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSBundle *currentBundle   = [NSBundle bundleForClass:self];
        NSString *jiebaBundlePath = [currentBundle pathForResource:@"VVJieba" ofType:@"bundle"];
        NSBundle *jiebaBundle     = [NSBundle bundleWithPath:jiebaBundlePath];
        const char *dictPath = [jiebaBundle pathForResource:@"jieba.dict" ofType:@"utf8"].UTF8String;
        const char *hmmPath  = [jiebaBundle pathForResource:@"hmm_model" ofType:@"utf8"].UTF8String;
        const char *userPath = [jiebaBundle pathForResource:@"user.dict" ofType:@"utf8"].UTF8String;
        const char *idfPath  = [jiebaBundle pathForResource:@"idf" ofType:@"utf8"].UTF8String;
        const char *stopPath = [jiebaBundle pathForResource:@"stop_words" ofType:@"utf8"].UTF8String;
        
        _tokenizer = new Jieba(dictPath, hmmPath, userPath, idfPath, stopPath);
    });
    return _tokenizer;
}

+ (void)enumerateTokens:(const char *)string usingBlock:(void (^)(const char *token, uint32_t offset, uint32_t len, BOOL *stop))block{
    vector<Word> words;
    [VVJieba tokenizer]->CutForSearch(string, words);
    unsigned long count = words.size();
    BOOL stop = NO;
    for (unsigned long i = 0; i < count; i ++) {
        Word word = words[i];
        block(word.word.c_str(), word.offset, (uint32_t)word.word.size(), &stop);
        if(stop) break;
    }
}

@end
