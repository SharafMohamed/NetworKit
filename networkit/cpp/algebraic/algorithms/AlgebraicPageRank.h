/*
 * AlgebraicPageRank.h
 *
 *  Created on: Jun 20, 2016
 *      Author: Michael Wegner (michael.wegner@student.kit.edu)
 */

#ifndef NETWORKIT_CPP_ALGEBRAIC_ALGORITHMS_ALGEBRAICPAGERANK_H_
#define NETWORKIT_CPP_ALGEBRAIC_ALGORITHMS_ALGEBRAICPAGERANK_H_

#include "../../base/Algorithm.h"
#include "../../auxiliary/Parallel.h"

#include "../../graph/Graph.h"
#include "../GraphBLAS.h"
#include "../Vector.h"

namespace NetworKit {

/**
 * @ingroup algebraic
 * Implementation of PageRank using the GraphBLAS interface.
 */
template<class Matrix>
class AlgebraicPageRank : public Algorithm {
public:

	/**
	 * Constructs an instance of AlgebraicPageRank for the given @a graph. Page rank uses the damping factor @a damp
	 * and the tolerance @a tol.
	 * @param graph
	 * @param damp
	 * @param tol
	 */
	AlgebraicPageRank(const Graph& graph, const double damp = 0.85, const double tol = 1e-8) : damp(damp), tol(tol) {
		Matrix A = Matrix::adjacencyMatrix(graph);
		// normalize At by out-degree
		Vector invOutDeg = GraphBLAS::rowReduce(A);
#pragma omp parallel for
		for (index i = 0; i < invOutDeg.getDimension(); ++i) {
			invOutDeg[i] = 1.0/invOutDeg[i];
		}
		
		std::vector<Triplet> mTriplets(A.nnz());
		index idx = 0;
		A.forNonZeroElementsInRowOrder([&](index i, index j, double value) {
			mTriplets[idx++] = {j,i, damp * value * invOutDeg[i]};
		});
		M = std::move(Matrix(A.numberOfRows(), mTriplets));
	}

	void run() override;

	/**
	 * Get a vector containing the betweenness score for each node in the graph.
	 * @param moveOut Return the actual internal data instead of a copy. Resets the hasRun-state. Default: false.
	 * @return The betweenness scores calculated by @link run().
	 */
	std::vector<double> scores(bool moveOut = false);


	/**
	 * Get a vector of pairs sorted into descending order. Each pair contains a node and the corresponding score
	 * calculated by @link run().
	 * @return A vector of pairs.
	 */
	std::vector<std::pair<node, double>> ranking();

	/**
	 * Get the betweenness score of node @a v calculated by @link run().
	 *
	 * @param v A node.
	 * @return The betweenness score of node @a v.
	 */
	double score(node v);

	/**
	 * Get the theoretical maximum of centrality score in the given graph.
	 *
	 * @return The maximum centrality score.
	 */
	double maximum() {
		return 1.0;
	}

private:
	Matrix M;

	const double damp;
	const double tol;

	std::vector<double> scoreData;
	std::vector<double> edgeScoreData;
};

template<class Matrix>
void AlgebraicPageRank<Matrix>::run() {
	count n = M.numberOfRows();
	double teleportProb = (1.0 - damp) / (double) n;
	Vector rank(n, 1.0/(double)n);
	Vector lastRank;

	do {
		lastRank = rank;
		rank = M * rank;
		rank.apply([&](double value) {return value += teleportProb;});
	} while ((rank - lastRank).length() > tol);

	double sum = 0.0;
#pragma omp parallel for reduction(+:sum)
	for (index i = 0; i < rank.getDimension(); ++i) {
		sum += rank[i];
	}

	scoreData.resize(n, 0);
#pragma omp parallel for
	for (index i = 0; i < rank.getDimension(); ++i) {
		scoreData[i] = rank[i] / sum;
	}

	hasRun = true;
}

template<class Matrix>
std::vector<double> AlgebraicPageRank<Matrix>::scores(bool moveOut) {
	if (!hasRun) throw std::runtime_error("Call run method first");
	hasRun = !moveOut;
	return moveOut ? std::move(scoreData) : scoreData;
}

template<class Matrix>
std::vector<std::pair<node, double>> AlgebraicPageRank<Matrix>::ranking() {
	if (!hasRun) throw std::runtime_error("Call run method first");
	std::vector<std::pair<node, double> > ranking;
	for (index i = 0; i < scoreData.size(); ++i) {
		ranking.push_back({i, scoreData[i]});
	}
	Aux::Parallel::sort(ranking.begin(), ranking.end(), [](std::pair<node, double> x, std::pair<node, double> y) { return x.second > y.second; });
	return ranking;
}

template<class Matrix>
double AlgebraicPageRank<Matrix>::score(node v) {
	if (!hasRun) throw std::runtime_error("Call run method first");
	return scoreData.at(v);
}

} /* namespace NetworKit */

#endif /* NETWORKIT_CPP_ALGEBRAIC_ALGORITHMS_ALGEBRAICPAGERANK_H_ */
