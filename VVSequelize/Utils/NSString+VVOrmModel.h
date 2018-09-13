//
//  NSString+VVOrmModel.h
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/13.
//

#import <Foundation/Foundation.h>

@interface NSString (VVOrmModel)
- (NSString *)trim;
- (BOOL)isMatchRegex:(NSString *)regex;
- (NSString *)prepareForParseSQL;
@end
