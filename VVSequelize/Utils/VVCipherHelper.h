//
//  VVCipherHelper.h
//  VVSequelize
//
//  Created by Jinbo Li on 2018/6/19.
//

#import <Foundation/Foundation.h>
#import "VVDataBase.h"

@interface VVCipherHelper : NSObject
/**
 *  数据库加密,加密后后数据库文件路径不变
 *
 *  @param path       数据库文件路径
 *  @param encryptKey 密钥
 *
 *  @return 是否加密成功
 */
+ (BOOL)encryptDatabase:(NSString *)path
             encryptKey:(NSString *)encryptKey;

/**
 *  数据库解密,解密后数据库文件路径不变
 *
 *  @param path       数据库文件路径
 *  @param encryptKey 密钥
 *
 *  @return 是否解密成功
 */
+ (BOOL)decryptDatabase:(NSString *)path
             encryptKey:(NSString *)encryptKey;

/**
 *  数据库加密,加密后生成新数据库文件
 *
 *  @param sourcePath 数据库文件路径
 *  @param targetPath 加密后的数据库文件路径
 *  @param encryptKey 密钥
 *
 *  @return 是否加密成功
 */
+ (BOOL)encryptDatabase:(NSString *)sourcePath
             targetPath:(NSString *)targetPath
             encryptKey:(NSString *)encryptKey;

/**
 *  数据库解密,解密后生成新数据库文件
 *
 *  @param sourcePath 数据库文件路径
 *  @param targetPath 解密后的数据库文件路径
 *  @param encryptKey 密钥
 *
 *  @return 是否解密成功
 */
+ (BOOL)decryptDatabase:(NSString *)sourcePath
             targetPath:(NSString *)targetPath
             encryptKey:(NSString *)encryptKey;

/**
 *  修改数据库秘钥
 *
 *  @param dbPath    数据库文件路径
 *  @param originKey 旧的密钥
 *  @param newKey    新的密钥
 *
 *  @return 是否修改成功
 */
+ (BOOL)changeKeyForDatabase:(NSString *)dbPath
                   originKey:(NSString *)originKey
                      newKey:(NSString *)newKey;

@end

@interface VVDataBase (VVCipherHelper)
@property (nonatomic, copy  ) NSString *userDefaultsKey;    ///< 保存密码的Key
@property (nonatomic, strong) NSString *encryptKey;         ///< 加密Key,可设置
@end
