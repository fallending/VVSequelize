//
//  VVFtsHighlighter.m
//  VVSequelize
//
//  Created by Valo on 2019/8/20.
//

#import "VVFtsHighlighter.h"
#import "VVDatabase+FTS.h"

@interface VVFtsHighlighter ()
@property (nonatomic, strong) NSArray<VVToken *> *keywordTokens;
@end

@implementation VVFtsHighlighter

- (instancetype)initWithOrm:(VVOrm *)orm
                    keyword:(NSString *)keyword
        highlightAttributes:(NSDictionary<NSAttributedStringKey, id> *)highlightAttributes
{
    self = [super init];
    if (self) {
        NSAssert(orm.config.fts && orm.config.ftsTokenizer.length > 0, @"Invalid fts orm!");
        NSString *tokenizer = [orm.config.ftsTokenizer componentsSeparatedByString:@" "].firstObject;
        _method = [orm.vvdb methodForTokenizer:tokenizer];
        _keyword = keyword;
        _highlightAttributes = highlightAttributes;
    }
    return self;
}

- (instancetype)initWithMethod:(VVTokenMethod)method
                       keyword:(NSString *)keyword
           highlightAttributes:(NSDictionary<NSAttributedStringKey, id> *)highlightAttributes
{
    self = [super init];
    if (self) {
        _method = method;
        _keyword = keyword;
        _highlightAttributes = highlightAttributes;
    }
    return self;
}

- (NSArray<VVToken *> *)keywordTokens {
    if (!_keywordTokens) {
        NSAssert(_keyword.length > 0, @"Invalid keyword");
        _keywordTokens = [self tokenize:_keyword pinyin:NO];
    }
    return _keywordTokens;
}

//MARK: - 对FTS搜索结果进行高亮
- (NSArray<VVToken *> *)tokenize:(NSString *)source
                          pinyin:(BOOL)pinyin
{
    NSAssert(_keyword.length > 0 && _highlightAttributes.count > 0, @"Invalid highlight parameters");
    NSArray<VVToken *> *results = [VVTokenEnumerator enumerate:source method:_method];
    if (pinyin) {
        NSArray *pys = [VVTokenEnumerator enumeratePinyins:source start:0 end:(int)strlen(source.UTF8String ? : "")];
        results = [results arrayByAddingObjectsFromArray:pys];
    }
    return results;
}

- (NSArray<NSAttributedString *> *)highlight:(NSArray<NSObject *> *)objects field:(NSString *)field
{
    NSAssert(_keyword.length > 0 && _highlightAttributes.count > 0 && field.length > 0, @"Invalid highlight parameters");
    NSMutableArray *results = [NSMutableArray arrayWithCapacity:objects.count];
    for (NSObject *object in objects) {
        NSString *source = [object valueForKey:field];
        BOOL valid = [source isKindOfClass:NSString.class] && source.length > 0;
        NSAttributedString *attrText = valid ? [self highlight:source hits:nil] : [NSAttributedString new];
        [results addObject:attrText];
    }
    return results;
}

- (NSAttributedString *)highlight:(NSString *)source hits:(BOOL *)hits
{
    const char *pText = source.UTF8String ? : "";
    int nText = (int)strlen(pText);
    int _hits = 0;

    NSArray *tokens = [self tokenize:source pinyin:_pinyin];

    __block char *tokenized = (char *)malloc(nText + 1);
    memset(tokenized, 0x0, nText + 1);

    for (VVToken *tk in tokens) {
        for (VVToken *kwtk in self.keywordTokens) {
            if (strncmp(tk.token.UTF8String, kwtk.token.UTF8String, kwtk.len) != 0) continue;
            memcpy(tokenized + tk.start, pText + tk.start, tk.end - tk.start);
        }
    }

    for (int i = 0; i < nText + 1; i++) {
        if (tokenized[i] == ' ') {
            memset(tokenized + i, 0x0, 1);
        }
    }

    char *remained = (char *)malloc(nText + 1);
    strncpy(remained, pText, nText);
    remained[nText] = 0x0;
    for (int i = 0; i < nText + 1; i++) {
        if (tokenized[i] != 0) {
            memset(remained + i, 0x0, 1);
        }
    }
    NSMutableAttributedString *attrText = [[NSMutableAttributedString alloc] init];

    int pos = 0;
    BOOL isBegin = YES;
    while (pos < nText) {
        if (remained[pos] != 0x0) {
            int rlen = (int)strlen(remained + pos);
            NSString *str = [[NSString alloc] initWithBytes:(remained + pos) length:rlen encoding:NSUTF8StringEncoding] ? : @"";
            if (isBegin && str.length > 5 && source.length > 12) {
                str = [@"..." stringByAppendingString:[str substringFromIndex:str.length - 3]];
            }
            isBegin = NO;
            [attrText appendAttributedString:[[NSAttributedString alloc] initWithString:str attributes:_normalAttributes]];
            pos += rlen;
        } else {
            isBegin = NO;
            int tlen = (int)strlen(tokenized + pos);
            NSString *str = [[NSString alloc] initWithBytes:(tokenized + pos) length:tlen encoding:NSUTF8StringEncoding] ? : @"";
            if (str.length > 0) _hits++;
            [attrText appendAttributedString:[[NSAttributedString alloc] initWithString:str attributes:_highlightAttributes]];
            pos += tlen;
        }
    }
    free(remained);
    free(tokenized);

    if (hits) *hits = _hits;
    return attrText;
}

@end
