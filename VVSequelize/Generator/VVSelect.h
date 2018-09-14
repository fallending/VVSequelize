//
//  VVSelect.h
//  VVSequelize
//
//  Created by Jinbo Li on 2018/9/14.
//

#import <Foundation/Foundation.h>

@interface VVSelect : NSObject

@property (nonatomic, copy  ) NSString *table;
@property (nonatomic, copy  ) id       fields;  //NSString, NSArray
@property (nonatomic, assign) BOOL     distinct;
@property (nonatomic, strong) id       where;   //NSString, NSDictionary, NSArray
@property (nonatomic, assign) NSRange  limit;
@property (nonatomic, strong) id       orderBy; //NSString, NSArray
@property (nonatomic, strong) id       groupBy; //NSString, NSArray
@property (nonatomic, strong) id       having;  //NSString

@property (nonatomic, copy, readonly) NSString *sql;

- (instancetype)table:(NSString *)table;

- (instancetype)fields:(NSString *)fields;

- (instancetype)distinct:(BOOL)distinct;

- (instancetype)where:(id)where;

- (instancetype)limit:(NSRange)limit;

- (instancetype)orderBy:(id)orderBy;

- (instancetype)groupBy:(id)groupBy;

- (instancetype)having:(id)having;

@end
