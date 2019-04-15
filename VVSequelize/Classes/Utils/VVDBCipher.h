//
//  VVSequelizeCipher.h
//  VVSequelize
//
//  Created by Valo on 2018/6/19.
//

#import <Foundation/Foundation.h>

@interface VVDBCipher : NSObject
/**
 *  数据库加密,加密后后数据库文件路径不变
 *
 *  @param path 数据库文件路径
 *  @param key    密钥
 *
 *  @return 是否加密成功
 */
+ (BOOL)encrypt:(NSString *)path key:(NSString *)key;

/**
 *  数据库解密,解密后数据库文件路径不变
 *
 *  @param path 数据库文件路径
 *  @param key 密钥
 *
 *  @return 是否解密成功
 */
+ (BOOL)decrypt:(NSString *)path key:(NSString *)key;

/**
 *  数据库加密,加密后生成新数据库文件
 *
 *  @param source 数据库文件路径
 *  @param target 加密后的数据库文件路径
 *  @param key 密钥
 *
 *  @return 是否加密成功
 */
+ (BOOL)encrypt:(NSString *)source target:(NSString *)target key:(NSString *)key;

/**
 *  数据库解密,解密后生成新数据库文件
 *
 *  @param source 数据库文件路径
 *  @param target 解密后的数据库文件路径
 *  @param key 密钥
 *
 *  @return 是否解密成功
 */
+ (BOOL)decrypt:(NSString *)source target:(NSString *)target key:(NSString *)key;

/**
 *  修改数据库秘钥
 *
 *  @param path    数据库文件路径
 *  @param originKey 旧的密钥
 *  @param newKey    新的密钥
 *
 *  @return 是否修改成功
 */
+ (BOOL)reEncrypt:(NSString *)path origin:(NSString *)originKey newKey:(NSString *)newKey;

@end
