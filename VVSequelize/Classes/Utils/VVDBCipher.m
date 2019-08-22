//
//  VVSequelizeCipher.m
//  VVSequelize
//
//  Created by Valo on 2018/6/19.
//

#import "VVDBCipher.h"

#ifdef SQLITE_HAS_CODEC
#import "sqlite3.h"
#else
#import <sqlite3.h>
#endif

@implementation VVDBCipher

+ (BOOL)encrypt:(NSString *)path key:(NSString *)key
{
    NSString *source = path;
    NSString *target = [NSString stringWithFormat:@"%@.tmp.sqlite", path];
    if ([self encrypt:source target:target key:key]) {
        NSFileManager *fm = [[NSFileManager alloc] init];
        [fm removeItemAtPath:source error:nil];
        [fm moveItemAtPath:target toPath:source error:nil];
        return YES;
    } else {
        return NO;
    }
}

+ (BOOL)decrypt:(NSString *)path key:(NSString *)key
{
    NSString *source = path;
    NSString *target = [NSString stringWithFormat:@"%@.tmp.sqlite", path];
    if ([self decrypt:source target:target key:key]) {
        NSFileManager *fm = [[NSFileManager alloc] init];
        [fm removeItemAtPath:source error:nil];
        [fm moveItemAtPath:target toPath:source error:nil];
        return YES;
    } else {
        return NO;
    }
}

+ (BOOL)encrypt:(NSString *)source target:(NSString *)target key:(NSString *)key
{
    if (key.length == 0) {
        return NO;
    }

    const char *sql = [[NSString stringWithFormat:@"ATTACH DATABASE '%@' AS encrypted KEY '%@';", target, key] UTF8String];
    sqlite3 *db;
    if (sqlite3_open([source UTF8String], &db) == SQLITE_OK) {
        // Attach empty encrypted database to decrypted database
        sqlite3_exec(db, sql, NULL, NULL, NULL);
        // export database
        sqlite3_exec(db, "SELECT sqlcipher_export('encrypted');", NULL, NULL, NULL);
        // Detach encrypted database
        sqlite3_exec(db, "DETACH DATABASE encrypted;", NULL, NULL, NULL);
        sqlite3_close(db);
        return YES;
    } else {
        sqlite3_close(db);
        NSAssert1(NO, @"Failed to open database with message '%s'.", sqlite3_errmsg(db));
        return NO;
    }
}

+ (BOOL)decrypt:(NSString *)source target:(NSString *)target key:(NSString *)key
{
    if (key.length == 0) {
        return NO;
    }

    const char *sql = [[NSString stringWithFormat:@"ATTACH DATABASE '%@' AS plaintext KEY '';", target] UTF8String];
    sqlite3 *db;
    if (sqlite3_open([source UTF8String], &db) == SQLITE_OK) {
        sqlite3_exec(db, [[NSString stringWithFormat:@"PRAGMA key = '%@';", key] UTF8String], NULL, NULL, NULL);
        // Attach empty decrypted database to encrypted database
        sqlite3_exec(db, sql, NULL, NULL, NULL);
        // export database
        sqlite3_exec(db, "SELECT sqlcipher_export('plaintext');", NULL, NULL, NULL);
        // Detach decrypted database
        sqlite3_exec(db, "DETACH DATABASE plaintext;", NULL, NULL, NULL);
        sqlite3_close(db);
        return YES;
    } else {
        sqlite3_close(db);
        NSAssert1(NO, @"Failed to open database with message '%s'.", sqlite3_errmsg(db));
        return NO;
    }
}

+ (BOOL)reEncrypt:(NSString *)path origin:(NSString *)originKey newKey:(NSString *)newKey
{
    if ((originKey.length == 0 && newKey.length == 0) ||
        [originKey isEqualToString:newKey]) {
        return YES;
    } else if (originKey.length == 0) {
        return [self encrypt:path key:newKey];
    } else if (newKey.length == 0) {
        return [self decrypt:path key:originKey];
    }
    sqlite3 *db;
    if (sqlite3_open([path UTF8String], &db) == SQLITE_OK) {
        sqlite3_exec(db, [[NSString stringWithFormat:@"PRAGMA key = '%@';", originKey] UTF8String], NULL, NULL, NULL);
        sqlite3_exec(db, [[NSString stringWithFormat:@"PRAGMA rekey = '%@';", newKey] UTF8String], NULL, NULL, NULL);
        sqlite3_close(db);
        return YES;
    } else {
        sqlite3_close(db);
        NSAssert1(NO, @"Failed to open database with message '%s'.", sqlite3_errmsg(db));
        return NO;
    }
}

@end
