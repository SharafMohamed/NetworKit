/*
 * LinearSolver.h
 *
 *  Created on: 30.10.2014
 *      Author: Michael Wegner (michael.wegner@student.kit.edu)
 */

#ifndef LINEARSOLVER_H_
#define LINEARSOLVER_H_

#include "../algebraic/Vector.h"
#include "../graph/Graph.h"
#include <limits>

namespace NetworKit {


/** Describes the status of a LinearSolver after the solver finished. */
struct SolverStatus {
	count numIters; // number of iterations needed during solve phase
	double residual; // absolute final residual
	bool converged; // flag of conversion status
};

/**
 * Abstract base class for solvers that solve linear systems.
 */
template<class Matrix>
class LinearSolver {
protected:
	double tolerance;

public:
	/**
	 * Construct an abstract solver with the given @a tolerance. The relative residual ||Ax-b||/||b|| should be less than or equal to
	 * @a tolerance after the solver finished.
	 * @param tolerance
	 */
	LinearSolver(const double tolerance) : tolerance(tolerance) {}
	virtual ~LinearSolver() = default;

	/**
	 * Sets the solver up for the specified @a matrix.
	 * @param matrix
	 */
	virtual void setup(const Matrix& matrix) = 0;

	/**
	 * Sets the solver up for the Laplacian matrix of the @a graph specified.
	 * @param graph
	 */
	virtual void setup(const Graph& graph);

	/**
	 * Sets the solver up for the specified @a matrix where the underlying graph has to be connected.
	 * @param matrix
	 */
	virtual void setupConnected(const Matrix& matrix) = 0;

	/**
	 * Sets the solver up for the Laplacian matrix of the @a graph specified. The graph has to be connected.
	 * @param graph
	 */
	virtual void setupConnected(const Graph& graph);

	/**
	 * Abstract solve function that computes @a result for the given right-hand side @a rhs and the matrix that has been setup in @ref setup.
	 * @param rhs
	 * @param result
	 * @param maxConvergenceTime
	 * @param maxIterations
	 * @return A @ref SolverStatus object which provides some statistics like the final absolute residual.
	 */
	virtual SolverStatus solve(const Vector& rhs, Vector& result, count maxConvergenceTime = 5 * 60 * 1000, count maxIterations = std::numeric_limits<count>::max()) = 0;

	/**
	 * Abstract parallel solve function that computes the @a results for the matrix currently setup and the right-hand sides @a rhs.
	 * The maximum spent time for each system can be specified by @a maxConvergenceTime and the maximum number of iterations can be set
	 * by @a maxIterations.
	 * @param rhs
	 * @param results
	 * @param maxConvergenceTime
	 * @param maxIterations
	 * @note If the solver does not support parallelism during solves, this function falls back to solving the systems sequentially.
	 */
	virtual void parallelSolve(const std::vector<Vector>& rhs, std::vector<Vector>& results, count maxConvergenceTime = 5 * 60 * 1000, count maxIterations = std::numeric_limits<count>::max());
};

template<class Matrix>
void LinearSolver<Matrix>::setup(const Graph& graph) {
	setup(Matrix::laplacianMatrix(graph));
}

template<class Matrix>
void LinearSolver<Matrix>::setupConnected(const Graph &graph) {
	setupConnected(Matrix::laplacianMatrix(graph));
}

template<class Matrix>
void LinearSolver<Matrix>::parallelSolve(const std::vector<Vector>& rhs, std::vector<Vector>& results, count maxConvergenceTime, count maxIterations) {
	for (index i = 0; i < rhs.size(); ++i) {
		solve(rhs[i], results[i], maxConvergenceTime, maxIterations);
	}
}

} /* namespace NetworKit */

#endif /* LINEARSOLVER_H_ */
