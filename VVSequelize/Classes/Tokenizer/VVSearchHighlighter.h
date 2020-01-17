//
//  VVFtsHighlighter.h
//  VVSequelize
//
//  Created by Valo on 2019/8/20.
//

#import <Foundation/Foundation.h>
#import "VVOrm.h"
#import "VVTokenEnumerator.h"

NS_ASSUME_NONNULL_BEGIN

@interface VVResultMatch : NSObject
@property (nonatomic, assign) UInt64 weight;
@property (nonatomic, assign) NSRange range;
@property (nonatomic, copy) NSString *source;
@property (nonatomic, copy) NSAttributedString *attrText;

//used to calculate weights
@property (nonatomic, assign, readonly) NSUInteger lv1;
@property (nonatomic, assign, readonly) NSUInteger lv2;
@property (nonatomic, assign, readonly) NSUInteger lv3;

- (NSComparisonResult)compare:(VVResultMatch *)other;

@end

@interface VVSearchHighlighter : NSObject
@property (nonatomic, assign) VVTokenMethod method; ///< default is VVTokenMethodSequelize
@property (nonatomic, copy) NSString *keyword;
@property (nonatomic, assign) BOOL fuzzyMatch;
@property (nonatomic, assign) BOOL tokenMatch;
@property (nonatomic, assign) VVTokenMask mask; ///< default is VVTokenMaskDeault | 30
@property (nonatomic, assign) NSUInteger attrTextMaxLength; ///< default is 17
@property (nonatomic, strong) NSDictionary<NSAttributedStringKey, id> *highlightAttributes;
@property (nonatomic, strong) NSDictionary<NSAttributedStringKey, id> *normalAttributes;
@property (nonatomic, strong) id reserved;

- (instancetype)initWithOrm:(VVOrm *)orm keyword:(NSString *)keyword;

- (instancetype)initWithMethod:(VVTokenMethod)method keyword:(NSString *)keyword;

/// highlight search results
/// @param field field to highlight
- (NSArray<VVResultMatch *> *)highlight:(NSArray<NSObject *> *)objects field:(NSString *)field;

/// highlight search result
- (VVResultMatch *)highlight:(NSString *)source;

@end

NS_ASSUME_NONNULL_END
