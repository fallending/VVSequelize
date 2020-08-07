//
//  VVDatabase+FTS.m
//  VVSequelize
//
//  Created by Valo on 2019/3/20.
//

#import "VVDatabase+FTS.h"
#import "NSString+Tokenizer.h"

#ifdef SQLITE_HAS_CODEC
#import "sqlite3.h"
#else
#import <sqlite3.h>
#endif

//MARK: - FTS3/4
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
    const void *xClass;
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
    uint64_t mask;
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
    tok->mask = 0;

    for (int i = 0; i < MIN(2, argc); i++) {
        const char *arg = argv[i];
        uint64_t mask = (uint64_t)atoll(arg);
        if (mask > 0) {
            tok->mask = mask;
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
    Class<VVTokenEnumerator> clazz = (__bridge Class)(module->xClass);
    if (!clazz || ![clazz conformsToProtocol:@protocol(VVTokenEnumerator)]) {
        return SQLITE_ERROR;
    }

    int nInput = (pInput == 0) ? 0 : (nBytes < 0 ? (int)strlen(pInput) : nBytes);

    vv_fts3_tokenizer *tok = (vv_fts3_tokenizer *)pTokenizer;

    NSArray *array = [clazz enumerate:pInput mask:(VVTokenMask)tok->mask];

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
    VVToken *t = array[c->iToken];
    *ppToken = t.word;
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
    uint64_t mask;
    void *clazz;
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
    tok->mask = 0;

    for (int i = 0; i < MIN(2, nArg); i++) {
        const char *arg = azArg[i];
        uint32_t mask = (uint32_t)atoll(arg);
        if (mask > 0) {
            tok->mask = mask;
        } else {
            strncpy(tok->locale, arg, 15);
        }
    }

    tok->clazz = pUnused;
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

    int rc = SQLITE_OK;
    Fts5VVTokenizer *tok = (Fts5VVTokenizer *)pTokenizer;
    Class<VVTokenEnumerator> clazz = (__bridge Class)(tok->clazz);
    if (!clazz || ![clazz conformsToProtocol:@protocol(VVTokenEnumerator)]) {
        return SQLITE_ERROR;
    }
    uint64_t mask = tok->mask;
    if ((mask & VVTokenMaskPinyin) > 0) {
        if (iUnused & FTS5_TOKENIZE_QUERY) {
            mask = (mask & ~VVTokenMaskAllPinYin) | VVTokenMaskSyllable;
        } else if (iUnused & FTS5_TOKENIZE_DOCUMENT) {
            mask = mask & ~VVTokenMaskSyllable;
        }
    }
    NSArray *array = [clazz enumerate:pText mask:(VVTokenMask)mask];

    for (VVToken *tk in array) {
        rc = xToken(pCtx, 0, tk.word, tk.len, tk.start, tk.end);
        if (rc != SQLITE_OK) break;
    }

    if (rc == SQLITE_DONE) rc = SQLITE_OK;
    return rc;
}

@implementation VVDatabase (FTS)

- (BOOL)registerEnumerator:(Class<VVTokenEnumerator>)enumerator forTokenizer:(NSString *)name
{
    sqlite3_tokenizer_module *module;
    module = (sqlite3_tokenizer_module *)sqlite3_malloc(sizeof(*module));
    module->iVersion = 0;
    module->xCreate = vv_fts3_create;
    module->xDestroy = vv_fts3_destroy;
    module->xOpen = vv_fts3_open;
    module->xClose = vv_fts3_close;
    module->xNext = vv_fts3_next;
    module->xName = name.cLangString;
    int rc = fts3_register_tokenizer(self.db, (char *)name.cLangString, module);

    NSString *errorsql = [NSString stringWithFormat:@"register tokenizer: %@", name];
    BOOL ret =  [self check:rc sql:errorsql];

    fts5_api *pApi = fts5_api_from_db(self.db);
    if (!pApi) {
#if DEBUG
        printf("[VVDB][Debug] fts5 is not supported\n");
#endif
        return ret;
    }
    fts5_tokenizer *tokenizer;
    tokenizer = (fts5_tokenizer *)sqlite3_malloc(sizeof(*tokenizer));
    tokenizer->xCreate = vv_fts5_xCreate;
    tokenizer->xDelete = vv_fts5_xDelete;
    tokenizer->xTokenize = vv_fts5_xTokenize;

    rc = pApi->xCreateTokenizer(pApi, name.cLangString, (__bridge void *)enumerator, tokenizer, NULL);
    ret = ret && [self check:rc sql:errorsql];
    return ret;
}

- (Class<VVTokenEnumerator>)enumeratorForTokenizer:(NSString *)name
{
    fts5_api *pApi = fts5_api_from_db(self.db);
    if (!pApi) return nil;

    void *pUserdata = 0;
    fts5_tokenizer *tokenizer;
    tokenizer = (fts5_tokenizer *)sqlite3_malloc(sizeof(*tokenizer));
    int rc = pApi->xFindTokenizer(pApi, name.cLangString, &pUserdata, tokenizer);
    if (rc != SQLITE_OK) return nil;
    Class<VVTokenEnumerator> clazz = (__bridge Class)pUserdata;
    if (!clazz || ![clazz conformsToProtocol:@protocol(VVTokenEnumerator)]) {
        return nil;
    }
    return clazz;
}

@end
