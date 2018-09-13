//
//  VVOrmFtsField.m
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/13.
//

#import "VVOrmFtsField.h"

@implementation VVOrmFtsField

+ (instancetype)fieldWithDictionary:(NSDictionary *)dictionary{
    NSString *name = dictionary[@"name"];
    if(!name || name.length == 0) return nil;
    VVOrmFtsField *field = [[VVOrmFtsField alloc] init];
    field.type  = dictionary[@"type"];
    return field;
}

- (instancetype)initWithName:(NSString *)name
                  notindexed:(BOOL)notindexed{
    self = [super init];
    if (self) {
        self.name       = name;
        self.notindexed = notindexed;
    }
    return self;
}

- (BOOL)isEqualToField:(VVOrmField *)field{
    if(![field isKindOfClass:VVOrmFtsField.class]) return NO;
    VVOrmFtsField *f1 = (VVOrmFtsField *)self;
    VVOrmFtsField *f2 = (VVOrmFtsField *)field;
    return [f1.name isEqualToString:f2.name]
    && f1.notindexed  == f2.notindexed;
}

@end
