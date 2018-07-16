//
//  NSObject+VVKeyValue.m
//  VVSequelize
//
//  Created by Jinbo Li on 2018/7/13.
//

#import "NSObject+VVKeyValue.h"
#import "VVSequelize.h"
#import <objc/runtime.h>

@interface VVMapper : NSObject
@property (nonatomic, copy) NSString *pk;
@property (nonatomic, copy) NSString *className;
@property (nonatomic, copy) NSString *field;
@property (nonatomic, copy) NSString *fieldClass;
@end

@implementation VVMapper

@end


@interface VVMapperPool : NSObject

/**
 存储模型中,字段与类的映射关系
 
 @return 映射关系, 格式为{class:{field1:class1,field2,class2,...}}
 @note 直接通过Runtime反射获取类名.
 */
@property (nonatomic, strong) NSMutableDictionary *defaultPool;

/**
 存储模型中,NSArray/NSSet等集合类型中的对象的对应的类
 
 @return 映射关系, 格式为{class:{arrayField:arrayObjClass,setField,setOjbClass,...}}
 @note 第一次调用[obj vv_keyValues]时,会将映射关系存储在customPool中.
 @attention NSArray/NSSet集合中必须是同一种类型的数据
 */
@property (nonatomic, strong) NSMutableDictionary *customPool;

@end

@implementation VVMapperPool

+ (instancetype)shared{
    static VVMapperPool *_shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _shared = [[VVMapperPool alloc] init];
    });
    return _shared;
}

- (instancetype)init{
    self = [super init];
    if (self) {
        _defaultPool = [NSMutableDictionary dictionaryWithCapacity:0];
        _customPool = [NSMutableDictionary dictionaryWithCapacity:0];
    }
    return self;
}

@end

@implementation NSObject (VVKeyValue)

- (NSDictionary *)vv_keyValues{
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    unsigned int propsCount;
    objc_property_t *props = class_copyPropertyList([self class], &propsCount);//获得属性列表
    for(int i = 0;i < propsCount; i++){
        objc_property_t prop = props[i];
        NSString *propName = [NSString stringWithUTF8String:property_getName(prop)];//获得属性的名称
        id value = [self valueForKey:propName];
        if([value isKindOfClass:[NSNull class]]){
            value = nil;
        }
        else if([value isKindOfClass:[NSArray class]]
                || [value isKindOfClass:[NSSet class]]){
            NSArray *tempArray = value;
            if([value isKindOfClass:[NSSet class]]){
                NSSet *set = value;
                tempArray = set.allObjects;
            }
            NSMutableArray *array = [NSMutableArray arrayWithCapacity:0];
            for (NSObject *obj in tempArray) {
                id val = [obj vv_value];
                if(val) [array addObject:val];
            }
            value = array;
        }
        else{
            value = [value vv_value];
        }
        dic[propName] = value;
    }
    free(props);
    return dic;
}

+ (instancetype)vv_objectWithKeyValues:(NSDictionary<NSString *, id> *)keyValues{
    NSObject *obj = [[self alloc] init];
    NSDictionary *mapper = [self mapper];
    NSDictionary *custommapper = [self customMapper];
    for (NSString *key in keyValues.allKeys) {
        id value = keyValues[key];
        Class cls = mapper[key];
        if(cls){
            if([cls isEqual:[NSDate class]]){
                if([value isKindOfClass:[NSNumber class]] ||
                   [value isKindOfClass:[NSString class]]){
                    NSTimeInterval interval = [value doubleValue];
                    value = [NSDate dateWithTimeIntervalSince1970:interval];
                }
                else if(![value isKindOfClass:[NSDate class]]){
                    value = nil;
                }
            }
            else {
                id jsonObj = nil;
                value = nil;
                if([value isKindOfClass:[NSString class]]){
                    NSData *data = [[NSData alloc] initWithBase64EncodedString:value options:0];
                    if(data){
                        jsonObj = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                    }
                }
                if([cls isEqual:[NSArray class]]
                   || [cls isEqual:[NSSet class]]){
                    Class subCls = custommapper[key];
                    if(subCls && jsonObj && [jsonObj isKindOfClass:[NSArray class]]){
                        NSArray *tempArray = [subCls vv_objectsWithKeyValuesArray:jsonObj];
                        value = [cls isEqual:[NSSet class]]? [NSSet setWithArray:tempArray] : tempArray;
                    }
                }
                else if([cls isEqual:[NSDictionary class]]){
                    if(jsonObj && [jsonObj isKindOfClass:[NSDictionary class]]) value = jsonObj;
                }
                else if(jsonObj && [jsonObj isKindOfClass:[NSDictionary class]]){
                    value = [cls vv_objectWithKeyValues:jsonObj];
                }
            }
        }
        if(!([value isKindOfClass:[NSNull class]] || value == nil)){
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
+ (NSDictionary *)mapper{
    NSString *className = NSStringFromClass(self);
    NSMutableDictionary *_mapper = [[VVMapperPool shared].defaultPool objectForKey:className];
    if(_mapper) return _mapper;
    _mapper = [NSMutableDictionary dictionaryWithCapacity:0];
    unsigned int propsCount;
    objc_property_t *props = class_copyPropertyList(self, &propsCount);//获得属性列表
    for(int i = 0;i < propsCount; i++){
        objc_property_t prop = props[i];
        NSString *name = [NSString stringWithUTF8String:property_getName(prop)];//名称
        NSString *attrs = [NSString stringWithUTF8String:property_getAttributes(prop)];//属性
        if([attrs hasPrefix:@"T@\""]){
            NSArray *temp = [attrs componentsSeparatedByString:@"\""];
            NSString *classname = temp[1];
            Class cls = NSClassFromString(classname);
            if(cls && !([cls isEqual:[NSString class]]
                        || [cls isEqual:[NSNumber class]]
                        || [cls isEqual:[NSData class]])) {
                _mapper[name] = cls;
            }
        }
    }
    free(props);
    [[VVMapperPool shared].defaultPool setObject:_mapper forKey:className];
    return _mapper;
}

/**
 Array/Set中需要转换的模型类

 @return Array/Set属性名和类的映射关系
 @note 若项目中使用了MJExtension,YYModel这二个常用的库,优先使用它们的映射关系,否则使用当前库定义的映射关系.
 */
+ (NSDictionary *)customMapper{
    NSString *className = NSStringFromClass(self);
    NSMutableDictionary *_mapper = [[VVMapperPool shared].customPool objectForKey:className];
    if(_mapper) return _mapper;
    NSDictionary *tempDic = nil;
    NSArray *mapperSelectors = @[@"mj_objectClassInArray",      // MJExtension
                                 @"modelCustomPropertyMapper",  // YYModel
                                 @"vv_collectionMapper"];       // VVKeyValue
    for (NSString *selectorString in mapperSelectors) {
        SEL mapperSelector = NSSelectorFromString(selectorString);
        if ([self respondsToSelector:mapperSelector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            NSDictionary *dic = [self performSelector:mapperSelector];
#pragma clang diagnostic pop
            if(dic && [dic isKindOfClass:[NSDictionary class]]) {
                tempDic = dic;
                break;
            }
        }
    }
    if(!tempDic) return nil;
    _mapper = [NSMutableDictionary dictionaryWithCapacity:0];
    for (NSString *key in tempDic.allKeys) {
        id val = tempDic[key];
        _mapper[key] = [val isKindOfClass:NSString.class] ? NSClassFromString(val) : val;
    }
    if(_mapper.count == 0) return nil;
    [[VVMapperPool shared].customPool setObject:_mapper forKey:className];
    return _mapper;
}

- (id)vv_value{
    if([self isKindOfClass:[NSNull class]]){
        return nil;
    }
    else if([self isKindOfClass:[NSString class]]
       || [self isKindOfClass:[NSNumber class]]
       || [self isKindOfClass:[NSDictionary class]]
       || [self isKindOfClass:[NSData class]]){
        return self;
    }
    else if([self isKindOfClass:[NSDate class]]){
        NSDate *date = (NSDate *)self;
        return @([date timeIntervalSince1970]);
    }
    else{
        return self.vv_keyValues;
    }
}


- (void)setValue:(id)value forUndefinedKey:(NSString *)key{
    // do Nothing
    VVLog(1,@"setValue: %@ forUndefinedKey: %@",value,key);
}

- (void)setNilValueForKey:(NSString *)key{
    VVLog(1,@"setNilValueForKey: %@",key);
}

- (id)valueForUndefinedKey:(NSString *)key{
    VVLog(1,@"valueForUndefinedKey: %@",key);
    return nil;
}
@end
