/*
 * GraphBenchmark.cpp
 *
 *  Created on: 01.02.2013
 *      Author: Christian Staudt (christian.staudt@kit.edu)
 */

#ifndef NOGTEST

#include "GraphBenchmark.h"
#include "../../auxiliary/Log.h"

namespace NetworKit {

GraphBenchmark::GraphBenchmark() {
	this->n = 1000;
	INFO("n = " , this->n);
}

GraphBenchmark::~GraphBenchmark() {
	// TODO Auto-generated destructor stub
}


// TASK: benchmark edge insertions standard vs raw

TEST_F(GraphBenchmark, edgeInsertions_noop_seq) {
	int64_t n = this->n;
	Aux::Timer runtime;

	Graph G(n);
	int64_t i = 0;
	runtime.start();
	G.forNodePairs([&](node u, node v) {
		i++;
		// G.insertEdge(u, v);
	});
	runtime.stop();

	TRACE("counted i = " , i);

	INFO("[DONE] edgeInsertions_noop_seq (" , runtime.elapsed().count() , " ms)");

}

TEST_F(GraphBenchmark, edgeInsertions_noop_par) {
	int64_t n = this->n;
	Aux::Timer runtime;

	Graph G(n);
	int64_t i = 0;
	runtime.start();
	G.parallelForNodePairs([&](node u, node v) {
		i++;
		// G.insertEdge(u, v);
	});
	runtime.stop();

	TRACE("counted i = " , i);

	INFO("[DONE] edgeInsertions_noop_par (" , runtime.elapsed().count() , " ms)");

}

TEST_F(GraphBenchmark, edgeInsertions_standard_seq) {
	count n = this->n;
	Aux::Timer runtime;

	Graph G(n);
	runtime.start();
	G.forNodePairs([&](node u, node v) {
		G.addEdge(u, v);
	});
	runtime.stop();

	INFO("[DONE] edgeInsertions_standard_seq (" , runtime.elapsed().count() , " ms)");
	EXPECT_EQ((n * (n-1)) / 2, G.numberOfEdges());


}

//TEST_F(GraphBenchmark, edgeInsertions_standard_par) {
//	int64_t n = this->n;
//	Aux::Timer runtime;
//
//	Graph G(n);
//	runtime.start();
//	G.parallelForNodePairs([&](node u, node v) {
//		G.insertEdge(u, v);
//	});
//	runtime.stop();
//
//	INFO("[DONE] edgeInsertions_standard_par(" , runtime.elapsed().count() , " ms)");
//	EXPECT_EQ((n * (n-1)) / 2, G.numberOfEdges());
//
//}
//
//TEST_F(GraphBenchmark, edgeInsertions_raw_seq) {
//	int64_t n = this->n;
//	Aux::Timer runtime;
//
//	Graph G(n);
//	stinger* S = G.asSTINGER();
//
//	runtime.start();
//	for (node u = 1; u <= n; ++u) {
//		for (node v = u + 1; v <= n; ++v) {
//			stinger_insert_edge_pair(S, G.defaultEdgeType, u, v, G.defaultEdgeWeight, G.defaultTimeStamp);
//		}
//	}
//	runtime.stop();
//
//
//	INFO("[DONE] edgeInsertions_raw_seq (" , runtime.elapsed().count() , " ms)");
//	EXPECT_EQ((n * (n-1)) / 2, G.numberOfEdges());
//
//
//}

//TEST_F(GraphBenchmark, edgeInsertions_raw_par) {
//	int64_t n = this->n;
//	Aux::Timer runtime;
//
//	Graph G(n);
//	stinger* S = G.asSTINGER();
//
//	runtime.start();
//	#pragma omp parallel
//	for (node u = 1; u <= n; ++u) {
//		for (node v = u + 1; v <= n; ++v) {
//			stinger_insert_edge_pair(S, G.defaultEdgeType, u, v, G.defaultEdgeWeight, G.defaultTimeStamp);
//		}
//	}
//	runtime.stop();
//
//	INFO("[DONE] edgeInsertions_raw_par (" , runtime.elapsed().count() , " ms)");
//	EXPECT_EQ((n * (n-1)) / 2, G.numberOfEdges());
//
//}




// Task: precompute incident weights with different methods



TEST_F(GraphBenchmark, weightedDegree_standard_seq) {
	int64_t n = this->n;
	Graph G(n);
	G.forNodePairs([&](node u, node v){
		G.addEdge(u,v);
	});

	Aux::Timer runtime;

	runtime.start();
	std::vector<double> weightedDegree(n, 0.0);

	G.forNodes([&](node v) {
		weightedDegree[v] = G.weightedDegree(v);
	});
	runtime.stop();

	INFO("[DONE] (" , runtime.elapsed().count() , " ms)");

	// test correctness of result
	bool correct = true;
	G.forNodes([&](node v){
		correct &= (weightedDegree[v] == (n - 1));
	});

	EXPECT_TRUE(correct);
}


// TEST: use different containers
// RESULT: NodeMap, vector and array are about equally fast


// TEST: parallelize

TEST_F(GraphBenchmark, weightedDegree_standard_par) {
	int64_t n = this->n;
	Graph G(n);
	G.forNodePairs([&](node u, node v){
		G.addEdge(u,v);
	});

	Aux::Timer runtime;

	runtime.start();
	std::vector<double> weightedDegree(n, 0.0);

	G.parallelForNodes([&](node v) {
		weightedDegree[v] = G.weightedDegree(v);
	});
	runtime.stop();

	INFO("[DONE] (" , runtime.elapsed().count() , " ms)");

	// test correctness of result
	bool correct = true;
	G.forNodes([&](node v){
		correct &= (weightedDegree[v] == (n - 1));
	});

	EXPECT_TRUE(correct);
}


// RESULT: significant super-linear speedup regardless of target container

//TEST_F(GraphBenchmark, weightedDegree_raw_seq) {
//	int64_t n = this->n;
//	GraphGenerator graphGen;
//	Graph G = graphGen.makeCompleteGraph(n);
//	stinger* S = G.asSTINGER();
//
//	Aux::Timer runtime;
//
//	runtime.start();
//	NodeMap<double> weightedDegree(n, 0.0);
//
//	for (node v = 1; v <= n; ++v) {
//		double iw = 0.0;
//		STINGER_READ_ONLY_FORALL_EDGES_OF_VTX_BEGIN(S, v) {
//			iw += stinger_edgeweight(S, STINGER_EDGE_SOURCE, STINGER_EDGE_DEST, G.defaultEdgeType);
//		} STINGER_READ_ONLY_FORALL_EDGES_OF_VTX_END();
//		weightedDegree[v] = iw;
//	}
//	runtime.stop();
//
//	INFO("[DONE] (" , runtime.elapsed().count() , " ms)");
//
//	// test correctness of result
//	bool correct = true;
//	G.forNodes([&](node v){
//		correct &= (weightedDegree[v] == (n - 1));
//	});
//
//	EXPECT_TRUE(correct);
//
//}

//
//TEST_F(GraphBenchmark, weightedDegree_raw_par) {
//	int64_t n = this->n;
//	GraphGenerator graphGen;
//	Graph G = graphGen.makeCompleteGraph(n);
//	stinger* S = G.asSTINGER();
//
//	Aux::Timer runtime;
//
//	runtime.start();
//	NodeMap<double> weightedDegree(n, 0.0);
//
//	#pragma omp parallel for
//	for (node v = 1; v <= n; ++v) {
//		double iw = 0.0;
//		STINGER_READ_ONLY_FORALL_EDGES_OF_VTX_BEGIN(S, v) {
//			iw += stinger_edgeweight(S, STINGER_EDGE_SOURCE, STINGER_EDGE_DEST, G.defaultEdgeType);
//		} STINGER_READ_ONLY_FORALL_EDGES_OF_VTX_END();
//		weightedDegree[v] = iw;
//	}
//	runtime.stop();
//
//	INFO("[DONE] (" , runtime.elapsed().count() , " ms)");
//
//	// test correctness of result
//	bool correct = true;
//	G.forNodes([&](node v){
//		correct &= (weightedDegree[v] == (n - 1));
//	});
//
//	EXPECT_TRUE(correct);
//
//}


} /* namespace NetworKit */

#endif /*NOGTEST */
