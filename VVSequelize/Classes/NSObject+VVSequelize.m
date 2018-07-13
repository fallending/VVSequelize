//
//  NSObject+VVSequelize.m
//  VVSequelize
//
//  Created by Jinbo Li on 2018/7/13.
//

#import "NSObject+VVSequelize.h"
#import <objc/runtime.h>

@interface VVMapperPool : NSObject
/**
 存储字段与对象的映射关系
 
 @return 映射关系, 格式为{class:{field1:class1,field2,class2,...}}
 @note 第一次调用[obj vv_keyValues]时,会将隐射关系存储在sharedPool中.
 */
+ (NSMutableDictionary *)sharedPool;

@end

@implementation VVMapperPool
+ (NSMutableDictionary *)sharedPool{
    static NSMutableDictionary *_mapperPool;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _mapperPool = [NSMutableDictionary dictionaryWithCapacity:0];
    });
    return _mapperPool;
}

@end

@implementation NSObject (VVSequelize)

- (NSDictionary *)vv_keyValues{
    NSMutableDictionary *mapper = [[VVMapperPool sharedPool] objectForKey:NSStringFromClass(self.class)];
    BOOL needMap = mapper == nil;
    if(needMap) mapper = [NSMutableDictionary dictionaryWithCapacity:0];
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    unsigned int propsCount;
    objc_property_t *props = class_copyPropertyList([self class], &propsCount);//获得属性列表
    for(int i = 0;i < propsCount; i++){
        objc_property_t prop = props[i];
        NSString *propName = [NSString stringWithUTF8String:property_getName(prop)];//获得属性的名称
        id value = [self valueForKey:propName];//kvc读值
        if(value == nil){
            value = [NSNull null];
        }
        else if ([value isKindOfClass:[NSString class]]
                 || [value isKindOfClass:[NSNumber class]]
                 || [value isKindOfClass:[NSNull class]]
                 || [value isKindOfClass:[NSData class]]){
            //Do Nothing
        }
        else if([value isKindOfClass:[NSArray class]]){
            NSArray *tempArray = value;
            if(needMap && tempArray.count > 0){
                mapper[propName] = [tempArray.firstObject class];
            }
            NSMutableArray *array = [NSMutableArray arrayWithCapacity:0];
            for (NSObject *obj in tempArray) {
                [array addObject:obj.vv_keyValues];
            }
            value = array;
        }
        else if([value isKindOfClass:[NSDictionary class]]){
            NSDictionary *tempdic = value;
            if(needMap){
                mapper[propName] = NSDictionary.class;
            }
            NSMutableDictionary *subdic = [NSMutableDictionary dictionaryWithCapacity:0];
            for (NSString *key in tempdic.allKeys) {
                NSAssert([key isKindOfClass:NSString.class], @"不支持非NSString类型的Key");
                subdic[key] = [tempdic[key] vv_keyValues];
            }
            value = subdic;
        }
        else{
            if(needMap){
                mapper[propName] = [value class];
            }
            value = [value vv_keyValues];
        }
        dic[propName] = value;
    }
    if(needMap){
        [[VVMapperPool sharedPool] setObject:mapper forKey:NSStringFromClass(self.class)];
    }
    return dic;
}

+ (instancetype)vv_objectWithKeyValues:(NSDictionary<NSString *, id> *)keyValues{
    NSObject *obj = [[self alloc] init];
    NSDictionary *mapper = [[VVMapperPool sharedPool] objectForKey:NSStringFromClass(self)];
    for (NSString *key in keyValues.allKeys) {
        id value = keyValues[key];
        if([value isKindOfClass:[NSArray class]]){
            id temp = mapper[key];
            if(!temp) continue;
            Class cls = [temp isKindOfClass:[NSString class]] ? NSClassFromString(temp) : temp;
            NSMutableArray *array = [NSMutableArray arrayWithCapacity:0];
            NSArray *subKvsArray = value;
            for (id kvs in subKvsArray) {
                [array addObject:[cls vv_objectWithKeyValues:kvs]];
            }
            [self setValue:array forKey:key];
        }
        else if([value isKindOfClass:[NSDictionary class]]){
            id temp = mapper[key];
            if(!temp) continue;
            Class cls = [temp isKindOfClass:[NSString class]] ? NSClassFromString(temp) : temp;
            NSDictionary *subKvs = value;
            [self setValue:key forKey:[cls vv_objectWithKeyValues:subKvs]];
        }
        else{
            [obj setValue:value forKey:key];
        }
    }
    return obj;
}

+ (NSArray *)vv_keyValuesArrayWithObjects:(NSArray *)objects{
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:0];
    for (NSObject *obj in objects) {
        [array addObject:[obj vv_keyValues]];
    }
    return array;
}

+ (NSArray *)vv_objectsWithKeyValuesArray:(id)keyValuesArray{
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:0];
    for (NSDictionary *dic in keyValuesArray) {
        [array addObject:[self vv_objectWithKeyValues:dic]];
    }
    return array;
}

//MARK: - Private
- (void)setValue:(id)value forUndefinedKey:(NSString *)key{
    // do Nothing
}

@end
