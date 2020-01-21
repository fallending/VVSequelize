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

typedef NS_ENUM (NSUInteger, VVMatchLV1) {
    VVMatchLV1_None = 0,
    VVMatchLV1_Firsts,
    VVMatchLV1_Fulls,
    VVMatchLV1_Origin,
};

typedef NS_ENUM (NSUInteger, VVMatchLV2) {
    VVMatchLV2_None = 0,
    VVMatchLV2_Other,
    VVMatchLV2_NonPrefix,
    VVMatchLV2_Prefix,
    VVMatchLV2_Full,
};

typedef NS_ENUM (NSUInteger, VVMatchLV3) {
    VVMatchLV3_Low = 0,
    VVMatchLV3_Medium,
    VVMatchLV3_High,
};

@interface VVResultMatch : NSObject
@property (nonatomic, assign) NSRange range;
@property (nonatomic, copy) NSString *source;
@property (nonatomic, copy) NSAttributedString *attrText;
@property (nonatomic, assign, readonly) UInt64 lowerWeight;
@property (nonatomic, assign, readonly) UInt64 upperWeight;
@property (nonatomic, assign, readonly) UInt64 weight;

//used to calculate weights
@property (nonatomic, assign, readonly) VVMatchLV1 lv1;
@property (nonatomic, assign, readonly) VVMatchLV2 lv2;
@property (nonatomic, assign, readonly) VVMatchLV3 lv3;

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
