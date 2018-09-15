//
//  NSArray+VVClause.h
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/15.
//

#import <Foundation/Foundation.h>

@interface NSArray (VVClause)

- (NSString *)where;

- (NSString *)asc;

- (NSString *)desc;

- (NSString *)sqlJoin:(BOOL)quota;

@end
