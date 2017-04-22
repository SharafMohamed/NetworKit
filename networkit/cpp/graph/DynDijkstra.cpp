/*
 * DynDijkstra.cpp
 *
 *  Created on: 21.07.2014
 *      Author: ebergamini
 */

#include "Dijkstra.h"
#include "DynDijkstra.h"
#include "../auxiliary/Log.h"
#include "../auxiliary/PrioQueue.h"
#include "../auxiliary/NumericTools.h"
#include <queue>


namespace NetworKit {

DynDijkstra::DynDijkstra(const Graph& G, node source, bool storePredecessors) : DynSSSP(G, source, storePredecessors),
color(G.upperNodeIdBound(), WHITE) {

}

void DynDijkstra::run() {
	Dijkstra dij(G, source, true);
	dij.run();
	distances = dij.distances;
	npaths = dij.npaths;
	if (storePreds) {
		previous = dij.previous;
	}
}

void DynDijkstra::update(const std::vector<GraphEvent>& batch) {
	mod = false;
	// priority queue with distance-node pairs
	Aux::PrioQueue<edgeweight, node> Q(G.upperNodeIdBound());
	// queue with all visited nodes
	std::queue<node> visited;
	// if u has a new shortest path going through v, it updates the distance of u
	// and inserts u in the priority queue (or updates its priority, if already in Q)
	auto updateQueue = [&](node u, node v, edgeweight w) {
		if (distances[u] >= distances[v]+w) {
			distances[u] = distances[v]+w;
			if (color[u] == WHITE) {
				Q.insert(distances[u], u);
				color[u] = BLACK;
			}	else {
				Q.decreaseKey(distances[u], u);
			}
		}
	};

	for (GraphEvent edge : batch) {
		if (edge.type!=GraphEvent::EDGE_ADDITION && edge.type!=GraphEvent::EDGE_WEIGHT_UPDATE)
			throw std::runtime_error("Graph update not allowed");
		//TODO: discuss with Christian whether you can substitute weight_update with with_increase/weight_decrease
		// otherwise, it is not possbile to check wether the change in the weight is positive or negative
		updateQueue(edge.u, edge.v, edge.w);
		updateQueue(edge.v, edge.u, edge.w);
	}

	while(Q.size() != 0) {
		mod = true;
		node current = Q.extractMin().second;
		visited.push(current);
		if (storePreds) {
			previous[current].clear();
		}
		npaths[current] = 0;
		G.forInNeighborsOf(current, [&](node current, node z, edgeweight w){
			//z is a predecessor of current node
			if (Aux::NumericTools::equal(distances[current], distances[z]+w, 0.000001)) {
				if (storePreds) {
					previous[current].push_back(z);
				}
				npaths[current] += npaths[z];
			}
			//check whether curent node is a predecessor of z
			else {
				updateQueue(z, current, w);
			}
		});
	}

	// reset colors
	while(!visited.empty()) {
		node w = visited.front();
		visited.pop();
		color[w] = WHITE;
	}

}

} /* namespace NetworKit */
