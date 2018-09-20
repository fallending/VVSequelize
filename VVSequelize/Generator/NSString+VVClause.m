//
//  NSString+VVClause.m
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/15.
//

#import "NSString+VVClause.h"
#import "NSArray+VVClause.h"

@implementation NSString (VVClause)
- (NSString *)and:(NSString *)andstr{
    return [NSString stringWithFormat:@"%@ AND %@", self, andstr];
}

- (NSString *)or:(NSString *)orstr{
    return [NSString stringWithFormat:@"(%@) OR (%@)", self, orstr];
}

- (NSString *)eq:(id)eq{
    return [self stringByAppendingFormat:@" = \"%@\"", eq];
}

- (NSString *)ne:(id)ne{
    return [self stringByAppendingFormat:@" != \"%@\"", ne];
}

- (NSString *)gt:(id)gt{
    return [self stringByAppendingFormat:@" > \"%@\"", gt];
}

- (NSString *)gte:(id)gte{
    return [self stringByAppendingFormat:@" >= \"%@\"", gte];
}

- (NSString *)lt:(id)lt{
    return [self stringByAppendingFormat:@" < \"%@\"", lt];
}

- (NSString *)lte:(id)lte{
    return [self stringByAppendingFormat:@" <= \"%@\"", lte];
}

- (NSString *)not:(id)notval{
    return [self stringByAppendingFormat:@" IS NOT \"%@\"", notval];
}

- (NSString *)between:(id)val1 _:(id)val2{
    return [self stringByAppendingFormat:@" BETWEEN \"%@\",\"%@\"", val1, val2];
}

- (NSString *)notBetween:(id)val1 _:(id)val2{
    return [self stringByAppendingFormat:@" NOT BETWEEN \"%@\",\"%@\"", val1, val2];
}

- (NSString *)in:(NSArray *)array{
    return [self stringByAppendingFormat:@" IN (%@)", [array sqlJoin:YES]];
}

- (NSString *)notIn:(NSArray *)array{
    return [self stringByAppendingFormat:@" NOT IN (%@)", [array sqlJoin:YES]];
}

- (NSString *)like:(id)like{
    return [self stringByAppendingFormat:@" LIKE \"%@\"", like];
}

- (NSString *)notLike:(id)notLike{
    return [self stringByAppendingFormat:@" NOT LIKE \"%@\"", notLike];
}

- (NSString *)glob:(id)glob{
    return [self stringByAppendingFormat:@" GLOB \"%@\"", glob];
}

- (NSString *)notGlob:(id)notGlob{
    return [self stringByAppendingFormat:@" NOT GLOB \"%@\"", notGlob];
}

- (NSString *)match:(id)match{
    return [self stringByAppendingFormat:@" MATCH \"%@\"", match];
}

- (NSString *)asc{
    return [self stringByAppendingFormat:@" ASC"];
}

- (NSString *)desc{
    return [self stringByAppendingFormat:@" DESC"];
}

@end
