//
//  VVOrmField.m
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/10.
//

#import "VVOrmField.h"

@implementation VVOrmField

- (instancetype)initWithName:(NSString *)name
                          pk:(VVOrmPkType)pk
                     notnull:(BOOL)notnull
                      unique:(BOOL)unique
                     indexed:(BOOL)indexed
                  dflt_value:(NSString *)dflt_value
{
    self = [super init];
    if (self) {
        self.name       = name;
        self.pk         = pk;
        self.notnull    = notnull;
        self.unique     = self.pk ? YES : unique;
        self.dflt_value = !dflt_value || [dflt_value isKindOfClass:NSNull.class] ? nil : [NSString stringWithFormat:@"%@",dflt_value];
        self.indexed    = (!self.pk && self.unique) ? YES : indexed;
    }
    return self;
}

+ (instancetype)fieldWithDictionary:(NSDictionary *)dictionary{
    NSString *name = dictionary[@"name"];
    if(!name || name.length == 0) return nil;
    VVOrmField *field = [[VVOrmField alloc] initWithName:name
                                                      pk:[dictionary[@"pk"] integerValue]
                                                 notnull:[dictionary[@"notnull"] boolValue]
                                                  unique:[dictionary[@"unique"] boolValue]
                                                 indexed:[dictionary[@"indexed"] boolValue]
                                              dflt_value:dictionary[@"dflt_value"]];
    field.type  = dictionary[@"type"];
    return field;
}

- (BOOL)isEqualToField:(VVOrmField *)field{
    return [self.name isEqualToString:field.name]
    && [self.type.uppercaseString isEqualToString:field.type.uppercaseString]
    && [self.dflt_value isEqualToString:self.dflt_value]
    && self.pk          == field.pk
    && self.notnull     == field.notnull
    && self.unique      == field.unique
    && self.indexed     == field.indexed
    && self.fts_notindexed  == field.fts_notindexed;
}

//MARK: - FTS
- (instancetype)initWithName:(NSString *)name
              fts_notindexed:(BOOL)fts_notindexed{
    self = [super init];
    if (self) {
        self.name           = name;
        self.fts_notindexed = fts_notindexed;
    }
    return self;
}

@end
