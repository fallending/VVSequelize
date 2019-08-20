//
//  VVFtsHighlighter.m
//  VVSequelize
//
//  Created by Valo on 2019/8/20.
//

#import "VVFtsHighlighter.h"
#import "VVDatabase+FTS.h"

@interface VVFtsHighlighter ()
@property (nonatomic, strong) NSArray<VVFtsToken *> *keywordTokens;
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
        _enumerator = [orm.vvdb enumeratorForFtsTokenizer:tokenizer];
        _keyword = keyword;
        _highlightAttributes = highlightAttributes;
    }
    return self;
}

- (instancetype)initWithEnumerator:(VVFtsXEnumerator)enumerator
                           keyword:(NSString *)keyword
               highlightAttributes:(NSDictionary<NSAttributedStringKey, id> *)highlightAttributes
{
    self = [super init];
    if (self) {
        _enumerator = enumerator;
        _keyword = keyword;
        _highlightAttributes = highlightAttributes;
    }
    return self;
}

- (NSArray<VVFtsToken *> *)keywordTokens {
    if (!_keywordTokens) {
        NSAssert(_enumerator != nil && _keyword.length > 0, @"Invalid highlight parameters");
        _keywordTokens = [self tokenize:_keyword pinyin:NO];
    }
    return _keywordTokens;
}

//MARK: - 对FTS搜索结果进行高亮
- (NSArray<VVFtsToken *> *)tokenize:(NSString *)source
                             pinyin:(BOOL)pinyin
{
    NSAssert(_enumerator != nil && _keyword.length > 0 && _highlightAttributes.count > 0, @"Invalid highlight parameters");

    const char *pText = source.UTF8String;

    if (!pText) {
        return @[];
    }

    int nText = (int)strlen(pText);
    if (!_enumerator) {
        VVFtsToken *token = [VVFtsToken token:source len:nText start:0 end:nText];
        return @[token];
    }

    __block NSMutableArray<VVFtsToken *> *results = [NSMutableArray arrayWithCapacity:0];
    VVFtsXTokenHandler handler = ^(const char *token, int len, int start, int end, BOOL *stop) {
        NSString *string = [[NSString alloc] initWithBytes:token length:len encoding:NSUTF8StringEncoding];
        [results addObject:[VVFtsToken token:string len:len start:start end:end]];
    };
    !_enumerator ? : _enumerator(pText, nText, nil, handler);
    return results;
}

- (NSArray<NSAttributedString *> *)highlight:(NSArray<NSObject *> *)objects field:(NSString *)field
{
    NSAssert(_enumerator != nil && _keyword.length > 0 && _highlightAttributes.count > 0 && field.length > 0, @"Invalid highlight parameters");
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
    NSString *temp = [source stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    const char *pText = temp.UTF8String ? : "";
    int nText = (int)strlen(pText);
    NSUInteger _hits = 0;

    if (nText == 0 || !_enumerator) {
        if (hits) *hits = _hits;
        return [[NSAttributedString alloc] init];
    }

    __block char *tokenized = (char *)malloc(nText + 1);
    memset(tokenized, 0x0, nText + 1);

    VVFtsXTokenHandler handler = ^(const char *token, int len, int start, int end, BOOL *stop) {
        for (VVFtsToken *kwToken in self.keywordTokens) {
            if (strncmp(token, kwToken.token.UTF8String, kwToken.len) != 0) continue;
            memcpy(tokenized + start, pText + start, end - start);
        }
    };

    !_enumerator ? : _enumerator(pText, nText, nil, handler);

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
