/*
 * AlgebraicTriangleCounting.h
 *
 *  Created on: Jul 12, 2016
 *      Author: Michael Wegner (michael.wegner@student.kit.edu)
 */

#ifndef NETWORKIT_CPP_ALGEBRAIC_ALGORITHMS_ALGEBRAICTRIANGLECOUNTING_H_
#define NETWORKIT_CPP_ALGEBRAIC_ALGORITHMS_ALGEBRAICTRIANGLECOUNTING_H_

#include "../../base/Algorithm.h"

namespace NetworKit {

/**
 * @ingroup algebraic
 * Implements a triangle counting algorithm for nodes based on algebraic methods.
 */
template<class Matrix>
class AlgebraicTriangleCounting : public Algorithm {
public:
	/**
	 * Creates an instance of AlgebraicTriangleCounting for the given Graph @a graph.
	 * @param graph
	 */
	AlgebraicTriangleCounting(const Graph& graph) : A(Matrix::adjacencyMatrix(graph)), directed(graph.isDirected()) {}

	/**
	 * Computes the number of triangles each node is part of. A triangle is considered as a set of nodes (i.e. if there
	 * is a triangle (u,v,w) it only counts as one triangle at each node).
	 */
	void run() override;

	/**
	 * Returns the score of node @a u.
	 * @param u
	 */
	count score(node u) const {
		if (!hasRun) throw std::runtime_error("AlgebraicTriangleCounting::score(node u): Call run() method first.");
		assert(u < A.numberOfRows());
		return nodeScores[u];
	}

	/**
	 * Returns the scores for all nodes of the graph. If @a moveOut is set to true (false by default) then the scores
	 * are std::moved such that no copy is constructed.
	 * @param moveOut
	 */
	std::vector<count> getScores(bool moveOut = false) {
		if (!hasRun) throw std::runtime_error("AlgebraicTriangleCounting::getScores(): Call run() method first.");
		hasRun = !moveOut;
		return moveOut? std::move(nodeScores) : nodeScores;
	}

private:
	Matrix A;
	bool directed;
	std::vector<count> nodeScores;
};

template<class Matrix>
void AlgebraicTriangleCounting<Matrix>::run() {
	Matrix powA = A * A * A;

	nodeScores.clear();
	nodeScores.resize(A.numberOfRows(), 0);

#pragma omp parallel for
	for (index i = 0; i < powA.numberOfRows(); ++i) {
		nodeScores[i] = directed? powA(i,i) : powA(i,i) / 2.0;
	}

	hasRun = true;
}

} /* namespace NetworKit */

#endif /* NETWORKIT_CPP_ALGEBRAIC_ALGORITHMS_ALGEBRAICTRIANGLECOUNTING_H_ */
