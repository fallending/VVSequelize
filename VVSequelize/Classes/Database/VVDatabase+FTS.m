//
//  VVDatabase+FTS.m
//  VVSequelize
//
//  Created by Valo on 2019/3/20.
//

#import "VVDatabase+FTS.h"
#import "NSString+Tokenizer.h"
#import "VVFtsEnumerator.h"

#ifdef SQLITE_HAS_CODEC
#import "sqlite3.h"
#else
#import <sqlite3.h>
#endif

//MARK: - FTS3
typedef struct sqlite3_tokenizer_module   sqlite3_tokenizer_module;
typedef struct sqlite3_tokenizer          sqlite3_tokenizer;
typedef struct sqlite3_tokenizer_cursor   sqlite3_tokenizer_cursor;

struct sqlite3_tokenizer_module {
    int iVersion;
    int (*xCreate)(
        int               argc,                         /* Size of argv array */
        const char *const *argv,                        /* Tokenizer argument strings */
        sqlite3_tokenizer **ppTokenizer                 /* OUT: Created tokenizer */
        );
    int (*xDestroy)(sqlite3_tokenizer *pTokenizer);
    int (*xOpen)(
        sqlite3_tokenizer *pTokenizer,                  /* Tokenizer object */
        const char *pInput, int nBytes,                 /* Input buffer */
        sqlite3_tokenizer_cursor **ppCursor             /* OUT: Created tokenizer cursor */
        );
    int (*xClose)(sqlite3_tokenizer_cursor *pCursor);
    int (*xNext)(
        sqlite3_tokenizer_cursor *pCursor,              /* Tokenizer cursor */
        const char **ppToken, int *pnBytes,             /* OUT: Normalized text for token */
        int *piStartOffset,                             /* OUT: Byte offset of token in input buffer */
        int *piEndOffset,                               /* OUT: Byte offset of end of token in input buffer */
        int *piPosition                                 /* OUT: Number of tokens returned before this one */
        );
    int (*xLanguageid)(sqlite3_tokenizer_cursor *pCsr, int iLangid);
    const char *xName;
    VVFtsXEnumerator xEnumerator;
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
    int pinyinMaxLen;
    bool tokenNum;
    bool transfrom;
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
    tok->pinyinMaxLen = 0;
    tok->tokenNum = false;
    tok->transfrom = false;

    for (int i = 0; i < MIN(2, argc); i++) {
        const char *arg = argv[i];
        uint32_t flag = (uint32_t)atol(arg);
        if (flag > 0) {
            tok->pinyinMaxLen = flag & VVFtsTokenParamPinyin;
            tok->tokenNum = (flag & VVFtsTokenParamNumber) > 0;
            tok->transfrom = (flag & VVFtsTokenParamTransform) > 0;
        } else {
            strncpy(tok->locale, arg, 15);
        }
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
    sqlite3_tokenizer *pTokenizer,                              /* The tokenizer */
    const char *pInput, int nBytes,                             /* String to be tokenized */
    sqlite3_tokenizer_cursor **ppCursor                         /* OUT: Tokenization cursor */
    )
{
    UNUSED_PARAM(pTokenizer);
    if (pInput == 0) return SQLITE_ERROR;

    vv_fts3_tokenizer_cursor *c;
    c = (vv_fts3_tokenizer_cursor *)sqlite3_malloc(sizeof(*c));
    if (c == NULL) return SQLITE_NOMEM;

    const sqlite3_tokenizer_module *module = pTokenizer->pModule;
    VVFtsXEnumerator enumerator = module->xEnumerator;
    if (!enumerator) {
        return SQLITE_ERROR;
    }

    int nInput = (pInput == 0) ? 0 : (nBytes < 0 ? (int)strlen(pInput) : nBytes);

    vv_fts3_tokenizer *tok = (vv_fts3_tokenizer *)pTokenizer;

    NSString *ocString = [NSString stringWithUTF8String:pInput].lowercaseString;
    if (tok->transfrom) {
        ocString = ocString.simplifiedChineseString;
    }
    const char *source = ocString.UTF8String;

    __block NSMutableArray *array = [NSMutableArray arrayWithCapacity:0];

    VVFtsXTokenHandler handler = ^(const char *token, int len, int start, int end, BOOL *stop) {
        NSString *string = [[NSString alloc] initWithBytes:token length:len encoding:NSUTF8StringEncoding];
        [array addObject:[VVFtsToken token:string len:len start:start end:end]];
    };

    if (tok->tokenNum) {
        [VVFtsEnumerator enumerateNumbers:ocString handler:handler];
    }
    if (tok->pinyinMaxLen > 0) {
        for (VVFtsToken *token in array) {
            if (token.len > tok->pinyinMaxLen) continue;
            [VVFtsEnumerator enumeratePinyins:token.token start:token.start end:token.end handler:handler];
        }
        if (nInput < tok->pinyinMaxLen) {
            [VVFtsEnumerator enumeratePinyins:ocString start:0 end:nInput handler:handler];
        }
    }

    enumerator(source, nBytes, tok->locale, handler);

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
    sqlite3_tokenizer_cursor *pCursor,                              /* Cursor returned by vv_fts3_open */
    const char               **ppToken,                             /* OUT: *ppToken is the token text */
    int                      *pnBytes,                              /* OUT: Number of bytes in token */
    int                      *piStartOffset,                        /* OUT: Starting offset of token */
    int                      *piEndOffset,                          /* OUT: Ending offset of token */
    int                      *piPosition                            /* OUT: Position integer of token */
    )
{
    vv_fts3_tokenizer_cursor *c = (vv_fts3_tokenizer_cursor *)pCursor;
    NSArray *array = (__bridge NSArray *)(c->tokens);
    if (array.count == 0 || c->iToken == array.count) return SQLITE_DONE;
    VVFtsToken *t = array[c->iToken];
    *ppToken = t.token.UTF8String;
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
    int pinyinMaxLen;
    bool tokenNum;
    bool transfrom;
    VVFtsXEnumerator enumerator;
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
    tok->pinyinMaxLen = 0;
    tok->tokenNum = false;
    tok->transfrom = false;

    for (int i = 0; i < MIN(2, nArg); i++) {
        const char *arg = azArg[i];
        uint32_t flag = (uint32_t)atol(arg);
        if (flag > 0) {
            tok->pinyinMaxLen = flag & VVFtsTokenParamPinyin;
            tok->tokenNum = (flag & VVFtsTokenParamNumber) > 0;
            tok->transfrom = (flag & VVFtsTokenParamTransform) > 0;
        } else {
            strncpy(tok->locale, arg, 15);
        }
    }

    VVFtsXEnumerator enumerator = (VVFtsXEnumerator)pUnused;
    if (!enumerator) return SQLITE_ERROR;

    tok->enumerator = enumerator;
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

    NSString *ocString = [NSString stringWithUTF8String:pText].lowercaseString;
    if (tok->transfrom) {
        ocString = ocString.simplifiedChineseString;
    }
    const char *source = ocString.UTF8String;

    VVFtsXEnumerator enumerator = tok->enumerator;
    VVFtsXTokenHandler handler = nil;
    handler = ^(const char *token, int len, int start, int end, BOOL *stop) {
        if (tok->pinyinMaxLen > 0 && len <= tok->pinyinMaxLen && (iUnused & FTS5_TOKENIZE_DOCUMENT)) {
            NSString *fragment = [NSString stringWithUTF8String:token];
            NSArray *tks = [VVFtsEnumerator enumeratePinyins:fragment start:start end:end];
            for (VVFtsToken *tk in tks) {
                rc = xToken(pCtx, iUnused, tk.token.UTF8String, tk.len, tk.start, tk.end);
                if (rc != SQLITE_OK) {
                    *stop = YES;
                    return;
                }
            }
        }
        rc = xToken(pCtx, iUnused, token, len, start, end);
        *stop = (rc != SQLITE_OK);
    };

    enumerator(source, nInput, tok->locale, handler);
    if (tok->tokenNum) {
        [VVFtsEnumerator enumerateNumbers:ocString handler:handler];
    }
    if (tok->pinyinMaxLen > 0 && nInput <= tok->pinyinMaxLen && (iUnused & FTS5_TOKENIZE_DOCUMENT)) {
        [VVFtsEnumerator enumeratePinyins:ocString start:0 end:nInput handler:handler];
    }

    if (rc == SQLITE_DONE) rc = SQLITE_OK;
    return rc;
}

@implementation VVDatabase (FTS)

+ (NSMutableDictionary *)enumerators
{
    static NSMutableDictionary *_enumerators;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _enumerators = [NSMutableDictionary dictionaryWithCapacity:0];
    });
    return _enumerators;
}

- (BOOL)registerFtsTokenizer:(Class<VVFtsTokenizer>)cls forName:(NSString *)name
{
    NSAssert([cls conformsToProtocol:@protocol(VVFtsTokenizer)], @"cls must conform `VVFtsTokenizer` protocol");

    VVFtsXEnumerator enumerator = [cls enumerator];

    sqlite3_tokenizer_module *module;
    module = (sqlite3_tokenizer_module *)sqlite3_malloc(sizeof(*module));
    module->iVersion = 0;
    module->xCreate = vv_fts3_create;
    module->xDestroy = vv_fts3_destroy;
    module->xOpen = vv_fts3_open;
    module->xClose = vv_fts3_close;
    module->xNext = vv_fts3_next;
    module->xName = name.UTF8String;
    module->xEnumerator = enumerator;
    int rc = fts3_register_tokenizer(self.db, (char *)name.UTF8String, module);

    NSString *errorsql = [NSString stringWithFormat:@"register tokenizer: %@", name];
    BOOL ret =  [self check:rc sql:errorsql];
    if (!ret) return ret;

    fts5_api *pApi = fts5_api_from_db(self.db);
    if (!pApi) return NO;
    fts5_tokenizer *tokenizer;
    tokenizer = (fts5_tokenizer *)sqlite3_malloc(sizeof(*tokenizer));
    tokenizer->xCreate = vv_fts5_xCreate;
    tokenizer->xDelete = vv_fts5_xDelete;
    tokenizer->xTokenize = vv_fts5_xTokenize;

    rc = pApi->xCreateTokenizer(pApi,
                                name.UTF8String,
                                (void *)enumerator,
                                tokenizer,
                                0);
    ret =  [self check:rc sql:errorsql];
    if (ret) {
        NSString *addr = [NSString stringWithFormat:@"%p", enumerator];
        [VVDatabase enumerators][name] = addr;
    }
    return ret;
}

- (VVFtsXEnumerator)enumeratorForFtsTokenizer:(NSString *)name
{
    fts5_api *pApi = fts5_api_from_db(self.db);
    if (!pApi) return nil;

    void *pUserdata = 0;
    fts5_tokenizer *tokenizer;
    tokenizer = (fts5_tokenizer *)sqlite3_malloc(sizeof(*tokenizer));
    int rc = pApi->xFindTokenizer(pApi, name.UTF8String, &pUserdata, tokenizer);
    if (rc != SQLITE_OK) return nil;

    NSString *addr = [NSString stringWithFormat:@"%p", pUserdata];
    NSString *mapped = [VVDatabase enumerators][name];
    if (![addr isEqualToString:mapped]) return nil;
    return (VVFtsXEnumerator)pUserdata;
}

@end
