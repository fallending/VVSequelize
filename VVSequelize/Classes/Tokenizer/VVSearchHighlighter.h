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

typedef NS_ENUM (NSUInteger, VVMatchType) {
    VVMatchFull,
    VVMatchPinyinFull,
    VVMatchPrefix,
    VVMatchPinyinPrefix,
    VVMatchNonPrefix,
    VVMatchPinyinNonPrefix,

    VVMatchOther,
    VVMatchNone,
};

@interface VVResultMatch : NSObject
@property (nonatomic, assign) VVMatchType type;
@property (nonatomic, assign) NSRange range;
@property (nonatomic, copy) NSString *source;
@property (nonatomic, copy) NSAttributedString *attrText;

- (NSComparisonResult)compare:(VVResultMatch *)other;

@end

@interface VVSearchHighlighter : NSObject
@property (nonatomic, assign) VVTokenMethod method;
@property (nonatomic, copy) NSString *keyword;
@property (nonatomic, assign) VVTokenMask mask;
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
