/*
 * CommuteTimeDistanceGTest.cpp
 *
 *  Created on: Jan 17, 2016
 *      Author: Michael
 */

#include "CommuteTimeDistanceGTest.h"
#include "../../graph/Graph.h"
#include "../../io/METISGraphReader.h"
#include "../../centrality/SpanningEdgeCentrality.h"
#include <math.h>
#include <fstream>
#include <iomanip>


namespace NetworKit {

TEST_F(CommuteTimeDistanceGTest, testOnToyGraph) {
	/* Graph:
		    0    3
		     \  / \
		      2    5
		     /  \ /
		    1    4
	 */
	count n = 6;
	Graph G(n, false, false);
	G.indexEdges();


	G.addEdge(0, 2);
	G.addEdge(1, 2);
	G.addEdge(2, 3);
	G.addEdge(2, 4);
	G.addEdge(3, 5);
	G.addEdge(4, 5);

	SpanningEdgeCentrality sp(G);

	sp.run();
	EXPECT_NEAR(1.0, sp.score(0), 1e-5);
	EXPECT_NEAR(1.0, sp.score(1), 1e-5);
	EXPECT_NEAR(0.75, sp.score(2), 1e-5);
	EXPECT_NEAR(0.75, sp.score(3), 1e-5);
	EXPECT_NEAR(0.75, sp.score(4), 1e-5);
	EXPECT_NEAR(0.75, sp.score(5), 1e-5);

	CommuteTimeDistance ctd(G);
	ctd.run();
	EXPECT_NEAR(sqrt(1.0 * G.numberOfEdges()), ctd.distance(0, 2), 1e-4);
	EXPECT_NEAR(sqrt(1.0 * G.numberOfEdges()), ctd.distance(1, 2), 1e-4);
	EXPECT_NEAR(sqrt(0.75 * G.numberOfEdges()), ctd.distance(2, 3), 1e-4);
	EXPECT_NEAR(sqrt(0.75 * G.numberOfEdges()), ctd.distance(2, 4), 1e-4);
	EXPECT_NEAR(sqrt(0.75 * G.numberOfEdges()), ctd.distance(3, 5), 1e-4);
	EXPECT_NEAR(sqrt(0.75 * G.numberOfEdges()), ctd.distance(4, 5), 1e-4);
}

TEST_F(CommuteTimeDistanceGTest, testECTDOnSmallGraphs) {
	METISGraphReader reader;

	std::string graphFiles[2] = {"input/karate.graph", "input/tiny_01.graph"};

	for (auto graphFile: graphFiles) {
		Graph G = reader.read(graphFile);
		G.indexEdges();
		Aux::Timer timer;
		CommuteTimeDistance exact(G);
		CommuteTimeDistance cen(G);

		timer.start();
		exact.run();
		timer.stop();
		INFO("ECTD time: ", timer.elapsedTag());

		timer.start();
		cen.runApproximation();
		timer.stop();
		INFO("approx ECTD time: ", timer.elapsedTag());

		double error = 0.0;
		G.forNodes([&](node u){
			G.forNodes([&](node v) {
				double relError = fabs(cen.distance(u,v) - exact.distance(u,v));
			//	INFO("Approximated: ", cen.distance(u,v), ", exact: ", exact.distance(u,v));
				if (fabs(exact.distance(u,v)) > 1e-9) {
					relError /= exact.distance(u,v);
				}
				error += relError;
			});
		});
		error /= G.numberOfNodes()*G.numberOfNodes();
		INFO("Avg. relative error: ", error);
	}
}

TEST_F(CommuteTimeDistanceGTest, testECTDParallelOnSmallGraphs) {
	METISGraphReader reader;

	std::string graphFiles[2] = {"input/karate.graph", "input/tiny_01.graph"};

	for (auto graphFile: graphFiles) {
		Graph G = reader.read(graphFile);
		G.indexEdges();
		Aux::Timer timer;
		CommuteTimeDistance exact(G);
		CommuteTimeDistance cen(G);

		timer.start();
		exact.run();
		timer.stop();
		INFO("ECTD time: ", timer.elapsedTag());

		timer.start();
		cen.runParallelApproximation();
		timer.stop();
		INFO("approx ECTD time: ", timer.elapsedTag());

		double error = 0.0;
		G.forNodes([&](node u){
			G.forNodes([&](node v) {
				double relError = fabs(cen.distance(u,v) - exact.distance(u,v));
			//	INFO("Approximated: ", cen.distance(u,v), ", exact: ", exact.distance(u,v));
				if (fabs(exact.distance(u,v)) > 1e-9) {
					relError /= exact.distance(u,v);
				}
				error += relError;
			});
		});
		error /= G.numberOfNodes()*G.numberOfNodes();
		INFO("Avg. relative error: ", error);
	}
}

TEST_F(CommuteTimeDistanceGTest, testECTDSingleSource) {
	METISGraphReader reader;

	std::string graphFiles[2] = {"input/karate.graph", "input/tiny_01.graph"};

	for (auto graphFile: graphFiles) {
		Graph G = reader.read(graphFile);
		Aux::Timer timer;
		CommuteTimeDistance ectd(G);
		node u = G.randomNode();
		double sum1 = ectd.runSingleSource(u);
		double sum2 = 0.0;
		G.forNodes([&](node v){
			if (u != v) {
				sum2 += ectd.runSinglePair(u,v);
			}
		});
		INFO("sum1 = ", sum1);
		INFO("sum2 = ", sum2);
	//	INFO("Avg. relative error: ", error);
	}
}

} /* namespace NetworKit */
