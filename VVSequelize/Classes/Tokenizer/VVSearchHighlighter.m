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

            case VVMatchMiddle:
            case VVMatchPinyinMiddle: {
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

- (NSString *)description {
    NSValue *r = [NSValue valueWithRange:_range];
    return [NSString stringWithFormat:@"%@ | %@ | %@", @(_type), r, _attrText];
}

@end

@interface VVSearchHighlighter ()
@property (nonatomic, strong) NSArray<VVToken *> *keywordTokens;
@end

@implementation VVSearchHighlighter

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self setup];
    }
    return self;
}

- (instancetype)initWithOrm:(VVOrm *)orm keyword:(NSString *)keyword
{
    self = [super init];
    if (self) {
        NSAssert(orm.config.fts && orm.config.ftsTokenizer.length > 0, @"Invalid fts orm!");
        [self setup];
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
        [self setup];
        _method = method;
        _keyword = keyword;
    }
    return self;
}

- (void)setup {
    _method = VVTokenMethodSequelize;
    _mask = VVTokenMaskDeault | 30;
    _attrTextMaxLength = 17;
}

- (NSArray<VVToken *> *)keywordTokens {
    if (!_keywordTokens) {
        NSAssert(_keyword.length > 0, @"Invalid keyword");
        uint64_t pylen = self.mask & VVTokenMaskPinyin;
        pylen = MAX(pylen, 30);
        VVTokenMask mask = (self.mask & (~VVTokenMaskPinyin)) | VVTokenMaskSplitPinyin | pylen;
        _keywordTokens = [VVTokenEnumerator enumerate:_keyword method:_method mask:mask];
    }
    return _keywordTokens;
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
    VVResultMatch *match = [[VVResultMatch alloc] init];
    match.source = source;
    if (source.length == 0) return match;

    NSString *clean = [source stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    NSString *comparison = clean.lowercaseString;
    NSString *kw = _keyword.lowercaseString;
    if (self.mask & VVTokenMaskTransform) {
        comparison = comparison.simplifiedChineseString;
        kw = kw.simplifiedChineseString;
    }
    const char *cleanText = clean.cString;
    const char *pText = comparison.cString;
    int nText = (int)strlen(pText);
    if (nText == 0) return match;

    NSMutableAttributedString *attrText = [[NSMutableAttributedString alloc] init];
    void (^ TrimAttrText)(NSRange) = ^(NSRange r) {
        if (r.location + r.length > self.attrTextMaxLength) {
            NSInteger rlen = MIN(r.location, r.location + r.length - self.attrTextMaxLength);
            [attrText deleteCharactersInRange:NSMakeRange(0, rlen)];
            NSAttributedString *ellipsis = [[NSAttributedString alloc] initWithString:@"..."];
            [attrText insertAttributedString:ellipsis atIndex:0];
        }
    };

    NSRange found = [comparison rangeOfString:kw];
    if (found.location == 0 && found.length == source.length) {
        match.type = VVMatchFull;
        match.range = NSMakeRange(0, nText);
        match.attrText = [[NSAttributedString alloc] initWithString:source attributes:self.highlightAttributes];
    } else if (found.location == 0 && found.length < source.length) {
        NSString *sk = [clean substringToIndex:kw.length];
        NSString *s2 = [clean substringFromIndex:kw.length];
        NSAttributedString *ak = [[NSAttributedString alloc] initWithString:sk attributes:self.highlightAttributes];
        NSAttributedString *a2 = [[NSAttributedString alloc] initWithString:s2 attributes:self.normalAttributes];
        [attrText appendAttributedString:ak];
        [attrText appendAttributedString:a2];

        match.type = VVMatchPrefix;
        match.range = NSMakeRange(0, strlen(kw.cString));
        match.attrText = attrText;
    } else if (found.location != NSNotFound && found.length > 0) {
        NSString *s1 = [clean substringToIndex:found.location];
        NSString *sk = [clean substringWithRange:found];
        NSString *s2 = [clean substringFromIndex:NSMaxRange(found)];
        NSAttributedString *a1 = [[NSAttributedString alloc] initWithString:s1 attributes:self.normalAttributes];
        NSAttributedString *ak = [[NSAttributedString alloc] initWithString:sk attributes:self.highlightAttributes];
        NSAttributedString *a2 = [[NSAttributedString alloc] initWithString:s2 attributes:self.normalAttributes];
        [attrText appendAttributedString:a1];
        [attrText appendAttributedString:ak];
        [attrText appendAttributedString:a2];

        match.type = VVMatchMiddle;
        match.range = NSMakeRange(strlen(s1.cString), strlen(sk.cString));
        TrimAttrText(found);
        match.attrText = attrText;
    }

    if (match.type != VVMatchNone) {
        return match;
    }

    u_long len = self.mask & VVTokenMaskPinyin;
    if (nText < len) {
        NSArray<NSArray<NSString *> *> *pinyins = [clean pinyinsForMatch];
        for (NSArray<NSString *> *sub in pinyins) {
            for (NSString *py in sub) {
                found = [py rangeOfString:kw];
                if (found.length > 0) {
                    if (found.location == 0 && found.length == py.length) {
                        match.type = kw.length == 1 ? VVMatchPinyinPrefix : VVMatchPinyinFull;
                        break;
                    } else if (found.location == 0 && found.length < py.length) {
                        match.type = VVMatchPinyinPrefix;
                    } else if (found.location > 0 && match.type == VVMatchNone) {
                        match.type = VVMatchPinyinMiddle;
                    }
                }
            }
        }
    }

    __block uint8_t *tokenized = (uint8_t *)malloc(nText + 1);
    memset(tokenized, 0x0, nText + 1);

    NSArray<VVToken *> *tokens = [VVTokenEnumerator enumerateCString:pText method:self.method mask:self.mask];

    unsigned long count = tokens.count;
    unsigned long kwcount = self.keywordTokens.count;

    unsigned long k = 0;
    for (unsigned long j = 0; j < kwcount; j++) {
        VVToken *kwToken = self.keywordTokens[j];
        for (unsigned long i = k; i < count; i++) {
            VVToken *token = tokens[i];
            if (strcmp(token.token.cString, kwToken.token.cString) != 0) continue;
            memcpy(tokenized + token.start, cleanText + token.start, token.end - token.start);
            k = i + 1;
            break;
        }
    }

//    for (int i = 0; i < nText + 1; i++) {
//        if (tokenized[i] == ' ') {
//            memset(tokenized + i, 0x0, 1);
//        }
//    }

    uint8_t *remained = (uint8_t *)malloc(nText + 1);
    memcpy(remained, cleanText, nText);
    remained[nText] = 0x0;
    for (int i = 0; i < nText + 1; i++) {
        if (tokenized[i] != 0) {
            memset(remained + i, 0x0, 1);
        }
    }

    int pos = 0, spos = 0, matchflag = -1;
    NSRange range = NSMakeRange(NSNotFound, 0);
    while (pos < nText + 1) {
        int curflag = tokenized[pos] == 0x0 ? 0 : 1;
        if (matchflag != curflag || pos == nText) {
            int len = pos - spos;
            if (len > 0) {
                uint8_t *bytes = (matchflag ? tokenized : remained) + spos;
                NSString *str = [[NSString alloc] initWithBytes:bytes length:len encoding:NSUTF8StringEncoding] ? : @"";
                if (matchflag == 1 && range.location == NSNotFound) {
                    range = NSMakeRange(attrText.length, str.length);
                }
                NSDictionary *attributes = matchflag == 1 ? self.highlightAttributes : self.normalAttributes;
                [attrText appendAttributedString:[[NSAttributedString alloc] initWithString:str attributes:attributes]];
            }
            spos = pos;
            matchflag = curflag;
        }
        pos++;
    }
    free(remained);
    free(tokenized);

    if (range.length > 0) {
        NSString *s1 = [attrText.string substringToIndex:range.location];
        NSString *sk = [attrText.string substringWithRange:range];
        match.range = NSMakeRange(strlen(s1.cString), strlen(sk.cString));
        TrimAttrText(range);
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
