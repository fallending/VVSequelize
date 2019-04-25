//
//  VVDatabase+FTS.m
//  VVSequelize
//
//  Created by Valo on 2019/3/20.
//

#import "VVDatabase+FTS.h"
#import "VVFtsTokenizer.h"
#import "VVFtsAppleTokenizer.h"
#import "VVFtsJiebaTokenizer.h"
#import "VVFtsNLTokenizer.h"

#ifdef SQLITE_HAS_CODEC
#import "sqlite3.h"
#else
#import <sqlite3.h>
#endif

static NSMutableDictionary *_fts3ClassMap;
static NSMutableDictionary *_fts5ClassMap;

static const char *kPinYinArg = "pinyin";

//MARK: - FTS3
typedef struct sqlite3_tokenizer_module   sqlite3_tokenizer_module;
typedef struct sqlite3_tokenizer          sqlite3_tokenizer;
typedef struct sqlite3_tokenizer_cursor   sqlite3_tokenizer_cursor;

struct sqlite3_tokenizer_module {
    int iVersion;
    int (*xCreate)(
                   int               argc,              /* Size of argv array */
                   const char *const *argv,             /* Tokenizer argument strings */
                   sqlite3_tokenizer **ppTokenizer      /* OUT: Created tokenizer */
                   );
    int (*xDestroy)(sqlite3_tokenizer *pTokenizer);
    int (*xOpen)(
                 sqlite3_tokenizer *pTokenizer,         /* Tokenizer object */
                 const char *pInput, int nBytes,        /* Input buffer */
                 sqlite3_tokenizer_cursor **ppCursor    /* OUT: Created tokenizer cursor */
                 );
    int (*xClose)(sqlite3_tokenizer_cursor *pCursor);
    int (*xNext)(
                 sqlite3_tokenizer_cursor *pCursor,     /* Tokenizer cursor */
                 const char **ppToken, int *pnBytes,    /* OUT: Normalized text for token */
                 int *piStartOffset,                    /* OUT: Byte offset of token in input buffer */
                 int *piEndOffset,                      /* OUT: Byte offset of end of token in input buffer */
                 int *piPosition                        /* OUT: Number of tokens returned before this one */
                 );
    int (*xLanguageid)(sqlite3_tokenizer_cursor *pCsr, int iLangid);
    const char *xName;
};

struct sqlite3_tokenizer {
    const sqlite3_tokenizer_module *pModule;  /* The module for this tokenizer */
};

struct sqlite3_tokenizer_cursor {
    sqlite3_tokenizer *pTokenizer;            /* Tokenizer for this cursor. */
};

typedef struct vv_fts3_tokenizer {
    sqlite3_tokenizer base;
    char locale[16];
    bool pinyin;
    int pinyinMaxLen;
} vv_fts3_tokenizer;

typedef struct vv_fts3_tokenizer_cursor {
    sqlite3_tokenizer_cursor base;  /* base cursor */
    const char *pInput;             /* input we are tokenizing */
    int nBytes;                     /* size of the input */
    int iToken;                     /* index of current token*/
    int nToken;                     /* count of token */
    CFArrayRef tokens;
} vv_fts3_tokenizer_cursor;

static int fts3_register_tokenizer(
                                   sqlite3                        *db,
                                   char                           *zName,
                                   const sqlite3_tokenizer_module *p
                                   )
{
    int rc;
    sqlite3_stmt *pStmt;
    const char *zSql = "SELECT fts3_tokenizer(?, ?)";
    
    sqlite3_db_config(db, SQLITE_DBCONFIG_ENABLE_FTS3_TOKENIZER, 1, 0);
    
    rc = sqlite3_prepare_v2(db, zSql, -1, &pStmt, 0);
    if (rc != SQLITE_OK) {
        return rc;
    }
    
    sqlite3_bind_text(pStmt, 1, zName, -1, SQLITE_STATIC);
    sqlite3_bind_blob(pStmt, 2, &p, sizeof(p), SQLITE_STATIC);
    sqlite3_step(pStmt);
    
    return sqlite3_finalize(pStmt);
}

static int vv_fts3_create(
                          int argc, const char *const *argv,
                          sqlite3_tokenizer **ppTokenizer
                          )
{
    vv_fts3_tokenizer *tok;
    UNUSED_PARAM(argc);
    UNUSED_PARAM(argv);
    
    tok = (vv_fts3_tokenizer *)sqlite3_malloc(sizeof(*tok));
    if (tok == NULL) return SQLITE_NOMEM;
    memset(tok, 0, sizeof(*tok));
    
    memset(tok->locale, 0x0, 16);
    tok->pinyin = false;
    tok->pinyinMaxLen = 0;
    
    int idx = -1;
    for (int i = 0; i < MIN(3, argc); i ++) {
        const char *arg = argv[i];
        if(strcmp(arg, kPinYinArg) == 0){
            idx = i;
            tok->pinyin = true;
        }
        else{
            if(tok->pinyin && i == idx + 1){
                tok->pinyinMaxLen = atoi(arg);
            }
            else if(i == 0){
                strncpy(tok->locale, arg, 15);
            }
        }
    }
    if(tok->pinyin && tok->pinyinMaxLen <= 0){
        tok->pinyinMaxLen = TOKEN_PINYIN_MAX_LENGTH;
    }

    *ppTokenizer = &tok->base;
    return SQLITE_OK;
}

static int vv_fts3_destroy(sqlite3_tokenizer *pTokenizer)
{
    sqlite3_free(pTokenizer);
    return SQLITE_OK;
}

static int vv_fts3_open(
                        sqlite3_tokenizer *pTokenizer,          /* The tokenizer */
                        const char *pInput, int nBytes,         /* String to be tokenized */
                        sqlite3_tokenizer_cursor **ppCursor     /* OUT: Tokenization cursor */
)
{
    UNUSED_PARAM(pTokenizer);
    if (pInput == 0) return SQLITE_ERROR;
    
    vv_fts3_tokenizer_cursor *c;
    c = (vv_fts3_tokenizer_cursor *)sqlite3_malloc(sizeof(*c));
    if (c == NULL) return SQLITE_NOMEM;
    
    const sqlite3_tokenizer_module *module = pTokenizer->pModule;
    NSString *name = [NSString stringWithUTF8String:module->xName];
    if (name.length == 0) {
        return SQLITE_ERROR;
    }
    Class<VVFtsTokenizer> cls = _fts3ClassMap[name];
    if (!cls || ![cls conformsToProtocol:@protocol(VVFtsTokenizer)]) {
        return SQLITE_ERROR;
    }
    
    int nInput = (pInput == 0) ? 0 : (nBytes < 0 ? (int)strlen(pInput) : nBytes);
    
    vv_fts3_tokenizer *tok = (vv_fts3_tokenizer *)pTokenizer;
    BOOL tokenPinyin = tok->pinyin && (nInput <= tok->pinyinMaxLen);
    __block NSMutableArray *array = [NSMutableArray arrayWithCapacity:0];
    
    [cls enumerateTokens:pInput len:nBytes locale:tok->locale pinyin:tokenPinyin usingBlock:^(const char *token, int len, int start, int end, BOOL *stop) {
        char *_token = (char *)malloc(len + 1);
        memcpy(_token, token, len);
        _token[len] = 0;
        VVFts3Token *t = [VVFts3Token new];
        t.token = _token;
        t.len   = len;
        t.start = start;
        t.end   = end;
        [array addObject:t];
    }];
    
    c->pInput = pInput;
    c->nBytes = nInput;
    c->iToken = 0;
    c->nToken = (int)array.count;
    c->tokens = (__bridge_retained CFArrayRef)array;
    
    *ppCursor = &c->base;
    return SQLITE_OK;
}

static int vv_fts3_close(sqlite3_tokenizer_cursor *pCursor)
{
    vv_fts3_tokenizer_cursor *c = (vv_fts3_tokenizer_cursor *)pCursor;
    CFRelease(c->tokens);
    sqlite3_free(c);
    return SQLITE_OK;
}

static int vv_fts3_next(
                        sqlite3_tokenizer_cursor *pCursor,          /* Cursor returned by vv_fts3_open */
                        const char               **ppToken,         /* OUT: *ppToken is the token text */
                        int                      *pnBytes,          /* OUT: Number of bytes in token */
                        int                      *piStartOffset,    /* OUT: Starting offset of token */
                        int                      *piEndOffset,      /* OUT: Ending offset of token */
                        int                      *piPosition        /* OUT: Position integer of token */
)
{
    vv_fts3_tokenizer_cursor *c = (vv_fts3_tokenizer_cursor *)pCursor;
    NSArray *array = (__bridge NSArray *)(c->tokens);
    if (array.count == 0 || c->iToken == array.count) return SQLITE_DONE;
    VVFts3Token *t = array[c->iToken];
    *ppToken = t.token;
    *pnBytes = t.len;
    *piStartOffset = t.start;
    *piEndOffset = t.end;
    *piPosition = c->iToken++;
    return SQLITE_OK;
}

//MARK: - FTS5

static fts5_api * fts5_api_from_db(sqlite3 *db)
{
    fts5_api *pRet = 0;
    sqlite3_stmt *pStmt = 0;
    
    if (SQLITE_OK == sqlite3_prepare(db, "SELECT fts5(?1)", -1, &pStmt, 0) ) {
#ifdef SQLITE_HAS_CODEC
        sqlite3_bind_pointer(pStmt, 1, (void *)&pRet, "fts5_api_ptr", NULL);
        sqlite3_step(pStmt);
#else
        if (@available(iOS 12.0, *)) {
            sqlite3_bind_pointer(pStmt, 1, (void *)&pRet, "fts5_api_ptr", NULL);
            sqlite3_step(pStmt);
        }
#endif
    }
    sqlite3_finalize(pStmt);
    return pRet;
}

typedef struct Fts5VVTokenizer Fts5VVTokenizer;
struct Fts5VVTokenizer {
    char locale[16];
    bool pinyin;
    int pinyinMaxLen;
    void *cls;
};

static void vv_fts5_xDelete(Fts5Tokenizer *p)
{
    sqlite3_free(p);
}

static int vv_fts5_xCreate(
                           void *pUnused,
                           const char **azArg, int nArg,
                           Fts5Tokenizer **ppOut
                           )
{
    Fts5VVTokenizer *tok = sqlite3_malloc(sizeof(Fts5VVTokenizer));
    if (!tok) return SQLITE_NOMEM;
    memset(tok->locale, 0x0, 16);
    tok->pinyin = false;
    tok->pinyinMaxLen = 0;
    
    int idx = -1;
    for (int i = 0; i < MIN(3, nArg); i ++) {
        const char *arg = azArg[i];
        if(strcmp(arg, kPinYinArg) == 0){
            idx = i;
            tok->pinyin = true;
        }
        else{
            if(tok->pinyin && i == idx + 1){
                tok->pinyinMaxLen = atoi(arg);
            }
            else if(i == 0){
                strncpy(tok->locale, arg, 15);
            }
        }
    }
    if(tok->pinyin && tok->pinyinMaxLen <= 0){
        tok->pinyinMaxLen = TOKEN_PINYIN_MAX_LENGTH;
    }
    
    NSString *name = [NSString stringWithUTF8String:(const char *)pUnused];
    if (name.length == 0) {
        return SQLITE_ERROR;
    }
    Class<VVFtsTokenizer> cls = _fts5ClassMap[name];
    if (!cls || ![cls conformsToProtocol:@protocol(VVFtsTokenizer)]) {
        return SQLITE_ERROR;
    }
    tok->cls = (__bridge void *)cls;
    *ppOut = (Fts5Tokenizer *)tok;
    return SQLITE_OK;
}

static int vv_fts5_xTokenize(
                             Fts5Tokenizer *pTokenizer,
                             void *pCtx,
                             int iUnused,
                             const char *pText, int nText,
                             int (*xToken)(void *, int, const char *, int nToken, int iStart, int iEnd)
                             )
{
    UNUSED_PARAM(iUnused);
    UNUSED_PARAM(pText);
    if (pText == 0) return SQLITE_OK;
    
    __block int rc = SQLITE_OK;
    Fts5VVTokenizer *tok = (Fts5VVTokenizer *)pTokenizer;
    int nInput = (pText == 0) ? 0 : (nText < 0 ? (int)strlen(pText) : nText);
    BOOL tokenPinyin = tok->pinyin && (nInput <= tok->pinyinMaxLen) && (iUnused & FTS5_TOKENIZE_DOCUMENT);
    
    Class<VVFtsTokenizer> cls = (__bridge Class)(tok->cls);
    [cls enumerateTokens:pText len:nText locale:tok->locale pinyin:tokenPinyin usingBlock:^(const char *token, int len, int start, int end, BOOL *stop) {
        rc = xToken(pCtx, iUnused, token, len, start, end);
        *stop = (rc != SQLITE_OK);
    }];
    
    if (rc == SQLITE_DONE) rc = SQLITE_OK;
    return rc;
}

@implementation VVDatabase (FTS)

+ (void)lazyLoadTokenizers
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        const char *pText = "中文";
        int len = (int)strlen(pText);
        void (^ block)(const char *token, int len, int start, int end, BOOL *stop) = ^(const char *token, int len, int start, int end, BOOL *stop) {};
        NSArray<Class<VVFtsTokenizer> > *classes = @[VVFtsJiebaTokenizer.class,
                                                     VVFtsNLTokenizer.class,
                                                     VVFtsAppleTokenizer.class];
        for (Class<VVFtsTokenizer> cls in classes) {
            [cls enumerateTokens:pText len:len locale:NULL pinyin:YES usingBlock:block];
        }
    });
}

- (BOOL)registerFtsThreeFourTokenizer:(Class<VVFtsTokenizer>)cls forName:(NSString *)name
{
    NSAssert([cls conformsToProtocol:@protocol(VVFtsTokenizer)], @"cls must conform `VVFtsTokenizer` protocol");
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _fts3ClassMap = [NSMutableDictionary dictionaryWithCapacity:0];
    });
    
    Class<VVFtsTokenizer> rcls = _fts3ClassMap[name];
    if (rcls && ![cls isEqual:rcls]) {
        NSAssert2(NO, @"`%@` has been registered by `%@`", name, rcls);
        return NO;
    }
    
    sqlite3_tokenizer_module *module;
    module = (sqlite3_tokenizer_module *)sqlite3_malloc(sizeof(*module));
    module->iVersion = 0;
    module->xCreate = vv_fts3_create;
    module->xDestroy = vv_fts3_destroy;
    module->xOpen = vv_fts3_open;
    module->xClose = vv_fts3_close;
    module->xNext = vv_fts3_next;
    module->xName = name.UTF8String;
    int rc = fts3_register_tokenizer(self.db, (char *)name.UTF8String, module);
    BOOL ret =  [self check:rc];
    if (ret) {
        _fts3ClassMap[name] = cls;
    }
    return ret;
}

- (BOOL)registerFtsFiveTokenizer:(Class<VVFtsTokenizer>)cls forName:(NSString *)name
{
    NSAssert([cls conformsToProtocol:@protocol(VVFtsTokenizer)], @"cls must conform `VVFtsTokenizer` protocol");
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _fts5ClassMap = [NSMutableDictionary dictionaryWithCapacity:0];
    });
    
    Class<VVFtsTokenizer> rcls = _fts5ClassMap[name];
    if (rcls && ![cls isEqual:rcls]) {
        NSAssert2(NO, @"`%@` has been registered by `%@`", name, rcls);
        return NO;
    }
    
    fts5_api *pApi = fts5_api_from_db(self.db);
    if (!pApi) return NO;
    fts5_tokenizer *tokenizer;
    tokenizer = (fts5_tokenizer *)sqlite3_malloc(sizeof(*tokenizer));
    tokenizer->xCreate = vv_fts5_xCreate;
    tokenizer->xDelete = vv_fts5_xDelete;
    tokenizer->xTokenize = vv_fts5_xTokenize;
    
    int rc = pApi->xCreateTokenizer(pApi,
                                    name.UTF8String,
                                    (void *)name.UTF8String,
                                    tokenizer,
                                    0);
    BOOL ret = [self check:rc];
    if (ret) {
        _fts5ClassMap[name] = cls;
    }
    return ret;
}

- (Class<VVFtsTokenizer>)ftsThreeFourTokenizerClassForName:(NSString *)name
{
    NSString *key = [name componentsSeparatedByString:@" "].firstObject;
    return _fts3ClassMap[key];
}

- (Class<VVFtsTokenizer>)ftsFiveTokenizerClassForName:(NSString *)name
{
    NSString *key = [name componentsSeparatedByString:@" "].firstObject;
    return _fts5ClassMap[key];
}

@end
