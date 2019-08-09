//
//  VVDataBase+FTS.h
//  VVSequelize
//
//  Created by Valo on 2019/3/20.
//

#import "VVDatabase.h"
#import "VVFtsTokenizer.h"

NS_ASSUME_NONNULL_BEGIN

//MARK: - 分词器参数
#define VVFtsTokenParamNumber    (1 << 16)
#define VVFtsTokenParamTransform (1 << 17)
#define VVFtsTokenParamPinyin    0xFFFF

@interface VVDatabase (FTS)

/**
 注册分词器,fts3/4/5

 @param cls 分词器核心类
 @param name 分词器名称
 @return 是否注册成功
 */
- (BOOL)registerFtsTokenizer:(Class<VVFtsTokenizer>)cls forName:(NSString *)name;

/**
 枚举函数

 @param name 分词器名称
 @return 分词器的核心枚举函数
 */
- (VVFtsXEnumerator)enumeratorForFtsTokenizer:(NSString *)name;

@end

NS_ASSUME_NONNULL_END
