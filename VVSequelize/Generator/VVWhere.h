//
//  VVWhere.h
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/14.
//

#import <Foundation/Foundation.h>


@interface NSString (VVWhere)
- (NSString *)and:(NSString *)and;

- (NSString *)or:(NSString *)and;

- (NSString *)eq:(id)eq;

- (NSString *)ne:(id)ne;

- (NSString *)gt:(id)gt;

- (NSString *)gte:(id)gte;

- (NSString *)lt:(id)lt;

- (NSString *)lte:(id)lte;

- (NSString *)not:(id)not;

- (NSString *)between:(id)val1 _:(id)val2;

- (NSString *)notBetween:(id)val1 _:(id)val2;

- (NSString *)in:(id)arrayOrSet;

- (NSString *)notIn:(NSArray *)array;

- (NSString *)like:(id)like;

- (NSString *)notLike:(id)notLike;

- (NSString *)glob:(id)glob;

- (NSString *)notGlob:(id)notGlob;

- (NSString *)match:(id)match;

- (NSString *)asc;

- (NSString *)desc;

@end

@interface NSDictionary (VVWhere)

- (NSString *)where;

@end


@interface NSArray (VVWhere)

- (NSString *)where;

- (NSString *)asc;

- (NSString *)desc;

- (NSString *)sqlJoin:(BOOL)quota;

@end
