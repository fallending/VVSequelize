//
//  VVSequelize.m
//  VVSequelize
//
//  Created by Jinbo Li on 2018/6/6.
//

#import "VVSequelize.h"

@interface VVSequelizeInnerPrivate: NSObject

@property (nonatomic, assign) NSInteger loglevel;        ///< 调试信息
@property (nonatomic, assign) BOOL      useCache;        ///< 是否使用缓存

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
        _innerPrivate.useCache = YES; //默认使用cache
    });
    return _innerPrivate;
}

//MARK: - 全局设置

+ (NSInteger)loglevel{
    return [[self class] innerPrivate].loglevel;
}

+ (void)setLoglevel:(NSInteger)loglevel{
    [[self class] innerPrivate].loglevel = loglevel;
}

+ (BOOL)useCache{
    return [[self class] innerPrivate].useCache;
}

+(void)setUseCache:(BOOL)useCache{
    [[self class] innerPrivate].useCache = useCache;
}

//MARK: - 对象和字典互转

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

+ (void)useVVKeyValue{
    [VVSequelize setKeyValuesToObject:^id(Class cls, NSDictionary *dic) {
        return [cls vv_objectWithKeyValues:dic];
    }];
    [VVSequelize setKeyValuesArrayToObjects:^NSArray *(Class cls, NSArray *dicArray) {
        return [cls vv_objectsWithKeyValuesArray:dicArray];
    }];
    [VVSequelize setObjectToKeyValues:^id(Class cls, id object) {
        return [object vv_keyValues];
    }];
    [VVSequelize setObjectsToKeyValuesArray:^NSArray *(Class cls, NSArray *objects) {
        return [cls vv_keyValuesArrayWithObjects:objects];
    }];
}

//MARK: - 调试信息打印
+ (void)VVVerbose:(NSUInteger)level
           format:(NSString *)fmt, ...{
    NSInteger loglevel = [[self class] innerPrivate].loglevel;
    if(loglevel > 0 && loglevel >= level){
        va_list args;
        va_start(args, fmt);
        NSString *string = fmt? [[NSString alloc] initWithFormat:fmt locale:[NSLocale currentLocale] arguments:args]:fmt;
        va_end(args);
        NSLog(@"VVSequelize->%@", string);
    }
}

@end
