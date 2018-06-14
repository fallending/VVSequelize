//
//  VVSequelize.h
//  VVSequelize
//
//  Created by Jinbo Li on 2018/6/6.
//

#import <Foundation/Foundation.h>

typedef id(^VVConversion)(Class,id);

@interface VVSequelize : NSObject

@property (nonatomic, copy, class) VVConversion dicToObject;        ///< 字典转对象
@property (nonatomic, copy, class) VVConversion dicArrayToObjects;  ///< 字典数组转对象数组
@property (nonatomic, copy, class) VVConversion objectToDic;        ///< 对象转字典
@property (nonatomic, copy, class) VVConversion objectsToDicArray;  ///< 对象数组转字典数组

@end
