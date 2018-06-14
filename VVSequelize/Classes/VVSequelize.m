//
//  VVSequelize.m
//  Pods
//
//  Created by Jinbo Li on 2018/6/6.
//

#import "VVSequelize.h"

@interface VVSequelizeInnerPrivate: NSObject

@property (nonatomic, copy) VVConversion dicToObject;
@property (nonatomic, copy) VVConversion dicArrayToObjects;
@property (nonatomic, copy) VVConversion objectToDic;
@property (nonatomic, copy) VVConversion objectsToDicArray;

@end

@implementation VVSequelizeInnerPrivate

@end

@implementation VVSequelize
+ (VVSequelizeInnerPrivate *)innerPrivate{
    static VVSequelizeInnerPrivate *_innerPrivate;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _innerPrivate = [[VVSequelizeInnerPrivate alloc] init];
    });
    return _innerPrivate;
}

+ (VVConversion)dicToObject{
    return [[self class] innerPrivate].dicToObject;
}

+ (void)setDicToObject:(VVConversion)dicToObject{
    [[self class] innerPrivate].dicToObject = dicToObject;
}

+ (VVConversion)dicArrayToObjects{
    return [[self class] innerPrivate].dicArrayToObjects;
}

+ (void)setDicArrayToObjects:(VVConversion)dicArrayToObjects{
    [[self class] innerPrivate].dicArrayToObjects = dicArrayToObjects;
}

+ (VVConversion)objectToDic{
    return [[self class] innerPrivate].objectToDic;
}

+ (void)setObjectToDic:(VVConversion)objectToDic{
    [[self class] innerPrivate].objectToDic = objectToDic;
}

+ (VVConversion)objectsToDicArray{
    return [[self class] innerPrivate].objectsToDicArray;
}

+ (void)setObjectsToDicArray:(VVConversion)objectsToDicArray{
    [[self class] innerPrivate].objectsToDicArray = objectsToDicArray;
    
}

@end
