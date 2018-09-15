//
//  NSArray+VVClause.h
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/15.
//

#import <Foundation/Foundation.h>

/**
 组装SQL语句各种子句的辅助分类
 */
@interface NSArray (VVClause)

/**
 生成sql中的where子句,不含`where`关键字.
 
 array中的元素仅支持string和非套嵌的dictionary.
 不同元素之间用`or`连接

 @return where子句
 */
- (NSString *)where;

/**
 生成order by子句, 不含`order by`关键字
 
 array中的元素仅支持string.
 不同元素之间以逗号`,`连接, 最后加上` asc`

 @return order by 子句
 */
- (NSString *)asc;

/**
 生成order by子句, 不含`order by`关键字
 
 array中的元素仅支持string.
 不同元素之间以逗号`,`连接, 最后加上` desc`
 
 @return order by 子句
 */
- (NSString *)desc;


/**
 将array中的元素以逗号`,`连接起来生成字符串

 @param quota 是否将每个元素用双引号`"`连接起来
 @return 连接好的字符串
 */
- (NSString *)sqlJoin:(BOOL)quota;

@end
