#pragma once

#include <cstddef>
#include <string>
#include <vector>

namespace streami {

struct Candidate {
    std::string identifier;
    std::vector<int> genreIDs;
    double voteAverage = 0.0;
    int voteCount = 0;
    double popularity = 0.0;
};

std::vector<std::string> rank(
    const std::vector<Candidate>& candidates,
    const std::vector<Candidate>& savedTitles,
    std::size_t limit = 20);

}