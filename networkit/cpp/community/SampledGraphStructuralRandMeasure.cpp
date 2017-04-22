/*
 * SampledRandMeasure.cpp
 *
 *  Created on: 01.07.2013
 *      Author: cls
 */

#include "SampledGraphStructuralRandMeasure.h"

#include "../auxiliary/Random.h"
#include "../auxiliary/Log.h"

namespace NetworKit {

SampledGraphStructuralRandMeasure::SampledGraphStructuralRandMeasure(count maxSamples) : maxSamples(maxSamples) {

}

double SampledGraphStructuralRandMeasure::getDissimilarity(const Graph& G, const Partition& first, const Partition& second) {
	assert (G.numberOfNodes() > 0);
	assert (G.numberOfEdges() > maxSamples);

	count e11 = 0; 	// number of node pairs for which clusterings agree
	count e00 = 0;	// number of node pairs for which clusterings disagree


	count nSamples = 0;

	index z = G.upperNodeIdBound();

	while (nSamples < maxSamples) {
		node u = Aux::Random::integer(z - 1);
		if (G.hasNode(u) && (G.degree(u) > 0)) {
			auto neighbors = G.neighbors(u);
			index i = Aux::Random::integer(neighbors.size() - 1);
			node v = neighbors.at(i);
			assert (G.hasEdge(u, v));
			if ((first[u] == first[v]) && (second[u] == second[v])) {
				e11 += 1;
			} else if ((first[u] != first[v]) && (second[u] != second[v])) {
				e00 += 1;
			}
			nSamples += 1;
		}
	}

	DEBUG("e11 = " , e11 , " e00 = " , e00 , " nSamples = " , nSamples);

	double dis = 1 - ((e00 + e11) / (double) nSamples);
	return dis;
}

} /* namespace NetworKit */
