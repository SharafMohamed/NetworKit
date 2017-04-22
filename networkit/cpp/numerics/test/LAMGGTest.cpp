/*
 * LAMGGTest.cpp
 *
 *  Created on: 20.11.2014
 *      Author: Michael
 */

#include "LAMGGTest.h"
#include "../LAMG/MultiLevelSetup.h"
#include "../LAMG/SolverLamg.h"
#include "../../io/LineFileReader.h"
#include "../../auxiliary/Timer.h"
#include "../../algebraic/CSRMatrix.h"

#include "../GaussSeidelRelaxation.h"

namespace NetworKit {

TEST_F(LAMGGTest, testSmallGraphs) {
	METISGraphReader reader;
	GaussSeidelRelaxation<CSRMatrix> gaussSmoother;
	Smoother<CSRMatrix> *smoother = new GaussSeidelRelaxation<CSRMatrix>();
	MultiLevelSetup<CSRMatrix> setup(gaussSmoother);
	Aux::Timer timer;
	for (index i = 0; i < GRAPH_INSTANCES.size(); ++i) {
		string graph = GRAPH_INSTANCES[i];
		Graph G = reader.read(graph);
		ConnectedComponents con(G);
		con.run();
		Partition comps = con.getPartition();
		if (comps.numberOfSubsets() > 1) { // disconnected graphs are currently not supported
			continue;
		}

		LevelHierarchy<CSRMatrix> hierarchy;
		timer.start();
		setup.setup(G, hierarchy);
		SolverLamg<CSRMatrix> solver(hierarchy, *smoother);
		timer.stop();
		INFO("setup time\t ", timer.elapsedMilliseconds());

		Vector b(G.numberOfNodes());
		Vector x(G.numberOfNodes());

		b = randZeroSum(G, 12345);
		x = randVector(G.numberOfNodes(), -1, 1);


		LAMGSolverStatus status;
		status.maxConvergenceTime = 10 * 60 * 1000;
		status.desiredResidualReduction = 1e-6 * b.length() / (hierarchy.at(0).getLaplacian() * x - b).length(); // needed for getting a relative residual <= 1e-6

		Vector result = x;
		INFO("Solving equation system - Gauss-Seidel");
		timer.start();
		solver.solve(result, b, status);
		timer.stop();

		EXPECT_TRUE(status.converged);

		INFO("solve time\t ", timer.elapsedMilliseconds());
		INFO("final residual = ", status.residual);
		INFO("numIters = ", status.numIters);
		INFO("DONE");

	}

	delete smoother;
}



Vector LAMGGTest::randVector(count dimension, double lower, double upper) const {
	Vector randVector(dimension);
	for (index i = 0; i < dimension; ++i) {
		randVector[i] = 2.0 * Aux::Random::probability() - 1.0;
	}

	// introduce bias
	for (index i = 0; i < dimension; ++i) {
		randVector[i] = randVector[i] * randVector[i];
	}

	return randVector;
}


Vector LAMGGTest::randZeroSum(const Graph& G, size_t seed) const {
	mt19937 rand(seed);
	auto rand_value = uniform_real_distribution<double>(-1.0, 1.0);
	ConnectedComponents con(G);
	count n = G.numberOfNodes();
	con.run();
	Partition comps = con.getPartition();

	/* Fill each component randomly such that its sum is 0 */
	Vector b(n, 0.0);

	for (int id : comps.getSubsetIds()) {
		auto indexes = comps.getMembers(id);
		assert(!indexes.empty());
		double sum = 0.0;
		for (auto entry : indexes) {
			b[entry] = rand_value(rand);
			sum += b[entry];
		}
		b[*indexes.begin()] -= sum;
	}

	return b;
}

} /* namespace NetworKit */
