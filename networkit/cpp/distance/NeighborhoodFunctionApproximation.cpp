/*
* NeighborhoodFunctionApproximation.cpp
*
*  Created on: 30.03.2016
*      Author: Maximilian Vogel
*/

#include "NeighborhoodFunctionApproximation.h"
#include "../components/ConnectedComponents.h"
#include "../auxiliary/Random.h"

#include <math.h>
#include <iterator>
#include <stdlib.h>
#include <omp.h>
#include <map>

namespace NetworKit {

NeighborhoodFunctionApproximation::NeighborhoodFunctionApproximation(const Graph& G, const count k, const count r) : Algorithm(), G(G), k(k), r(r), result() {
	if (G.isDirected()) throw std::runtime_error("current implementation can only deal with undirected graphs");
	ConnectedComponents cc(G);
	cc.run();
	if (cc.getPartition().numberOfSubsets() > 1) throw std::runtime_error("current implementation only runs on graphs with 1 connected component");
}

void NeighborhoodFunctionApproximation::run() {
	// the length of the bitmask where the number of connected nodes is saved
	const count lengthOfBitmask = (count) ceil(log2(G.numberOfNodes())) + r;
	// saves all k bitmasks for every node of the current iteration
	std::vector<std::vector<unsigned int> > mCurr(G.upperNodeIdBound());
	// saves all k bitmasks for every node of the previous iteration
	std::vector<std::vector<unsigned int> > mPrev(G.upperNodeIdBound());
	// the list of nodes that are already connected to all other nodes
	std::vector<unsigned int> highestCount(k, 0);
	// nodes that are not connected to enough nodes yet
	std::vector<char> activeNodes(G.upperNodeIdBound(),0);

	// initialize all vectors
	std::vector<std::vector<unsigned int>> localHighest(omp_get_max_threads(), std::vector<unsigned int>(k, 0));

	std::vector<unsigned int> bitmasks(k, 0);
	omp_set_nested(1);
	Aux::Random::setSeed(Aux::Random::getSeed(), true);
	G.parallelForNodes([&](node v) {
		mCurr[v] = bitmasks;
		mPrev[v] = bitmasks;
		activeNodes[v] = 1;
		// set one bit in each bitmask with probability P(bit i=1) = 0.5^(i+1), i=0,..
		for (count j = 0; j < k; j++) {
			double random = Aux::Random::real(0,1);
			count position = ceil(log(random)/log(0.5) - 1);
			// set the bit in the bitmask
			if (position < lengthOfBitmask) {
				mPrev[v][j] = 1 << position;
			}
			// add the current bit to the maximum-bitmask
			localHighest[omp_get_thread_num()][j] |= mPrev[v][j];
		}
	});
	#pragma omp parallel for
	for (size_t i = 0; i < k; ++i) {
		count tmp = 0;
		for (ssize_t t = 0; t < omp_get_max_threads(); ++t) {
			tmp |= localHighest[t][i];
		}
		highestCount[i] = tmp;
	}

	std::vector<count> localEstimatesSum(omp_get_max_threads(), 0);
	std::vector<count> localSumRemoved(omp_get_max_threads(), 0);
	
	bool queued = true;
	while (queued) {
		queued = false;
		count tmp = 0;
		for (index i = 0; i < (count)omp_get_max_threads(); ++i) {
			tmp += localSumRemoved[i];
		}
		#pragma omp parallel for schedule(guided) 
		for (count v = 0; v < activeNodes.size(); ++v) {
			if (!activeNodes[v]) continue;
			index tid = (index)omp_get_thread_num();
			
			for (count j = 0; j < k; j++) {
				// and to all previous neighbors of all its neighbors
				G.forNeighborsOf(v, [&](node u) {
					mCurr[v][j] |= mPrev[u][j];
				});
			}
			// the least bit number in the bitmask of the current node/distance that has not been set
			double b = 0;
			for (count j = 0; j < k; j++) {
				for (count i = 0; i < lengthOfBitmask; i++) {
					if (((mCurr[v][j] >> i) & 1) == 0) {
						b += i;
						break;
					}
				}
			}
			// calculate the average least bit number that has not been set over all parallel approximations
			b = b / k;
			// calculate the estimated number of neighbors where 0.77351 is a correction factor and the result of a complex sum
			count estimatedConnectedNodes = (count)round(pow(2,b) / 0.77351);
			localEstimatesSum[tid] += estimatedConnectedNodes;
			//std::cout << "(" << v << ", " << estimatedConnectedNodes << ")\t";

			// check whether all k bitmask for this node have reached their highest possible value
			bool nodeFinished = true;
			for (count j = 0; j < k; j++) {
				if (mCurr[v][j] != highestCount[j]) {
					nodeFinished = false;
					break;
				}
			}
			// if the node wont change or is connected to enough nodes it must no longer be considered
			if (nodeFinished) {
				localSumRemoved[tid] += estimatedConnectedNodes;
				activeNodes[v] = 0;
			} else {
				queued = true;
			}
		}
		for (const auto& elem : localEstimatesSum) {
			tmp += elem;
		}
		result.push_back(tmp);
		localEstimatesSum.assign(omp_get_max_threads(), 0);
		mPrev = mCurr;
	}
	hasRun = true;
}

std::vector<count> NeighborhoodFunctionApproximation::getNeighborhoodFunction() const {
	if(!hasRun) {
		throw std::runtime_error("Call run()-function first.");
	}
	return result;
}


}
