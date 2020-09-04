//
//  VVDBCipher.h
//  VVSequelize
//
//  Created by Valo on 2018/6/19.
//

#ifdef SQLITE_HAS_CODEC

#import <Foundation/Foundation.h>

@interface VVDBCipher : NSObject

/// encrypt database
/// @param path database file path
/// @param key encrypt key
/// @param options cipher options, such as `pragma cipher_plaintext_header_size = 32;`
+ (BOOL)encrypt:(NSString *)path
            key:(NSString *)key
        options:(NSArray<NSString *> *)options;

/// decrypt database
+ (BOOL)decrypt:(NSString *)path
            key:(NSString *)key
        options:(NSArray<NSString *> *)options;

/// encrypt database
+ (BOOL)encrypt:(NSString *)source
         target:(NSString *)target
            key:(NSString *)key
        options:(NSArray<NSString *> *)options;

/// decrypt databse
+ (BOOL)decrypt:(NSString *)source
         target:(NSString *)target
            key:(NSString *)key
        options:(NSArray<NSString *> *)options;

/// change databse encrypt key
+ (BOOL)change:(NSString *)path
        oldKey:(NSString *)oldKey
    oldOptions:(NSArray<NSString *> *)oldOptions
        newKey:(NSString *)newKey
    newOptions:(NSArray<NSString *> *)newOptions;

@end

#endif
