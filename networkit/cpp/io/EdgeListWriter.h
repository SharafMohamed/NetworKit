/*
 * EdgeListWriter.h
 *
 *  Created on: 18.06.2013
 *      Author: cls
 */

#ifndef EDGELISTWRITER_H_
#define EDGELISTWRITER_H_

#include <fstream>
#include <iostream>
#include <string>

#include "GraphReader.h"

namespace NetworKit {

/**
 * @ingroup io
 * A writer for the edge list format. The output will contain one edge per line,
 * in the format fromNodeSEPARATORtoNode, where separator can be specified by
 * the user.
 *
 */
class EdgeListWriter {

public:

	EdgeListWriter() = default; //nullary constructor for Python shell

	/**
	 * @param[in]	separator	character used to separate nodes in an edge line
	 * @param[in]	firstNode	index of the first node in the file
	 */
	EdgeListWriter(char separator, node firstNode);

	/**
	 * Write the graph to a file.
	 * @param[in]	G		the graph
	 * @param[in]	path	the output file path
	 */
	void write(const Graph& G, std::string path);

protected:

	char separator; 	//!< character separating nodes in an edge line
	node firstNode;
};

} /* namespace NetworKit */
#endif /* EDGELISTIO_H_ */
