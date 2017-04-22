/*
 * EdmondsKarp.cpp
 *
 *  Created on: 11.06.2014
 *      Author: Michael Wegner (michael.wegner@student.kit.edu), Michael Hamann <michael.hamann@kit.edu>
 */

#include "EdmondsKarp.h"
#include <limits>
#include <algorithm>
#include <stdexcept>

namespace NetworKit {

EdmondsKarp::EdmondsKarp(const Graph &graph, node source, node sink) : graph(graph), source(source), sink(sink) {
}

edgeweight EdmondsKarp::BFS(std::vector<edgeweight> &residFlow, std::vector<node> &pred) const {
	pred.clear();
	pred.resize(graph.upperNodeIdBound(), none);
	std::vector<edgeweight> gain(graph.upperNodeIdBound(), 0);

	std::queue<node> Q;
	Q.push(source);
	pred[source] = source;
	gain[source] = std::numeric_limits<edgeweight>::max();
	while (!Q.empty()) {
		node u = Q.front(); Q.pop();

		bool sinkReached = false;
		graph.forNeighborsOf(u, [&](node _u, node v, edgeweight weight, edgeid eid){
			if ((
			(u >= v && flow[eid] < weight) || (u < v && residFlow[eid] < weight)
			)&& pred[v] == none) { // only add those neighbors with rest capacity and which were not discovered yet
				pred[v] = u;
				gain[v] = std::min(gain[u], weight - (u >= v ? flow[eid] : residFlow[eid]));

				if (v != sink && !sinkReached) {
					Q.push(v);
				} else {
					sinkReached = true;
				}
			}
		});

		if (sinkReached) {
			return gain[sink];
		}
	}

	return 0.0;
}

void EdmondsKarp::run() {
	if (!graph.hasEdgeIds()) { throw std::runtime_error("edges have not been indexed - call indexEdges first"); }
	flow.clear();
	flow.resize(graph.upperEdgeIdBound(), 0.0);

	std::vector<edgeweight> residFlow(graph.upperEdgeIdBound(), 0.0);

	flowValue = 0;
	while (true) {
		std::vector<node> pred;
		edgeweight gain = BFS(residFlow, pred);
		if (gain == 0) break;

		flowValue += gain;
		node v = sink;
		while (v != source) {
			node u = pred[v];
			edgeid eid = graph.edgeId(u, v);
			if (u >= v) {
				flow[eid] += gain;
				residFlow[eid] -= gain;
			} else {
				flow[eid] -= gain;
				residFlow[eid] += gain;
			}
			v = u;
		}
	}

	graph.parallelForEdges([&](node u, node v, edgeid eid) {
		flow[eid] = std::max(flow[eid], residFlow[eid]);
	});
}

edgeweight EdmondsKarp::getMaxFlow() const {
	return flowValue;
}


std::vector<node> EdmondsKarp::getSourceSet() const {
	// perform bfs from source
	std::vector<bool> visited(graph.upperNodeIdBound(), false);
	std::vector<node> sourceSet;

	std::queue<node> Q;
	Q.push(source);
	visited[source] = true;
	while (!Q.empty()) {
		node u = Q.front(); Q.pop();
		sourceSet.push_back(u);

		graph.forNeighborsOf(u, [&](node _u, node v, edgeweight weight, edgeid eid) {
			if (!visited[v] && flow[eid] < weight) {
				Q.push(v);
				visited[v] = true;
			}
		});
	}

	return sourceSet;
}

edgeweight EdmondsKarp::getFlow(node u, node v) const {
	return flow[graph.edgeId(u, v)];
}

std::vector<edgeweight> EdmondsKarp::getFlowVector() const {
	return flow;
}

} /* namespace NetworKit */
