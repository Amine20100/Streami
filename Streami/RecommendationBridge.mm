#import "RecommendationBridge.h"

#include "RecommendationEngine.hpp"

#include <string>
#include <vector>

namespace {

streami::Candidate candidateFromDictionary(NSDictionary<NSString *, id> *record) {
    streami::Candidate candidate;
    id identifierValue = record[@"id"];
    if ([identifierValue isKindOfClass:[NSString class]]) {
        NSString *identifier = identifierValue;
        candidate.identifier = [identifier UTF8String] ?: "";
    }

    id genreValues = record[@"genres"];
    if ([genreValues isKindOfClass:[NSArray class]]) {
        NSArray *genreArray = genreValues;
        for (id value in genreArray) {
            if ([value isKindOfClass:[NSNumber class]]) {
                NSNumber *genreID = value;
                candidate.genreIDs.push_back([genreID intValue]);
            }
        }
    }

    id voteAverage = record[@"voteAverage"];
    if ([voteAverage isKindOfClass:[NSNumber class]]) {
        NSNumber *number = voteAverage;
        candidate.voteAverage = [number doubleValue];
    }

    id voteCount = record[@"voteCount"];
    if ([voteCount isKindOfClass:[NSNumber class]]) {
        NSNumber *number = voteCount;
        candidate.voteCount = [number intValue];
    }

    id popularity = record[@"popularity"];
    if ([popularity isKindOfClass:[NSNumber class]]) {
        NSNumber *number = popularity;
        candidate.popularity = [number doubleValue];
    }
    return candidate;
}

std::vector<streami::Candidate> candidatesFromArray(NSArray<NSDictionary<NSString *, id> *> *records) {
    std::vector<streami::Candidate> candidates;
    candidates.reserve(records.count);
    for (NSDictionary<NSString *, id> *record in records) {
        candidates.push_back(candidateFromDictionary(record));
    }
    return candidates;
}

}

@implementation RecommendationBridge

+ (NSArray<NSString *> *)rankCandidates:(NSArray<NSDictionary<NSString *, id> *> *)candidates
                            savedTitles:(NSArray<NSDictionary<NSString *, id> *> *)savedTitles
                                  limit:(NSUInteger)limit {
    const std::vector<streami::Candidate> candidateValues = candidatesFromArray(candidates);
    const std::vector<streami::Candidate> savedValues = candidatesFromArray(savedTitles);
    const std::vector<std::string> ranked = streami::rank(candidateValues, savedValues, static_cast<std::size_t>(limit));

    NSMutableArray<NSString *> *identifiers = [NSMutableArray arrayWithCapacity:ranked.size()];
    for (const std::string& identifier : ranked) {
        NSString *value = [[NSString alloc] initWithBytes:identifier.data()
                                                   length:identifier.size()
                                                 encoding:NSUTF8StringEncoding];
        if (value != nil) {
            [identifiers addObject:value];
        }
    }
    return [identifiers copy];
}

@end