#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RecommendationBridge : NSObject

+ (NSArray<NSString *> *)rankCandidates:(NSArray<NSDictionary<NSString *, id> *> *)candidates
                            savedTitles:(NSArray<NSDictionary<NSString *, id> *> *)savedTitles
                                  limit:(NSUInteger)limit;

@end

NS_ASSUME_NONNULL_END