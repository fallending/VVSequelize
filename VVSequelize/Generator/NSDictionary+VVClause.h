//
//  NSDictionary+VVClause.h
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/15.
//

#import <Foundation/Foundation.h>

/**
 组装SQL语句各种子句的辅助分类
 */
@interface NSDictionary (VVClause)

/**
 生成sql中的where子句,不含`where`关键字.
 
 仅支持非套嵌的dictionary.
 不同的key-value之间用`and`连接
 
 @return where子句
 */
- (NSString *)where;

@end
