//
//  VVFtsHighlighter.m
//  VVSequelize
//
//  Created by Valo on 2019/8/20.
//

#import "VVSearchHighlighter.h"
#import "VVDatabase+FTS.h"
#import "NSString+Tokenizer.h"

@implementation VVResultMatch

- (instancetype)init
{
    self = [super init];
    if (self) {
        _range = NSMakeRange(0, 0);
        _type = VVMatchNone;
    }
    return self;
}

- (NSComparisonResult)compare:(VVResultMatch *)other
{
    if (self.type == other.type) {
        switch (self.type) {
            case VVMatchPrefix:
            case VVMatchPinyinPrefix:
                return [self.source compare:other.source];

            case VVMatchNonPrefix:
            case VVMatchPinyinNonPrefix: {
                if (self.range.location == other.range.location) {
                    return self.range.length > other.range.length ? NSOrderedAscending : NSOrderedDescending;
                } else {
                    return self.range.location < other.range.location ? NSOrderedAscending : NSOrderedDescending;
                }
            }

            default:
                return NSOrderedSame;
        }
    }
    return self.type < other.type ? NSOrderedAscending : NSOrderedDescending;
}

@end

@interface VVSearchHighlighter ()
@property (nonatomic, strong) NSArray<VVToken *> *keywordTokens;
@end

@implementation VVSearchHighlighter

- (instancetype)initWithOrm:(VVOrm *)orm keyword:(NSString *)keyword
{
    self = [super init];
    if (self) {
        NSAssert(orm.config.fts && orm.config.ftsTokenizer.length > 0, @"Invalid fts orm!");
        NSString *tokenizer = [orm.config.ftsTokenizer componentsSeparatedByString:@" "].firstObject;
        _method = [orm.vvdb methodForTokenizer:tokenizer];
        _keyword = keyword;
    }
    return self;
}

- (instancetype)initWithMethod:(VVTokenMethod)method keyword:(NSString *)keyword
{
    self = [super init];
    if (self) {
        _method = method;
        _keyword = keyword;
    }
    return self;
}

- (NSArray<VVToken *> *)keywordTokens {
    if (!_keywordTokens) {
        NSAssert(_keyword.length > 0, @"Invalid keyword");
        VVTokenMask ops = self.mask | VVTokenMaskPinyin;
        _keywordTokens = [VVTokenEnumerator enumerate:_keyword method:_method mask:ops];
    }
    return _keywordTokens;
}

- (VVTokenMask)mask {
    if (_mask == 0) {
        _mask = VVTokenMaskDeault;
    }
    return _mask;
}

- (NSDictionary<NSAttributedStringKey, id> *)normalAttributes {
    if (!_normalAttributes) {
        _normalAttributes = @{};
    }
    return _normalAttributes;
}

- (NSDictionary<NSAttributedStringKey, id> *)highlightAttributes {
    if (!_highlightAttributes) {
        _highlightAttributes = @{};
    }
    return _highlightAttributes;
}

//MARK: - highlight search result
- (NSArray<VVResultMatch *> *)highlight:(NSArray<NSObject *> *)objects field:(NSString *)field
{
    NSAssert(_keyword.length > 0 && field.length > 0, @"Invalid highlight parameters");
    NSMutableArray *results = [NSMutableArray arrayWithCapacity:objects.count];
    for (NSObject *object in objects) {
        NSString *source = [object valueForKey:field];
        BOOL valid = [source isKindOfClass:NSString.class] && source.length > 0;
        if (!valid) source = @"";
        VVResultMatch *match = [self highlight:source];
        [results addObject:match];
    }
    return results;
}

- (VVResultMatch *)highlight:(NSString *)source
{
    NSString *temp = [source stringByReplacingOccurrencesOfString:@"\n" withString:@" "].lowercaseString;
    NSString *kw = _keyword.lowercaseString;
    if (self.mask & VVTokenMaskTransform) {
        temp = temp.simplifiedChineseString;
        kw = kw.simplifiedChineseString;
    }
    const char *pText = temp.UTF8String ? : "";
    int nText = pText ? (int)strlen(pText) : 0;

    VVResultMatch *match = [[VVResultMatch alloc] init];
    match.source = source;

    NSMutableAttributedString *attrText = [[NSMutableAttributedString alloc] init];
    if (nText == 0) {
        return match;
    }

    NSRange found = [temp rangeOfString:kw];
    if (found.location == 0 && found.length == source.length) {
        match.type = VVMatchFull;
        match.range = NSMakeRange(0, nText);
        match.attrText = [[NSAttributedString alloc] initWithString:source attributes:self.highlightAttributes];
    } else if (found.location == 0 && found.length < source.length) {
        NSString *sk = [source substringToIndex:kw.length];
        NSString *s2 = [source substringFromIndex:kw.length];
        NSAttributedString *ak = [[NSAttributedString alloc] initWithString:sk attributes:self.highlightAttributes];
        NSAttributedString *a2 = [[NSAttributedString alloc] initWithString:s2 attributes:self.normalAttributes];
        [attrText appendAttributedString:ak];
        [attrText appendAttributedString:a2];

        match.type = VVMatchPrefix;
        match.range = NSMakeRange(0, strlen(kw.UTF8String));
        match.attrText = attrText;
    } else if (found.location != NSNotFound && found.length > 0) {
        NSString *s1 = [source substringToIndex:found.location];
        NSString *sk = [source substringWithRange:found];
        NSString *s2 = [source substringFromIndex:NSMaxRange(found)];
        NSAttributedString *a1 = [[NSAttributedString alloc] initWithString:s1 attributes:self.normalAttributes];
        NSAttributedString *ak = [[NSAttributedString alloc] initWithString:sk attributes:self.highlightAttributes];
        NSAttributedString *a2 = [[NSAttributedString alloc] initWithString:s2 attributes:self.normalAttributes];
        [attrText appendAttributedString:a1];
        [attrText appendAttributedString:ak];
        [attrText appendAttributedString:a2];

        match.type = VVMatchNonPrefix;
        match.range = NSMakeRange(strlen(s1.UTF8String), strlen(sk.UTF8String));
        match.attrText = attrText;
    }

    if (match.type != VVMatchNone) {
        return match;
    }

    u_long len = self.mask & VVTokenMaskPinyin;
    if (nText < len) {
        NSArray *pinyins = [source pinyinsForTokenize];
        for (NSString *py in pinyins) {
            found = [py rangeOfString:kw];
            if (found.length > 0) {
                if (found.location == 0 && found.length == py.length) {
                    match.type = VVMatchPinyinFull;
                    break;
                } else if (found.location == 0 && found.length < py.length) {
                    match.type = VVMatchPinyinPrefix;
                } else if (found.location > 0 && match.type == VVMatchNone) {
                    NSSet *ak = [NSSet setWithArray:[kw splitIntoPinyins]];
                    NSMutableSet *at = [NSMutableSet setWithArray:[py splitIntoPinyins]];
                    NSUInteger count = at.count;
                    [at minusSet:ak];
                    if (at.count < count) {
                        match.type = VVMatchPinyinNonPrefix;
                    }
                }
            }
        }
    }

    __block char *tokenized = (char *)malloc(nText + 1);
    memset(tokenized, 0x0, nText + 1);

    NSArray<VVToken *> *tokens = [VVTokenEnumerator enumerateCString:pText method:VVTokenMethodSequelize mask:self.mask];

    unsigned long count = tokens.count;
    unsigned long kwcount = self.keywordTokens.count;
    NSUInteger firstMatchLen = 0;
    NSRange range = NSMakeRange(NSNotFound, 0);

    unsigned long k = 0;
    for (unsigned long j = 0; j < kwcount; j++) {
        VVToken *kwToken = self.keywordTokens[j];
        for (unsigned long i = k; i < count; i++) {
            VVToken *token = tokens[i];
            if (strcmp(token.token.UTF8String, kwToken.token.UTF8String) != 0) continue;
            memcpy(tokenized + token.start, pText + token.start, token.len);
            if (firstMatchLen == 0) firstMatchLen = token.len;
            k = i + 1;
            break;
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

    int pos = 0;
    BOOL isBegin = YES;
    while (pos < nText) {
        if (remained[pos] != 0x0) {
            int rlen = (int)strlen(remained + pos);
            NSString *str = [[NSString alloc] initWithBytes:(remained + pos) length:rlen encoding:NSUTF8StringEncoding] ? : @"";
            if (isBegin && str.length + firstMatchLen > 17) {
                str = [@"..." stringByAppendingString:[str substringFromIndex:str.length + firstMatchLen - 17]];
            }
            isBegin = NO;
            [attrText appendAttributedString:[[NSAttributedString alloc] initWithString:str attributes:self.normalAttributes]];
            pos += rlen;
        } else {
            isBegin = NO;
            int tlen = (int)strlen(tokenized + pos);
            NSString *str = [[NSString alloc] initWithBytes:(tokenized + pos) length:tlen encoding:NSUTF8StringEncoding] ? : @"";
            if (str.length > 0 && range.length == 0) {
                range = NSMakeRange(pos, tlen);
            }
            [attrText appendAttributedString:[[NSAttributedString alloc] initWithString:str attributes:self.highlightAttributes]];
            pos += tlen;
        }
    }
    free(remained);
    free(tokenized);

    if (range.length > 0) {
        match.range = range;
        match.attrText = attrText;
        if (match.type == VVMatchNone) {
            match.type = VVMatchOther;
        }
    } else {
        match.attrText = [[NSAttributedString alloc] initWithString:source attributes:self.normalAttributes];
    }

    return match;
}

@end
