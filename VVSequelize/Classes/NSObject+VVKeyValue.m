//
//  NSObject+VVKeyValue.m
//  VVSequelize
//
//  Created by Jinbo Li on 2018/7/13.
//

#import "NSObject+VVKeyValue.h"
#import "VVSequelize.h"
#import "VVClassInfo.h"

@interface NSData (VVKeyValue)

+ (NSData *)dataWithValue:(NSValue*)value;

+ (NSData *)dataWithNumber:(NSNumber*)number;

@end

@implementation NSData (VVKeyValue)
+ (NSData *)dataWithValue:(NSValue*)value{
    NSUInteger size;
    const char* encoding = [value objCType];
    NSGetSizeAndAlignment(encoding, &size, NULL);
    void* ptr = malloc(size);
    [value getValue:ptr];
    NSData* data = [NSData dataWithBytes:ptr length:size];
    free(ptr);
    return data;
}

+ (NSData *)dataWithNumber:(NSNumber*)number{
    return [NSData dataWithValue:(NSValue*)number];
}
@end

@interface VVMapper : NSObject
@property (nonatomic, copy) NSString *pk;
@property (nonatomic, copy) NSString *className;
@property (nonatomic, copy) NSString *field;
@property (nonatomic, copy) NSString *fieldClass;
@end

@implementation VVMapper

@end

@implementation NSObject (VVKeyValue)

- (NSDictionary *)vv_keyValues{
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    VVClassInfo *info = [VVClassInfo classInfoWithClass:self.class];
    unsigned int propsCount;
    objc_property_t *props = class_copyPropertyList([self class], &propsCount);//获得属性列表
    for(int i = 0;i < propsCount; i++){
        objc_property_t prop = props[i];
        NSString *propName = [NSString stringWithUTF8String:property_getName(prop)];//获得属性的名称
        VVPropertyInfo *properyInfo = info.propertyInfos[propName];
        dic[propName] = [self valueForProperty:properyInfo];
    }
    if(props){
        free(props);
        props = NULL;
    }
    return dic;
}

+ (instancetype)vv_objectWithKeyValues:(NSDictionary<NSString *, id> *)keyValues{
    NSObject *obj = [[self alloc] init];
    NSDictionary *mapper = nil; //TODO: [self mapper];
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
/**
 Array/Set中需要转换的模型类

 @return Array/Set属性名和类的映射关系
 @note 若项目中使用了MJExtension,YYModel这二个常用的库,优先使用它们的映射关系,否则使用当前库定义的映射关系.
 */
+ (NSDictionary *)customMapper{
    NSString *className = NSStringFromClass(self);
    static NSMutableDictionary *_mapperPool;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _mapperPool = [NSMutableDictionary dictionaryWithCapacity:0];
    });
    NSMutableDictionary *_mapper = [_mapperPool objectForKey:className];
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
    [_mapperPool setObject:_mapper forKey:className];
    return _mapper;
}

- (id)vv_targetValue{
    VVEncodingNSType nstype = VVClassGetNSType(self.class);
    switch (nstype) {
        case VVEncodingTypeNSDate: //NSDate转换为NSTimeInterval
            return @([(NSDate *)self timeIntervalSince1970]);
            
        case VVEncodingTypeNSURL:  //NSURL转换为字符串
            return [(NSURL *)self relativeString];

        case VVEncodingTypeNSArray:
        case VVEncodingTypeNSMutableArray:
        case VVEncodingTypeNSSet:
        case VVEncodingTypeNSMutableSet:
        {
            id<NSFastEnumeration> colletion = (id<NSFastEnumeration>)self;
            NSMutableArray *vals = [NSMutableArray arrayWithCapacity:0];
            for (id obj in colletion) {
                id subval = [obj vv_targetValue];
                if(subval) [vals addObject:subval];
            }
            return vals;
        }

        case VVEncodingTypeNSDictionary:
        case VVEncodingTypeNSMutableDictionary:
        {
            NSDictionary *dic = (NSDictionary *)self;
            NSMutableDictionary *vals = [NSMutableDictionary dictionaryWithCapacity:0];
            for (NSString *key in dic.allKeys) {
                vals[key] = [dic[key] vv_targetValue];
            }
            return vals;
        }
            
        case VVEncodingTypeNSValue:{
            return [NSData dataWithValue:(NSValue *)self];
        }

        case VVEncodingTypeNSUnknown:{
            return [self vv_keyValues];
        }
            
        default:
            return self;
    }
}

- (id)valueForProperty:(VVPropertyInfo *)properytyInfo {
    id value = [self valueForKey:properytyInfo.name];
    if([value isKindOfClass:[NSNull class]]) return nil;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    switch (properytyInfo.type) {
        case VVEncodingTypeCNumber:
            return value;
            
        case VVEncodingTypeCString:{
            char *str = (char *)(__bridge void *)[self performSelector:properytyInfo.getter];
            return [NSString stringWithCString:str encoding:NSUTF8StringEncoding];
        }

        case VVEncodingTypeSEL:{
            SEL selector = (__bridge void *)[self performSelector:properytyInfo.getter];
            if(selector) return NSStringFromSelector(selector);
        }

        case VVEncodingTypeStruct:
            return [NSData dataWithValue:value];

        case VVEncodingTypeUnion:{
            void *t = (__bridge void *)[self performSelector:properytyInfo.getter];
            const char *objCType = [properytyInfo.typeEncoding cStringUsingEncoding:NSUTF8StringEncoding];
            NSValue *val = [NSValue value:t withObjCType:objCType];
            return [NSData dataWithValue:val];
        }

        case VVEncodingTypeObject:
            return [value vv_targetValue];
            
        default:
            break;
    }
#pragma clang diagnostic pop
    return nil;
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
