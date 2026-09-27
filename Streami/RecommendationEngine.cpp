#include "RecommendationEngine.hpp"

#include <algorithm>
#include <cmath>
#include <unordered_map>
#include <unordered_set>

namespace streami {
namespace {

std::vector<int> uniqueGenres(const Candidate& candidate) {
    std::vector<int> genres = candidate.genreIDs;
    std::sort(genres.begin(), genres.end());
    genres.erase(std::unique(genres.begin(), genres.end()), genres.end());
    return genres;
}

struct ScoredCandidate {
    const Candidate* candidate;
    std::vector<int> genres;
    double relevance;
    double quality;
    double popularity;
};

double overlap(const std::vector<int>& first, const std::vector<int>& second) {
    if (first.empty() || second.empty()) {
        return 0.0;
    }

    std::size_t shared = 0;
    for (const int genreID : first) {
        if (std::binary_search(second.begin(), second.end(), genreID)) {
            ++shared;
        }
    }
    const std::size_t combined = first.size() + second.size() - shared;
    return combined == 0 ? 0.0 : static_cast<double>(shared) / static_cast<double>(combined);
}

}

std::vector<std::string> rank(
    const std::vector<Candidate>& candidates,
    const std::vector<Candidate>& savedTitles,
    const std::size_t limit) {
    std::unordered_map<int, double> genreAffinity;
    std::unordered_set<std::string> savedIdentifiers;

    for (std::size_t index = 0; index < savedTitles.size(); ++index) {
        const Candidate& savedTitle = savedTitles[index];
        savedIdentifiers.insert(savedTitle.identifier);
        const double recencyWeight = 1.0 / std::sqrt(1.0 + static_cast<double>(index) * 0.35);
        for (const int genreID : uniqueGenres(savedTitle)) {
            genreAffinity[genreID] += recencyWeight;
        }
    }

    if (genreAffinity.empty() || candidates.empty() || limit == 0) {
        return {};
    }

    std::unordered_map<int, std::size_t> genreFrequency;
    std::vector<std::vector<int>> candidateGenres;
    candidateGenres.reserve(candidates.size());
    for (const Candidate& candidate : candidates) {
        candidateGenres.push_back(uniqueGenres(candidate));
        for (const int genreID : candidateGenres.back()) {
            ++genreFrequency[genreID];
        }
    }

    double maximumAffinity = 0.0;
    double profileWeight = 0.0;
    for (const auto& entry : genreAffinity) {
        maximumAffinity = std::max(maximumAffinity, entry.second);
        const auto frequency = genreFrequency.find(entry.first);
        const double documentFrequency = frequency == genreFrequency.end()
            ? 0.0
            : static_cast<double>(frequency->second);
        const double inverseFrequency = 1.0 + std::log1p(static_cast<double>(candidates.size()) / (documentFrequency + 1.0));
        profileWeight += entry.second * inverseFrequency;
    }

    double maximumPopularity = 0.0;
    for (const Candidate& candidate : candidates) {
        maximumPopularity = std::max(maximumPopularity, std::max(candidate.popularity, 0.0));
    }
    const double popularityNormalizer = std::log1p(maximumPopularity);

    std::vector<ScoredCandidate> scored;
    scored.reserve(candidates.size());
    for (std::size_t index = 0; index < candidates.size(); ++index) {
        const Candidate& candidate = candidates[index];
        if (savedIdentifiers.count(candidate.identifier) != 0 || candidate.identifier.empty()) {
            continue;
        }

        const std::vector<int>& genres = candidateGenres[index];
        double weightedAffinity = 0.0;
        for (const int genreID : genres) {
            const auto affinity = genreAffinity.find(genreID);
            if (affinity == genreAffinity.end()) {
                continue;
            }

            const double frequency = static_cast<double>(genreFrequency[genreID]);
            const double inverseFrequency = 1.0 + std::log1p(static_cast<double>(candidates.size()) / frequency);
            weightedAffinity += affinity->second * inverseFrequency;
        }
        if (weightedAffinity == 0.0 || profileWeight == 0.0 || maximumAffinity == 0.0) {
            continue;
        }

        const double relevance = std::clamp(weightedAffinity / profileWeight, 0.0, 1.0);
        const double votes = static_cast<double>(std::max(candidate.voteCount, 0));
        const double bayesianRating = (std::clamp(candidate.voteAverage, 0.0, 10.0) * votes + 6.5 * 80.0) / (votes + 80.0);
        const double quality = bayesianRating / 10.0;
        const double normalizedPopularity = popularityNormalizer == 0.0
            ? 0.0
            : std::log1p(std::max(candidate.popularity, 0.0)) / popularityNormalizer;

        scored.push_back({&candidate, genres, relevance, quality, normalizedPopularity});
    }

    std::vector<std::string> result;
    std::vector<std::vector<int>> selectedGenres;
    result.reserve(std::min(limit, scored.size()));
    selectedGenres.reserve(std::min(limit, scored.size()));

    while (!scored.empty() && result.size() < limit) {
        std::size_t bestIndex = 0;
        double bestScore = -1.0;
        for (std::size_t index = 0; index < scored.size(); ++index) {
            const ScoredCandidate& candidate = scored[index];
            double redundancy = 0.0;
            for (const std::vector<int>& selected : selectedGenres) {
                redundancy = std::max(redundancy, overlap(candidate.genres, selected));
            }
            const double baseScore = candidate.relevance * 0.72 + candidate.quality * 0.20 + candidate.popularity * 0.08;
            const double finalScore = baseScore - redundancy * 0.14;
            const double scoreEpsilon = 1e-9;
            if (finalScore > bestScore + scoreEpsilon ||
                (std::abs(finalScore - bestScore) <= scoreEpsilon &&
                 candidate.candidate->identifier < scored[bestIndex].candidate->identifier)) {
                bestIndex = index;
                bestScore = finalScore;
            }
        }

        const ScoredCandidate& selected = scored[bestIndex];
        result.push_back(selected.candidate->identifier);
        selectedGenres.push_back(selected.genres);
        scored.erase(scored.begin() + static_cast<std::ptrdiff_t>(bestIndex));
    }

    return result;
}

}