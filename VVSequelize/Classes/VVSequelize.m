//
//  VVSequelize.m
//  VVSequelize
//
//  Created by Jinbo Li on 2018/6/6.
//

#import "VVSequelize.h"

static VVLogLevel _verbose = VVLogLevelNone;

@interface VVSequelizeInnerPrivate: NSObject

@property (nonatomic, copy) VVKeyValuesToObject       keyValuesToObject;        ///< 字典转对象
@property (nonatomic, copy) VVKeyValuesArrayToObjects keyValuesArrayToObjects;  ///< 字典数组转对象数组
@property (nonatomic, copy) VVObjectToKeyValues       objectToKeyValues;        ///< 对象转字典
@property (nonatomic, copy) VVObjectsToKeyValuesArray objectsToKeyValuesArray;  ///< 对象数组转字典数组

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

#pragma mark - 调试信息打印
+ (void)VVVerbose:(NSUInteger)level
           format:(NSString *)fmt, ...{
    if(_verbose > 0 && _verbose >= level){
        va_list args;
        va_start(args, fmt);
        NSString *string = fmt? [[NSString alloc] initWithFormat:fmt locale:[NSLocale currentLocale] arguments:args]:fmt;
        va_end(args);
        NSLog(@"%@", string);
    }
}

+ (BOOL)verbose{
    return _verbose;
}

+ (void)setVerbose:(VVLogLevel)verbose{
    _verbose = verbose;
}


#pragma mark - 对象和字典互转

+ (VVKeyValuesToObject)keyValuesToObject{
    return [[self class] innerPrivate].keyValuesToObject;
}

+ (void)setKeyValuesToObject:(VVKeyValuesToObject)keyValuesToObject{
    [[self class] innerPrivate].keyValuesToObject = keyValuesToObject;
}

+ (VVKeyValuesArrayToObjects)keyValuesArrayToObjects{
    return [[self class] innerPrivate].keyValuesArrayToObjects;
}

+ (void)setKeyValuesArrayToObjects:(VVKeyValuesArrayToObjects)keyValuesArrayToObjects{
    [[self class] innerPrivate].keyValuesArrayToObjects = keyValuesArrayToObjects;
}

+ (VVObjectToKeyValues)objectToKeyValues{
    return [[self class] innerPrivate].objectToKeyValues;
}

+ (void)setObjectToKeyValues:(VVObjectToKeyValues)objectToKeyValues{
    [[self class] innerPrivate].objectToKeyValues = objectToKeyValues;
}

+ (VVObjectsToKeyValuesArray)objectsToKeyValuesArray{
    return [[self class] innerPrivate].objectsToKeyValuesArray;
}

+ (void)setObjectsToKeyValuesArray:(VVObjectsToKeyValuesArray)objectsToKeyValuesArray{
    [[self class] innerPrivate].objectsToKeyValuesArray = objectsToKeyValuesArray;
}

@end
