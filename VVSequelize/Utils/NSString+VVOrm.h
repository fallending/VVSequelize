//
//  NSString+VVOrm.h
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/13.
//

#import <Foundation/Foundation.h>

@interface NSString (VVOrm)

/**
 去除string首尾的空格和回车

 @return 剪裁后的string
 */
- (NSString *)trim;

/**
 去除重复的空格

 @return 去除重复空格的string
 */
- (NSString *)strip;

/**
 检查string是否匹配正则表达式

 @param regex 正则表达式
 @return 是否匹配
 */
- (BOOL)isMatch:(NSString *)regex;

/**
 准备解析SQL语句,去除语句中的单双引号,多余空格

 @return 整理后的SQL语句
 */
- (NSString *)prepareForParseSQL;
@end
