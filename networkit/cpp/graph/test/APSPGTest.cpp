/*
 * APSPGTest.cpp
 *
 *  Created on: 07.07.2015
 *      Author: Arie Slobbe, Elisabetta Bergamini
 */

#ifndef NOGTEST

#include "APSPGTest.h"
#include "../APSP.h"
#include <string>
#include "../../auxiliary/Random.h"


namespace NetworKit {

TEST_F(APSPGTest, testAPSP) {
/* Graph:
     ______
		/      \
	 0    3   6
		\  / \ /
		 2    5
		/  \ / \
	 1    4   7
*/
	int n = 8;
	Graph G(n);

	G.addEdge(0, 2);
	G.addEdge(1, 2);
	G.addEdge(2, 3);
	G.addEdge(2, 4);
	G.addEdge(3, 5);
	G.addEdge(4, 5);
	G.addEdge(5, 6);
	G.addEdge(5, 7);
	G.addEdge(0, 6);

	APSP apsp(G);
	apsp.run();
	std::vector<std::vector<edgeweight> > distances = apsp.getDistances();
	INFO("distances[0]: ", distances[0][0], distances[0][1], distances[0][2], distances[0][3], distances[0][4], distances[0][5], distances[0][6]);
	INFO("distances[1]: ", distances[1][0], distances[1][1], distances[1][2], distances[1][3], distances[1][4], distances[1][5], distances[1][6]);
	EXPECT_TRUE(apsp.isParallel());
}

TEST_F(APSPGTest, tryAPSP) {
	count n = 1000;
	count m = int(n * n);
	Graph G(n, true, false);
	for (count i = 0; i < m; i++) {
		node u = G.randomNode();
		node v = G.randomNode();
		if (u != v && !G.hasEdge(u, v)) {
			G.addEdge(u, v, Aux::Random::integer(10));
		}
	}
	INFO("Nodes: ", G.numberOfNodes(), ", edges: ", G.numberOfEdges());
	APSP apsp(G);
	apsp.run();
}
} /* namespace NetworKit */

#endif /*NOGTEST */
