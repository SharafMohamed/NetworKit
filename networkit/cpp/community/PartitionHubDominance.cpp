/*
 *
 */

#include "PartitionHubDominance.h"
#include "../auxiliary/SignalHandling.h"
#include "../auxiliary/Parallel.h"
#include <atomic>

void NetworKit::PartitionHubDominance::run() {
	hasRun = false;

	Aux::SignalHandler handler;

	std::vector<std::atomic<count> > maxInternalDeg(P.upperBound());
	std::vector<count> clusterSizes(P.upperBound(), 0);

	handler.assureRunning();

	G.balancedParallelForNodes([&](node u) {
		index c = P[u];

		if (c != none) {
			count internalDeg = 0;
			G.forNeighborsOf(u, [&](node v) {
				if (P[v] == c) {
					internalDeg++;
				}
			});

			Aux::Parallel::atomic_max(maxInternalDeg[c], internalDeg);

			#pragma omp atomic update
			++clusterSizes[c];
		}
	});

	handler.assureRunning();

	count numClusters = 0;
	weightedAverage = 0;
	unweightedAverage = 0;
	maximumValue = std::numeric_limits<double>::lowest();
	minimumValue = std::numeric_limits<double>::max();
	values.clear();
	values.resize(P.upperBound(), 0);

	for (index i = 0; i < P.upperBound(); ++i) {
		if (clusterSizes[i] > 0) {
			++numClusters;

			double dominance = 1;
			if (clusterSizes[i] > 1) {
				dominance = maxInternalDeg[i] * 1.0 / (clusterSizes[i] - 1);
			}

			values[i] = dominance;
			unweightedAverage += dominance;
			weightedAverage = dominance * clusterSizes[i];

			maximumValue = std::max(dominance, maximumValue);
			minimumValue = std::min(dominance, minimumValue);
		}
	}

	handler.assureRunning();

	unweightedAverage /= numClusters;
	weightedAverage /= G.numberOfNodes();
	hasRun = true;
}
