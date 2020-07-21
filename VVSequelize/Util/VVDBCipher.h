//
//  VVDBCipher.h
//  VVSequelize
//
//  Created by Valo on 2018/6/19.
//

#import <Foundation/Foundation.h>

@interface VVDBCipher : NSObject
/// encrypt database
+ (BOOL)encrypt:(NSString *)path key:(NSString *)key;

/// decrypt databse
+ (BOOL)decrypt:(NSString *)path key:(NSString *)key;

/// encrypt database
+ (BOOL)encrypt:(NSString *)source target:(NSString *)target key:(NSString *)key;

/// decrypt databse
+ (BOOL)decrypt:(NSString *)source target:(NSString *)target key:(NSString *)key;

/// change databse encrypt key
+ (BOOL)reEncrypt:(NSString *)path origin:(NSString *)originKey newKey:(NSString *)newKey;

@end
