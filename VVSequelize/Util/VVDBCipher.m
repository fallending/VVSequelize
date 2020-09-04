//
//  VVDBCipher.m
//  VVSequelize
//
//  Created by Valo on 2018/6/19.
//

#ifdef SQLITE_HAS_CODEC

#import "VVDBCipher.h"
#import "sqlite3.h"

@implementation VVDBCipher

+ (BOOL)encrypt:(NSString *)path
            key:(NSString *)key
        options:(NSArray<NSString *> *)options
{
    NSString *target = [NSString stringWithFormat:@"%@.tmp.sqlite", path];
    if ([self encrypt:path target:target key:key options:options]) {
        NSFileManager *fm = [NSFileManager defaultManager];
        [fm removeItemAtPath:path error:nil];
        [fm moveItemAtPath:target toPath:path error:nil];
        return YES;
    }
    return NO;
}

+ (BOOL)decrypt:(NSString *)path
            key:(NSString *)key
        options:(NSArray<NSString *> *)options
{
    NSString *target = [NSString stringWithFormat:@"%@.tmp.sqlite", path];
    if ([self decrypt:path target:target key:key options:options]) {
        NSFileManager *fm = [NSFileManager defaultManager];
        [fm removeItemAtPath:path error:nil];
        [fm moveItemAtPath:target toPath:path error:nil];
        return YES;
    }
    return NO;
}

+ (BOOL)encrypt:(NSString *)source
         target:(NSString *)target
            key:(NSString *)key
        options:(NSArray<NSString *> *)options
{
    if (key.length == 0) return NO;

    sqlite3 *db;
    int rc = sqlite3_open(source.UTF8String, &db);
    if (rc != SQLITE_OK) return NO;

    NSString *attach = [NSString stringWithFormat:@"ATTACH DATABASE '%@' AS encrypted KEY '%@';", target, key];
    NSString *export = @"SELECT sqlcipher_export('encrypted');";
    NSString *detach = @"DETACH DATABASE encrypted;";
    NSArray *pragmas = [self pretreat:options db:@"encrypted"];

    NSMutableArray *array = [NSMutableArray array];
    [array addObject:attach];
    [array addObjectsFromArray:pragmas];
    [array addObject:export];
    [array addObject:detach];

    for (NSString *sql in array) {
        int rc = sqlite3_exec(db, sql.UTF8String, NULL, NULL, NULL);
#if DEBUG
        if (rc != SQLITE_OK) {
            printf("[VVDBCipher][Error] code: %i, error: %s, sql: %s\n", rc, sqlite3_errmsg(db), sql.UTF8String);
        } else {
            printf("[VVDBCipher][DEBUG] code: %i, sql: %s\n", rc, sql.UTF8String);
        }
#endif
        if (rc != SQLITE_OK) break;
    }
    sqlite3_close(db);
    return rc == SQLITE_OK;
}

+ (BOOL)decrypt:(NSString *)source
         target:(NSString *)target
            key:(NSString *)key
        options:(NSArray<NSString *> *)options
{
    if (key.length == 0) return NO;

    sqlite3 *db;
    int rc = sqlite3_open(source.UTF8String, &db);
    if (rc != SQLITE_OK) return NO;
    const char *xKey = key.UTF8String ? : "";
    int nKey = (int)strlen(xKey);
    if (nKey == 0) return NO;
    rc = sqlite3_key(db, xKey, nKey);
    if (rc != SQLITE_OK) return NO;

    NSString *attach = [NSString stringWithFormat:@"ATTACH DATABASE '%@' AS plaintext KEY '';", target];
    NSString *export = @"SELECT sqlcipher_export('plaintext');";
    NSString *detach = @"DETACH DATABASE plaintext;";
    NSArray *pragmas = [self pretreat:options db:@"main"];

    NSMutableArray *array = [NSMutableArray array];
    [array addObjectsFromArray:pragmas];
    [array addObject:attach];
    [array addObject:export];
    [array addObject:detach];

    for (NSString *sql in array) {
        int rc = sqlite3_exec(db, sql.UTF8String, NULL, NULL, NULL);
#if DEBUG
        if (rc != SQLITE_OK) {
            printf("[VVDBCipher][Error] code: %i, error: %s, sql: %s\n", rc, sqlite3_errmsg(db), sql.UTF8String);
        } else {
            printf("[VVDBCipher][DEBUG] code: %i, sql: %s\n", rc, sql.UTF8String);
        }
#endif
        if (rc != SQLITE_OK) break;
    }
    sqlite3_close(db);
    return rc == SQLITE_OK;
}

+ (BOOL)change:(NSString *)path
        oldKey:(NSString *)oldKey
    oldOptions:(NSArray<NSString *> *)oldOptions
        newKey:(NSString *)newKey
    newOptions:(NSArray<NSString *> *)newOptions
{
    if (oldKey.length == 0) {
        return [self encrypt:path key:newKey options:newOptions];
    } else if (newKey.length == 0) {
        return [self decrypt:path key:oldKey options:oldOptions];
    }

    NSString *target = [NSString stringWithFormat:@"%@.tmp.sqlite", path];
    BOOL ret = [self decrypt:path target:target key:oldKey options:oldOptions];
    if (!ret) return ret;
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    ret = [self encrypt:target target:path key:newKey options:newOptions];
    [[NSFileManager defaultManager] removeItemAtPath:target error:nil];
    return ret;
}

+ (NSArray<NSString *> *)pretreat:(NSArray<NSString *> *)options db:(NSString *)db
{
    if (db.length == 0) return options ? : @[];

    NSRegularExpression *exp = [NSRegularExpression regularExpressionWithPattern:@"[a-z]|[A-Z]" options:0 error:nil];
    NSString *dbPrefix = [db stringByAppendingString:@"."];
    NSMutableArray *results = [NSMutableArray arrayWithCapacity:options.count];
    for (NSString *option in options) {
        NSArray<NSString *> *subOptions = [option componentsSeparatedByString:@";"];
        for (NSString *pragma in subOptions) {
            NSRange r = [pragma.lowercaseString rangeOfString:@"pragma "];
            if (r.location == NSNotFound) {
#if DEBUG
                NSRange range = [pragma rangeOfString:@" *" options:NSRegularExpressionSearch];
                if (range.location == NSNotFound) printf("[VVDBCipher][DEBUG] invalid option: %s\n", pragma.UTF8String);
#endif
                continue;
            }
            NSUInteger loc = NSMaxRange(r);
            NSTextCheckingResult *first = [exp firstMatchInString:pragma options:0 range:NSMakeRange(loc, pragma.length - loc)];
            if (!first) continue;
            NSMutableString *string = [pragma mutableCopy];
            [string insertString:dbPrefix atIndex:first.range.location];
            [string appendString:@";"];
            [results addObject:string];
        }
    }
    return results;
}

@end

#endif
