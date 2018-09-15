//
//  NSString+VVOrm.h
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/13.
//

#import <Foundation/Foundation.h>

@interface NSString (VVOrm)
- (NSString *)trim;
- (NSString *)strip;
- (BOOL)isMatchRegex:(NSString *)regex;
- (NSString *)prepareForParseSQL;
@end
