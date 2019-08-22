//
//  NSObject+VVKeyValue.m
//  VVSequelize
//
//  Created by Valo on 2018/7/13.
//

#import "NSObject+VVKeyValue.h"
#import "VVClassInfo.h"
#import <objc/message.h>

NSString * NSStringFromCoordinate2D(CLLocationCoordinate2D coordinate2D)
{
    return [NSString stringWithFormat:@"{%f,%f}", coordinate2D.latitude, coordinate2D.longitude];
}

CLLocationCoordinate2D Coordinate2DFromString(NSString *string)
{
    if ([string hasPrefix:@"{"] && [string hasSuffix:@"}"]) {
        NSString *content = [string substringWithRange:NSMakeRange(1, string.length - 2)];
        NSArray *array = [content componentsSeparatedByString:@","];
        if (array.count == 2) {
            return CLLocationCoordinate2DMake([array[0] doubleValue], [array[1] doubleValue]);
        }
    }
    return CLLocationCoordinate2DMake(0, 0);
}

@implementation NSData (VVKeyValue)
+ (NSData *)dataWithValue:(NSValue *)value
{
    NSUInteger size;
    const char *encoding = [value objCType];
    NSGetSizeAndAlignment(encoding, &size, NULL);
    void *ptr = malloc(size);
    [value getValue:ptr];
    NSData *data = [NSData dataWithBytes:ptr length:size];
    free(ptr);
    return data;
}

+ (NSData *)dataWithNumber:(NSNumber *)number
{
    return [NSData dataWithValue:(NSValue *)number];
}

+ (NSData *)dataWithDescription:(NSString *)dataDescription
{
    NSString *newStr = [dataDescription stringByReplacingOccurrencesOfString:@" " withString:@""]; //去掉空格
    NSString *replaceString = [newStr substringWithRange:NSMakeRange(1, newStr.length - 2)]; //去掉<>符号
    const char *hexChar = [replaceString UTF8String]; //转换为 char 字符串
    Byte *byte = malloc(sizeof(Byte) * (replaceString.length / 2)); // 开辟空间 用来存放 转换后的byte
    char tmpChar[3] = { '\0', '\0', '\0' };
    int btIndex = 0;
    for (int i = 0; i < replaceString.length; i += 2) {
        tmpChar[0] = hexChar[i];
        tmpChar[1] = hexChar[i + 1];
        byte[btIndex] = strtoul(tmpChar, NULL, 16); // 将 hexstring 转换为 byte 的c方法 16 为16进制
        btIndex++;
    }
    NSData *data = [NSData dataWithBytes:byte length:btIndex]; //创建 nsdata 对象
    free(byte); //释放空间
    return data;
}

@end

@implementation NSValue (VVKeyValue)
- (NSString *)vv_encodedString
{
    NSString *convertStr = @"<unconvertable>";
    NSString *typeEncoding = [NSString stringWithUTF8String:self.objCType];
    VVStructType structType = VVStructGetType(typeEncoding);
    switch (structType) {
        case VVStructTypeNSRange: convertStr = NSStringFromRange(self.rangeValue); break;
        case VVStructTypeCGPoint: convertStr = NSStringFromCGPoint(self.CGPointValue); break;
        case VVStructTypeCGVector: convertStr = NSStringFromCGVector(self.CGVectorValue); break;
        case VVStructTypeCGSize: convertStr = NSStringFromCGSize(self.CGSizeValue); break;
        case VVStructTypeCGRect: convertStr = NSStringFromCGRect(self.CGRectValue); break;
        case VVStructTypeCGAffineTransform: convertStr = NSStringFromCGAffineTransform(self.CGAffineTransformValue); break;
        case VVStructTypeUIEdgeInsets: convertStr = NSStringFromUIEdgeInsets(self.UIEdgeInsetsValue); break;
        case VVStructTypeUIOffset: convertStr = NSStringFromUIOffset(self.UIOffsetValue); break;
        case VVStructTypeCLLocationCoordinate2D: convertStr = NSStringFromCoordinate2D(self.coordinate2DValue); break;
        case VVStructTypeNSDirectionalEdgeInsets:
            if (@available(iOS 11.0, *)) {
                convertStr = NSStringFromDirectionalEdgeInsets(self.directionalEdgeInsetsValue);
            }
            break;
        default: break;
    }
    NSData *data = [NSData dataWithValue:self];
    return [NSString stringWithFormat:@"%@|%@|%@", typeEncoding, convertStr, data];
}

+ (nullable instancetype)vv_decodedWithString:(NSString *)encodedString
{
    NSArray *array = [encodedString componentsSeparatedByString:@"|"];
    if (array.count != 3) return nil;
    NSData *data = [NSData dataWithDescription:array[2]];
    char *objCType = (char *)[array[0] UTF8String];
    return [NSValue valueWithBytes:data.bytes objCType:objCType];
}

- (CLLocationCoordinate2D)coordinate2DValue
{
    CLLocationCoordinate2D coordinate2D = CLLocationCoordinate2DMake(0, 0);
    if (@available(iOS 11.0, *)) {
        NSUInteger size;
        NSGetSizeAndAlignment(@encode(CLLocationCoordinate2D), &size, NULL);
        [self getValue:&coordinate2D size:size];
    } else {
        [self getValue:&coordinate2D];
    }
    return coordinate2D;
}

+ (NSValue *)valueWithCoordinate2D:(CLLocationCoordinate2D)coordinate2D
{
    return [NSValue valueWithBytes:&coordinate2D objCType:@encode(CLLocationCoordinate2D)];
}

@end

@implementation NSDate (VVKeyValue)

+ (NSDateFormatter *)vv_dateFormater
{
    static NSDateFormatter *_dateFormater;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _dateFormater = [[NSDateFormatter alloc] init];
        _dateFormater.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        _dateFormater.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
        _dateFormater.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
    });
    return _dateFormater;
}

- (NSString *)vv_dateString
{
    return [[NSDate vv_dateFormater] stringFromDate:self];
}

+ (instancetype)vv_dateWithString:(NSString *)dateString
{
    return [[NSDate vv_dateFormater] dateFromString:dateString];
}

@end

@implementation NSObject (VVKeyValue)

- (nullable id)vv_dbStoreValue
{
    if ([self isKindOfClass:[NSString class]]
        || [self isKindOfClass:[NSNumber class]]
        || [self isKindOfClass:[NSData class]]) {
        return self;
    }
    id targetVal = [self vv_targetValue];
    if ([targetVal isKindOfClass:[NSString class]]) {
        return targetVal;
    } else if ([targetVal isKindOfClass:[NSArray class]]) {
        NSArray *array = [[self class] convertArrayInlineDataToString:targetVal];
        NSData *data = [NSJSONSerialization dataWithJSONObject:array options:0 error:nil];
        if (data.length == 0) return nil;
        return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    } else if ([targetVal isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dic = [[self class] convertDictionaryInlineDataToString:targetVal];
        NSData *data = [NSJSONSerialization dataWithJSONObject:dic options:0 error:nil];
        if (data.length == 0) return nil;
        return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    return [targetVal description];
}

- (NSDictionary *)vv_keyValues
{
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    VVClassInfo *info = [VVClassInfo classInfoWithClass:self.class];
    NSArray *ignores = [[self class] ignoreProperties];
    unsigned int propsCount;
    objc_property_t *props = class_copyPropertyList([self class], &propsCount);//获得属性列表
    for (int i = 0; i < propsCount; i++) {
        objc_property_t prop = props[i];
        NSString *propName = [NSString stringWithUTF8String:property_getName(prop)];//获得属性的名称
        VVPropertyInfo *properyInfo = info.propertyInfos[propName];
        if ([ignores containsObject:propName]) continue;
        dic[propName] = [self valueForProperty:properyInfo];
    }
    if (props) {
        free(props);
    }
    return dic;
}

+ (instancetype)vv_objectWithKeyValues:(NSDictionary<NSString *, id> *)keyValues
{
    NSObject *obj = [[self alloc] init];
    VVClassInfo *info = [VVClassInfo classInfoWithClass:self.class];
    NSArray *ignores = [self ignoreProperties];
    for (NSString *key in keyValues.allKeys) {
        VVPropertyInfo *propertyInfo = info.propertyInfos[key];
        if (propertyInfo && ![ignores containsObject:propertyInfo.name]) {
            [obj setValue:keyValues[key] forProperty:propertyInfo];
        }
    }
    return obj;
}

+ (NSArray *)vv_keyValuesArrayWithObjects:(NSArray *)objects
{
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:0];
    for (NSObject *obj in objects) {
        [array addObject:[obj vv_keyValues]];
    }
    return array;
}

+ (NSArray *)vv_objectsWithKeyValuesArray:(id)keyValuesArray
{
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
 @note 依次遍历VVKeyValue,MJExtension,YYModel的映射关系,只使用最先获取到的结果.
 */
+ (NSDictionary *)customMapper
{
    NSString *className = NSStringFromClass(self);
    static NSMutableDictionary *_mapperPool;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _mapperPool = [NSMutableDictionary dictionaryWithCapacity:0];
    });
    NSMutableDictionary *_mapper = [_mapperPool objectForKey:className];
    if (_mapper) return _mapper;
    NSDictionary *tempDic = [NSDictionary dictionary];
    NSArray *selectors = @[@"vv_collectionMapper",        // VVKeyValue
                           @"mj_objectClassInArray",      // MJExtension
                           @"modelCustomPropertyMapper"]; // YYModel
    for (NSString *selectorString in selectors) {
        SEL mapperSelector = NSSelectorFromString(selectorString);
        if ([self respondsToSelector:mapperSelector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            NSDictionary *dic = [self performSelector:mapperSelector];
#pragma clang diagnostic pop
            if (dic && [dic isKindOfClass:[NSDictionary class]]) {
                tempDic = dic;
                break;
            }
        }
    }
    _mapper = [NSMutableDictionary dictionaryWithCapacity:0];
    for (NSString *key in tempDic.allKeys) {
        id val = tempDic[key];
        _mapper[key] = [val isKindOfClass:NSString.class] ? NSClassFromString(val) : val;
    }
    [_mapperPool setObject:_mapper forKey:className];
    return _mapper;
}

/**
 对象/字典转换中不转换的属性

 @return 黑名单数组
 @note 依次遍历VVKeyValue,MJExtension,YYModel的黑名单,只使用最先获取到的结果.
 */
+ (NSArray *)ignoreProperties
{
    NSString *className = NSStringFromClass(self);
    static NSMutableDictionary *_ignoresPool;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _ignoresPool = [NSMutableDictionary dictionaryWithCapacity:0];
    });
    NSArray *_ignores = [_ignoresPool objectForKey:className];
    if (_ignores) return _ignores;
    NSArray *ignores = [NSArray array];
    NSArray *selectors = @[@"vv_ignoredProperties",         // VVKeyValue
                           @"mj_ignoredPropertyNames",      // MJExtension
                           @"modelPropertyBlacklist"];      // YYModel
    for (NSString *selectorString in selectors) {
        SEL mapperSelector = NSSelectorFromString(selectorString);
        if ([self respondsToSelector:mapperSelector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            NSArray *array = [self performSelector:mapperSelector];
#pragma clang diagnostic pop
            if (array && [array isKindOfClass:[NSArray class]]) {
                ignores = array;
                break;
            }
        }
    }
    [_ignoresPool setObject:ignores forKey:className];
    return ignores;
}

/**
 生成当前对象存储时的数据类型

 @return 存储的数据
 @note NSData->Blob, NSURL->String, Array->JsonString, Dictionary->JsonString, NSValue->Blob, OtherClass->JsonString
 */
- (id)vv_targetValue
{
    VVEncodingNSType nstype = VVClassGetNSType(self.class);
    switch (nstype) {
        case VVEncodingTypeNSDate: //NSDate转换为NSTimeInterval
            return [(NSDate *)self vv_dateString];

        case VVEncodingTypeNSURL:  //NSURL转换为字符串
            return [(NSURL *)self relativeString];

        case VVEncodingTypeNSArray:
        case VVEncodingTypeNSMutableArray:
        case VVEncodingTypeNSSet:
        case VVEncodingTypeNSMutableSet: {
            id<NSFastEnumeration> colletion = (id<NSFastEnumeration>)self;
            NSMutableArray *vals = [NSMutableArray arrayWithCapacity:0];
            for (id obj in colletion) {
                id subval = [obj vv_targetValue];
                if (subval) [vals addObject:subval];
            }
            return vals;
        }

        case VVEncodingTypeNSDictionary:
        case VVEncodingTypeNSMutableDictionary: {
            NSDictionary *dic = (NSDictionary *)self;
            NSMutableDictionary *vals = [NSMutableDictionary dictionaryWithCapacity:0];
            for (NSString *key in dic.allKeys) {
                vals[key] = [dic[key] vv_targetValue];
            }
            return vals;
        }

        case VVEncodingTypeNSValue: {
            NSValue *val = (NSValue *)self;
            return [val vv_encodedString];
        }

        case VVEncodingTypeNSUnknown: {
            return [self vv_keyValues];
        }

        default:
            return self;
    }
}

+ (NSArray *)convertArrayInlineDataToString:(NSArray *)array
{
    NSMutableArray *tempArray = [NSMutableArray arrayWithCapacity:0];
    for (id obj in array) {
        if ([obj isKindOfClass:NSData.class]) {
            [tempArray addObject:[obj description]];
        } else if ([obj isKindOfClass:NSArray.class]) {
            [tempArray addObject:[self convertArrayInlineDataToString:obj]];
        } else if ([obj isKindOfClass:NSDictionary.class]) {
            [tempArray addObject:[self convertDictionaryInlineDataToString:obj]];
        } else {
            [tempArray addObject:obj];
        }
    }
    return tempArray;
}

+ (NSDictionary *)convertDictionaryInlineDataToString:(NSDictionary *)dictionary
{
    NSMutableDictionary *tempdic = [NSMutableDictionary dictionaryWithCapacity:0];
    for (NSString *key in dictionary) {
        id obj = dictionary[key];
        if ([obj isKindOfClass:NSData.class]) {
            tempdic[key] = [obj description];
        } else if ([obj isKindOfClass:NSArray.class]) {
            tempdic[key] = [self convertArrayInlineDataToString:obj];
        } else if ([obj isKindOfClass:NSDictionary.class]) {
            tempdic[key] = [self convertDictionaryInlineDataToString:obj];
        } else {
            tempdic[key] = obj;
        }
    }
    return tempdic;
}

/**
 根据属性生成要存储的数据类型

 @param propertyInfo 属性信息
 @return 存储的数据
 @note SEL->String, Struct->Blob, Union->Blob, CNumber->Number
 */
- (id)valueForProperty:(VVPropertyInfo *)propertyInfo
{
    id value = [self valueForKey:propertyInfo.name];
    if ([value isKindOfClass:[NSNull class]]) return nil;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    switch (propertyInfo.type) {
        case VVEncodingTypeCNumber:
        case VVEncodingTypeCRealNumber:
            return value;

        case VVEncodingTypeCString: {
            char *str = (char *)(__bridge void *)[self performSelector:propertyInfo.getter];
            return [NSString stringWithCString:str encoding:NSUTF8StringEncoding];
        }

        case VVEncodingTypeSEL: {
            SEL selector = (__bridge void *)[self performSelector:propertyInfo.getter];
            if (selector) return NSStringFromSelector(selector);
        }

        case VVEncodingTypeStruct: {
            return [(NSValue *)value vv_encodedString];
        }

        case VVEncodingTypeUnion: {
            size_t t = ((size_t (*)(id, SEL))(void *) objc_msgSend)(self, propertyInfo.getter);
            const char *objCType = [propertyInfo.typeEncoding UTF8String];
            NSValue *val = [NSValue valueWithBytes:&t objCType:objCType];
            return [val vv_encodedString];
        }

        case VVEncodingTypeObject:
            return [value vv_targetValue];

        default:
            break;
    }
#pragma clang diagnostic pop
    return nil;
}

/**
 将存储的数据转换为原数据

 @param propertyInfo 属性信息
 */
- (void)setValue:(id)value forProperty:(VVPropertyInfo *)propertyInfo
{
    NSString *propertyName = propertyInfo.name;
    if (value == nil || [value isKindOfClass:[NSNull class]]) return;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    switch (propertyInfo.type) {
        case VVEncodingTypeCNumber:
        case VVEncodingTypeCRealNumber:
            [self setValue:value forKey:propertyName];
            break;

        case VVEncodingTypeCString:
            if ([value isKindOfClass:[NSString class]]) {
                const char *str = [(NSString *)value UTF8String];
                ((void (*)(id, SEL, const char *))(void *) objc_msgSend)(self, propertyInfo.setter, str);
            }
            break;

        case VVEncodingTypeSEL:
            if ([value isKindOfClass:[NSString class]]) {
                SEL selector = NSSelectorFromString(value);
                ((void (*)(id, SEL, void *))(void *) objc_msgSend)(self, propertyInfo.setter, (void *)selector);
            }
            break;

        case VVEncodingTypeStruct:
            if ([value isKindOfClass:[NSString class]]) {
                NSValue *val = [NSValue vv_decodedWithString:value];
                [self setValue:val forKey:propertyName];
            }
            break;

        case VVEncodingTypeUnion:
            if ([value isKindOfClass:[NSString class]]) {
                NSValue *val = [NSValue vv_decodedWithString:value];
                size_t t;
                NSUInteger size;
                NSGetSizeAndAlignment(val.objCType, &size, NULL);
                if (@available(iOS 11.0, *)) {
                    [val getValue:&t size:size];
                } else {
                    [val getValue:&t];
                }
                ((void (*)(id, SEL, size_t))(void *) objc_msgSend)(self, propertyInfo.setter, t);
            }
            break;

        case VVEncodingTypeObject: {
            VVEncodingNSType nstype = propertyInfo.nsType;
            switch (nstype) {
                case VVEncodingTypeNSDate: //NSDate转换为NSTimeInterval
                {
                    NSDate *date = nil;
                    if ([value isKindOfClass:[NSDate class]]) {
                        date = value;
                    } else if ([value isKindOfClass:[NSString class]]) {
                        date = [NSDate vv_dateWithString:value];
                    }
                    if (date) [self setValue:date forKey:propertyName];
                } break;

                case VVEncodingTypeNSURL:  //NSURL转换为字符串
                    if ([value isKindOfClass:[NSNumber class]]) {
                        NSURL *url = [NSURL URLWithString:value];
                        if (url) [self setValue:url forKey:propertyName];
                    }
                    break;

                case VVEncodingTypeNSArray:
                case VVEncodingTypeNSMutableArray: {
                    NSArray *tempArray = nil;
                    if ([value isKindOfClass:[NSArray class]]) tempArray = value;
                    else if ([value isKindOfClass:[NSString class]]) {
                        NSData *data = [(NSString *)value dataUsingEncoding:NSUTF8StringEncoding];
                        if (data.length > 0) tempArray = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                    }
                    if (tempArray && [tempArray isKindOfClass:[NSArray class]]) {
                        NSDictionary *mapper = [[self class] customMapper];
                        Class cls = mapper[propertyName];
                        NSArray *array = cls ? [cls vv_objectsWithKeyValuesArray:tempArray] : tempArray;
                        [self setValue:array forKey:propertyName];
                    }
                } break;

                case VVEncodingTypeNSSet:
                case VVEncodingTypeNSMutableSet: {
                    NSArray *tempArray = nil;
                    if ([value isKindOfClass:[NSArray class]]) tempArray = value;
                    else if ([value isKindOfClass:[NSString class]]) {
                        NSData *data = [(NSString *)value dataUsingEncoding:NSUTF8StringEncoding];
                        if (data.length > 0) tempArray = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                    }
                    if (tempArray && [tempArray isKindOfClass:[NSArray class]]) {
                        NSDictionary *mapper = [[self class] customMapper];
                        Class cls = mapper[propertyName];
                        NSArray *array = cls ? [cls vv_objectsWithKeyValuesArray:tempArray] : tempArray;
                        NSMutableSet *set = [NSMutableSet setWithArray:array];
                        [self setValue:set forKey:propertyName];
                    }
                } break;

                case VVEncodingTypeNSDictionary:
                case VVEncodingTypeNSMutableDictionary: {
                    NSDictionary *tempDic = nil;
                    if ([value isKindOfClass:[NSDictionary class]]) tempDic = value;
                    else if ([value isKindOfClass:[NSString class]]) {
                        NSData *data = [(NSString *)value dataUsingEncoding:NSUTF8StringEncoding];
                        if (data.length > 0) tempDic = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                    }
                    if (tempDic) [self setValue:[tempDic mutableCopy] forKey:propertyName];
                } break;

                case VVEncodingTypeNSValue:
                    if ([value isKindOfClass:[NSString class]]) {
                        NSValue *val = [NSValue vv_decodedWithString:value];
                        [self setValue:val forKey:propertyName];
                    }
                    break;

                case VVEncodingTypeNSUnknown: {
                    Class cls = propertyInfo.cls;
                    if (!cls) {
                        NSDictionary *mapper = [[self class] customMapper];
                        cls = mapper[propertyName];
                    }
                    if (cls) {
                        if ([value isKindOfClass:[NSDictionary class]]) {
                            id obj = [cls vv_objectWithKeyValues:value];
                            if (obj) [self setValue:obj forKey:propertyName];
                        }
                        if ([value isKindOfClass:[NSString class]]) {
                            NSData *data = [(NSString *)value dataUsingEncoding:NSUTF8StringEncoding];
                            NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                            id obj = [cls vv_objectWithKeyValues:dic];
                            if (obj) [self setValue:obj forKey:propertyName];
                        } else if ([value isKindOfClass:cls]) {
                            [self setValue:value forKey:propertyName];
                        }
                    }
                } break;

                case VVEncodingTypeNSUndefined:
                    break;

                default:
                    [self setValue:value forKey:propertyName];
                    break;
            }
        } break;

        default:
            break;
    }
#pragma clang diagnostic pop
}

- (void)setValue:(id)value forUndefinedKey:(NSString *)key
{
    // do Nothing
#if DEBUG
    NSLog(@"setValue: %@ forUndefinedKey: %@", value, key);
#endif
}

- (void)setNilValueForKey:(NSString *)key
{
#if DEBUG
    NSLog(@"setNilValueForKey: %@", key);
#endif
}

- (id)valueForUndefinedKey:(NSString *)key
{
#if DEBUG
    NSLog(@"valueForUndefinedKey: %@", key);
#endif
    return nil;
}

@end
