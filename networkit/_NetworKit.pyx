
# cython: language_level=3

#includes
# needed for collections.Iterable
import collections
import math
import os


try:
	import pandas
except:
	print(""" WARNING: module 'pandas' not found, some functionality will be restricted """)


# C++ operators
from cython.operator import dereference, preincrement

# type imports
from libc.stdint cimport uint64_t
from libc.stdint cimport int64_t

# the C++ standard library
from libcpp cimport bool
from libcpp.vector cimport vector
from libcpp.utility cimport pair
from libcpp.map cimport map
from libcpp.set cimport set
from libcpp.stack cimport stack
from libcpp.string cimport string
from libcpp.unordered_set cimport unordered_set
from libcpp.unordered_map cimport unordered_map
from libcpp.algorithm cimport sort as stdsort

# NetworKit typedefs
ctypedef uint64_t count
ctypedef uint64_t index
ctypedef uint64_t edgeid
ctypedef index node
ctypedef index cluster
ctypedef double edgeweight

cdef extern from "cpp/Globals.h" namespace "NetworKit":
	index _none "NetworKit::none"

none = _none

cdef extern from "<algorithm>" namespace "std":
	void swap[T](T &a,  T &b)
	_Graph move( _Graph t ) nogil # specialized declaration as general declaration disables template argument deduction and doesn't work
	_Partition move( _Partition t) nogil
	_Cover move(_Cover t) nogil
	_Matching move(_Matching) nogil
	vector[double] move(vector[double])
	vector[bool] move(vector[bool])
	vector[count] move(vector[count])
	pair[_Graph, vector[node]] move(pair[_Graph, vector[node]]) nogil
	vector[pair[pair[node, node], double]] move(vector[pair[pair[node, node], double]]) nogil
	vector[pair[node, node]] move(vector[pair[node, node]]) nogil

cdef extern from "cpp/auxiliary/Parallel.h" namespace "Aux::Parallel":
	void sort[Iter](Iter begin, Iter end) nogil
	void sort[Iter, Comp](Iter begin, Iter end, Comp compare) nogil

cdef extern from "cython_helper.h":
	void throw_runtime_error(string message)

# Cython helper functions

def stdstring(pystring):
	""" convert a Python string to a bytes object which is automatically coerced to std::string"""
	pybytes = pystring.encode("utf-8")
	return pybytes

def pystring(stdstring):
	""" convert a std::string (= python byte string) to a normal Python string"""
	return stdstring.decode("utf-8")


cdef extern from "cpp/base/Algorithm.h":
	cdef cppclass _Algorithm "NetworKit::Algorithm":
		_Algorithm()
		void run() nogil except +
		bool hasFinished() except +
		string toString() except +
		bool isParallel() except +

cdef class Algorithm:
	""" Abstract base class for algorithms """
	cdef _Algorithm *_this

	def __init__(self, *args, **namedargs):
		if type(self) == Algorithm:
			raise RuntimeError("Error, you may not use Algorithm directly, use a sub-class instead")

	def __cinit__(self, *args, **namedargs):
		self._this = NULL

	def __dealloc__(self):
		if self._this != NULL:
			del self._this
		self._this = NULL

	def run(self):
		"""
		Executes the algorithm.

		Returns
		-------
		Algorithm:
			self
		"""
		if self._this == NULL:
			raise RuntimeError("Error, object not properly initialized")
		with nogil:
			self._this.run()
		return self

	def hasFinished(self):
		"""
		States whether an algorithm has already run.

		Returns
		-------
		Algorithm:
			self
		"""
		if self._this == NULL:
			raise RuntimeError("Error, object not properly initialized")
		return self._this.hasFinished()

	def toString(self):
		""" Get string representation.

		Returns
		-------
		string
			String representation of algorithm and parameters.
		"""
		if self._this == NULL:
			raise RuntimeError("Error, object not properly initialized")
		return self._this.toString().decode("utf-8")


	def isParallel(self):
		"""
		Returns
		-------
		bool
			True if algorithm can run multi-threaded
		"""
		if self._this == NULL:
			raise RuntimeError("Error, object not properly initialized")
		return self._this.isParallel()


# Function definitions

cdef extern from "cpp/auxiliary/Log.h" namespace "Aux":
	#void _configureLogging "Aux::configureLogging" (string loglevel)
	string _getLogLevel "Aux::Log::getLogLevel" () except +
	void _setLogLevel "Aux::Log::setLogLevel" (string loglevel) except +
	void _setPrintLocation "Aux::Log::Settings::setPrintLocation" (bool) except +

def getLogLevel():
	""" Get the current log level"""
	return pystring(_getLogLevel());

def setLogLevel(loglevel):
	""" Set the current loglevel"""
	_setLogLevel(stdstring(loglevel))

def setPrintLocation(flag):
	""" Switch locations in log statements on or off"""
	_setPrintLocation(flag)

cdef extern from "cpp/auxiliary/Parallelism.h" namespace "Aux":
	void _setNumberOfThreads "Aux::setNumberOfThreads" (int)
	int _getCurrentNumberOfThreads "Aux::getCurrentNumberOfThreads" ()
	int _getMaxNumberOfThreads "Aux::getMaxNumberOfThreads" ()
	void _enableNestedParallelism "Aux::enableNestedParallelism" ()

def setNumberOfThreads(nThreads):
	""" Set the number of OpenMP threads """
	_setNumberOfThreads(nThreads)

def getCurrentNumberOfThreads():
	""" Get the number of currently running threads"""
	return _getCurrentNumberOfThreads()

def getMaxNumberOfThreads():
	""" Get the maximum number of available threads"""
	return _getMaxNumberOfThreads()

def enableNestedParallelism():
	""" Enable nested parallelism for OpenMP"""
	_enableNestedParallelism()

cdef extern from "cpp/auxiliary/Random.h" namespace "Aux::Random":
	void _setSeed "Aux::Random::setSeed" (uint64_t, bool)

def setSeed(uint64_t seed, bool useThreadId):
	""" Set the random seed that is used in NetworKit.

	Note that there is a separate random number generator per thread.

	Parameters
	----------
	seed : uint64_t
		The seed
	useThreadId : bool
		If the thread id shall be added to the seed
	"""
	_setSeed(seed, useThreadId)

# Class definitions

## Module: engineering

# TODO: timer

## Module: graph

# DEPRECATED
# TODO: replace with std::pair<double>
cdef extern from "cpp/viz/Point.h" namespace "NetworKit":
	cdef cppclass Point[T]:
		Point()
		Point(T x, T y)
		T& operator[](const index i) except +
		T& at(const index i) except +

cdef extern from "cpp/graph/Graph.h":
	cdef cppclass _Graph "NetworKit::Graph":
		_Graph() except +
		_Graph(count, bool, bool) except +
		_Graph(const _Graph& other) except +
		_Graph(const _Graph& other, bool weighted, bool directed) except +
		void indexEdges(bool) except +
		bool hasEdgeIds() except +
		edgeid edgeId(node, node) except +
		count numberOfNodes() except +
		count numberOfEdges() except +
		pair[count, count] size() except +
		double density() except +
		index upperNodeIdBound() except +
		index upperEdgeIdBound() except +
		count degree(node u) except +
		count degreeIn(node u) except +
		count degreeOut(node u) except +
		double weightedDegree(node u) except +
		bool isIsolated(node u) except +
		_Graph copyNodes() except +
		node addNode() except +
		void removeNode(node u) except +
		bool hasNode(node u) except +
		void restoreNode(v) except +
		void append(_Graph) except +
		void merge(_Graph) except +
		void addEdge(node u, node v, edgeweight w) except +
		void setWeight(node u, node v, edgeweight w) except +
		void increaseWeight(node u, node v, edgeweight w) except +
		void removeEdge(node u, node v) except +
		void removeSelfLoops() except +
		void swapEdge(node s1, node t1, node s2, node t2) except +
		void compactEdges() except +
		void sortEdges() except +
		bool hasEdge(node u, node v) except +
		edgeweight weight(node u, node v) except +
		vector[node] nodes() except +
		vector[pair[node, node]] edges() except +
		vector[node] neighbors(node u) except +
		void forEdges[Callback](Callback c) except +
		void forNodes[Callback](Callback c) except +
		void forNodePairs[Callback](Callback c) except +
		void forNodesInRandomOrder[Callback](Callback c) except +
		void forEdgesOf[Callback](node u, Callback c) except +
		void forInEdgesOf[Callback](node u, Callback c) except +
		bool isWeighted() except +
		bool isDirected() except +
		string toString() except +
		string getName() except +
		void setName(string name) except +
		edgeweight totalEdgeWeight() except +
		node randomNode() except +
		node randomNeighbor(node) except +
		pair[node, node] randomEdge() except +
		Point[float] getCoordinate(node v) except +
		void setCoordinate(node v, Point[float] value) except +
		void initCoordinates() except +
		count numberOfSelfLoops() except +
		_Graph toUndirected() except +
		_Graph toUnweighted() except +
		_Graph transpose() except +
		void BFSfromNode "BFSfrom"[Callback] (node r, Callback c) except +
		void BFSfrom[Callback](vector[node] startNodes, Callback c) except +
		void BFSEdgesFrom[Callback](node r, Callback c) except +
		void DFSfrom[Callback](node r, Callback c) except +
		void DFSEdgesFrom[Callback](node r, Callback c) except +
		bool checkConsistency() except +
		_Graph subgraphFromNodes(unordered_set[node] nodes)  except +

cdef cppclass EdgeCallBackWrapper:
	void* callback
	__init__(object callback):
		this.callback = <void*>callback
	void cython_call_operator(node u, node v, edgeweight w, edgeid eid):
		cdef bool error = False
		cdef string message
		try:
			(<object>callback)(u, v, w, eid)
		except Exception as e:
			error = True
			message = stdstring("An Exception occurred, aborting execution of iterator: {0}".format(e))
		if (error):
			throw_runtime_error(message)

cdef cppclass NodeCallbackWrapper:
	void* callback
	__init__(object callback):
		this.callback = <void*>callback
	void cython_call_operator(node u):
		cdef bool error = False
		cdef string message
		try:
			(<object>callback)(u)
		except Exception as e:
			error = True
			message = stdstring("An Exception occurred, aborting execution of iterator: {0}".format(e))
		if (error):
			throw_runtime_error(message)

cdef cppclass NodeDistCallbackWrapper:
	void* callback
	__init__(object callback):
		this.callback = <void*>callback
	void cython_call_operator(node u, count dist):
		cdef bool error = False
		cdef string message
		try:
			(<object>callback)(u, dist)
		except Exception as e:
			error = True
			message = stdstring("An Exception occurred, aborting execution of iterator: {0}".format(e))
		if (error):
			throw_runtime_error(message)

cdef cppclass NodePairCallbackWrapper:
	void* callback
	__init__(object callback):
		this.callback = <void*>callback
	void cython_call_operator(node u, node v):
		cdef bool error = False
		cdef string message
		try:
			(<object>callback)(u, v)
		except Exception as e:
			error = True
			message = stdstring("An Exception occurred, aborting execution of iterator: {0}".format(e))
		if (error):
			throw_runtime_error(message)

cdef class Graph:
	""" An undirected graph (with optional weights) and parallel iterator methods.

		Graph(n=0, weighted=False, directed=False)

		Create a graph of `n` nodes. The graph has assignable edge weights if `weighted` is set to True.
	 	If `weighted` is set to False each edge has edge weight 1.0 and any other weight assignment will
	 	be ignored.

	    Parameters
	    ----------
	    n : count, optional
	    	Number of nodes.
	    weighted : bool, optional
	    	If set to True, the graph can have edge weights other than 1.0.
	    directed : bool, optional
	    	If set to True, the graph will be directed.
	"""
	cdef _Graph _this

	def __cinit__(self, n=0, bool weighted=False, bool directed=False):
		if isinstance(n, Graph):
			self._this = move(_Graph((<Graph>n)._this, weighted, directed))
		else:
			self._this = move(_Graph(<count>n, weighted, directed))

	cdef setThis(self, _Graph& other):
		swap[_Graph](self._this, other)
		return self

	def __copy__(self):
		"""
		Generates a copy of the graph
		"""
		return Graph().setThis(_Graph(self._this))

	def __deepcopy__(self, memo):
		"""
		Generates a (deep) copy of the graph
		"""
		return Graph().setThis(_Graph(self._this))

	def __str__(self):
		return "NetworKit.Graph(name={0}, n={1}, m={2})".format(self.getName(), self.numberOfNodes(), self.numberOfEdges())


	def copyNodes(self):
		"""
		Copies all nodes to a new graph

		Returns
		-------
		Graph
			Graph with the same nodes (without edges)
		"""
		return Graph().setThis(self._this.copyNodes())

	def indexEdges(self, bool force = False):
		"""
		Assign integer ids to edges.

		Parameters
		----------
		force : bool
			Force re-indexing of edges.

		"""
		self._this.indexEdges(force)

	def hasEdgeIds(self):
		"""
		Returns true if edges have been indexed

		Returns
		-------
		bool
			if edges have been indexed
		"""
		return self._this.hasEdgeIds()

	def edgeId(self, node u, node v):
		"""
		Returns
		-------
		edgeid
			id of the edge
		"""
		return self._this.edgeId(u, v)

	def numberOfNodes(self):
		"""
		Get the number of nodes in the graph.

	 	Returns
	 	-------
	 	count
	 		The number of nodes.
		"""
		return self._this.numberOfNodes()

	def numberOfEdges(self):
		"""
		Get the number of edges in the graph.

	 	Returns
	 	-------
	 	count
	 		The number of edges.
		"""
		return self._this.numberOfEdges()

	def size(self):
		"""
		Get the size of the graph.

	 	Returns
	 	-------
	 	tuple
	 		a pair (n, m) where n is the number of nodes and m is the number of edges
		"""
		return self._this.size()


	def density(self):
		"""
		Get the density of the graph.

	 	Returns
	 	-------
	 	double
		"""
		return self._this.density()

	def upperNodeIdBound(self):
		"""
		Get an upper bound for the node ids in the graph

		Returns
		-------
		count
			An upper bound for the node ids in the graph
		"""
		return self._this.upperNodeIdBound()

	def upperEdgeIdBound(self):
		"""
		Get an upper bound for the edge ids in the graph

		Returns
		-------
		count
			An upper bound for the edge ids in the graph
		"""
		return self._this.upperEdgeIdBound()

	def degree(self, u):
		"""
		Get the number of neighbors of `v`.

		Parameters
		----------
		v : node
			Node.

		Returns
		-------
		count
			The number of neighbors.
		"""
		return self._this.degree(u)

	def degreeIn(self, u):
		return self._this.degreeIn(u)

	def degreeOut(self, u):
		return self._this.degreeOut(u)

	def weightedDegree(self, v):
		"""
		Returns the weighted degree of v.

		For directed graphs this is the sum of weights of all outgoing edges of v.

		Parameters
		----------
		v : node
			Node.

		Returns
		-------
		double
			The weighted degree of v.
		"""
		return self._this.weightedDegree(v)

	def isIsolated(self, u):
		"""
		If the node `u` is isolated

		Parameters
		----------
		u : node
			Node.

		Returns
		-------
		bool
			If the node is isolated
		"""
		return self._this.isIsolated(u)

	def addNode(self):
		""" Add a new node to the graph and return it.

		Returns
		-------
		node
			The new node.
	 	"""
		return self._this.addNode()

	def removeNode(self, u):
		""" Remove the isolated node `u` from the graph.

	 	Parameters
	 	----------
	 	u : node
	 		Node.

	 	Notes
	 	-----
	 	Although it would be convenient to remove all incident edges at the same time, this causes complications for
	 	dynamic applications. Therefore, removeNode is an atomic event. All incident edges need to be removed first
	 	and an exception is thrown otherwise.
		"""
		self._this.removeNode(u)

	def hasNode(self, u):
		""" Checks if the Graph has the node `u`, i.e. if `u` hasn't been deleted and is in the range of valid ids.

		Parameters
		----------
		u : node
			Node

		Returns
		-------
		bool
			If the Graph has the node `u`
		"""
		return self._this.hasNode(u)

	def append(self, Graph G):
		""" Appends another graph to this graph as a new subgraph. Performs node id remapping.

		Parameters
		----------
		G : Graph
		"""
		self._this.append(G._this)
		return self

	def merge(self, Graph G):
		""" Modifies this graph to be the union of it and another graph.
			Nodes with the same ids are identified with each other.

		Parameters
		----------
		G : Graph
		"""
		self._this.merge(G._this)
		return self

	def addEdge(self, u, v, w=1.0):
		""" Insert an undirected edge between the nodes `u` and `v`. If the graph is weighted you can optionally
	 	set a weight for this edge. The default weight is 1.0.

	 	Parameters
	 	----------
	 	u : node
	 		Endpoint of edge.
 		v : node
 			Endpoint of edge.
		w : edgeweight, optional
			Edge weight.
		"""
		self._this.addEdge(u, v, w)
		return self

	def setWeight(self, u, v, w):
		""" Set the weight of an edge. If the edge does not exist, it will be inserted.

		Parameters
		----------
		u : node
			Endpoint of edge.
		v : node
			Endpoint of edge.
		w : edgeweight
			Edge weight.
		"""
		self._this.setWeight(u, v, w)
		return self

	def increaseWeight(self, u, v, w):
		""" Increase the weight of an edge. If the edge does not exist, it will be inserted.

		Parameters
		----------
		u : node
			Endpoint of edge.
		v : node
			Endpoint of edge.
		w : edgeweight
			Edge weight.
		"""
		self._this.increaseWeight(u, v, w)
		return self

	def removeEdge(self, u, v):
		""" Removes the undirected edge {`u`,`v`}.

		Parameters
		----------
		u : node
			Endpoint of edge.
		v : node
			Endpoint of edge.
		"""
		self._this.removeEdge(u, v)
		return self

	def removeSelfLoops(self):
		""" Removes all self-loops from the graph.
		"""
		self._this.removeSelfLoops()

	def swapEdge(self, node s1, node t1, node s2, node t2):
		"""
		Changes the edge (s1, t1) into (s1, t2) and the edge (s2, t2) into (s2, t1).

		If there are edge weights or edge ids, they are preserved. Note that no check is performed if the swap is actually possible, i.e. does not generate duplicate edges.

		Parameters
		----------
		s1 : node
			Source node of the first edge
		t1 : node
			Target node of the first edge
		s2 : node
			Source node of the second edge
		t2 : node
			Target node of the second edge
		"""
		self._this.swapEdge(s1, t1, s2, t2)
		return self

	def compactEdges(self):
		"""
		Compact the edge storage, this should be called after executing many edge deletions.
		"""
		self._this.compactEdges()

	def sortEdges(self):
		"""
		Sorts the adjacency arrays by node id. While the running time is linear this
		temporarily duplicates the memory.
		"""
		self._this.sortEdges()

	def hasEdge(self, u, v):
		""" Checks if undirected edge {`u`,`v`} exists in the graph.

		Parameters
		----------
		u : node
			Endpoint of edge.
		v : node
			Endpoint of edge.

		Returns
		-------
		bool
			True if the edge exists, False otherwise.
		"""
		return self._this.hasEdge(u, v)

	def weight(self, u, v):
		""" Get edge weight of edge {`u` , `v`}. Returns 0 if edge does not exist.

		Parameters
		----------
		u : node
			Endpoint of edge.
		v : node
			Endpoint of edge.

		Returns
		-------
		edgeweight
			Edge weight of edge {`u` , `v`} or 0 if edge does not exist.
		"""
		return self._this.weight(u, v)

	def nodes(self):
		""" Get list of all nodes.

	 	Returns
	 	-------
	 	list
	 		List of all nodes.
		"""
		return self._this.nodes()

	def edges(self):
		""" Get list of edges as node pairs.

	 	Returns
	 	-------
	 	list
	 		List of edges as node pairs.
		"""
		return self._this.edges()

	def neighbors(self, u):
		""" Get list of neighbors of `u`.

	 	Parameters
	 	----------
	 	u : node
	 		Node.

	 	Returns
	 	-------
	 	list
	 		List of neighbors of `u.
		"""
		return self._this.neighbors(u)

	def forNodes(self, object callback):
		""" Experimental node iterator interface

		Parameters
		----------
		callback : object
			Any callable object that takes the parameter node
		"""
		cdef NodeCallbackWrapper* wrapper
		try:
			wrapper = new NodeCallbackWrapper(callback)
			self._this.forNodes[NodeCallbackWrapper](dereference(wrapper))
		finally:
			del wrapper

	def forNodesInRandomOrder(self, object callback):
		""" Experimental node iterator interface

		Parameters
		----------
		callback : object
			Any callable object that takes the parameter node
		"""
		cdef NodeCallbackWrapper* wrapper
		try:
			wrapper = new NodeCallbackWrapper(callback)
			self._this.forNodesInRandomOrder[NodeCallbackWrapper](dereference(wrapper))
		finally:
			del wrapper

	def forNodePairs(self, object callback):
		""" Experimental node pair iterator interface

		Parameters
		----------
		callback : object
			Any callable object that takes the parameters (node, node)
		"""
		cdef NodePairCallbackWrapper* wrapper
		try:
			wrapper = new NodePairCallbackWrapper(callback)
			self._this.forNodePairs[NodePairCallbackWrapper](dereference(wrapper))
		finally:
			del wrapper

	def forEdges(self, object callback):
		""" Experimental edge iterator interface

		Parameters
		----------
		callback : object
			Any callable object that takes the parameter (node, node, edgeweight, edgeid)
		"""
		cdef EdgeCallBackWrapper* wrapper
		try:
			wrapper = new EdgeCallBackWrapper(callback)
			self._this.forEdges[EdgeCallBackWrapper](dereference(wrapper))
		finally:
			del wrapper

	def forEdgesOf(self, node u, object callback):
		""" Experimental incident (outgoing) edge iterator interface

		Parameters
		----------
		u : node
			The node of which incident edges shall be passed to the callback
		callback : object
			Any callable object that takes the parameter (node, node, edgeweight, edgeid)
		"""
		cdef EdgeCallBackWrapper* wrapper
		try:
			wrapper = new EdgeCallBackWrapper(callback)
			self._this.forEdgesOf[EdgeCallBackWrapper](u, dereference(wrapper))
		finally:
			del wrapper

	def forInEdgesOf(self, node u, object callback):
		""" Experimental incident incoming edge iterator interface

		Parameters
		----------
		u : node
			The node of which incident edges shall be passed to the callback
		callback : object
			Any callable object that takes the parameter (node, node, edgeweight, edgeid)
		"""
		cdef EdgeCallBackWrapper* wrapper
		try:
			wrapper = new EdgeCallBackWrapper(callback)
			self._this.forInEdgesOf[EdgeCallBackWrapper](u, dereference(wrapper))
		finally:
			del wrapper

	def toUndirected(self):
		"""
		Return an undirected version of this graph.

	 	Returns
	 	-------
			undirected graph.
		"""
		return Graph().setThis(self._this.toUndirected())


	def toUnweighted(self):
		"""
		Return an unweighted version of this graph.

	 	Returns
	 	-------
			graph.
		"""
		return Graph().setThis(self._this.toUnweighted())

	def transpose(self):
		"""
		Return the transpose of this (directed) graph.

		Returns
		-------
			directed graph.
		"""
		return Graph().setThis(self._this.transpose())

	def isWeighted(self):
		"""
		Returns
		-------
		bool
			True if this graph supports edge weights other than 1.0.
		"""
		return self._this.isWeighted()

	def isDirected(self):
		return self._this.isDirected()

	def toString(self):
		""" Get a string representation of the graph.

		Returns
		-------
		string
			A string representation of the graph.
		"""
		return self._this.toString()

	def getName(self):
		""" Get the name of the graph.

		Returns
		-------
		string
			The name of the graph.
		"""
		return pystring(self._this.getName())

	def setName(self, name):
		""" Set name of graph to `name`.

		Parameters
		----------
		name : string
			The name.
		"""
		self._this.setName(stdstring(name))

	def totalEdgeWeight(self):
		""" Get the sum of all edge weights.

		Returns
		-------
		edgeweight
			The sum of all edge weights.
		"""
		return self._this.totalEdgeWeight()

	def randomNode(self):
		""" Get a random node of the graph.

		Returns
		-------
		node
			A random node.
		"""
		return self._this.randomNode()

	def randomNeighbor(self, u):
		""" Get a random neighbor of `v` and `none` if degree is zero.

		Parameters
		----------
		v : node
			Node.

		Returns
		-------
		node
			A random neighbor of `v.
		"""
		return self._this.randomNeighbor(u)

	def randomEdge(self):
		""" Get a random edge of the graph.

		Returns
		-------
		pair
			Random random edge.

		Notes
		-----
		Fast, but not uniformly random.
		"""
		return self._this.randomEdge()

	def getCoordinate(self, v):
		"""
		DEPRECATED: Coordinates should be handled outside the Graph class
		 like general node attributes.

		Get the coordinates of node v.
		Parameters
		----------
		v : node
			Node.

		Returns
		-------
		pair[float, float]
			x and y coordinates of v.
		"""

		return (self._this.getCoordinate(v)[0], self._this.getCoordinate(v)[1])

	def setCoordinate(self, v, value):
		"""
		DEPRECATED: Coordinates should be handled outside the Graph class
		 like general node attributes.

		Set the coordinates of node v.
		Parameters
		----------
		v : node
			Node.
		value : pair[float, float]
			x and y coordinates of v.
		"""
		cdef Point[float] p = Point[float](value[0], value[1])
		self._this.setCoordinate(v, p)

	def initCoordinates(self):
		"""
		DEPRECATED: Coordinates should be handled outside the Graph class
		 like general node attributes.
		"""
		self._this.initCoordinates()

	def numberOfSelfLoops(self):
		""" Get number of self-loops, i.e. edges {v, v}.
		Returns
		-------
		count
			number of self-loops.
		"""
		return self._this.numberOfSelfLoops()

	def BFSfrom(self, start, object callback):
		""" Experimental BFS search interface

		Parameters
		----------
		start: node or list[node]
			One or more start nodes from which the BFS shall be started
		callback : object
			Any callable object that takes the parameter (node, count) (the second parameter is the depth)
		"""
		cdef NodeDistCallbackWrapper *wrapper
		try:
			wrapper = new NodeDistCallbackWrapper(callback)
			try:
				self._this.BFSfromNode[NodeDistCallbackWrapper](<node?>start, dereference(wrapper))
			except TypeError:
				self._this.BFSfrom[NodeDistCallbackWrapper](<vector[node]?>start, dereference(wrapper))
		finally:
			del wrapper

	def BFSEdgesFrom(self, node start, object callback):
		""" Experimental BFS search interface that passes edges that are part of the BFS tree to the callback

		Parameters
		----------
		start: node
			The start node from which the BFS shall be started
		callback : object
			Any callable object that takes the parameter (node, node)
		"""
		cdef EdgeCallBackWrapper *wrapper
		try:
			wrapper = new EdgeCallBackWrapper(callback)
			self._this.BFSEdgesFrom[EdgeCallBackWrapper](start, dereference(wrapper))
		finally:
			del wrapper

	def DFSfrom(self, node start, object callback):
		""" Experimental DFS search interface

		Parameters
		----------
		start: node
			The start node from which the DFS shall be started
		callback : object
			Any callable object that takes the parameter node
		"""
		cdef NodeCallbackWrapper *wrapper
		try:
			wrapper = new NodeCallbackWrapper(callback)
			self._this.DFSfrom[NodeCallbackWrapper](start, dereference(wrapper))
		finally:
			del wrapper

	def DFSEdgesFrom(self, node start, object callback):
		""" Experimental DFS search interface that passes edges that are part of the DFS tree to the callback

		Parameters
		----------
		start: node
			The start node from which the DFS shall be started
		callback : object
			Any callable object that takes the parameter (node, node)
		"""
		cdef NodePairCallbackWrapper *wrapper
		try:
			wrapper = new NodePairCallbackWrapper(callback)
			self._this.DFSEdgesFrom(start, dereference(wrapper))
		finally:
			del wrapper

	def checkConsistency(self):
		"""
		Check for invalid graph states, such as multi-edges.
		"""
		return self._this.checkConsistency()


	def subgraphFromNodes(self, nodes):
		""" Create a subgraph induced by the set `nodes`.

		Parameters
		----------
		nodes : list
			A subset of nodes of `G` which induce the subgraph.

		Returns
		-------
		Graph
			The subgraph induced by `nodes`.

		Notes
		-----
		The returned graph G' is isomorphic (structurally identical) to the subgraph in G,
		but node indices are not preserved.
		"""
		cdef unordered_set[node] nnodes
		for node in nodes:
			nnodes.insert(node);
		return Graph().setThis(self._this.subgraphFromNodes(nnodes))

# TODO: expose all methods

cdef extern from "cpp/graph/SSSP.h":
	cdef cppclass _SSSP "NetworKit::SSSP"(_Algorithm):
		_SSSP(_Graph G, node source, bool storePaths, bool storeStack, node target) except +
		void run() nogil except +
		vector[edgeweight] getDistances(bool moveOut) except +
		edgeweight distance(node t) except +
		vector[node] getPredecessors(node t) except +
		vector[node] getPath(node t, bool forward) except +
		set[vector[node]] getPaths(node t, bool forward) except +
		vector[node] getStack(bool moveOut) except +
		double _numberOfPaths(node t) except +

cdef class SSSP(Algorithm):
	""" Base class for single source shortest path algorithms. """

	cdef Graph _G

	def __init__(self, *args, **namedargs):
		if type(self) == SSSP:
			raise RuntimeError("Error, you may not use SSSP directly, use a sub-class instead")

	def __dealloc__(self):
		self._G = None # just to be sure the graph is deleted

	def getDistances(self, moveOut=True):
		"""
		Returns a vector of weighted distances from the source node, i.e. the
 	 	length of the shortest path from the source node to any other node.

 	 	Returns
 	 	-------
 	 	vector
 	 		The weighted distances from the source node to any other node in the graph.
		"""
		return (<_SSSP*>(self._this)).getDistances(moveOut)

	def distance(self, t):
		return (<_SSSP*>(self._this)).distance(t)

	def getPredecessors(self, t):
		return (<_SSSP*>(self._this)).getPredecessors(t)

	def getPath(self, t, forward=True):
		""" Returns a shortest path from source to `t` and an empty path if source and `t` are not connected.

		Parameters
		----------
		t : node
			Target node.

		Returns
		-------
		vector
			A shortest path from source to `t or an empty path.
		"""
		return (<_SSSP*>(self._this)).getPath(t, forward)

	def getPaths(self, t, forward=True):
		cdef set[vector[node]] paths = (<_SSSP*>(self._this)).getPaths(t, forward)
		result = []
		for elem in paths:
			result.append(list(elem))
		return result

	def getStack(self, moveOut=True):
		return (<_SSSP*>(self._this)).getStack(moveOut)

	def numberOfPaths(self, t):
		return (<_SSSP*>(self._this))._numberOfPaths(t)

cdef extern from "cpp/graph/DynSSSP.h":
	cdef cppclass _DynSSSP "NetworKit::DynSSSP"(_SSSP):
		_DynSSSP(_Graph G, node source, bool storePaths, bool storeStack, node target) except +
		void update(vector[_GraphEvent] batch) except +
		bool modified() except +
		void setTargetNode(node t) except +

cdef class DynSSSP(SSSP):
	""" Base class for single source shortest path algorithms in dynamic graphs. """
	def __init__(self, *args, **namedargs):
		if type(self) == SSSP:
			raise RuntimeError("Error, you may not use DynSSSP directly, use a sub-class instead")

	""" Updates shortest paths with the batch `batch` of edge insertions.

		Parameters
		----------
		batch : list of GraphEvent.
		"""
	def update(self, batch):
		cdef vector[_GraphEvent] _batch
		for ev in batch:
			_batch.push_back(_GraphEvent(ev.type, ev.u, ev.v, ev.w))
		(<_DynSSSP*>(self._this)).update(_batch)

	def modified(self):
		return (<_DynSSSP*>(self._this)).modified()

	def setTargetNode(self, t):
		(<_DynSSSP*>(self._this)).setTargetNode(t)


cdef extern from "cpp/graph/BFS.h":
	cdef cppclass _BFS "NetworKit::BFS"(_SSSP):
		_BFS(_Graph G, node source, bool storePaths, bool storeStack, node target) except +

cdef class BFS(SSSP):
	""" Simple breadth-first search on a Graph from a given source

	BFS(G, source, [storePaths], [storeStack], target)

	Create BFS for `G` and source node `source`.

	Parameters
	----------
	G : Graph
		The graph.
	source : node
		The source node of the breadth-first search.
	storePaths : bool
		store paths and number of paths?
	target: node
		terminate search when the target has been reached
	"""

	def __cinit__(self, Graph G, source, storePaths=True, storeStack=False, target=none):
		self._G = G
		self._this = new _BFS(G._this, source, storePaths, storeStack, target)

cdef extern from "cpp/graph/DynBFS.h":
	cdef cppclass _DynBFS "NetworKit::DynBFS"(_DynSSSP):
		_DynBFS(_Graph G, node source) except +

cdef class DynBFS(DynSSSP):
	""" Dynamic version of BFS.

	DynBFS(G, source)

	Create DynBFS for `G` and source node `source`.

	Parameters
	----------
	G : Graph
		The graph.
	source : node
		The source node of the breadth-first search.
	storeStack : bool
		maintain a stack of nodes in order of decreasing distance?
	"""
	def __cinit__(self, Graph G, source):
		self._G = G
		self._this = new _DynBFS(G._this, source)


cdef extern from "cpp/graph/Dijkstra.h":
	cdef cppclass _Dijkstra "NetworKit::Dijkstra"(_SSSP):
		_Dijkstra(_Graph G, node source, bool storePaths, bool storeStack, node target) except +

cdef class Dijkstra(SSSP):
	""" Dijkstra's SSSP algorithm.
	Returns list of weighted distances from node source, i.e. the length of the shortest path from source to
	any other node.

    Dijkstra(G, source, [storePaths], [storeStack], target)

    Creates Dijkstra for `G` and source node `source`.

    Parameters
	----------
	G : Graph
		The graph.
	source : node
		The source node.
	storePaths : bool
		store paths and number of paths?
	storeStack : bool
		maintain a stack of nodes in order of decreasing distance?
	target : node
		target node. Search ends when target node is reached. t is set to None by default.
    """
	def __cinit__(self, Graph G, source, storePaths=True, storeStack=False, node target=none):
		self._G = G
		self._this = new _Dijkstra(G._this, source, storePaths, storeStack, target)

cdef extern from "cpp/graph/DynDijkstra.h":
	cdef cppclass _DynDijkstra "NetworKit::DynDijkstra"(_DynSSSP):
		_DynDijkstra(_Graph G, node source) except +

cdef class DynDijkstra(DynSSSP):
	""" Dynamic version of Dijkstra.

	DynDijkstra(G, source)

	Create DynDijkstra for `G` and source node `source`.

	Parameters
	----------
	G : Graph
		The graph.
	source : node
		The source node of the breadth-first search.

	"""
	def __cinit__(self, Graph G, source):
		self._G = G
		self._this = new _DynDijkstra(G._this, source)


cdef extern from "cpp/graph/APSP.h":
	cdef cppclass _APSP "NetworKit::APSP"(_Algorithm):
		_APSP(_Graph G) except +
		vector[vector[edgeweight]] getDistances() except +
		edgeweight getDistance(node u, node v) except +

cdef class APSP(Algorithm):
	""" All-Pairs Shortest-Paths algorithm (implemented running Dijkstra's algorithm from each node, or BFS if G is unweighted).

    APSP(G)

    Computes all pairwise shortest-path distances in G.

    Parameters
	----------
	G : Graph
		The graph.
    """
	cdef Graph _G

	def __cinit__(self, Graph G):
		self._G = G
		self._this = new _APSP(G._this)

	def __dealloc__(self):
		self._G = None

	def getDistances(self):
		""" Returns a vector of vectors of distances between each node pair.

 	 	Returns
 	 	-------
 	 	vector of vectors
 	 		The shortest-path distances from each node to any other node in the graph.
		"""
		return (<_APSP*>(self._this)).getDistances()

	def getDistance(self, node u, node v):
		""" Returns the length of the shortest path from source 'u' to target `v`.

		Parameters
		----------
		u : node
			Source node.
		v : node
			Target node.

		Returns
		-------
		int or float
			The distance from 'u' to 'v'.
		"""
		return (<_APSP*>(self._this)).getDistance(u, v)



cdef extern from "cpp/graph/SpanningForest.h":
	cdef cppclass _SpanningForest "NetworKit::SpanningForest":
		_SpanningForest(_Graph) except +
		_Graph generate() except +

cdef class SpanningForest:
	""" Generates a spanning forest for a given graph

		Parameters
		----------
		G : Graph
			The graph.
		nodes : list
			A subset of nodes of `G` which induce the subgraph.
	"""
	cdef _SpanningForest* _this
	cdef Graph _G

	def __cinit__(self, Graph G not None):
		self._G = G
		self._this = new _SpanningForest(G._this)


	def __dealloc__(self):
		del self._this

	def generate(self):
		return Graph().setThis(self._this.generate());

cdef extern from "cpp/graph/UnionMaximumSpanningForest.h":
	cdef cppclass _UnionMaximumSpanningForest "NetworKit::UnionMaximumSpanningForest"(_Algorithm):
		_UnionMaximumSpanningForest(_Graph) except +
		_UnionMaximumSpanningForest(_Graph, vector[double]) except +
		_Graph getUMSF(bool move) except +
		vector[bool] getAttribute(bool move) except +
		bool inUMSF(edgeid eid) except +
		bool inUMSF(node u, node v) except +

cdef class UnionMaximumSpanningForest(Algorithm):
	"""
	Union maximum-weight spanning forest algorithm, computes the union of all maximum-weight spanning forests using Kruskal's algorithm.

	Parameters
	----------
	G : Graph
		The input graph.
	attribute : list
		If given, this edge attribute is used instead of the edge weights.
	"""
	cdef Graph _G

	def __cinit__(self, Graph G not None, vector[double] attribute = vector[double]()):
		self._G = G

		if attribute.empty():
			self._this = new _UnionMaximumSpanningForest(G._this)
		else:
			self._this = new _UnionMaximumSpanningForest(G._this, attribute)

	def getUMSF(self, bool move = False):
		"""
		Gets the union of all maximum-weight spanning forests as graph.

		Parameters
		----------
		move : boolean
			If the graph shall be moved out of the algorithm instance.

		Returns
		-------
		Graph
			The calculated union of all maximum-weight spanning forests.
		"""
		return Graph().setThis((<_UnionMaximumSpanningForest*>(self._this)).getUMSF(move))

	def getAttribute(self, bool move = False):
		"""
		Get a boolean attribute that indicates for each edge if it is part of any maximum-weight spanning forest.

		This attribute is only calculated and can thus only be request if the supplied graph has edge ids.

		Parameters
		----------
		move : boolean
			If the attribute shall be moved out of the algorithm instance.

		Returns
		-------
		list
			The list with the boolean attribute for each edge.
		"""
		return (<_UnionMaximumSpanningForest*>(self._this)).getAttribute(move)

	def inUMST(self, node u, node v = _none):
		"""
		Checks if the edge (u, v) or the edge with id u is part of any maximum-weight spanning forest.

		Parameters
		----------
		u : node or edgeid
			The first node of the edge to check or the edge id of the edge to check
		v : node
			The second node of the edge to check (only if u is not an edge id)

		Returns
		-------
		boolean
			If the edge is part of any maximum-weight spanning forest.
		"""
		if v == _none:
			return (<_UnionMaximumSpanningForest*>(self._this)).inUMSF(u)
		else:
			return (<_UnionMaximumSpanningForest*>(self._this)).inUMSF(u, v)

cdef extern from "cpp/graph/RandomMaximumSpanningForest.h":
	cdef cppclass _RandomMaximumSpanningForest "NetworKit::RandomMaximumSpanningForest"(_Algorithm):
		_RandomMaximumSpanningForest(_Graph) except +
		_RandomMaximumSpanningForest(_Graph, vector[double]) except +
		void run() except +
		_Graph getMSF(bool move) except +
		vector[bool] getAttribute(bool move) except +
		bool inMSF(edgeid eid) except +
		bool inMSF(node u, node v) except +

cdef class RandomMaximumSpanningForest(Algorithm):
	"""
	Computes a random maximum-weight spanning forest using Kruskal's algorithm by randomizing the order of edges of the same weight.

	Parameters
	----------
	G : Graph
		The input graph.
	attribute : list
		If given, this edge attribute is used instead of the edge weights.
	"""
	cdef vector[double] _attribute
	cdef Graph _G

	def __cinit__(self, Graph G not None, vector[double] attribute = vector[double]()):
		self._G = G
		if attribute.empty():
			self._this = new _RandomMaximumSpanningForest(G._this)
		else:
			self._attribute = move(attribute)
			self._this = new _RandomMaximumSpanningForest(G._this, self._attribute)

	def getMSF(self, bool move = False):
		"""
		Gets the calculated maximum-weight spanning forest as graph.

		Parameters
		----------
		move : boolean
			If the graph shall be moved out of the algorithm instance.

		Returns
		-------
		Graph
			The calculated maximum-weight spanning forest.
		"""
		return Graph().setThis((<_RandomMaximumSpanningForest*>(self._this)).getMSF(move))

	def getAttribute(self, bool move = False):
		"""
		Get a boolean attribute that indicates for each edge if it is part of the calculated maximum-weight spanning forest.

		This attribute is only calculated and can thus only be request if the supplied graph has edge ids.

		Parameters
		----------
		move : boolean
			If the attribute shall be moved out of the algorithm instance.

		Returns
		-------
		list
			The list with the boolean attribute for each edge.
		"""
		return (<_RandomMaximumSpanningForest*>(self._this)).getAttribute(move)

	def inMSF(self, node u, node v = _none):
		"""
		Checks if the edge (u, v) or the edge with id u is part of the calculated maximum-weight spanning forest.

		Parameters
		----------
		u : node or edgeid
			The first node of the edge to check or the edge id of the edge to check
		v : node
			The second node of the edge to check (only if u is not an edge id)

		Returns
		-------
		boolean
			If the edge is part of the calculated maximum-weight spanning forest.
		"""
		if v == _none:
			return (<_RandomMaximumSpanningForest*>(self._this)).inMSF(u)
		else:
			return (<_RandomMaximumSpanningForest*>(self._this)).inMSF(u, v)


cdef extern from "cpp/independentset/Luby.h":
	cdef cppclass _Luby "NetworKit::Luby":
		_Luby() except +
		vector[bool] run(_Graph G) except +
		string toString()


# FIXME: check correctness
cdef class Luby:
	""" Luby's parallel maximal independent set algorithm"""
	cdef _Luby _this

	def run(self, Graph G not None):
		""" Returns a boolean vector of length n where vec[v] is True iff v is in the independent sets.

		Parameters
		----------
		G : Graph
			The graph.

		Returns
		-------
		vector
			A boolean vector of length n.
		"""
		return self._this.run(G._this)
		# TODO: return self

	def toString(self):
		""" Get string representation of the algorithm.

		Returns
		-------
		string
			The string representation of the algorithm.
		"""
		return self._this.toString().decode("utf-8")


# Module: generators



cdef extern from "cpp/generators/BarabasiAlbertGenerator.h":
	cdef cppclass _BarabasiAlbertGenerator "NetworKit::BarabasiAlbertGenerator":
		_BarabasiAlbertGenerator() except +
		_BarabasiAlbertGenerator(count k, count nMax, count n0, bool batagelj) except +
		_BarabasiAlbertGenerator(count k, count nMax, const _Graph & initGraph, bool batagelj) except +
		_Graph generate() except +

cdef class BarabasiAlbertGenerator:
	"""
	This generator implements the preferential attachment model as introduced by Barabasi and Albert[1].
	The original algorithm is very slow and thus, the much faster method from Batagelj and Brandes[2] is
	implemented and the current default.
	The original method can be chosen by setting \p batagelj to false.
	[1] Barabasi, Albert: Emergence of Scaling in Random Networks http://arxiv.org/pdf/cond-mat/9910332.pdf
	[2] ALG 5 of Batagelj, Brandes: Efficient Generation of Large Random Networks https://kops.uni-konstanz.de/bitstream/handle/123456789/5799/random.pdf?sequence=1

	Parameters
	----------
	k : count
		number of edges that come with a new node
	nMax : count
		maximum number of nodes produced
	n0 : count
		number of starting nodes
	batagelj : bool
		Specifies whether to use batagelj's method or the original one.
	"""
	cdef _BarabasiAlbertGenerator _this

	def __cinit__(self, count k, count nMax, n0=0, bool batagelj=True):
		if isinstance(n0, Graph):
			self._this = _BarabasiAlbertGenerator(k, nMax, (<Graph>n0)._this, batagelj)
		else:
			self._this = _BarabasiAlbertGenerator(k, nMax, <count>n0, batagelj)

	def generate(self):
		return Graph().setThis(self._this.generate())

	@classmethod
	def fit(cls, Graph G, scale=1):
		(n, m) = G.size()
		k = math.floor(m / n)
		return cls(nMax=scale * n, k=k, n0=k)


cdef extern from "cpp/generators/PubWebGenerator.h":
	cdef cppclass _PubWebGenerator "NetworKit::PubWebGenerator":
		_PubWebGenerator(count numNodes, count numberOfDenseAreas, float neighborhoodRadius, count maxNumberOfNeighbors) except +
		_Graph generate() except +

cdef class PubWebGenerator:
	""" Generates a static graph that resembles an assumed geometric distribution of nodes in
	a P2P network.

	The basic structure is to distribute points randomly in the unit torus
	and to connect vertices close to each other (at most @a neighRad distance and none of
	them already has @a maxNeigh neighbors). The distribution is chosen to get some areas with
	high density and others with low density. There are @a numDenseAreas dense areas, which can
	overlap. Each area is circular, has a certain position and radius and number of points.
	These values are strored in @a denseAreaXYR and @a numPerArea, respectively.

	Used and described in more detail in J. Gehweiler, H. Meyerhenke: A Distributed
	Diffusive Heuristic for Clustering a Virtual P2P Supercomputer. In Proc. 7th High-Performance
	Grid Computing Workshop (HPGC'10), in conjunction with 24th IEEE Internatl. Parallel and
	Distributed Processing Symposium (IPDPS'10), IEEE, 2010.

	PubWebGenerator(numNodes, numberOfDenseAreas, neighborhoodRadius, maxNumberOfNeighbors)

	Parameters
	----------
	numNodes : count
		Up to a few thousand (possibly more if visualization is not desired and quadratic
		time complexity has been resolved)
	numberOfDenseAreas : count
		Depending on number of nodes, e.g. [8, 50]
	neighborhoodRadius : float
		The higher, the better the connectivity [0.1, 0.35]
	maxNumberOfNeighbors : count
		Maximum degree, a higher value corresponds to better connectivity [4, 40]
	"""
	cdef _PubWebGenerator* _this

	def __cinit__(self, numNodes, numberOfDenseAreas, neighborhoodRadius, maxNumberOfNeighbors):
		self._this = new _PubWebGenerator(numNodes, numberOfDenseAreas, neighborhoodRadius, maxNumberOfNeighbors)

	def __dealloc__(self):
		del self._this

	def generate(self):
		return Graph(0).setThis(self._this.generate())


cdef extern from "cpp/generators/ErdosRenyiGenerator.h":
	cdef cppclass _ErdosRenyiGenerator "NetworKit::ErdosRenyiGenerator":
		_ErdosRenyiGenerator(count nNodes, double prob, bool directed) except +
		_Graph generate() except +

cdef class ErdosRenyiGenerator:
	""" Creates random graphs in the G(n,p) model.
	The generation follows Vladimir Batagelj and Ulrik Brandes: "Efficient
	generation of large random networks", Phys Rev E 71, 036113 (2005).

	ErdosRenyiGenerator(count, double)

	Creates G(nNodes, prob) graphs.

	Parameters
	----------
	nNodes : count
		Number of nodes n in the graph.
	prob : double
		Probability of existence for each edge p.
	directed : bool
		Generates a directed
	"""

	cdef _ErdosRenyiGenerator* _this

	def __cinit__(self, nNodes, prob, directed=False):
		self._this = new _ErdosRenyiGenerator(nNodes, prob, directed)

	def __dealloc__(self):
		del self._this

	def generate(self):
		return Graph(0).setThis(self._this.generate())

	@classmethod
	def fit(cls, Graph G, scale=1):
		""" Fit model to input graph"""
		(n, m) = G.size()
		if G.isDirected():
			raise Exception("TODO: figure out scaling scheme for directed graphs")
		else:
			p = (2 * m) / (scale * n * (n-1))
		return cls(scale * n, p)

cdef extern from "cpp/generators/DorogovtsevMendesGenerator.h":
	cdef cppclass _DorogovtsevMendesGenerator "NetworKit::DorogovtsevMendesGenerator":
		_DorogovtsevMendesGenerator(count nNodes) except +
		_Graph generate() except +

cdef class DorogovtsevMendesGenerator:
	""" Generates a graph according to the Dorogovtsev-Mendes model.

 	DorogovtsevMendesGenerator(nNodes)

 	Constructs the generator class.

	Parameters
	----------
	nNodes : count
		Number of nodes in the target graph.
	"""

	cdef _DorogovtsevMendesGenerator* _this

	def __cinit__(self, nNodes):
		self._this = new _DorogovtsevMendesGenerator(nNodes)

	def __dealloc__(self):
		del self._this

	def generate(self):
		""" Generates a random graph according to the Dorogovtsev-Mendes model.

		Returns
		-------
		Graph
			The generated graph.
		"""
		return Graph(0).setThis(self._this.generate())

	@classmethod
	def fit(cls, Graph G, scale=1):
		return cls(scale * G.numberOfNodes())


cdef extern from "cpp/generators/RegularRingLatticeGenerator.h":
	cdef cppclass _RegularRingLatticeGenerator "NetworKit::RegularRingLatticeGenerator":
		_RegularRingLatticeGenerator(count nNodes, count nNeighbors) except +
		_Graph generate() except +

cdef class RegularRingLatticeGenerator:
	"""
	Constructs a regular ring lattice.

	RegularRingLatticeGenerator(count nNodes, count nNeighbors)

	Constructs the generator.

	Parameters
	----------
	nNodes : number of nodes in the target graph.
	nNeighbors : number of neighbors on each side of a node
	"""

	cdef _RegularRingLatticeGenerator* _this

	def __cinit__(self, nNodes, nNeighbors):
		self._this = new _RegularRingLatticeGenerator(nNodes, nNeighbors)

	def __dealloc__(self):
		del self._this

	def generate(self):
		""" Generates a rgular ring lattice.

		Returns
		-------
		Graph
			The generated graph.
		"""
		return Graph(0).setThis(self._this.generate())


cdef extern from "cpp/generators/WattsStrogatzGenerator.h":
	cdef cppclass _WattsStrogatzGenerator "NetworKit::WattsStrogatzGenerator":
		_WattsStrogatzGenerator(count nNodes, count nNeighbors, double p) except +
		_Graph generate() except +

cdef class WattsStrogatzGenerator:
	""" Generates a graph according to the Watts-Strogatz model.

	First, a regular ring lattice is generated. Then edges are rewired
		with a given probability.

	WattsStrogatzGenerator(count nNodes, count nNeighbors, double p)

	Constructs the generator.

	Parameters
	----------
	nNodes : Number of nodes in the target graph.
	nNeighbors : number of neighbors on each side of a node
	p : rewiring probability
	"""

	cdef _WattsStrogatzGenerator* _this

	def __dealloc__(self):
		del self._this

	def __cinit__(self, nNodes, nNeighbors, p):
		self._this = new _WattsStrogatzGenerator(nNodes, nNeighbors, p)

	def generate(self):
		""" Generates a random graph according to the Watts-Strogatz model.

		Returns
		-------
		Graph
			The generated graph.
		"""
		return Graph(0).setThis(self._this.generate())


cdef extern from "cpp/generators/ClusteredRandomGraphGenerator.h":
	cdef cppclass _ClusteredRandomGraphGenerator "NetworKit::ClusteredRandomGraphGenerator":
		_ClusteredRandomGraphGenerator(count, count, double, double) except +
		_Graph generate() except +
		_Partition getCommunities() except +

cdef class ClusteredRandomGraphGenerator:
	""" The ClusteredRandomGraphGenerator class is used to create a clustered random graph.

	The number of nodes and the number of edges are adjustable as well as the probabilities
	for intra-cluster and inter-cluster edges.

	ClusteredRandomGraphGenerator(count, count, pin, pout)

	Creates a clustered random graph.

	Parameters
	----------
	n : count
		number of nodes
	k : count
		number of clusters
	pin : double
		intra-cluster edge probability
	pout : double
		inter-cluster edge probability
	"""

	cdef _ClusteredRandomGraphGenerator* _this

	def __cinit__(self, n, k, pin, pout):
		self._this = new _ClusteredRandomGraphGenerator(n, k, pin, pout)

	def __dealloc__(self):
		del self._this

	def generate(self):
		""" Generates a clustered random graph with the properties given in the constructor.

		Returns
		-------
		Graph
			The generated graph.
		"""
		return Graph(0).setThis(self._this.generate())

	def getCommunities(self):
		""" Returns the generated ground truth clustering.

		Returns
		-------
		Partition
			The generated ground truth clustering.
		"""
		return Partition().setThis(self._this.getCommunities())


cdef extern from "cpp/generators/ChungLuGenerator.h":
	cdef cppclass _ChungLuGenerator "NetworKit::ChungLuGenerator":
		_ChungLuGenerator(vector[count] degreeSequence) except +
		_Graph generate() except +

cdef class ChungLuGenerator:
	"""
		Given an arbitrary degree sequence, the Chung-Lu generative model
		will produce a random graph with the same expected degree sequence.

		see Chung, Lu: The average distances in random graphs with given expected degrees
		and Chung, Lu: Connected Components in Random Graphs with Given Expected Degree Sequences.
		Aiello, Chung, Lu: A Random Graph Model for Massive Graphs describes a different generative model
		which is basically asymptotically equivalent but produces multi-graphs.
	"""

	cdef _ChungLuGenerator* _this

	def __cinit__(self, vector[count] degreeSequence):
		self._this = new _ChungLuGenerator(degreeSequence)

	def __dealloc__(self):
		del self._this

	def generate(self):
		""" Generates graph with expected degree sequence seq.

		Returns
		-------
		Graph
			The generated graph.
		"""
		return Graph(0).setThis(self._this.generate())

	@classmethod
	def fit(cls, Graph G, scale=1):
		""" Fit model to input graph"""
		(n, m) = G.size()
		degSeq = DegreeCentrality(G).run().scores()
		return cls(degSeq * scale)


cdef extern from "cpp/generators/HavelHakimiGenerator.h":
	cdef cppclass _HavelHakimiGenerator "NetworKit::HavelHakimiGenerator":
		_HavelHakimiGenerator(vector[count] degreeSequence, bool ignoreIfRealizable) except +
		_Graph generate() except +
		bool isRealizable() except +
		bool getRealizable() except +

cdef class HavelHakimiGenerator:
	""" Havel-Hakimi algorithm for generating a graph according to a given degree sequence.

		The sequence, if it is realizable, is reconstructed exactly. The resulting graph usually
		has a high clustering coefficient. Construction runs in linear time O(m).

		If the sequence is not realizable, depending on the parameter ignoreIfRealizable, either
		an exception is thrown during generation or the graph is generated with a modified degree
		sequence, i.e. not all nodes might have as many neighbors as requested.

		HavelHakimiGenerator(sequence, ignoreIfRealizable=True)

		Parameters
		----------
		sequence : vector
			Degree sequence to realize. Must be non-increasing.
		ignoreIfRealizable : bool, optional
			If true, generate the graph even if the degree sequence is not realizable. Some nodes may get lower degrees than requested in the sequence.
	"""

	cdef _HavelHakimiGenerator* _this


	def __cinit__(self, vector[count] degreeSequence, ignoreIfRealizable=True):
		self._this = new _HavelHakimiGenerator(degreeSequence, ignoreIfRealizable)

	def __dealloc__(self):
		del self._this

	def isRealizable(self):
		return self._this.isRealizable()

	def getRealizable(self):
		return self._this.getRealizable();

	def generate(self):
		""" Generates degree sequence seq (if it is realizable).

		Returns
		-------
		Graph
			Graph with degree sequence seq or modified sequence if ignoreIfRealizable is true and the sequence is not realizable.
		"""
		return Graph(0).setThis(self._this.generate())

	@classmethod
	def fit(cls, Graph G, scale=1):
		degSeq = DegreeCentrality(G).run().scores()
		return cls(degSeq * scale, ignoreIfRealizable=True)

cdef extern from "cpp/generators/EdgeSwitchingMarkovChainGenerator.h":
	cdef cppclass _EdgeSwitchingMarkovChainGenerator "NetworKit::EdgeSwitchingMarkovChainGenerator":
		_EdgeSwitchingMarkovChainGenerator(vector[count] degreeSequence, bool ignoreIfRealizable) except +
		_Graph generate() except +
		bool isRealizable() except +
		bool getRealizable() except +

cdef class EdgeSwitchingMarkovChainGenerator:
	"""
	Graph generator for generating a random simple graph with exactly the given degree sequence based on the Edge-Switching Markov-Chain method.

	This implementation is based on the paper
	"Random generation of large connected simple graphs with prescribed degree distribution" by Fabien Viger and Matthieu Latapy,
	available at http://www-rp.lip6.fr/~latapy/FV/generation.html, however without preserving connectivity (this could later be added as
	optional feature).

	The Havel-Hakami generator is used for the initial graph generation, then the Markov-Chain Monte-Carlo algorithm as described and
	implemented by Fabien Viger and Matthieu Latapy but without the steps for ensuring connectivity is executed. This should lead to a
	graph that is drawn uniformly at random from all graphs with the given degree sequence.

	Note that at most 10 times the number of edges edge swaps are performed (same number as in the abovementioned implementation) and
	in order to limit the running time, at most 200 times as many attempts to perform an edge swap are made (as certain degree distributions
	do not allow edge swaps at all).

	Parameters
	----------
	degreeSequence : vector[count]
		The degree sequence that shall be generated
	ignoreIfRealizable : bool, optional
		If true, generate the graph even if the degree sequence is not realizable. Some nodes may get lower degrees than requested in the sequence.
	"""
	cdef _EdgeSwitchingMarkovChainGenerator *_this

	def __cinit__(self, vector[count] degreeSequence, bool ignoreIfRealizable = False):
		self._this = new _EdgeSwitchingMarkovChainGenerator(degreeSequence, ignoreIfRealizable)

	def __dealloc__(self):
		del self._this

	def isRealizable(self):
		return self._this.isRealizable()

	def getRealizable(self):
		return self._this.getRealizable()

	def generate(self):
		"""
		Generate a graph according to the configuration model.

		Issues a INFO log message if the wanted number of edge swaps cannot be performed because of the limit of attempts (see in the description of the class for details).

		Returns
		-------
		Graph
			The generated graph.
		"""
		return Graph().setThis(self._this.generate())

	@classmethod
	def fit(cls, Graph G, scale=1):
		degSeq = DegreeCentrality(G).run().scores()
		return cls(degSeq * scale, ignoreIfRealizable=True)


cdef extern from "cpp/generators/HyperbolicGenerator.h":
	cdef cppclass _HyperbolicGenerator "NetworKit::HyperbolicGenerator":
		# TODO: revert to count when cython issue fixed
		_HyperbolicGenerator(unsigned int nodes,  double k, double gamma, double T) except +
		void setLeafCapacity(unsigned int capacity) except +
		void setTheoreticalSplit(bool split) except +
		void setBalance(double balance) except +
		vector[double] getElapsedMilliseconds() except +
		_Graph generate() except +
		_Graph generate(vector[double] angles, vector[double] radii, double R, double T) except +

cdef class HyperbolicGenerator:
	""" The Hyperbolic Generator distributes points in hyperbolic space and adds edges between points with a probability depending on their distance. The resulting graphs have a power-law degree distribution, small diameter and high clustering coefficient.
For a temperature of 0, the model resembles a unit-disk model in hyperbolic space.

 		HyperbolicGenerator(n, k=6, gamma=3, T=0)

 		Parameters
		----------
		n : integer
			number of nodes
		k : double
			average degree
		gamma : double
			exponent of power-law degree distribution
		T : double
			temperature of statistical model

	"""

	cdef _HyperbolicGenerator* _this

	def __cinit__(self,  n, k=6, gamma=3, T=0):
		if gamma <= 2:
				raise ValueError("Exponent of power-law degree distribution must be > 2")
		self._this = new _HyperbolicGenerator(n, k, gamma, T)

	def setLeafCapacity(self, capacity):
		self._this.setLeafCapacity(capacity)

	def setBalance(self, balance):
		self._this.setBalance(balance)

	def setTheoreticalSplit(self, theoreticalSplit):
		self._this.setTheoreticalSplit(theoreticalSplit)

	def getElapsedMilliseconds(self):
		return self._this.getElapsedMilliseconds()

	def generate(self):
		""" Generates hyperbolic random graph

		Returns
		-------
		Graph

		"""
		return Graph(0).setThis(self._this.generate())

	def generate(self, angles, radii, R, T=0):
		# TODO: documentation
		return Graph(0).setThis(self._this.generate(angles, radii, R, T))

	@classmethod
	def fit(cls, Graph G, scale=1):
		""" Fit model to input graph"""
		degSeq = DegreeCentrality(G).run().scores()
		gamma = max(-1 * PowerlawDegreeSequence(degSeq).getGamma(), 2.1)
		(n, m) = G.size()
		k = 2 * (m / n)
		return cls(n * scale, k, gamma)


cdef extern from "cpp/generators/RmatGenerator.h":
	cdef cppclass _RmatGenerator "NetworKit::RmatGenerator":
		_RmatGenerator(count scale, count edgeFactor, double a, double b, double c, double d, bool weighted, count reduceNodes) except +
		_Graph generate() except +

cdef class RmatGenerator:
	"""
	Generates static R-MAT graphs. R-MAT (recursive matrix) graphs are
	random graphs with n=2^scale nodes and m=nedgeFactor edges.
	More details at http://www.graph500.org or in the original paper:
	Deepayan Chakrabarti, Yiping Zhan, Christos Faloutsos:
	R-MAT: A Recursive Model for Graph Mining. SDM 2004: 442-446.

	RmatGenerator(scale, edgeFactor, a, b, c, d)

	Parameters
	----------
	scale : count
		Number of nodes = 2^scale
	edgeFactor : count
		Number of edges = number of nodes * edgeFactor
	a : double
		Probability for quadrant upper left
	b : double
		Probability for quadrant upper right
	c : double
		Probability for quadrant lower left
	d : double
		Probability for quadrant lower right
	weighted : bool
		result graph weighted?
	"""

	cdef _RmatGenerator* _this
	paths = {"workingDir" : None, "kronfitPath" : None}

	def __cinit__(self, count scale, count edgeFactor, double a, double b, double c, double d, bool weighted=False, count reduceNodes=0):
		self._this = new _RmatGenerator(scale, edgeFactor, a, b, c, d, weighted, reduceNodes)

	def __dealloc__(self):
		del self._this

	def generate(self):
		""" Graph to be generated according to parameters specified in constructor.

		Returns
		-------
		Graph
			The generated graph.
		"""
		return Graph(0).setThis(self._this.generate())

	@classmethod
	def setPaths(cls, kronfitPath, workingDir="/tmp"):
		cls.paths["kronfitPath"] = kronfitPath
		cls.paths["workingDir"] = workingDir

	@classmethod
	def fit(cls, G, scale=1, initiator=None, kronfit=True, iterations=50):
		import math
		import re
		import subprocess
		import os
		import random
		from networkit import graphio
		if initiator:
			(a,b,c,d) = initiator
		else:
			if kronfit:
				if cls.paths["workingDir"] is None:
					raise RuntimeError("call setPaths class method first to configure")
				# write graph
				tmpGraphPath = os.path.join(cls.paths["workingDir"], "{0}.edgelist".format(G.getName()))
				graphio.writeGraph(G, tmpGraphPath, graphio.Format.EdgeListTabOne)
				# call kronfit
				args = [cls.paths["kronfitPath"], "-i:{0}".format(tmpGraphPath), "-gi:{0}".format(str(iterations))]
				subprocess.call(args)
				# read estimated parameters
				with open("KronFit-{0}.tab".format(G.getName())) as resultFile:
					for i, line in enumerate(resultFile):
						if i == 7:
							matches = re.findall("\d+\.\d+", line)
							weights = [float(s) for s in matches]
			else:
				# random weights because kronfit is slow
				weights = (random.random(), random.random(), random.random(), random.random())
			# normalize
			nweights = [w / sum(weights) for w in weights]
			(a,b,c,d) = nweights
		print("using initiator matrix [{0},{1};{2},{3}]".format(a,b,c,d))
		# other parameters
		(n,m) = G.size()
		scaleParameter = math.ceil(math.log(n * scale, 2))
		edgeFactor = math.floor(m / n)
		reduceNodes = (2**scaleParameter) - (scale * n)
		print("random nodes to delete to achieve target node count: ", reduceNodes)
		return RmatGenerator(scaleParameter, edgeFactor, a, b, c, d, False, reduceNodes)

cdef extern from "cpp/generators/PowerlawDegreeSequence.h":
	cdef cppclass _PowerlawDegreeSequence "NetworKit::PowerlawDegreeSequence":
		_PowerlawDegreeSequence(count minDeg, count maxDeg, double gamma) except +
		_PowerlawDegreeSequence(_Graph) except +
		_PowerlawDegreeSequence(vector[double]) except +
		void setMinimumFromAverageDegree(double avgDeg) nogil except +
		void setGammaFromAverageDegree(double avgDeg, double minGamma, double maxGamma) nogil except +
		double getExpectedAverageDegree() except +
		count getMinimumDegree() const
		count getMaximumDegree() const
		double getGamma() const
		double setGamma(double) const
		void run() nogil except +
		vector[count] getDegreeSequence(count numNodes) except +
		count getDegree() except +

cdef class PowerlawDegreeSequence:
	"""
	Generates a powerlaw degree sequence with the given minimum and maximum degree, the powerlaw exponent gamma

	If a list of degrees or a graph is given instead of a minimum degree, the class uses the minimum and maximum
	value of the sequence and fits the exponent such that the expected average degree is the actual average degree.

	Parameters
	----------
	minDeg : count, list or Graph
		The minium degree, or a list of degrees to fit or graphs
	maxDeg : count
		The maximum degree
	gamma : double
		The powerlaw exponent, default: -2
	"""
	cdef _PowerlawDegreeSequence *_this

	def __cinit__(self, minDeg, count maxDeg = 0, double gamma = -2):
		if isinstance(minDeg, Graph):
			self._this = new _PowerlawDegreeSequence((<Graph>minDeg)._this)
		elif isinstance(minDeg, collections.Iterable):
			self._this = new _PowerlawDegreeSequence(<vector[double]?>minDeg)
		else:
			self._this = new _PowerlawDegreeSequence((<count?>minDeg), maxDeg, gamma)

	def __dealloc__(self):
		del self._this

	def setMinimumFromAverageDegree(self, double avgDeg):
		"""
		Tries to set the minimum degree such that the specified average degree is expected.

		Parameters
		----------
		avgDeg : double
			The average degree that shall be approximated
		"""
		with nogil:
			self._this.setMinimumFromAverageDegree(avgDeg)
		return self

	def setGammaFromAverageDegree(self, double avgDeg, double minGamma = -1, double maxGamma = -6):
		"""
		Tries to set the powerlaw exponent gamma such that the specified average degree is expected.

		Parameters
		----------
		avgDeg : double
			The average degree that shall be approximated
		minGamma : double
			The minimum gamma to use, default: -1
		maxGamma : double
			The maximum gamma to use, default: -6
		"""
		with nogil:
			self._this.setGammaFromAverageDegree(avgDeg, minGamma, maxGamma)
		return self

	def getExpectedAverageDegree(self):
		"""
		Returns the expected average degree. Note: run needs to be called first.

		Returns
		-------
		double
			The expected average degree.
		"""
		return self._this.getExpectedAverageDegree()

	def getMinimumDegree(self):
		"""
		Returns the minimum degree.

		Returns
		-------
		count
			The minimum degree
		"""
		return self._this.getMinimumDegree()

	def setGamma(self, double gamma):
		"""
		Set the exponent gamma

		Parameters
		----------
		gamma : double
			The exponent to set
		"""
		self._this.setGamma(gamma)
		return self

	def getGamma(self):
		"""
		Get the exponent gamma.

		Returns
		-------
		double
			The exponent gamma
		"""
		return self._this.getGamma()

	def getMaximumDegree(self):
		"""
		Get the maximum degree

		Returns
		-------
		count
			The maximum degree
		"""
		return self._this.getMaximumDegree()

	def run(self):
		"""
		Executes the generation of the probability distribution.
		"""
		with nogil:
			self._this.run()
		return self

	def getDegreeSequence(self, count numNodes):
		"""
		Returns a degree sequence with even degree sum.

		Parameters
		----------
		numNodes : count
			The number of nodes/degrees that shall be returned

		Returns
		-------
		vector[count]
			The generated degree sequence
		"""
		return self._this.getDegreeSequence(numNodes)

	def getDegree(self):
		"""
		Returns a degree drawn at random with a power law distribution

		Returns
		-------
		count
			The generated random degree
		"""
		return self._this.getDegree()

cdef extern from "cpp/generators/LFRGenerator.h":
	cdef cppclass _LFRGenerator "NetworKit::LFRGenerator"(_Algorithm):
		_LFRGenerator(count n) except +
		void setDegreeSequence(vector[count] degreeSequence) nogil except +
		void generatePowerlawDegreeSequence(count avgDegree, count maxDegree, double nodeDegreeExp) nogil except +
		void setCommunitySizeSequence(vector[count] communitySizeSequence) nogil except +
		void setPartition(_Partition zeta) nogil except +
		void generatePowerlawCommunitySizeSequence(count minCommunitySize, count maxCommunitySize, double communitySizeExp) nogil except +
		void setMu(double mu) nogil except +
		void setMu(const vector[double] & mu) nogil except +
		void setMuWithBinomialDistribution(double mu) nogil except +
		_Graph getGraph() except +
		_Partition getPartition() except +
		_Graph generate() except +

cdef class LFRGenerator(Algorithm):
	"""
	The LFR clustered graph generator as introduced by Andrea Lancichinetti, Santo Fortunato, and Filippo Radicchi.

	The community assignment follows the algorithm described in
	"Benchmark graphs for testing community detection algorithms". The edge generation is however taken from their follow-up publication
	"Benchmarks for testing community detection algorithms on directed and weighted graphs with overlapping communities". Parts of the
	implementation follow the choices made in their implementation which is available at https://sites.google.com/site/andrealancichinetti/software
	but other parts differ, for example some more checks for the realizability of the community and degree size distributions are done
	instead of heavily modifying the distributions.

	The edge-switching markov-chain algorithm implementation in NetworKit is used which is different from the implementation in the original LFR benchmark.

	You need to set a degree sequence, a community size sequence and a mu using the additionally provided set- or generate-methods.

	Parameters
	----------
	n : count
		The number of nodes
	"""
	params = {}
	paths = {}

	def __cinit__(self, count n):
		self._this = new _LFRGenerator(n)

	def setDegreeSequence(self, vector[count] degreeSequence):
		"""
		Set the given degree sequence.

		Parameters
		----------
		degreeSequence : collections.Iterable
			The degree sequence that shall be used by the generator
		"""
		with nogil:
			(<_LFRGenerator*>(self._this)).setDegreeSequence(degreeSequence)
		return self

	def generatePowerlawDegreeSequence(self, count avgDegree, count maxDegree, double nodeDegreeExp):
		"""
		Generate and set a power law degree sequence using the given average and maximum degree with the given exponent.


		Parameters
		----------
		avgDegree : count
			The average degree of the created graph
		maxDegree : count
			The maximum degree of the created graph
		nodeDegreeExp : double
			The (negative) exponent of the power law degree distribution of the node degrees
		"""
		with nogil:
			(<_LFRGenerator*>(self._this)).generatePowerlawDegreeSequence(avgDegree, maxDegree, nodeDegreeExp)
		return self

	def setCommunitySizeSequence(self, vector[count] communitySizeSequence):
		"""
		Set the given community size sequence.

		Parameters
		----------
		communitySizeSequence : collections.Iterable
			The community sizes that shall be used.
		"""
		with nogil:
			(<_LFRGenerator*>(self._this)).setCommunitySizeSequence(communitySizeSequence)
		return self

	def setPartition(self, Partition zeta not None):
		"""
		Set the partition, this replaces the community size sequence and the random assignment of the nodes to communities.

		Parameters
		----------
		zeta : Partition
			The partition to use
		"""
		with nogil:
			(<_LFRGenerator*>(self._this)).setPartition(zeta._this)
		return self

	def generatePowerlawCommunitySizeSequence(self, count minCommunitySize, count maxCommunitySize, double communitySizeExp):
		"""
		Generate a powerlaw community size sequence with the given minimum and maximum size and the given exponent.

		Parameters
		----------
		minCommunitySize : count
			The minimum community size
		maxCommunitySize : count
			The maximum community size
		communitySizeExp : double
			The (negative) community size exponent of the power law degree distribution of the community sizes
		"""
		with nogil:
			(<_LFRGenerator*>(self._this)).generatePowerlawCommunitySizeSequence(minCommunitySize, maxCommunitySize, communitySizeExp)
		return self

	def setMu(self, mu):
		"""
		Set the mixing parameter, this is the fraction of neighbors of each node that do not belong to the node's own community.

		This can either be one value for all nodes or an iterable of values for each node.

		Parameters
		----------
		mu : double or collections.Iterable
			The mixing coefficient(s), i.e. the factor of the degree that shall be inter-cluster degree
		"""
		if isinstance(mu, collections.Iterable):
			(<_LFRGenerator*>(self._this)).setMu(<vector[double]>mu)
		else:
			(<_LFRGenerator*>(self._this)).setMu(<double>mu)
		return self

	def setMuWithBinomialDistribution(self, double mu):
		"""
		Set the internal degree of each node using a binomial distribution such that the expected mixing parameter is the given @a mu.

		The mixing parameter is for each node the fraction of neighbors that do not belong to the node's own community.

		Parameters
		----------
		mu : double
			The expected mu that shall be used.
		"""
		with nogil:
			(<_LFRGenerator*>(self._this)).setMuWithBinomialDistribution(mu)
		return self

	def getGraph(self):
		"""
		Return the generated Graph.

		Returns
		-------
		Graph
			The generated graph.
		"""
		return Graph().setThis((<_LFRGenerator*>(self._this)).getGraph())

	def generate(self, useReferenceImplementation=False):
		"""
		Generates and returns the graph. Wrapper for the StaticGraphGenerator interface.

		Returns
		-------
		Graph
			The generated graph.
		"""
		if useReferenceImplementation:
			from networkit import graphio
			os.system("{0}/benchmark {1}".format(self.paths["refImplDir"], self.params["refImplParams"]))
			return graphio.readGraph("network.dat", graphio.Format.EdgeListTabOne)
		return Graph().setThis((<_LFRGenerator*>(self._this)).generate())

	def getPartition(self):
		"""
		Return the generated Partiton.

		Returns
		-------
		Partition
			The generated partition.
		"""
		return Partition().setThis((<_LFRGenerator*>(self._this)).getPartition())

	@classmethod
	def setPathToReferenceImplementationDir(cls, path):
		cls.paths["refImplDir"] = path


	@classmethod
	def fit(cls, Graph G, scale=1, vanilla=False, communityDetectionAlgorithm=PLM, plfit=False):
		""" Fit model to input graph"""
		(n, m) = G.size()
		# detect communities
		communities = communityDetectionAlgorithm(G).run().getPartition()
		# get degree sequence
		degSeq = DegreeCentrality(G).run().scores()
		# set number of nodes
		gen = cls(n * scale)
		if vanilla:
			# fit power law to degree distribution and generate degree sequence accordingly
			#print("fit power law to degree distribution and generate degree sequence accordingly")
			avgDegree = int(sum(degSeq) / len(degSeq))
			maxDegree = max(degSeq)
			if plfit:
				degSeqGen = PowerlawDegreeSequence(G)
				nodeDegreeExp = -1 * degSeqGen.getGamma()
				degSeqGen.run()
				gen.setDegreeSequence(degSeqGen.getDegreeSequence(n * scale))
			else:
				nodeDegreeExp = 2
				gen.generatePowerlawDegreeSequence(avgDegree, maxDegree, -1 * nodeDegreeExp)
			print(avgDegree, maxDegree, nodeDegreeExp)
			# fit power law to community size sequence and generate accordingly
			#print("fit power law to community size sequence and generate accordingly")
			communitySize = communities.subsetSizes()
			communityAvgSize = int(sum(communitySize) / len(communitySize))
			communityMaxSize = max(communitySize)
			communityMinSize = min(communitySize)
			if plfit:
				communityExp = -1 * PowerlawDegreeSequence(communitySize).getGamma()
			else:
				communityExp = 1
			pl = PowerlawDegreeSequence(communityMinSize, communityMaxSize, -1 * communityExp)

			try: # it can be that the exponent is -1 because the average would be too low otherwise, increase minimum to ensure average fits.
				pl.setMinimumFromAverageDegree(communityAvgSize)
				communityMinSize = pl.getMinimumDegree()
			except RuntimeError: # if average is too low with chosen exponent, this might not work...
				pl.run()
				print("Could not set desired average community size {}, average will be {} instead".format(communityAvgSize, pl.getExpectedAverageDegree()))

			gen.generatePowerlawCommunitySizeSequence(minCommunitySize=communityMinSize, maxCommunitySize=communityMaxSize, communitySizeExp=-1 * communityExp)
			# mixing parameter
			#print("mixing parameter")
			localCoverage = LocalPartitionCoverage(G, communities).run().scores()
			mu = sum(localCoverage) / len(localCoverage)
			gen.setMu(mu)
			refImplParams = "-N {0} -k {1} -maxk {2} -mu {3} -minc {4} -maxc {5} -t1 {6} -t2 {7}".format(n * scale, avgDegree, maxDegree, mu, communityMinSize, communityMaxSize, nodeDegreeExp, communityExp)
			cls.params["refImplParams"] = refImplParams
			print(refImplParams)
		else:
			if scale > 1:
				# scale communities
				cData = communities.getVector()
				cDataCopy = cData[:]
				b = communities.upperBound()
				for s in range(1, scale):
					cDataExtend = [i + (b * s) for i in cDataCopy]
					cData = cData + cDataExtend
				assert (len(cData) == n * scale)
				gen.setPartition(Partition(0, cData))
			else:
				gen.setPartition(communities)
			# degree sequence
			gen.setDegreeSequence(degSeq * scale)
			# mixing parameter
			localCoverage = LocalPartitionCoverage(G, communities).run().scores()
			gen.setMu([1.0 - x for x in localCoverage] * scale)
		return gen


# cdef extern from "cpp/generators/MultiscaleGenerator.h":
# 	cdef cppclass _MultiscaleGenerator "NetworKit::MultiscaleGenerator":
# 		_MultiscaleGenerator(_Graph O) except +
# 		_Graph generate() except +
#
#
# cdef class MultiscaleGenerator:
# 	"""
# 	TODO:
# 	"""
# 	cdef _MultiscaleGenerator *_this
# 	cdef Graph O	# store reference to input graph to not let it be garbage-collection
#
# 	def __cinit__(self, Graph O):
# 		self._this = new _MultiscaleGenerator(O._this)
# 		self.O = O
#
# 	def generate(self):
# 		return Graph(0).setThis(self._this.generate())
#
# 	@classmethod
# 	def fit(cls, Graph G):
# 		return cls(G)




# Module: graphio

cdef extern from "cpp/io/GraphReader.h":
	cdef cppclass _GraphReader "NetworKit::GraphReader":
		_GraphReader() nogil except +
		_Graph read(string path) nogil except +

cdef class GraphReader:
	""" Abstract base class for graph readers"""

	cdef _GraphReader* _this

	def __init__(self, *args, **kwargs):
		if type(self) == GraphReader:
			raise RuntimeError("Error, you may not use GraphReader directly, use a sub-class instead")

	def __cinit__(self, *args, **kwargs):
		self._this = NULL

	def __dealloc__(self):
		if self._this != NULL:
			del self._this
		self._this = NULL

	def read(self, path):
		cdef string cpath = stdstring(path)
		cdef _Graph result

		with nogil:
			result = move(self._this.read(cpath)) # extra move in order to avoid copying the internal variable that is used by Cython
		return Graph(0).setThis(result)

cdef extern from "cpp/io/METISGraphReader.h":
	cdef cppclass _METISGraphReader "NetworKit::METISGraphReader" (_GraphReader):
		_METISGraphReader() nogil except +

cdef class METISGraphReader(GraphReader):
	""" Reads the METIS adjacency file format [1]. If the Fast reader fails,
		use readGraph(path, graphio.formats.metis) as an alternative.
		[1]: http://people.sc.fsu.edu/~jburkardt/data/metis_graph/metis_graph.html
	"""
	def __cinit__(self):
		self._this = new _METISGraphReader()

cdef extern from "cpp/io/GraphToolBinaryReader.h":
	cdef cppclass _GraphToolBinaryReader "NetworKit::GraphToolBinaryReader" (_GraphReader):
		_GraphToolBinaryReader() except +

cdef class GraphToolBinaryReader(GraphReader):
	""" Reads the binary file format defined by graph-tool[1].
		[1]: http://graph-tool.skewed.de/static/doc/gt_format.html
	"""
	def __cinit__(self):
		self._this = new _GraphToolBinaryReader()


cdef extern from "cpp/io/EdgeListReader.h":
	cdef cppclass _EdgeListReader "NetworKit::EdgeListReader"(_GraphReader):
		_EdgeListReader() except +
		_EdgeListReader(char separator, node firstNode, string commentPrefix, bool continuous, bool directed)
		map[string,node] getNodeMap() except +


cdef class EdgeListReader(GraphReader):
	""" Reads a file in an edge list format.
		TODO: docstring
	"""
	def __cinit__(self, separator, firstNode, commentPrefix="#", continuous=True, directed=False):
		self._this = new _EdgeListReader(stdstring(separator)[0], firstNode, stdstring(commentPrefix), continuous, directed)

	def getNodeMap(self):
		cdef map[string,node] cResult = (<_EdgeListReader*>(self._this)).getNodeMap()
		result = dict()
		for elem in cResult:
			#result.append((elem.first,elem.second))
			result[(elem.first).decode("utf-8")] = elem.second
		return result

cdef extern from "cpp/io/KONECTGraphReader.h":
	cdef cppclass _KONECTGraphReader "NetworKit::KONECTGraphReader"(_GraphReader):
		_KONECTGraphReader() except +
		_KONECTGraphReader(char separator, bool ignoreLoops)

cdef class KONECTGraphReader(GraphReader):
	""" Reader for the KONECT graph format, which is described in detail on the KONECT website[1].

		[1]: http://konect.uni-koblenz.de/downloads/konect-handbook.pdf
	"""
	def __cinit__(self, separator, ignoreLoops = False):
		self._this = new _KONECTGraphReader(stdstring(separator)[0], ignoreLoops)

cdef extern from "cpp/io/GMLGraphReader.h":
	cdef cppclass _GMLGraphReader "NetworKit::GMLGraphReader"(_GraphReader):
		_GMLGraphReader() except +

cdef class GMLGraphReader(GraphReader):
	""" Reader for the GML graph format, which is documented here [1].

		[1]: http://www.fim.uni-passau.de/fileadmin/files/lehrstuhl/brandenburg/projekte/gml/gml-technical-report.pdf
 	"""
	def __cinit__(self):
		self._this = new _GMLGraphReader()

cdef extern from "cpp/io/METISGraphWriter.h":
	cdef cppclass _METISGraphWriter "NetworKit::METISGraphWriter":
		_METISGraphWriter() except +
		void write(_Graph G, string path) nogil except +


cdef class METISGraphWriter:
	""" Writes graphs in the METIS format"""
	cdef _METISGraphWriter _this

	def write(self, Graph G not None, path):
		 # string needs to be converted to bytes, which are coerced to std::string
		cdef string cpath = stdstring(path)
		with nogil:
			self._this.write(G._this, cpath)

cdef extern from "cpp/io/GraphToolBinaryWriter.h":
	cdef cppclass _GraphToolBinaryWriter "NetworKit::GraphToolBinaryWriter":
		_GraphToolBinaryWriter() except +
		void write(_Graph G, string path) nogil except +


cdef class GraphToolBinaryWriter:
	""" Reads the binary file format defined by graph-tool[1].
		[1]: http://graph-tool.skewed.de/static/doc/gt_format.html
	"""
	cdef _GraphToolBinaryWriter _this

	def write(self, Graph G not None, path):
		 # string needs to be converted to bytes, which are coerced to std::string
		cdef string cpath = stdstring(path)
		with nogil:
			self._this.write(G._this, cpath)


cdef extern from "cpp/io/DotGraphWriter.h":
	cdef cppclass _DotGraphWriter "NetworKit::DotGraphWriter":
		_DotGraphWriter() except +
		void write(_Graph G, string path) nogil except +


cdef class DotGraphWriter:
	""" Writes graphs in the .dot/GraphViz format"""
	cdef _DotGraphWriter _this

	def write(self, Graph G not None, path):
		 # string needs to be converted to bytes, which are coerced to std::string
		cdef string cpath = stdstring(path)
		with nogil:
			self._this.write(G._this, cpath)


cdef extern from "cpp/io/GMLGraphWriter.h":
	cdef cppclass _GMLGraphWriter "NetworKit::GMLGraphWriter":
		_GMLGraphWriter() except +
		void write(_Graph G, string path) nogil except +


cdef class GMLGraphWriter:
	""" Writes a graph and its coordinates as a GML file.[1]
		[1] http://svn.bigcat.unimaas.nl/pvplugins/GML/trunk/docs/gml-technical-report.pdf """
	cdef _GMLGraphWriter _this

	def write(self, Graph G not None, path):
		 # string needs to be converted to bytes, which are coerced to std::string
		cdef string cpath = stdstring(path)
		with nogil:
			self._this.write(G._this, cpath)


cdef extern from "cpp/io/EdgeListWriter.h":
	cdef cppclass _EdgeListWriter "NetworKit::EdgeListWriter":
		_EdgeListWriter() except +
		_EdgeListWriter(char separator, node firstNode) except +
		void write(_Graph G, string path) nogil except +

cdef class EdgeListWriter:
	""" Reads and writes graphs in various edge list formats. The constructor takes a
		seperator char and the ID of the first node as paraneters."""

	cdef _EdgeListWriter _this

	def __cinit__(self, separator, firstNode):
		cdef char sep = stdstring(separator)[0]
		self._this = _EdgeListWriter(sep, firstNode)

	def write(self, Graph G not None, path):
		cdef string cpath = stdstring(path)
		with nogil:
			self._this.write(G._this, cpath)



cdef extern from "cpp/io/LineFileReader.h":
	cdef cppclass _LineFileReader "NetworKit::LineFileReader":
		_LineFileReader() except +
		vector[string] read(string path)


cdef class LineFileReader:
	""" Reads a file and puts each line in a list of strings """
	cdef _LineFileReader _this

	def read(self, path):
		return self._this.read(stdstring(path))


cdef extern from "cpp/io/SNAPGraphWriter.h":
	cdef cppclass _SNAPGraphWriter "NetworKit::SNAPGraphWriter":
		_SNAPGraphWriter() except +
		void write(_Graph G, string path) nogil except +

cdef class SNAPGraphWriter:
	""" Writes graphs in a format suitable for the Georgia Tech SNAP software [1]
		[1]: http://snap-graph.sourceforge.net/
	"""
	cdef _SNAPGraphWriter _this

	def write(self, Graph G, path):
		cdef string cpath = stdstring(path)
		with nogil:
			self._this.write(G._this, cpath)


cdef extern from "cpp/io/SNAPGraphReader.h":
	cdef cppclass _SNAPGraphReader "NetworKit::SNAPGraphReader"(_GraphReader):
		_SNAPGraphReader() except +
		unordered_map[node,node] getNodeIdMap() except +

cdef class SNAPGraphReader(GraphReader):
	""" Reads a graph from the SNAP graph data collection [1] (currently experimental)
		[1]: http://snap.stanford.edu/data/index.html
	"""
	def __cinit__(self):
		self._this = new _SNAPGraphReader()

	def getNodeIdMap(self):
		cdef unordered_map[node,node] cResult = (<_SNAPGraphReader*>(self._this)).getNodeIdMap()
		result = []
		for elem in cResult:
			result.append((elem.first,elem.second))
		return result


cdef extern from "cpp/io/PartitionReader.h":
	cdef cppclass _PartitionReader "NetworKit::PartitionReader":
		_PartitionReader() except +
		_Partition read(string path) except +


cdef class PartitionReader:
	""" Reads a partition from a file.
		File format: line i contains subset id of element i.
	 """
	cdef _PartitionReader _this

	def read(self, path):
		return Partition().setThis(self._this.read(stdstring(path)))


cdef extern from "cpp/io/PartitionWriter.h":
	cdef cppclass _PartitionWriter "NetworKit::PartitionWriter":
		_PartitionWriter() except +
		void write(_Partition, string path) nogil except +


cdef class PartitionWriter:
	""" Writes a partition to a file.
		File format: line i contains subset id of element i.
	 """
	cdef _PartitionWriter _this

	def write(self, Partition zeta, path):
		cdef string cpath = stdstring(path)
		with nogil:
			self._this.write(zeta._this, cpath)


cdef extern from "cpp/io/EdgeListPartitionReader.h":
	cdef cppclass _EdgeListPartitionReader "NetworKit::EdgeListPartitionReader":
		_EdgeListPartitionReader() except +
		_EdgeListPartitionReader(node firstNode, char sepChar) except +
		_Partition read(string path) except +


cdef class EdgeListPartitionReader:
	""" Reads a partition from an edge list type of file
	 """
	cdef _EdgeListPartitionReader _this

	def __cinit__(self, node firstNode=1, sepChar = '\t'):
		self._this = _EdgeListPartitionReader(firstNode, stdstring(sepChar)[0])

	def read(self, path):
		return Partition().setThis(self._this.read(stdstring(path)))

cdef extern from "cpp/io/SNAPEdgeListPartitionReader.h":
	cdef cppclass _SNAPEdgeListPartitionReader "NetworKit::SNAPEdgeListPartitionReader":
		_SNAPEdgeListPartitionReader() except +
		_Cover read(string path, unordered_map[node,node] nodeMap,_Graph G) except +
#		_Partition readWithInfo(string path, count nNodes) except +

cdef class SNAPEdgeListPartitionReader:
	""" Reads a partition from a SNAP 'community with ground truth' file
	 """
	cdef _SNAPEdgeListPartitionReader _this

	def read(self,path, nodeMap, Graph G):
		cdef unordered_map[node,node] cNodeMap
		for (key,val) in nodeMap:
			cNodeMap[key] = val
		return Cover().setThis(self._this.read(stdstring(path), cNodeMap, G._this))

#	def readWithInfo(self,path,nNodes):
#		return Partition().setThis(self._this.readWithInfo(stdstring(path),nNodes))

#not existing yet, maybe in the future?
#cdef extern from "cpp/io/EdgeListPartitionWriter.h":
#	cdef cppclass _EdgeListPartitionWriter "NetworKit::EdgeListPartitionWriter":
#		_EdgeListPartitionWriter() except +
#		void write(_Partition, string path)


#cdef class EdgeListPartitionWriter:
#	""" Writes a partition to a edge list type of file.
#		File format: a line contains the element id and the subsed id of the element.
#	 """
#	cdef _EdgeListPartitionWriter _this

#	def Write(self, Partition zeta, path):
#		self._this.write(zeta._this, stdstring(path))

cdef extern from "cpp/io/CoverReader.h":
	cdef cppclass _CoverReader "NetworKit::CoverReader":
		_CoverReader() except +
		_Cover read(string path,_Graph G) except +

cdef class CoverReader:
	""" Reads a cover from a file
		File format: each line contains the space-separated node ids of a community
	 """
	cdef _CoverReader _this

	def read(self, path, Graph G):
		return Cover().setThis(self._this.read(stdstring(path), G._this))

cdef extern from "cpp/io/CoverWriter.h":
	cdef cppclass _CoverWriter "NetworKit::CoverWriter":
		_CoverWriter() except +
		void write(_Cover, string path) nogil except +


cdef class CoverWriter:
	""" Writes a partition to a file.
		File format: each line contains the space-separated node ids of a community
	 """
	cdef _CoverWriter _this

	def write(self, Cover zeta, path):
		cdef string cpath = stdstring(path)
		with nogil:
			self._this.write(zeta._this, cpath)

cdef extern from "cpp/io/EdgeListCoverReader.h":
	cdef cppclass _EdgeListCoverReader "NetworKit::EdgeListCoverReader":
		_EdgeListCoverReader() except +
		_EdgeListCoverReader(node firstNode) except +
		_Cover read(string path, _Graph G) except +


cdef class EdgeListCoverReader:
	""" Reads a cover from an edge list type of file
		File format: each line starts with a node id and continues with a list of the communities the node belongs to
	 """
	cdef _EdgeListCoverReader _this

	def __cinit__(self, firstNode=1):
		self._this = _EdgeListCoverReader(firstNode)

	def read(self, path, Graph G):
		return Cover().setThis(self._this.read(stdstring(path), G._this))


# Module: structures
#
cdef extern from "cpp/structures/Partition.h":
	cdef cppclass _Partition "NetworKit::Partition":
		_Partition() except +
		_Partition(index) except +
		_Partition(_Partition) except +
		_Partition(vector[index]) except +
		index subsetOf(index e) except +
		index extend() except +
		void remove(index e) except +
		void addToSubset(index s, index e) except +
		void moveToSubset(index s, index e) except +
		void toSingleton(index e) except +
		void allToSingletons() except +
		void mergeSubsets(index s, index t) except +
		void setUpperBound(index upper) except +
		index upperBound() except +
		index lowerBound() except +
		void compact(bool useTurbo) except +
		bool contains(index e) except +
		bool inSameSubset(index e1, index e2) except +
		vector[count] subsetSizes() except +
		map[index, count] subsetSizeMap() except +
		set[index] getMembers(const index s) except +
		count numberOfElements() except +
		count numberOfSubsets() except +
		vector[index] getVector() except +
		void setName(string name) except +
		string getName() except +
		set[index] getSubsetIds() except +
		index operator[](index) except +


cdef class Partition:
	""" Implements a partition of a set, i.e. a subdivision of the
 		set into disjoint subsets.

 		Partition(z=0)

 		Create a new partition data structure for `z` elements.

		Parameters
		----------
		size : index, optional
			Maximum index of an element. Default is 0.
	"""
	cdef _Partition _this

	def __cinit__(self, index size=0, vector[index] data=[]):
		if data.size() != 0:
			self._this = move(_Partition(data))
		else:
			self._this = move(_Partition(size))

	def __len__(self):
		"""
		Returns
		-------
		count
			Number of elements in the partition.
		"""
		return self._this.numberOfElements()

	def __getitem__(self, index e):
		""" Get the set (id) in which the element `e` is contained.

	 	Parameters
	 	----------
	 	e : index
	 		Index of element.

	 	Returns
	 	-------
	 	index
	 		The index of the set in which `e` is contained.
		"""
		return self._this.subsetOf(e)

	def __setitem__(self, index e, index s):
		""" Set the set (id) in which the element `e` is contained.

		Parameters
		----------
		e : index
			Index of the element
		s : index
			Index of the subset
		"""
		self._this.addToSubset(s, e)

	def __copy__(self):
		"""
		Generates a copy of the partition
		"""
		return Partition().setThis(_Partition(self._this))

	def __deepcopy__(self):
		"""
		Generates a copy of the partition
		"""
		return Partition().setThis(_Partition(self._this))

	cdef setThis(self,  _Partition& other):
		swap[_Partition](self._this,  other)
		return self

	def subsetOf(self, e):
		""" Get the set (id) in which the element `e` is contained.

	 	Parameters
	 	----------
	 	e : index
	 		Index of element.

	 	Returns
	 	-------
	 	index
	 		The index of the set in which `e` is contained.
		"""
		return self._this.subsetOf(e)

	def extend(self):
		""" Extend the data structure and create a slot	for one more element.

		Initializes the entry to `none` and returns the index of the entry.

		Returns
		-------
		index
			The index of the new element.
		"""
		return self._this.extend()

	def addToSubset(self, s, e):
		""" Add a (previously unassigned) element `e` to the set `s`.

		Parameters
		----------
		s : index
			The index of the subset.
		e : index
			The element to add.
		"""
		self._this.addToSubset(s, e)

	def moveToSubset(self, index s, index e):
		"""  Move the (previously assigned) element `e` to the set `s.

		Parameters
		----------
		s : index
			The index of the subset.
		e : index
			The element to move.
		"""
		self._this.moveToSubset(s, e)

	def toSingleton(self, index e):
		""" Creates a singleton set containing the element `e`.

		Parameters
		----------
		e : index
			The index of the element.
		"""
		self._this.toSingleton(e)

	def allToSingletons(self):
		""" Assigns every element to a singleton set. Set id is equal to element id. """
		self._this.allToSingletons()

	def mergeSubsets(self, index s, index t):
		""" Assigns the elements from both sets to a new set and returns the id of it.

		Parameters
		----------
		s : index
			Set to merge.
		t : index
			Set to merge.

		Returns
		-------
		index
			Id of newly created set.
		"""
		self._this.mergeSubsets(s, t)

	def setUpperBound(self, index upper):
		""" Sets an upper bound for the subset ids that **can** be assigned.

		Parameters
		----------
		upper : index
			Highest assigned subset id + 1
		"""
		self._this.setUpperBound(upper)

	def upperBound(self):
		""" Return an upper bound for the subset ids that have been assigned.
	 	(This is the maximum id + 1.)

	 	Returns
	 	-------
	 	index
	 		The upper bound.
		"""
		return self._this.upperBound()

	def lowerBound(self):
		""" Get a lower bound for the subset ids that have been assigned.

		Returns
		-------
		index
			The lower bound.
		"""
		return self._this.lowerBound()

	def compact(self, useTurbo = False):
		""" Change subset IDs to be consecutive, starting at 0.

		Parameters
		----------
		useTurbo : bool
			Default: false. If set to true, a vector instead of a map to assign new ids
	 		which results in a shorter running time but possibly a large space overhead.

		"""
		self._this.compact(useTurbo)

	def contains(self, index e):
		""" Check if partition assigns a valid subset to the element `e`.

		Parameters
		----------
		e : index
			The element.

		Returns
		-------
		bool
			True if the assigned subset is valid, False otherwise.
		"""
		return self._this.contains(e)

	def inSameSubset(self, index e1, index e2):
		""" Check if two elements `e1` and `e2` belong to the same subset.

		Parameters
		----------
		e1 : index
			An Element.
		e2 : index
			An Element.

		Returns
		-------
		bool
			True if `e1` and `e2` belong to same subset, False otherwise.
		"""
		return self._this.inSameSubset(e1, e2)

	def subsetSizes(self):
		""" Get a list of subset sizes. Indices do not necessarily correspond to subset ids.

	 	Returns
	 	-------
	 	vector
	 		A vector of subset sizes.
		"""
		return self._this.subsetSizes()

	def subsetSizeMap(self):
		""" Get a map from subset id to size of the subset.

		Returns
		-------
		dict
			A map from subset id to size of the subset.
		"""
		return self._this.subsetSizeMap()

	def getMembers(self, s):
		""" Get the members of the subset `s`.

		Parameters
		----------
		s : index
			The subset.

		Returns
		-------
		set
			A set containing the members of `s.
		"""
		return self._this.getMembers(s)

	def numberOfElements(self):
		"""
		Returns
		-------
		count
			Number of elements in the partition.
		"""
		return self._this.numberOfElements()

	def numberOfSubsets(self):
		""" Get the current number of sets in this partition.

		Returns
		-------
		count
			The current number of sets.
		"""
		return self._this.numberOfSubsets()

	def getVector(self):
		""" Get the actual vector representing the partition data structure.

		Returns
		-------
		vector
			Vector containing information about partitions.
		"""
		return self._this.getVector()

	def setName(self, string name):
		"""  Set a human-readable identifier `name` for the instance.

		Parameters
		----------
		name : string
			The name.
		"""
		self._this.setName(name)

	def getName(self):
		""" Get the human-readable identifier.

		Returns
		-------
		string
			The name of this partition.
		"""
		return self._this.getName()

	def getSubsetIds(self):
		""" Get the ids of nonempty subsets.

		Returns
		-------
		set
			A set of ids of nonempty subsets.
		"""
		return self._this.getSubsetIds()


cdef extern from "cpp/structures/Cover.h":
	cdef cppclass _Cover "NetworKit::Cover":
		_Cover() except +
		_Cover(_Partition p) except +
		_Cover(count n) except +
		set[index] subsetsOf(index e) except +
#		index extend() except +
		void remove(index e) except +
		void addToSubset(index s, index e) except +
		void removeFromSubset(index s, index e) except +
		void moveToSubset(index s, index e) except +
		void toSingleton(index e) except +
		void allToSingletons() except +
		void mergeSubsets(index s, index t) except +
		void setUpperBound(index upper) except +
		index upperBound() except +
		index lowerBound() except +
#		void compact() except +
		bool contains(index e) except +
		bool inSameSubset(index e1, index e2) except +
		vector[count] subsetSizes() except +
		map[index, count] subsetSizeMap() except +
		set[index] getMembers(const index s) except +
		count numberOfElements() except +
		count numberOfSubsets() except +
#		vector[index] getVector() except +
#		void setName(string name) except +
#		string getName() except +
		set[index] getSubsetIds() except +


cdef class Cover:
	""" Implements a cover of a set, i.e. an assignment of its elements to possibly overlapping subsets. """
	cdef _Cover _this

	def __cinit__(self, n=0):
		if isinstance(n, Partition):
			self._this = move(_Cover((<Partition>n)._this))
		else:
			self._this = move(_Cover(<count?>n))

	cdef setThis(self, _Cover& other):
		swap[_Cover](self._this, other)
		return self

	def subsetsOf(self, e):
		""" Get the ids of subsets in which the element `e` is contained.

		Parameters
		----------
		e : index
			An element

		Returns
		-------
		set
			A set of subset ids in which `e` 	is contained.
		"""
		return self._this.subsetsOf(e)

#	def extend(self):
#		self._this.extend()

	def addToSubset(self, s, e):
		""" Add the (previously unassigned) element `e` to the set `s`.

		Parameters
		----------
		s : index
			A subset
		e : index
			An element
		"""
		self._this.addToSubset(s, e)

	def removeFromSubset(self, s, e):
		""" Remove the element `e` from the set `s`.

		Parameters
		----------
		s : index
			A subset
		e : index
			An element
		"""
		self._this.removeFromSubset(s, e)

	def moveToSubset(self, index s, index e):
		""" Move the element `e` to subset `s`, i.e. remove it from all other subsets and place it in the subset.

		Parameters
		----------
		s : index
			A subset
		e : index
			An element
		"""
		self._this.moveToSubset(s, e)

	def toSingleton(self, index e):
		""" Creates a singleton set containing the element `e` and returns the index of the new set.

		Parameters
		----------
		e : index
			An element

		Returns
		-------
		index
			The index of the new set.
		"""
		self._this.toSingleton(e)

	def allToSingletons(self):
		""" Assigns every element to a singleton set. Set id is equal to element id. """
		self._this.allToSingletons()

	def mergeSubsets(self, index s, index t):
		""" Assigns the elements from both sets to a new set.

		Parameters
		----------
		s : index
			A subset
		t : index
			A subset
		"""
		self._this.mergeSubsets(s, t)

	def setUpperBound(self, index upper):
		self._this.setUpperBound(upper)

	def upperBound(self):
		""" Get an upper bound for the subset ids that have been assigned.
	   	(This is the maximum id + 1.)

	   	Returns
	   	-------
	   	index
	   		An upper bound.
		"""
		return self._this.upperBound()

	def lowerBound(self):
		""" Get a lower bound for the subset ids that have been assigned.

		Returns
		-------
		index
			A lower bound.
		"""
		return self._this.lowerBound()

#	def compact(self):
#		self._this.compact()

	def contains(self, index e):
		"""  Check if cover assigns a valid subset to the element `e`.

		Parameters
		----------
		e : index
			An element.

		Returns
		-------
		bool
			True, if `e` is assigned to a valid subset, False otherwise.

		"""
		return self._this.contains(e)

	def inSameSubset(self, index e1, index e2):
		"""  Check if two elements `e1` and `e2` belong to the same subset.

	 	Parameters
	 	----------
	 	e1 : index
			An element.
		e2 : index
			An element.

		Returns
		-------
		bool
			True, if `e1` and `e2` belong to the same subset, False otherwise.
		"""
		return self._this.inSameSubset(e1, e2)

	def subsetSizes(self):
		""" Get a list of subset sizes.

		Returns
		-------
		list
			A list of subset sizes.

		Notes
		-----
		Indices do not necessarily correspond to subset ids.
		"""
		return self._this.subsetSizes()

	def subsetSizeMap(self):
		""" Get a map from subset id to size of the subset.

	 	Returns
	 	-------
	 	dict
	 		A map from subset id to size of the subset.
		"""
		return self._this.subsetSizeMap()

	def getMembers(self, s):
		""" Get the members of a specific subset `s`.

		Returns
		-------
		set
			The set of members of subset `s`.
		"""
		return self._this.getMembers(s)

	def numberOfElements(self):
		""" Get the current number of elements in this cover.

		Returns
		-------
		count
			The current number of elements.
		"""
		return self._this.numberOfElements()

	def numberOfSubsets(self):
		"""  Get the current number of sets in this cover.

		Returns
		-------
		count
			The number of sets in this cover.
		"""
		return self._this.numberOfSubsets()

#	def getVector(self):
#		return self._this.getVector()

#	def setName(self, string name):
#		self._this.setName(name)

#	def getName(self):
#		return self._this.getName()

	def getSubsetIds(self):
		""" Get the ids of nonempty subsets.

		Returns
		-------
		set
			A set of ids of nonempty subsets.
		"""
		return self._this.getSubsetIds()


# Module: community

# Fused type for methods that accept both a partition and a cover
ctypedef fused PartitionCover:
	Partition
	Cover

cdef extern from "cpp/community/ClusteringGenerator.h":
	cdef cppclass _ClusteringGenerator "NetworKit::ClusteringGenerator":
		_ClusteringGenerator() except +
		_Partition makeSingletonClustering(_Graph G) except +
		_Partition makeOneClustering(_Graph G) except +
		_Partition makeRandomClustering(_Graph G, count k) except +
		_Partition makeContinuousBalancedClustering(_Graph G, count k) except +
		_Partition makeNoncontinuousBalancedClustering(_Graph G, count k) except +

cdef class ClusteringGenerator:
	""" Generators for various clusterings """
	cdef _ClusteringGenerator _this
	def makeSingletonClustering(self, Graph G):
		"""  Generate a clustering where each node has its own cluster

		Parameters
		----------
		G: Graph
			The graph for which the clustering shall be generated

		Returns
		-------
		Partition
			The generated partition
		"""
		return Partition().setThis(self._this.makeSingletonClustering(G._this))
	def makeOneClustering(self, Graph G):
		"""  Generate a clustering with one cluster consisting of all nodes

		Parameters
		----------
		G: Graph
			The graph for which the clustering shall be generated

		Returns
		-------
		Partition
			The generated partition
		"""
		return Partition().setThis(self._this.makeOneClustering(G._this))
	def makeRandomClustering(self, Graph G, count k):
		"""  Generate a clustering with `k` clusters to which nodes are assigned randomly

		Parameters
		----------
		G: Graph
			The graph for which the clustering shall be generated
		k: count
			The number of clusters that shall be generated

		Returns
		-------
		Partition
			The generated partition
		"""
		return Partition().setThis(self._this.makeRandomClustering(G._this, k))
	def makeContinuousBalancedClustering(self, Graph G, count k):
		"""  Generate a clustering with `k` clusters to which nodes are assigned in continuous blocks

		Parameters
		----------
		G: Graph
			The graph for which the clustering shall be generated
		k: count
			The number of clusters that shall be generated

		Returns
		-------
		Partition
			The generated partition
		"""
		return Partition().setThis(self._this.makeContinuousBalancedClustering(G._this, k))
	def makeNoncontinuousBalancedClustering(self, Graph G, count k):
		"""  Generate a clustering with `k` clusters, the ith node is assigned to cluster i % k. This means that
		for k**2 nodes, this clustering is complementary to the continuous clustering in the sense that no pair
		of nodes that is in the same cluster in one of the clusterings is in the same cluster in the other clustering.

		Parameters
		----------
		G: Graph
			The graph for which the clustering shall be generated
		k: count
			The number of clusters that shall be generated

		Returns
		-------
		Partition
			The generated partition
		"""
		return Partition().setThis(self._this.makeNoncontinuousBalancedClustering(G._this, k))

cdef extern from "cpp/community/GraphClusteringTools.h" namespace "NetworKit::GraphClusteringTools":
	float getImbalance(_Partition zeta) except +
	_Graph communicationGraph(_Graph graph, _Partition zeta) except +
	count weightedDegreeWithCluster(_Graph graph, _Partition zeta, node u, index cid)
	bool isProperClustering(_Graph G, _Partition zeta)
	bool isSingletonClustering(_Graph G, _Partition zeta)
	bool isOneClustering(_Graph G, _Partition zeta)
	bool equalClusterings(_Partition zeta, _Partition eta, _Graph G)

cdef class GraphClusteringTools:
	@staticmethod
	def getImbalance(Partition zeta):
		return getImbalance(zeta._this)
	@staticmethod
	def communicationGraph(Graph graph, Partition zeta):
		return Graph().setThis(communicationGraph(graph._this, zeta._this))
	@staticmethod
	def weightedDegreeWithCluster(Graph graph, Partition zeta, node u, index cid):
		return weightedDegreeWithCluster(graph._this, zeta._this, u, cid)
	@staticmethod
	def isProperClustering(Graph G, Partition zeta):
		return isProperClustering(G._this, zeta._this)
	@staticmethod
	def isSingletonClustering(Graph G, Partition zeta):
		return isSingletonClustering(G._this, zeta._this)
	@staticmethod
	def isOneClustering(Graph G, Partition zeta):
		return isOneClustering(G._this, zeta._this)
	@staticmethod
	def equalClustering(Partition zeta, Partition eta, Graph G):
		return equalClusterings(zeta._this, eta._this, G._this)

cdef extern from "cpp/graph/GraphTools.h" namespace "NetworKit::GraphTools":
	_Graph getCompactedGraph(_Graph G, unordered_map[node,node]) nogil except +
	unordered_map[node,node] getContinuousNodeIds(_Graph G) nogil except +
	unordered_map[node,node] getRandomContinuousNodeIds(_Graph G) nogil except +

cdef class GraphTools:
	@staticmethod
	def getCompactedGraph(Graph graph, nodeIdMap):
		"""
			Computes a graph with the same structure but with continuous node ids.
		"""
		cdef unordered_map[node,node] cNodeIdMap
		for key in nodeIdMap:
			cNodeIdMap[key] = nodeIdMap[key]
		return Graph().setThis(getCompactedGraph(graph._this,cNodeIdMap))

	@staticmethod
	def getContinuousNodeIds(Graph graph):
		"""
			Computes a map of node ids to continuous node ids.
		"""
		cdef unordered_map[node,node] cResult
		with nogil:
			cResult = getContinuousNodeIds(graph._this)
		result = dict()
		for elem in cResult:
			result[elem.first] = elem.second
		return result

	@staticmethod
	def getRandomContinuousNodeIds(Graph graph):
		"""
			Computes a map of node ids to continuous, randomly permutated node ids.
		"""
		cdef unordered_map[node,node] cResult
		with nogil:
			cResult = getRandomContinuousNodeIds(graph._this)
		result = dict()
		for elem in cResult:
			result[elem.first] = elem.second
		return result


cdef extern from "cpp/community/PartitionIntersection.h":
	cdef cppclass _PartitionIntersection "NetworKit::PartitionIntersection":
		_PartitionIntersection() except +
		_Partition calculate(_Partition zeta, _Partition eta) except +

cdef class PartitionIntersection:
	""" Class for calculating the intersection of two partitions, i.e. the clustering with the fewest clusters
	such that each cluster is a subset of a cluster in both partitions.
	"""
	cdef _PartitionIntersection _this
	def calculate(self, Partition zeta, Partition eta):
		"""  Calculate the intersection of two partitions `zeta` and `eta`

		Parameters
		----------
		zeta: Partition
			The first partition
		eta: Partition
			The second partition

		Returns
		-------
		Partition
			The intersection of zeta and eta
		"""
		return Partition().setThis(self._this.calculate(zeta._this, eta._this))

cdef extern from "cpp/community/Coverage.h":
	cdef cppclass _Coverage "NetworKit::Coverage":
		_Coverage() except +
		double getQuality(_Partition _zeta, _Graph _G) except +

cdef class Coverage:
	""" Coverage is the fraction of intra-community edges """
	cdef _Coverage _this

	def getQuality(self, Partition zeta, Graph G):
		return self._this.getQuality(zeta._this, G._this)


cdef extern from "cpp/community/EdgeCut.h":
	cdef cppclass _EdgeCut "NetworKit::EdgeCut":
		_EdgeCut() except +
		double getQuality(_Partition _zeta, _Graph _G) except +

cdef class EdgeCut:
	""" Edge cut is the total weight of inter-community edges"""
	cdef _EdgeCut _this

	def getQuality(self, Partition zeta, Graph G):
		return self._this.getQuality(zeta._this, G._this)


cdef extern from "cpp/community/Modularity.h":
	cdef cppclass _Modularity "NetworKit::Modularity":
		_Modularity() except +
		double getQuality(_Partition _zeta, _Graph _G) nogil except +


cdef class Modularity:
	"""	Modularity is a quality index for community detection.
	It assigns a quality value in [-0.5, 1.0] to a partition of a graph which is higher for more modular networks and
	partitions which better capture the modular structure. See also http://en.wikipedia.org/wiki/Modularity_(networks).

 	Notes
	-----
	Modularity is defined as:

	.. math:: mod(\zeta) := \\frac{\sum_{C \in \zeta} \sum_{ e \in E(C) } \omega(e)}{\sum_{e \in E} \omega(e)} - \\frac{ \sum_{C \in \zeta}( \sum_{v \in C} \omega(v) )^2 }{4( \sum_{e \in E} \omega(e) )^2 }

	"""
	cdef _Modularity _this

	def getQuality(self, Partition zeta, Graph G):
		cdef double ret
		with nogil:
			ret = self._this.getQuality(zeta._this, G._this)
		return ret

cdef extern from "cpp/community/HubDominance.h":
	cdef cppclass _HubDominance "NetworKit::HubDominance":
		_HubDominance() except +
		double getQuality(_Partition _zeta, _Graph _G) except +
		double getQuality(_Cover _zeta, _Graph _G) except +

cdef class HubDominance:
	"""
	A quality measure that measures the dominance of hubs in clusters. The hub dominance of a single
	cluster is defined as the maximum cluster-internal degree of a node in that cluster divided by
	the maximum cluster-internal degree, i.e. the number of nodes in the cluster minus one. The
	value for all clusters is defined as the average of all clusters.

	Strictly speaking this is not a quality measure as this is rather dependent on the type of the
	considered graph, for more information see
	Lancichinetti A, Kivelä M, Saramäki J, Fortunato S (2010)
	Characterizing the Community Structure of Complex Networks
	PLoS ONE 5(8): e11976. doi: 10.1371/journal.pone.0011976
	http://www.plosone.org/article/info%3Adoi%2F10.1371%2Fjournal.pone.0011976
	"""

	cdef _HubDominance _this

	def getQuality(self, PartitionCover zeta, Graph G):
		"""
		Calculates the dominance of hubs in the given Partition or Cover of the given
		Graph.

		Parameters
		----------
		zeta : Partition or Cover
			The Partition or Cover for which the hub dominance shall be calculated
		G : Graph
			The Graph to which zeta belongs

		Returns
		-------
		double
			The average hub dominance in the given Partition or Cover
		"""
		return self._this.getQuality(zeta._this, G._this)


cdef extern from "cpp/community/CommunityDetectionAlgorithm.h":
	cdef cppclass _CommunityDetectionAlgorithm "NetworKit::CommunityDetectionAlgorithm"(_Algorithm):
		_CommunityDetectionAlgorithm(const _Graph &_G)
		_Partition getPartition() except +


cdef class CommunityDetector(Algorithm):
	""" Abstract base class for static community detection algorithms """
	cdef Graph _G

	def __init__(self, *args, **namedargs):
		if type(self) == CommunityDetector:
			raise RuntimeError("Error, you may not use CommunityDetector directly, use a sub-class instead")

	def __dealloc__(self):
		self._G = None # just to be sure the graph is deleted

	def getPartition(self):
		"""  Returns a partition of the clustering.

		Returns
		-------
		Partition:
			A Partition of the clustering.
		"""
		if self._this == NULL:
			raise RuntimeError("Error, object not properly initialized")
		return Partition().setThis((<_CommunityDetectionAlgorithm*>(self._this)).getPartition())

cdef extern from "cpp/community/PLP.h":
	cdef cppclass _PLP "NetworKit::PLP"(_CommunityDetectionAlgorithm):
		_PLP(_Graph _G, count updateThreshold, count maxIterations) except +
		_PLP(_Graph _G, _Partition baseClustering, count updateThreshold) except +
		count numberOfIterations() except +
		vector[count] getTiming() except +


cdef class PLP(CommunityDetector):
	""" Parallel label propagation for community detection:
	Moderate solution quality, very short time to solution.

	Notes
	-----
	As described in Ovelgoenne et al: An Ensemble Learning Strategy for Graph Clustering
 	Raghavan et al. proposed a label propagation algorithm for graph clustering.
 	This algorithm initializes every vertex of a graph with a unique label. Then, in iterative
 	sweeps over the set of vertices the vertex labels are updated. A vertex gets the label
 	that the maximum number of its neighbors have. The procedure is stopped when every vertex
 	has the label that at least half of its neighbors have.
	"""

	def __cinit__(self, Graph G not None, count updateThreshold=none, count maxIterations=none, Partition baseClustering=None,):
		"""
		Constructor to the Parallel label propagation community detection algorithm.

		Parameters
		----------
		G : Graph
			The graph on which the algorithm has to run.
		updateThreshold : integer
			number of nodes that have to be changed in each iteration so that a new iteration starts.
		baseClustering : Partition
			PLP needs a base clustering to start from; if none is given the algorithm will run on a singleton clustering.
		"""
		self._G = G


		if baseClustering is None:
			self._this = new _PLP(G._this, updateThreshold, maxIterations)
		else:
			self._this = new _PLP(G._this, baseClustering._this, updateThreshold)


	def numberOfIterations(self):
		""" Get number of iterations in last run.

		Returns
		-------
		count
			The number of iterations.
		"""
		return (<_PLP*>(self._this)).numberOfIterations()

	def getTiming(self):
		""" Get list of running times for each iteration.

		Returns
		-------
		count
			The list of running times in milliseconds.
		"""
		return (<_PLP*>(self._this)).getTiming()

cdef extern from "cpp/community/LPDegreeOrdered.h":
	cdef cppclass _LPDegreeOrdered "NetworKit::LPDegreeOrdered"(_CommunityDetectionAlgorithm):
		_LPDegreeOrdered(_Graph _G) except +
		count numberOfIterations()

cdef class LPDegreeOrdered(CommunityDetector):
	""" Label propagation-based community detection algorithm which processes nodes in increasing order of node degree.	"""

	def __cinit__(self, Graph G not None):
		self._G = G
		self._this = new _LPDegreeOrdered(G._this)

	def numberOfIterations(self):
		""" Get number of iterations in last run.

		Returns
		-------
		count
			Number of iterations.
		"""
		return (<_LPDegreeOrdered*>(self._this)).numberOfIterations()



cdef extern from "cpp/community/PLM.h":
	cdef cppclass _PLM "NetworKit::PLM"(_CommunityDetectionAlgorithm):
		_PLM(_Graph _G) except +
		_PLM(_Graph _G, bool refine, double gamma, string par, count maxIter, bool turbo, bool recurse) except +
		map[string, vector[count]] getTiming() except +

cdef extern from "cpp/community/PLM.h" namespace "NetworKit::PLM":
	pair[_Graph, vector[node]] PLM_coarsen "NetworKit::PLM::coarsen" (const _Graph& G, const _Partition& zeta) except +
	_Partition PLM_prolong "NetworKit::PLM::prolong"(const _Graph& Gcoarse, const _Partition& zetaCoarse, const _Graph& Gfine, vector[node] nodeToMetaNode) except +


cdef class PLM(CommunityDetector):
	""" Parallel Louvain Method - the Louvain method, optionally extended to
		a full multi-level algorithm with refinement

		Parameters
		----------
		G : Graph
			A graph.
		refine : bool, optional
			Add a second move phase to refine the communities.
		gamma : double
			Multi-resolution modularity parameter:
			1.0 -> standard modularity
	 		0.0 -> one community
	 		2m 	-> singleton communities
		par : string
			parallelization strategy
		maxIter : count
			maximum number of iterations for move phase
		turbo : bool, optional
			faster but uses O(n) additional memory per thread
		recurse: bool, optional
			use recursive coarsening, see http://journals.aps.org/pre/abstract/10.1103/PhysRevE.89.049902 for some explanations (default: true)
	"""

	def __cinit__(self, Graph G not None, refine=False, gamma=1.0, par="balanced", maxIter=32, turbo=True, recurse=True):
		self._G = G
		self._this = new _PLM(G._this, refine, gamma, stdstring(par), maxIter, turbo, recurse)

	def getTiming(self):
		"""  Get detailed time measurements.
		"""
		return (<_PLM*>(self._this)).getTiming()

	@staticmethod
	def coarsen(Graph G, Partition zeta, bool parallel = False):
		cdef pair[_Graph, vector[node]] result = move(PLM_coarsen(G._this, zeta._this))
		return (Graph().setThis(result.first), result.second)

	@staticmethod
	def prolong(Graph Gcoarse, Partition zetaCoarse, Graph Gfine, vector[node] nodeToMetaNode):
		return Partition().setThis(PLM_prolong(Gcoarse._this, zetaCoarse._this, Gfine._this, nodeToMetaNode))

cdef extern from "cpp/community/CutClustering.h":
	cdef cppclass _CutClustering "NetworKit::CutClustering"(_CommunityDetectionAlgorithm):
		_CutClustering(_Graph _G) except +
		_CutClustering(_Graph _G, edgeweight alpha) except +

cdef extern from "cpp/community/CutClustering.h" namespace "NetworKit::CutClustering":
	map[double, _Partition] CutClustering_getClusterHierarchy "NetworKit::CutClustering::getClusterHierarchy"(const _Graph& G) nogil except +


cdef class CutClustering(CommunityDetector):
	"""
	Cut clustering algorithm as defined in
	Flake, Gary William; Tarjan, Robert E.; Tsioutsiouliklis, Kostas. Graph Clustering and Minimum Cut Trees.
	Internet Mathematics 1 (2003), no. 4, 385--408.

	Parameters
	----------
	G : Graph
	alpha : double
		The parameter for the cut clustering algorithm
	"""
	def __cinit__(self, Graph G not None,  edgeweight alpha):
		self._G = G
		self._this = new _CutClustering(G._this, alpha)

	@staticmethod
	def getClusterHierarchy(Graph G not None):
		""" Get the complete hierarchy with all possible parameter values.

		Each reported parameter value is the lower bound for the range in which the corresponding clustering is calculated by the cut clustering algorithm.

		Warning: all reported parameter values are slightly too high in order to avoid wrong clusterings because of numerical inaccuracies.
		Furthermore the completeness of the hierarchy cannot be guaranteed because of these inaccuracies.
		This implementation hasn't been optimized for performance.

		Parameters
		----------
		G : Graph
			The graph.

		Returns
		-------
		dict
			A dictionary with the parameter values as keys and the corresponding Partition instances as values
		"""
		cdef map[double, _Partition] result
		# FIXME: this probably copies the whole hierarchy because of exception handling, using move might fix this
		with nogil:
			result = CutClustering_getClusterHierarchy(G._this)
		pyResult = {}
		# FIXME: this code copies the partitions a lot!
		for res in result:
			pyResult[res.first] = Partition().setThis(res.second)
		return pyResult

cdef class DissimilarityMeasure:
	""" Abstract base class for partition/community dissimilarity measures """
	# TODO: use conventional class design of parametrized constructor, run-method and getters
	pass


cdef extern from "cpp/community/NodeStructuralRandMeasure.h":
	cdef cppclass _NodeStructuralRandMeasure "NetworKit::NodeStructuralRandMeasure":
		_NodeStructuralRandMeasure() except +
		double getDissimilarity(_Graph G, _Partition first, _Partition second) nogil except +

cdef class NodeStructuralRandMeasure(DissimilarityMeasure):
	""" The node-structural Rand measure assigns a similarity value in [0,1]
		to two partitions of a graph, by considering all pairs of nodes.
	"""
	cdef _NodeStructuralRandMeasure _this

	def getDissimilarity(self, Graph G, Partition first, Partition second):
		cdef double ret
		with nogil:
			ret = self._this.getDissimilarity(G._this, first._this, second._this)
		return ret


cdef extern from "cpp/community/GraphStructuralRandMeasure.h":
	cdef cppclass _GraphStructuralRandMeasure "NetworKit::GraphStructuralRandMeasure":
		_GraphStructuralRandMeasure() except +
		double getDissimilarity(_Graph G, _Partition first, _Partition second) nogil except +

cdef class GraphStructuralRandMeasure(DissimilarityMeasure):
	""" The graph-structural Rand measure assigns a similarity value in [0,1]
		to two partitions of a graph, by considering connected pairs of nodes.
	"""
	cdef _GraphStructuralRandMeasure _this

	def getDissimilarity(self, Graph G, Partition first, Partition second):
		cdef double ret
		with nogil:
			ret = self._this.getDissimilarity(G._this, first._this, second._this)
		return ret


cdef extern from "cpp/community/JaccardMeasure.h":
	cdef cppclass _JaccardMeasure "NetworKit::JaccardMeasure":
		_JaccardMeasure() except +
		double getDissimilarity(_Graph G, _Partition first, _Partition second) nogil except +

cdef class JaccardMeasure(DissimilarityMeasure):
	""" TODO:
	"""
	cdef _JaccardMeasure _this

	def getDissimilarity(self, Graph G, Partition first, Partition second):
		cdef double ret
		with nogil:
			ret = self._this.getDissimilarity(G._this, first._this, second._this)
		return ret

cdef extern from "cpp/community/NMIDistance.h":
	cdef cppclass _NMIDistance "NetworKit::NMIDistance":
		_NMIDistance() except +
		double getDissimilarity(_Graph G, _Partition first, _Partition second) nogil except +

cdef class NMIDistance(DissimilarityMeasure):
	""" The NMI distance assigns a similarity value in [0,1] to two partitions
		of a graph.
	"""
	cdef _NMIDistance _this

	def getDissimilarity(self, Graph G, Partition first, Partition second):
		cdef double ret
		with nogil:
			ret = self._this.getDissimilarity(G._this, first._this, second._this)
		return ret

cdef extern from "cpp/community/AdjustedRandMeasure.h":
	cdef cppclass _AdjustedRandMeasure "NetworKit::AdjustedRandMeasure":
		double getDissimilarity(_Graph G, _Partition first, _Partition second) nogil except +

cdef class AdjustedRandMeasure(DissimilarityMeasure):
	"""
	The adjusted rand dissimilarity measure as proposed by Huber and Arabie in "Comparing partitions" (http://link.springer.com/article/10.1007/BF01908075)
	"""
	cdef _AdjustedRandMeasure _this

	def getDissimilarity(self, Graph G not None, Partition first not None, Partition second not None):
		"""
		Get the adjust rand dissimilarity. Runs in O(n log(n)).

		Note that the dissimilarity can be larger than 1 if the partitions are more different than expected in the random model.

		Parameters
		----------
		G : Graph
			The graph on which the partitions shall be compared
		zeta : Partition
			The first partiton
		eta : Partition
			The second partition

		Returns
		-------
		double
			The adjusted rand dissimilarity
		"""
		cdef double ret
		with nogil:
			ret = self._this.getDissimilarity(G._this, first._this, second._this)
		return ret

cdef extern from "cpp/community/LocalCommunityEvaluation.h":
	cdef cppclass _LocalCommunityEvaluation "NetworKit::LocalCommunityEvaluation"(_Algorithm):
		double getWeightedAverage() except +
		double getUnweightedAverage() except +
		double getMaximumValue() except +
		double getMinimumValue() except +
		double getValue(index i) except +
		vector[double] getValues() except +
		bool isSmallBetter() except +

cdef class LocalCommunityEvaluation(Algorithm):
	"""
	Virtual base class of all evaluation methods for a single clustering which is based on the evaluation of single clusters.
	This is the base class both for Partitions as well as for Covers.
	"""
	def __init__(self, *args, **namedargs):
		if type(self) == LocalCommunityEvaluation:
			raise RuntimeError("Error, you may not use LocalCommunityEvaluation directly, use a sub-class instead")

	def getWeightedAverage(self):
		""" Get the average value weighted by cluster size.

		Returns
		-------
		double:
			The weighted average value.
		"""
		if self._this == NULL:
			raise RuntimeError("Error, object not properly initialized")
		return (<_LocalCommunityEvaluation*>(self._this)).getWeightedAverage()

	def getUnweightedAverage(self):
		""" Get the (unweighted) average value of all clusters.

		Returns
		-------
		double:
			The unweighted average value.
		"""
		if self._this == NULL:
			raise RuntimeError("Error, object not properly initialized")
		return (<_LocalCommunityEvaluation*>(self._this)).getUnweightedAverage()

	def getMaximumValue(self):
		""" Get the maximum value of all clusters.

		Returns
		-------
		double:
			The maximum value.
		"""
		if self._this == NULL:
			raise RuntimeError("Error, object not properly initialized")
		return (<_LocalCommunityEvaluation*>(self._this)).getMaximumValue()

	def getMinimumValue(self):
		""" Get the minimum value of all clusters.

		Returns
		-------
		double:
			The minimum value.
		"""
		if self._this == NULL:
			raise RuntimeError("Error, object not properly initialized")
		return (<_LocalCommunityEvaluation*>(self._this)).getMinimumValue()

	def getValue(self, index i):
		""" Get the value of the specified cluster.

		Parameters
		----------
		i : index
			The cluster to get the value for.

		Returns
		-------
		double:
			The value of cluster i.
		"""
		if self._this == NULL:
			raise RuntimeError("Error, object not properly initialized")
		return (<_LocalCommunityEvaluation*>(self._this)).getValue(i)

	def getValues(self):
		""" Get the values of all clusters.

		Returns
		-------
		list[double]:
			The values of all clusters.
		"""
		if self._this == NULL:
			raise RuntimeError("Error, object not properly initialized")
		return (<_LocalCommunityEvaluation*>(self._this)).getValues()

	def isSmallBetter(self):
		""" If small values are better (otherwise large values are better).

		Returns
		-------
		bool:
			If small values are better.
		"""
		if self._this == NULL:
			raise RuntimeError("Error, object not properly initialized")
		return (<_LocalCommunityEvaluation*>(self._this)).isSmallBetter()

cdef extern from "cpp/community/LocalPartitionEvaluation.h":
	cdef cppclass _LocalPartitionEvaluation "NetworKit::LocalPartitionEvaluation"(_LocalCommunityEvaluation):
		pass

cdef class LocalPartitionEvaluation(LocalCommunityEvaluation):
	"""
	Virtual base class of all evaluation methods for a single clustering which is based on the evaluation of single clusters.
	This is the base class for Partitions.
	"""
	cdef Graph _G
	cdef Partition _P

	def __init__(self, *args, **namedargs):
		if type(self) == LocalPartitionEvaluation:
			raise RuntimeError("Error, you may not use LocalPartitionEvaluation directly, use a sub-class instead")

	def __cinit__(self, Graph G not None, Partition P not None, *args, **namedargs):
		self._G = G
		self._P = P

	def __dealloc__(self):
		# Just to be sure that everything is properly deleted
		self._G = None
		self._P = None


cdef extern from "cpp/community/LocalCoverEvaluation.h":
	cdef cppclass _LocalCoverEvaluation "NetworKit::LocalCoverEvaluation"(_LocalCommunityEvaluation):
		pass


cdef class LocalCoverEvaluation(LocalCommunityEvaluation):
	"""
	Virtual base class of all evaluation methods for a single clustering which is based on the evaluation of single clusters.
	This is the base class for Covers.
	"""
	cdef Graph _G
	cdef Cover _C

	def __init__(self, *args, **namedargs):
		if type(self) == LocalCoverEvaluation:
			raise RuntimeError("Error, you may not use LocalCoverEvaluation directly, use a sub-class instead")

	def __cinit__(self, Graph G not None, Cover C not None, *args, **namedargs):
		self._G = G
		self._C = C

	def __dealloc__(self):
		# Just to be sure that everything is properly deleted
		self._G = None
		self._C = None

cdef extern from "cpp/community/IntrapartitionDensity.h":
	cdef cppclass _IntrapartitionDensity "NetworKit::IntrapartitionDensity"(_LocalPartitionEvaluation):
		_IntrapartitionDensity(_Graph G, _Partition P) except +
		double getGlobal() except +

cdef class IntrapartitionDensity(LocalPartitionEvaluation):
	"""
	The intra-cluster density of a partition is defined as the number of existing edges divided by the number of possible edges.
	The global value is the sum of all existing intra-cluster edges divided by the sum of all possible intra-cluster edges.

	Parameters
	----------
	G : Graph
		The graph on which the measure shall be evaluated
	P : Partition
		The partition that shall be evaluated
	"""
	def __cinit__(self):
		self._this = new _IntrapartitionDensity(self._G._this, self._P._this)

	def getGlobal(self):
		""" Get the global intra-cluster density.

		Returns
		-------
		double:
			The global intra-cluster density.
		"""
		if self._this == NULL:
			raise RuntimeError("Error, object not properly initialized")
		return (<_IntrapartitionDensity*>(self._this)).getGlobal()


cdef extern from "cpp/community/IsolatedInterpartitionConductance.h":
	cdef cppclass _IsolatedInterpartitionConductance "NetworKit::IsolatedInterpartitionConductance"(_LocalPartitionEvaluation):
		_IsolatedInterpartitionConductance(_Graph G, _Partition P) except +

cdef class IsolatedInterpartitionConductance(LocalPartitionEvaluation):
	"""
	Isolated inter-partition conductance is a measure for how well a partition
	(communtiy/cluster) is separated from the rest of the graph.

	The conductance of a partition is defined as the weight of the cut divided
	by the volume (the sum of the degrees) of the nodes in the partition or the
	nodes in the rest of the graph, whatever is smaller. Small values thus indicate
	that the cut is small compared to the volume of the smaller of the separated
	parts. For the whole partitions usually the maximum or the unweighted average
	is used.

	See also Experiments on Density-Constrained Graph Clustering,
	Robert Görke, Andrea Kappes and  Dorothea Wagner, JEA 2015:
	http://dx.doi.org/10.1145/2638551

	Parameters
	----------
	G : Graph
		The graph on which the measure shall be evaluated
	P : Partition
		The partition that shall be evaluated
	"""
	def __cinit__(self):
		self._this = new _IsolatedInterpartitionConductance(self._G._this, self._P._this)

cdef extern from "cpp/community/IsolatedInterpartitionExpansion.h":
	cdef cppclass _IsolatedInterpartitionExpansion "NetworKit::IsolatedInterpartitionExpansion"(_LocalPartitionEvaluation):
		_IsolatedInterpartitionExpansion(_Graph G, _Partition P) except +

cdef class IsolatedInterpartitionExpansion(LocalPartitionEvaluation):
	"""
	Isolated inter-partition expansion is a measure for how well a partition
	(communtiy/cluster) is separated from the rest of the graph.

	The expansion of a partition is defined as the weight of the cut divided
	by number of nodes in the partition or in the rest of the graph, whatever
	is smaller. Small values thus indicate that the cut is small compared to
	the size of the smaller of the separated parts. For the whole partitions
	usually the maximum or the unweighted average is used. Note that expansion
	values can be larger than 1.

	See also Experiments on Density-Constrained Graph Clustering,
	Robert Görke, Andrea Kappes and Dorothea Wagner, JEA 2015:
	http://dx.doi.org/10.1145/2638551

	Parameters
	----------
	G : Graph
		The graph on which the measure shall be evaluated
	P : Partition
		The partition that shall be evaluated
	"""
	def __cinit__(self):
		self._this = new _IsolatedInterpartitionExpansion(self._G._this, self._P._this)

cdef extern from "cpp/community/CoverHubDominance.h":
	cdef cppclass _CoverHubDominance "NetworKit::CoverHubDominance"(_LocalCoverEvaluation):
		_CoverHubDominance(_Graph G, _Cover C) except +

cdef class CoverHubDominance(LocalCoverEvaluation):
	"""
	A quality measure that measures the dominance of hubs in clusters. The hub dominance of a single
	cluster is defined as the maximum cluster-internal degree of a node in that cluster divided by
	the maximum cluster-internal degree, i.e. the number of nodes in the cluster minus one. The
	value for all clusters is defined as the average of all clusters.
	This implementation is a natural generalization of this measure for covers.
	Strictly speaking this is not a quality measure as this is rather dependent on the type of the
	considered graph, for more information see
	Lancichinetti A, Kivelä M, Saramäki J, Fortunato S (2010)
	Characterizing the Community Structure of Complex Networks
	PLoS ONE 5(8): e11976. doi: 10.1371/journal.pone.0011976
	http://www.plosone.org/article/info%3Adoi%2F10.1371%2Fjournal.pone.0011976

	Parameters
	----------
	G : Graph
		The graph on which the measure shall be evaluated
	C : Cover
		The cover that shall be evaluated
	"""
	def __cinit__(self):
		self._this = new _CoverHubDominance(self._G._this, self._C._this)

cdef extern from "cpp/community/PartitionHubDominance.h":
	cdef cppclass _PartitionHubDominance "NetworKit::PartitionHubDominance"(_LocalPartitionEvaluation):
		_PartitionHubDominance(_Graph G, _Partition C) except +

cdef class PartitionHubDominance(LocalPartitionEvaluation):
	"""
	A quality measure that measures the dominance of hubs in clusters. The hub dominance of a single
	cluster is defined as the maximum cluster-internal degree of a node in that cluster divided by
	the maximum cluster-internal degree, i.e. the number of nodes in the cluster minus one. The
	value for all clusters is defined as the average of all clusters.
	Strictly speaking this is not a quality measure as this is rather dependent on the type of the
	considered graph, for more information see
	Lancichinetti A, Kivelä M, Saramäki J, Fortunato S (2010)
	Characterizing the Community Structure of Complex Networks
	PLoS ONE 5(8): e11976. doi: 10.1371/journal.pone.0011976
	http://www.plosone.org/article/info%3Adoi%2F10.1371%2Fjournal.pone.0011976

	Parameters
	----------
	G : Graph
		The graph on which the measure shall be evaluated
	P : Partition
		The partition that shall be evaluated
	"""
	def __cinit__(self):
		self._this = new _PartitionHubDominance(self._G._this, self._P._this)

cdef extern from "cpp/community/PartitionFragmentation.h":
	cdef cppclass _PartitionFragmentation "NetworKit::PartitionFragmentation"(_LocalPartitionEvaluation):
		_PartitionFragmentation(_Graph G, _Partition C) except +

cdef class PartitionFragmentation(LocalPartitionEvaluation):
	"""
	This measure evaluates how fragmented a partition is. The fragmentation of a single cluster is defined as one minus the
	number of nodes in its maximum connected componented divided by its total number of nodes. Smaller values thus indicate a smaller fragmentation.

	Parameters
	----------
	G : Graph
		The graph on which the measure shall be evaluated
	P : Partition
		The partition that shall be evaluated
	"""
	def __cinit__(self):
		self._this = new _PartitionFragmentation(self._G._this, self._P._this)

cdef extern from "cpp/community/StablePartitionNodes.h":
	cdef cppclass _StablePartitionNodes "NetworKit::StablePartitionNodes"(_LocalPartitionEvaluation):
		_StablePartitionNodes(_Graph G, _Partition C) except +
		bool isStable(node u) except +

cdef class StablePartitionNodes(LocalPartitionEvaluation):
	"""
	Evaluates how stable a given partition is. A node is considered to be stable if it has strictly more connections
	to its own partition than to other partitions. Isolated nodes are considered to be stable.
	The value of a cluster is the percentage of stable nodes in the cluster.
	Larger values indicate that a clustering is more stable and thus better defined.

	Parameters
	----------
	G : Graph
		The graph on which the measure shall be evaluated
	P : Partition
		The partition that shall be evaluated
	"""
	def __cinit__(self):
		self._this = new _StablePartitionNodes(self._G._this, self._P._this)


	def isStable(self, node u):
		"""
		Check if a given node is stable, i.e. more connected to its own partition than to other partitions.

		Parameters
		----------
		u : node
			The node to check

		Returns
		-------
		bool
			If the node u is stable.
		"""
		if self._this == NULL:
			raise RuntimeError("Error, object not properly initialized")
		return (<_StablePartitionNodes*>(self._this)).isStable(u)

# Module: flows

cdef extern from "cpp/flow/EdmondsKarp.h":
	cdef cppclass _EdmondsKarp "NetworKit::EdmondsKarp":
		_EdmondsKarp(const _Graph &graph, node source, node sink) except +
		void run() nogil except +
		edgeweight getMaxFlow() const
		vector[node] getSourceSet() except +
		edgeweight getFlow(node u, node v) except +
		edgeweight getFlow(edgeid eid) const
		vector[edgeweight] getFlowVector() except +

cdef class EdmondsKarp:
	"""
	The EdmondsKarp class implements the maximum flow algorithm by Edmonds and Karp.

	Parameters
	----------
	graph : Graph
		The graph
	source : node
		The source node for the flow calculation
	sink : node
		The sink node for the flow calculation
	"""
	cdef _EdmondsKarp* _this
	cdef Graph _graph

	def __cinit__(self, Graph graph not None, node source, node sink):
		self._graph = graph # store reference of graph for memory management, so the graph is not deallocated before this object
		self._this = new _EdmondsKarp(graph._this, source, sink)

	def __dealloc__(self):
		del self._this

	def run(self):
		"""
		Computes the maximum flow, executes the EdmondsKarp algorithm
		"""
		with nogil:
			self._this.run()
		return self

	def getMaxFlow(self):
		"""
		Returns the value of the maximum flow from source to sink.

		Returns
		-------
		edgeweight
			The maximum flow value
		"""
		return self._this.getMaxFlow()

	def getSourceSet(self):
		"""
		Returns the set of the nodes on the source side of the flow/minimum cut.

		Returns
		-------
		list
			The set of nodes that form the (smallest) source side of the flow/minimum cut.
		"""
		return self._this.getSourceSet()

	def getFlow(self, node u, node v = none):
		"""
		Get the flow value between two nodes u and v or an edge identified by the edge id u.
		Warning: The variant with two edge ids is linear in the degree of u.

		Parameters
		----------
		u : node or edgeid
			The first node incident to the edge or the edge id
		v : node
			The second node incident to the edge (optional if edge id is specified)

		Returns
		-------
		edgeweight
			The flow on the specified edge
		"""
		if v == none: # Assume that node and edge ids are the same type
			return self._this.getFlow(u)
		else:
			return self._this.getFlow(u, v)

	def getFlowVector(self):
		"""
		Return a copy of the flow values of all edges.

		Returns
		-------
		list
			The flow values of all edges indexed by edge id
		"""
		return self._this.getFlowVector()

# Module: properties

cdef extern from "cpp/components/ConnectedComponents.h":
	cdef cppclass _ConnectedComponents "NetworKit::ConnectedComponents":
		_ConnectedComponents(_Graph G) except +
		void run() nogil except +
		count numberOfComponents() except +
		count componentOfNode(node query) except +
		_Partition getPartition() except +
		map[index, count] getComponentSizes() except +


cdef class ConnectedComponents:
	""" Determines the connected components and associated values for an undirected graph.

	ConnectedComponents(G)

	Create ConnectedComponents for Graph `G`.

	Parameters
	----------
	G : Graph
		The graph.
	"""
	cdef _ConnectedComponents* _this
	cdef Graph _G

	def __cinit__(self,  Graph G):
		self._G = G
		self._this = new _ConnectedComponents(G._this)

	def __dealloc__(self):
		del self._this

	def run(self):
		""" This method determines the connected components for the graph given in the constructor. """
		with nogil:
			self._this.run()
		return self

	def getPartition(self):
		""" Get a Partition that represents the components.

		Returns
		-------
		Partition
			A partition representing the found components.
		"""
		return Partition().setThis(self._this.getPartition())

	def numberOfComponents(self):
		""" Get the number of connected components.

		Returns
		-------
		count:
			The number of connected components.
		"""
		return self._this.numberOfComponents()

	def componentOfNode(self, v):
		"""  Get the the component in which node `v` is situated.

		v : node
			The node whose component is asked for.
		"""
		return self._this.componentOfNode(v)

	def getComponentSizes(self):
		return self._this.getComponentSizes()


cdef extern from "cpp/components/ParallelConnectedComponents.h":
	cdef cppclass _ParallelConnectedComponents "NetworKit::ParallelConnectedComponents":
		_ParallelConnectedComponents(_Graph G, bool coarsening) except +
		void run() nogil except +
		count numberOfComponents() except +
		count componentOfNode(node query) except +
		_Partition getPartition() except +


cdef class ParallelConnectedComponents:
	""" Determines the connected components and associated values for
		an undirected graph.
	"""
	cdef _ParallelConnectedComponents* _this
	cdef Graph _G

	def __cinit__(self,  Graph G, coarsening=True	):
		self._G = G
		self._this = new _ParallelConnectedComponents(G._this, coarsening)

	def __dealloc__(self):
		del self._this

	def run(self):
		with nogil:
			self._this.run()
		return self

	def getPartition(self):
		return Partition().setThis(self._this.getPartition())

	def numberOfComponents(self):
		return self._this.numberOfComponents()

	def componentOfNode(self, v):
		return self._this.componentOfNode(v)


cdef extern from "cpp/components/StronglyConnectedComponents.h":
	cdef cppclass _StronglyConnectedComponents "NetworKit::StronglyConnectedComponents":
		_StronglyConnectedComponents(_Graph G, bool iterativeAlgo) except +
		void run() nogil except +
		void runIteratively() nogil except +
		void runRecursively() nogil except +
		count numberOfComponents() except +
		count componentOfNode(node query) except +
		_Partition getPartition() except +


cdef class StronglyConnectedComponents:
	""" Determines the connected components and associated values for
		a directed graph.

		By default, the iterative implementation is used. If edges on the graph have been removed,
		you should switch to the recursive implementation.

		Parameters
		----------
		G : Graph
			The graph.
		iterativeAlgo : boolean
			Specifies which implementation to use, by default True for the iterative implementation.
	"""
	cdef _StronglyConnectedComponents* _this
	cdef Graph _G

	def __cinit__(self, Graph G, iterativeAlgo = True):
		self._G = G
		self._this = new _StronglyConnectedComponents(G._this, iterativeAlgo)

	def __dealloc__(self):
		del self._this

	def run(self):
		with nogil:
			self._this.run()
		return self

	def runIteratively(self):
		with nogil:
			self._this.runIteratively()
		return self

	def runRecursively(self):
		with nogil:
			self._this.runRecursively()
		return self

	def getPartition(self):
		return Partition().setThis(self._this.getPartition())

	def numberOfComponents(self):
		return self._this.numberOfComponents()

	def componentOfNode(self, v):
		return self._this.componentOfNode(v)



cdef extern from "cpp/global/ClusteringCoefficient.h" namespace "NetworKit::ClusteringCoefficient":
		double avgLocal(_Graph G, bool turbo) nogil except +
		double sequentialAvgLocal(_Graph G) nogil except +
		double approxAvgLocal(_Graph G, count trials) nogil except +
		double exactGlobal(_Graph G) nogil except +
		double approxGlobal(_Graph G, count trials) nogil except +

cdef class ClusteringCoefficient:
	@staticmethod
	def avgLocal(Graph G, bool turbo = False):
		"""
		DEPRECATED: Use centrality.LocalClusteringCoefficient and take average.

		This calculates the average local clustering coefficient of graph `G`. The graph may not contain self-loops.

		Parameters
		----------
		G : Graph
			The graph.

		Notes
		-----

		.. math:: c(G) := \\frac{1}{n} \sum_{u \in V} c(u)

		where

		.. math:: c(u) := \\frac{2 \cdot |E(N(u))| }{\deg(u) \cdot ( \deg(u) - 1)}

		"""
		cdef double ret
		with nogil:
			ret = avgLocal(G._this, turbo)
		return ret

	@staticmethod
	def sequentialAvgLocal(Graph G):
		""" This calculates the average local clustering coefficient of graph `G` using inherently sequential triangle counting.
		Parameters
		----------
		G : Graph
			The graph.

		Notes
		-----

		.. math:: c(G) := \\frac{1}{n} \sum_{u \in V} c(u)

		where

		.. math:: c(u) := \\frac{2 \cdot |E(N(u))| }{\deg(u) \cdot ( \deg(u) - 1)}

		"""
		cdef double ret
		with nogil:
			ret = sequentialAvgLocal(G._this)
		return ret

	@staticmethod
	def approxAvgLocal(Graph G, count trials):
		cdef double ret
		with nogil:
			ret = approxAvgLocal(G._this, trials)
		return ret

	@staticmethod
	def exactGlobal(Graph G):
		""" This calculates the global clustering coefficient. """
		cdef double ret
		with nogil:
			ret = exactGlobal(G._this)
		return ret

	@staticmethod
	def approxGlobal(Graph G, count trials):
		cdef double ret
		with nogil:
			ret = approxGlobal(G._this, trials)
		return ret

cdef extern from "cpp/distance/Diameter.h" namespace "NetworKit":
	cdef enum DiameterAlgo:
		automatic = 0
		exact = 1
		estimatedRange = 2
		estimatedSamples = 3
		estimatedPedantic = 4

class _DiameterAlgo(object):
	Automatic = automatic
	Exact = exact
	EstimatedRange = estimatedRange
	EstimatedSamples = estimatedSamples
	EstimatedPedantic = estimatedPedantic

cdef extern from "cpp/distance/Diameter.h" namespace "NetworKit::Diameter":
	cdef cppclass _Diameter "NetworKit::Diameter"(_Algorithm):
		_Diameter(_Graph G, DiameterAlgo algo, double error, count nSamples) except +
		pair[count, count] getDiameter() nogil except +

cdef class Diameter(Algorithm):
	cdef Graph _G
	"""
	TODO: docstring
	"""
	def __cinit__(self, Graph G not None, algo = _DiameterAlgo.Automatic, error = -1., nSamples = 0):
		self._G = G
		self._this = new _Diameter(G._this, algo, error, nSamples)

	def getDiameter(self):
		return (<_Diameter*>(self._this)).getDiameter()


cdef extern from "cpp/distance/Eccentricity.h" namespace "NetworKit::Eccentricity":
	pair[node, count] getValue(_Graph G, node v) except +

cdef class Eccentricity:
	"""
	TODO: docstring
	"""

	@staticmethod
	def getValue(Graph G, v):
		return getValue(G._this, v)


cdef extern from "cpp/distance/EffectiveDiameter.h" namespace "NetworKit::EffectiveDiameter":
	cdef cppclass _EffectiveDiameter "NetworKit::EffectiveDiameter"(_Algorithm):
		_EffectiveDiameter(_Graph& G, double ratio) except +
		void run() nogil except +
		double getEffectiveDiameter() except +

cdef class EffectiveDiameter(Algorithm):
	"""
	Calculates the effective diameter of a graph.
	The effective diameter is defined as the number of edges on average to reach a given ratio of all other nodes.

	Parameters
	----------
	G : Graph
		The graph.
	ratio : double
		The percentage of nodes that shall be within stepwidth; default = 0.9
	"""
	cdef Graph _G

	def __cinit__(self, Graph G not None, double ratio=0.9):
		self._G = G
		self._this = new _EffectiveDiameter(G._this, ratio)

	def getEffectiveDiameter(self):
		"""
		Returns
		-------
		double
			the effective diameter
		"""
		return (<_EffectiveDiameter*>(self._this)).getEffectiveDiameter()


cdef extern from "cpp/distance/EffectiveDiameterApproximation.h" namespace "NetworKit::EffectiveDiameterApproximation":
	cdef cppclass _EffectiveDiameterApproximation "NetworKit::EffectiveDiameterApproximation"(_Algorithm):
		_EffectiveDiameterApproximation(_Graph& G, double ratio, count k, count r) except +
		void run() nogil except +
		double getEffectiveDiameter() except +

cdef class EffectiveDiameterApproximation(Algorithm):
	"""
	Calculates the effective diameter of a graph.
	The effective diameter is defined as the number of edges on average to reach a given ratio of all other nodes.

	Implementation after the ANF algorithm presented in the paper "A Fast and Scalable Tool for Data Mining in Massive Graphs"[1]

	[1] by Palmer, Gibbons and Faloutsos which can be found here: http://www.cs.cmu.edu/~christos/PUBLICATIONS/kdd02-anf.pdf

	Parameters
	----------
	G : Graph
		The graph.
	ratio : double
		The percentage of nodes that shall be within stepwidth, default = 0.9
	k : count
		number of parallel approximations, bigger k -> longer runtime, more precise result; default = 64
	r : count
		number of additional bits, important in tiny graphs; default = 7
	"""
	cdef Graph _G

	def __cinit__(self, Graph G not None, double ratio=0.9, count k=64, count r=7):
		self._G = G
		self._this = new _EffectiveDiameterApproximation(G._this, ratio, k, r)

	def getEffectiveDiameter(self):
		"""
		Returns
		-------
		double
			the approximated effective diameter
		"""
		return (<_EffectiveDiameterApproximation*>(self._this)).getEffectiveDiameter()


cdef extern from "cpp/distance/HopPlotApproximation.h" namespace "NetworKit::HopPlotApproximation":
	cdef cppclass _HopPlotApproximation "NetworKit::HopPlotApproximation"(_Algorithm):
		_HopPlotApproximation(_Graph& G, count maxDistance, count k, count r) except +
		void run() nogil except +
		map[count, double] getHopPlot() except +

cdef class HopPlotApproximation(Algorithm):
	"""
	Computes an approxmation of the hop-plot of a given graph.
	The hop-plot is the set of pairs (d, g(g)) for each natural number d
	and where g(d) is the fraction of connected node pairs whose shortest connecting path has length at most d.

	Implementation after the ANF algorithm presented in the paper "A Fast and Scalable Tool for Data Mining in Massive Graphs"[1]

	[1] by Palmer, Gibbons and Faloutsos which can be found here: http://www.cs.cmu.edu/~christos/PUBLICATIONS/kdd02-anf.pdf

	Parameters
	----------
	G : Graph
		The graph.
	maxDistance : double
		maximum distance between considered nodes
		set to 0 or negative to get the hop-plot for the entire graph so that each node can reach each other node
	k : count
		number of parallel approximations, bigger k -> longer runtime, more precise result; default = 64
	r : count
		number of additional bits, important in tiny graphs; default = 7
	"""
	cdef Graph _G

	def __cinit__(self, Graph G not None, count maxDistance=0, count k=64, count r=7):
		self._G = G
		self._this = new _HopPlotApproximation(G._this, maxDistance, k, r)

	def getHopPlot(self):
		"""
		Returns
		-------
		map
			number of connected nodes for each distance
		"""
		cdef map[count, double] hp = (<_HopPlotApproximation*>(self._this)).getHopPlot()
		result = dict()
		for elem in hp:
			result[elem.first] = elem.second
		return result


cdef extern from "cpp/distance/NeighborhoodFunction.h" namespace "NetworKit::NeighborhoodFunction":
	cdef cppclass _NeighborhoodFunction "NetworKit::NeighborhoodFunction"(_Algorithm):
		_NeighborhoodFunction(_Graph& G) except +
		void run() nogil except +
		vector[count] getNeighborhoodFunction() except +

cdef class NeighborhoodFunction(Algorithm):
	"""
	Computes the neighborhood function exactly.
	The neighborhood function N of a graph G for a given distance t is defined
	as the number of node pairs (u,v) that can be reached within distance t.

	Parameters
	----------
	G : Graph
		The graph.
	"""
	cdef Graph _G

	def __cinit__(self, Graph G not None):
		self._G = G
		self._this = new _NeighborhoodFunction(G._this)

	def getNeighborhoodFunction(self):
		"""
		Returns
		-------
		list
			the i-th element denotes the number of node pairs that have a distance at most (i+1)
		"""
		return (<_NeighborhoodFunction*>(self._this)).getNeighborhoodFunction()


cdef extern from "cpp/distance/NeighborhoodFunctionApproximation.h" namespace "NetworKit::NeighborhoodFunctionApproximation":
	cdef cppclass _NeighborhoodFunctionApproximation "NetworKit::NeighborhoodFunctionApproximation"(_Algorithm):
		_NeighborhoodFunctionApproximation(_Graph& G, count k, count r) except +
		void run() nogil except +
		vector[count] getNeighborhoodFunction() except +

cdef class NeighborhoodFunctionApproximation(Algorithm):
	"""
	Computes an approximation of the neighborhood function.
	The neighborhood function N of a graph G for a given distance t is defined
	as the number of node pairs (u,v) that can be reached within distance t.

	Implementation after the ANF algorithm presented in the paper "A Fast and Scalable Tool for Data Mining in Massive Graphs"[1]

	[1] by Palmer, Gibbons and Faloutsos which can be found here: http://www.cs.cmu.edu/~christos/PUBLICATIONS/kdd02-anf.pdf

	Parameters
	----------
	G : Graph
		The graph.
	k : count
		number of approximations, bigger k -> longer runtime, more precise result; default = 64
	r : count
		number of additional bits, important in tiny graphs; default = 7
	"""
	cdef Graph _G

	def __cinit__(self, Graph G not None, count k=64, count r=7):
		self._G = G
		self._this = new _NeighborhoodFunctionApproximation(G._this, k, r)

	def getNeighborhoodFunction(self):
		"""
		Returns
		-------
		list
			the i-th element denotes the number of node pairs that have a distance at most (i+1)
		"""
		return (<_NeighborhoodFunctionApproximation*>(self._this)).getNeighborhoodFunction()

cdef extern from "cpp/distance/NeighborhoodFunctionHeuristic.h" namespace "NetworKit::NeighborhoodFunctionHeuristic::SelectionStrategy":
	enum _SelectionStrategy "NetworKit::NeighborhoodFunctionHeuristic::SelectionStrategy":
		RANDOM
		SPLIT

cdef extern from "cpp/distance/NeighborhoodFunctionHeuristic.h" namespace "NetworKit::NeighborhoodFunctionHeuristic":
	cdef cppclass _NeighborhoodFunctionHeuristic "NetworKit::NeighborhoodFunctionHeuristic"(_Algorithm):
		_NeighborhoodFunctionHeuristic(_Graph& G, const count nSamples, const _SelectionStrategy strategy) except +
		void run() nogil except +
		vector[count] getNeighborhoodFunction() except +

cdef class NeighborhoodFunctionHeuristic(Algorithm):
	"""
	Computes a heuristic of the neighborhood function.
	The algorithm runs nSamples breadth-first searches and scales the results up to the actual amount of nodes.
	Accepted strategies are "split" and "random".

	Parameters
	----------
	G : Graph
		The graph.
	nSamples : count
		the amount of samples, set to zero for heuristic of max(sqrt(m), 0.15*n)
	strategy : enum
		the strategy to select the samples, accepts "random" or "split"
	"""
	cdef Graph _G

	RANDOM = 0
	SPLIT = 1

	def __cinit__(self, Graph G not None, count nSamples=0, strategy=SPLIT):
		self._G = G
		self._this = new _NeighborhoodFunctionHeuristic(G._this, nSamples, strategy)

	def getNeighborhoodFunction(self):
		"""
		Returns
		-------
		list
			the i-th element denotes the number of node pairs that have a distance at most (i+1)
		"""
		return (<_NeighborhoodFunctionHeuristic*>(self._this)).getNeighborhoodFunction()


cdef extern from "cpp/correlation/Assortativity.h":
	cdef cppclass _Assortativity "NetworKit::Assortativity"(_Algorithm):
		_Assortativity(_Graph, vector[double]) except +
		_Assortativity(_Graph, _Partition) except +
		void run() nogil except +
		double getCoefficient() except +

cdef class Assortativity(Algorithm):
	""" """
	cdef Graph G
	cdef vector[double] attribute
	cdef Partition partition

	def __cinit__(self, Graph G, data):
		if isinstance(data, Partition):
			self._this = new _Assortativity(G._this, (<Partition>data)._this)
			self.partition = <Partition>data
		else:
			self.attribute = <vector[double]?>data
			self._this = new _Assortativity(G._this, self.attribute)
		self.G = G

	def getCoefficient(self):
		return (<_Assortativity*>(self._this)).getCoefficient()

# Module: centrality

cdef extern from "cpp/centrality/Centrality.h":
	cdef cppclass _Centrality "NetworKit::Centrality"(_Algorithm):
		_Centrality(_Graph, bool, bool) except +
		vector[double] scores() except +
		vector[pair[node, double]] ranking() except +
		double score(node) except +
		double maximum() except +
		double centralization() except +


cdef class Centrality(Algorithm):
	""" Abstract base class for centrality measures"""

	cdef Graph _G

	def __init__(self, *args, **kwargs):
		if type(self) == Centrality:
			raise RuntimeError("Error, you may not use Centrality directly, use a sub-class instead")

	def __dealloc__(self):
		self._G = None # just to be sure the graph is deleted

	def scores(self):
		if self._this == NULL:
			raise RuntimeError("Error, object not properly initialized")
		return (<_Centrality*>(self._this)).scores()

	def score(self, v):
		if self._this == NULL:
			raise RuntimeError("Error, object not properly initialized")
		return (<_Centrality*>(self._this)).score(v)

	def ranking(self):
		if self._this == NULL:
			raise RuntimeError("Error, object not properly initialized")
		return (<_Centrality*>(self._this)).ranking()

	def maximum(self):
		if self._this == NULL:
			raise RuntimeError("Error, object not properly initialized")
		return (<_Centrality*>(self._this)).maximum()

	def centralization(self):
		"""
		Compute the centralization of a network with respect to some centrality measure.

	 	The centralization of any network is a measure of how central its most central
	 	node is in relation to how central all the other nodes are.
	 	Centralization measures then (a) calculate the sum in differences
	 	in centrality between the most central node in a network and all other nodes;
	 	and (b) divide this quantity by the theoretically largest such sum of
	 	differences in any network of the same size.
		"""
		if self._this == NULL:
			raise RuntimeError("Error, object not properly initialized")
		return (<_Centrality*>(self._this)).centralization()

cdef extern from "cpp/centrality/TopCloseness.h":
	cdef cppclass _TopCloseness "NetworKit::TopCloseness":
		_TopCloseness(_Graph G, count, bool, bool) except +
		void run() except +
		node maximum() except +
		edgeweight maxSum() except +
		count iterations() except +
		count operations() except +
		vector[node] topkNodesList() except +
		vector[edgeweight] topkScoresList() except +


cdef class TopCloseness:
	"""
	Finds the top k nodes with highest closeness centrality faster than computing it for all nodes, based on "Computing Top-k Closeness Centrality Faster in Unweighted Graphs", Bergamini et al., ALENEX16.
	The algorithms is based on two independent heuristics, described in the referenced paper. We recommend to use first_heu = true and second_heu = false for complex networks and first_heu = true and second_heu = true for street networks or networks with large diameters.

	Parameters
	----------
	G: An unweighted graph.
	k: Number of nodes with highest closeness that have to be found. For example, if k = 10, the top 10 nodes with highest closeness will be computed.
	first_heu: If true, the neighborhood-based lower bound is computed and nodes are sorted according to it. If false, nodes are simply sorted by degree.
	sec_heu: If true, the BFSbound is re-computed at each iteration. If false, BFScut is used.
	"""
	cdef _TopCloseness* _this
	cdef Graph _G

	def __cinit__(self,  Graph G, k=1, first_heu=True, sec_heu=True):
		self._G = G
		self._this = new _TopCloseness(G._this, k, first_heu, sec_heu)

	def __dealloc__(self):
		del self._this

	def run(self):
		""" Computes top-k closeness. """
		self._this.run()
		return self

	""" Returns a list with the k nodes with highest closeness.
	Returns
	-------
	vector
		The k nodes with highest closeness.
	"""
	def topkNodesList(self):
		return self._this.topkNodesList()


	""" Returns a list with the scores of the k nodes with highest closeness.
	Returns
	-------
	vector
		The k highest closeness scores.
	"""
	def topkScoresList(self):
		return self._this.topkScoresList()


cdef extern from "cpp/centrality/DegreeCentrality.h":
	cdef cppclass _DegreeCentrality "NetworKit::DegreeCentrality" (_Centrality):
		_DegreeCentrality(_Graph, bool normalized, bool outdeg, bool ignoreSelfLoops) except +

cdef class DegreeCentrality(Centrality):
	""" Node centrality index which ranks nodes by their degree.
 	Optional normalization by maximum degree.

 	DegreeCentrality(G, normalized=False)

 	Constructs the DegreeCentrality class for the given Graph `G`. If the scores should be normalized,
 	then set `normalized` to True.

 	Parameters
 	----------
 	G : Graph
 		The graph.
 	normalized : bool, optional
 		Normalize centrality values in the interval [0,1].
	"""

	def __cinit__(self, Graph G, bool normalized=False, bool outDeg = True, bool ignoreSelfLoops=True):
		self._G = G
		self._this = new _DegreeCentrality(G._this, normalized, outDeg, ignoreSelfLoops)



cdef extern from "cpp/centrality/Betweenness.h":
	cdef cppclass _Betweenness "NetworKit::Betweenness" (_Centrality):
		_Betweenness(_Graph, bool, bool) except +
		vector[double] edgeScores() except +

cdef class Betweenness(Centrality):
	"""
		Betweenness(G, normalized=False, computeEdgeCentrality=False)

		Constructs the Betweenness class for the given Graph `G`. If the betweenness scores should be normalized,
  		then set `normalized` to True.

	 	Parameters
	 	----------
	 	G : Graph
	 		The graph.
	 	normalized : bool, optional
	 		Set this parameter to True if scores should be normalized in the interval [0,1].
		computeEdgeCentrality: bool, optional
			Set this to true if edge betweenness scores should be computed as well.
	"""

	def __cinit__(self, Graph G, normalized=False, computeEdgeCentrality=False):
		self._G = G
		self._this = new _Betweenness(G._this, normalized, computeEdgeCentrality)


	def edgeScores(self):
		""" Get a vector containing the betweenness score for each edge in the graph.

		Returns
		-------
		vector
			The betweenness scores calculated by run().
		"""
		return (<_Betweenness*>(self._this)).edgeScores()


cdef extern from "cpp/centrality/Closeness.h":
	cdef cppclass _Closeness "NetworKit::Closeness" (_Centrality):
		_Closeness(_Graph, bool, bool) except +

cdef class Closeness(Centrality):
	"""
		Closeness(G, normalized=False, checkConnectedness=True)

		Constructs the Closeness class for the given Graph `G`. If the Closeness scores should be normalized,
  		then set `normalized` to True.

	 	Parameters
	 	----------
	 	G : Graph
	 		The graph.
	 	normalized : bool, optional
	 		Set this parameter to True if scores should be normalized in the interval [0,1]. Normalization only for unweighted networks.
	 	checkConnectedness : bool, optional
			turn this off if you know the graph is connected
	"""

	def __cinit__(self, Graph G, normalized=False, checkConnectedness=True):
		self._G = G
		self._this = new _Closeness(G._this, normalized, checkConnectedness)


cdef extern from "cpp/centrality/KPathCentrality.h":
	cdef cppclass _KPathCentrality "NetworKit::KPathCentrality" (_Centrality):
		_KPathCentrality(_Graph, double, count) except +

cdef class KPathCentrality(Centrality):
	"""
		KPathCentrality(G, alpha=0.2, k=0)

		Constructs the K-Path Centrality class for the given Graph `G`.

	 	Parameters
	 	----------
	 	G : Graph
	 		The graph.
	 	alpha : double, in interval [-0.5, 0.5]
			tradeoff between runtime and precision
			-0.5: maximum precision, maximum runtime
	 		 0.5: lowest precision, lowest runtime
	"""

	def __cinit__(self, Graph G, alpha=0.2, k=0):
		self._G = G
		self._this = new _KPathCentrality(G._this, alpha, k)


cdef extern from "cpp/centrality/KatzCentrality.h":
	cdef cppclass _KatzCentrality "NetworKit::KatzCentrality" (_Centrality):
		_KatzCentrality(_Graph, double, double, double) except +

cdef class KatzCentrality(Centrality):
	"""
		KatzCentrality(G, alpha=5e-4, beta=0.1, tol=1e-8)

		Constructs a KatzCentrality object for the given Graph `G`

	 	Parameters
	 	----------
	 	G : Graph
	 		The graph.
	 	alpha : double
			Damping of the matrix vector product result
		beta : double
			Constant value added to the centrality of each vertex
		tol : double
			The tolerance for convergence.
	"""

	def __cinit__(self, Graph G, alpha=0.2, beta=0.1, tol=1e-8):
		self._G = G
		self._this = new _KatzCentrality(G._this, alpha, beta, tol)




cdef extern from "cpp/centrality/ApproxBetweenness.h":
	cdef cppclass _ApproxBetweenness "NetworKit::ApproxBetweenness" (_Centrality):
		_ApproxBetweenness(_Graph, double, double, double) except +
		count numberOfSamples() except +

cdef class ApproxBetweenness(Centrality):
	""" Approximation of betweenness centrality according to algorithm described in
 	Matteo Riondato and Evgenios M. Kornaropoulos: Fast Approximation of Betweenness Centrality through Sampling

 	ApproxBetweenness(G, epsilon=0.01, delta=0.1, universalConstant=1.0)

 	The algorithm approximates the betweenness of all vertices so that the scores are
	within an additive error epsilon with probability at least (1- delta).
	The values are normalized by default.

	Parameters
	----------
	G : Graph
		the graph
	epsilon : double, optional
		maximum additive error
	delta : double, optional
		probability that the values are within the error guarantee
	diameterSamples: count, optional
		if 0 (the default), use the possibly slow estimation of the
		vertex diameter which definitely  guarantees approximation
		quality. Otherwise, use a fast heuristic that has a higher
		chance of getting the estimate right the higher the number of
		samples (note: there is no approximation guarantee when using
		the heuristic).
	universalConstant: double, optional
		the universal constant to be used in computing the sample size.
		It is 1 by default. Some references suggest using 0.5, but there
		is no guarantee in this case.
	"""

	def __cinit__(self, Graph G, epsilon=0.1, delta=0.1, universalConstant=1.0):
		self._G = G
		self._this = new _ApproxBetweenness(G._this, epsilon, delta, universalConstant)

	def numberOfSamples(self):
		return (<_ApproxBetweenness*>(self._this)).numberOfSamples()



cdef extern from "cpp/centrality/ApproxBetweenness2.h":
	cdef cppclass _ApproxBetweenness2 "NetworKit::ApproxBetweenness2" (_Centrality):
		_ApproxBetweenness2(_Graph, count, bool, bool) except +


cdef class ApproxBetweenness2(Centrality):
	""" Approximation of betweenness centrality according to algorithm described in
	Sanders, Geisberger, Schultes: Better Approximation of Betweenness Centrality

	ApproxBetweenness2(G, nSamples, normalized=False)

	The algorithm approximates the betweenness of all nodes, using weighting
	of the contributions to avoid biased estimation.

	Parameters
	----------
	G : Graph
		input graph
	nSamples : count
		user defined number of samples
	normalized : bool, optional
		normalize centrality values in interval [0,1]
	parallel : bool, optional
		run in parallel with additional memory cost z + 3z * t
	"""

	def __cinit__(self, Graph G, nSamples, normalized=False, parallel=False):
		self._G = G
		self._this = new _ApproxBetweenness2(G._this, nSamples, normalized, parallel)



cdef extern from "cpp/centrality/ApproxCloseness.h":
	enum _ClosenessType "NetworKit::ApproxCloseness::CLOSENESS_TYPE":
		INBOUND,
		OUTBOUND,
		SUM

cdef extern from "cpp/centrality/ApproxCloseness.h":
	cdef cppclass _ApproxCloseness "NetworKit::ApproxCloseness" (_Centrality):
		_ClosenessType type
		_ApproxCloseness(_Graph, count, float, bool, _ClosenessType type) except +
		vector[double] getSquareErrorEstimates() except +



cdef class ApproxCloseness(Centrality):
	""" Approximation of closeness centrality according to algorithm described in
  Cohen et al., Computing Classic Closeness Centrality, at Scale.

	ApproxCloseness(G, nSamples, epsilon=0.1, normalized=False, type=OUTBOUND)

	The algorithm approximates the closeness of all nodes in both directed and undirected graphs using a hybrid estimator.
	First, it takes nSamples samples. For these sampled nodes, the closeness is computed exactly. The pivot of each of the
	remaining nodes is the closest sampled node to it. If a node lies very close to its pivot, a sampling approach is used.
	Otherwise, a pivoting approach is used. Notice that the input graph has to be connected.

	Parameters
	----------
	G : Graph
		input graph (undirected)
	nSamples : count
		user defined number of samples
	epsilon : double, optional
		parameter used for the error guarantee; it is also used to control when to use sampling and when to use pivoting
	normalized : bool, optional
		normalize centrality values in interval [0,1]
	type : _ClosenessType, optional
		use in- or outbound centrality or the sum of both (see paper) for computing closeness on directed graph. If G is undirected, this can be ignored.
	"""

	#cdef _ApproxCloseness _this
	INBOUND = 0
	OUTBOUND = 1
	SUM = 2

	def __cinit__(self, Graph G, nSamples, epsilon=0.1, normalized=False, _ClosenessType type=OUTBOUND):
		self._G = G
		self._this = new _ApproxCloseness(G._this, nSamples, epsilon, normalized, type)

	def getSquareErrorEstimates(self):
		""" Return a vector containing the square error estimates for all nodes.

		Returns
		-------
		vector
			A vector of doubles.
		"""
		return (<_ApproxCloseness*>(self._this)).getSquareErrorEstimates()



cdef extern from "cpp/centrality/PageRank.h":
	cdef cppclass _PageRank "NetworKit::PageRank" (_Centrality):
		_PageRank(_Graph, double damp, double tol) except +

cdef class PageRank(Centrality):
	"""	Compute PageRank as node centrality measure.

	PageRank(G, damp=0.85, tol=1e-9)

	Parameters
	----------
	G : Graph
		Graph to be processed.
	damp : double
		Damping factor of the PageRank algorithm.
	tol : double, optional
		Error tolerance for PageRank iteration.
	"""

	def __cinit__(self, Graph G, double damp=0.85, double tol=1e-9):
		self._G = G
		self._this = new _PageRank(G._this, damp, tol)



cdef extern from "cpp/centrality/EigenvectorCentrality.h":
	cdef cppclass _EigenvectorCentrality "NetworKit::EigenvectorCentrality" (_Centrality):
		_EigenvectorCentrality(_Graph, double tol) except +

cdef class EigenvectorCentrality(Centrality):
	"""	Computes the leading eigenvector of the graph's adjacency matrix (normalized in 2-norm).
	Interpreted as eigenvector centrality score.

	EigenvectorCentrality(G, tol=1e-9)

	Constructs the EigenvectorCentrality class for the given Graph `G`. `tol` defines the tolerance for convergence.

	Parameters
	----------
	G : Graph
		The graph.
	tol : double, optional
		The tolerance for convergence.
	"""

	def __cinit__(self, Graph G, double tol=1e-9):
		self._G = G
		self._this = new _EigenvectorCentrality(G._this, tol)


cdef extern from "cpp/centrality/CoreDecomposition.h":
	cdef cppclass _CoreDecomposition "NetworKit::CoreDecomposition" (_Centrality):
		_CoreDecomposition(_Graph, bool, bool) except +
		_Cover getCover() except +
		_Partition getPartition() except +
		index maxCoreNumber() except +

cdef class CoreDecomposition(Centrality):
	""" Computes k-core decomposition of a graph.

	CoreDecomposition(G)

	Create CoreDecomposition class for graph `G`. The graph may not contain self-loops.

	Parameters
	----------
	G : Graph
		The graph.
	normalized : boolean
		Divide each core number by the maximum degree.
	enforceBucketQueueAlgorithm : boolean
		enforce switch to sequential algorithm
	"""

	def __cinit__(self, Graph G, bool normalized=False, bool enforceBucketQueueAlgorithm=False):
		self._G = G
		self._this = new _CoreDecomposition(G._this, normalized, enforceBucketQueueAlgorithm)

	def maxCoreNumber(self):
		""" Get maximum core number.

		Returns
		-------
		index
			The maximum core number.
		"""
		return (<_CoreDecomposition*>(self._this)).maxCoreNumber()

	def getCover(self):
		""" Get the k-cores as cover.

		Returns
		-------
		vector
			The k-cores as sets of nodes, indexed by k.
		"""
		return Cover().setThis((<_CoreDecomposition*>(self._this)).getCover())

	def getPartition(self):
		""" Get the k-shells as a partition object.

		Returns
		-------
		Partition
			The k-shells
		"""
		return Partition().setThis((<_CoreDecomposition*>(self._this)).getPartition())

cdef extern from "cpp/centrality/LocalClusteringCoefficient.h":
	cdef cppclass _LocalClusteringCoefficient "NetworKit::LocalClusteringCoefficient" (_Centrality):
		_LocalClusteringCoefficient(_Graph, bool) except +

cdef class LocalClusteringCoefficient(Centrality):
	"""
		LocalClusteringCoefficient(G, normalized=False, computeEdgeCentrality=False)

		Constructs the LocalClusteringCoefficient class for the given Graph `G`. If the local clustering coefficient values should be normalized,
		then set `normalized` to True. The graph may not contain self-loops.

		There are two algorithms available. The trivial (parallel) algorithm needs only a small amount of additional memory.
		The turbo mode adds a (sequential, but fast) pre-processing step using ideas from [0]. This reduces the running time
		significantly for most graphs. However, the turbo mode needs O(m) additional memory. In practice this should be a bit
		less than half of the memory that is needed for the graph itself. The turbo mode is particularly effective for graphs
		with nodes of very high degree and a very skewed degree distribution.

		[0] Triangle Listing Algorithms: Back from the Diversion
		Mark Ortmann and Ulrik Brandes                                                                          *
		2014 Proceedings of the Sixteenth Workshop on Algorithm Engineering and Experiments (ALENEX). 2014, 1-8

	 	Parameters
	 	----------
	 	G : Graph
	 		The graph.
		turbo : bool
			If the turbo mode shall be activated.
	"""

	def __cinit__(self, Graph G, bool turbo = False):
		self._G = G
		self._this = new _LocalClusteringCoefficient(G._this, turbo)


cdef extern from "cpp/centrality/Sfigality.h":
	cdef cppclass _Sfigality "NetworKit::Sfigality" (_Centrality):
		_Sfigality(_Graph) except +

cdef class Sfigality(Centrality):
	"""
	Sfigality is a new type of node centrality measures that is high if neighboring nodes have a higher degree, e.g. in social networks, if your friends have more friends than you. Formally:

		$$\sigma(u) = \frac{| \{ v: \{u,v\} \in E, deg(u) < deg(v) \} |}{ deg(u) }$$

 	Parameters
 	----------
 	G : Graph
 		The graph.
	"""

	def __cinit__(self, Graph G):
		self._G = G
		self._this = new _Sfigality(G._this)



cdef extern from "cpp/centrality/DynApproxBetweenness.h":
	cdef cppclass _DynApproxBetweenness "NetworKit::DynApproxBetweenness":
		_DynApproxBetweenness(_Graph, double, double, bool, double) except +
		void run() nogil except +
		void update(vector[_GraphEvent]) except +
		vector[double] scores() except +
		vector[pair[node, double]] ranking() except +
		double score(node) except +
		count getNumberOfSamples() except +

cdef class DynApproxBetweenness:
	""" New dynamic algorithm for the approximation of betweenness centrality with
	a guaranteed error

	DynApproxBetweenness(G, epsilon=0.01, delta=0.1, storePredecessors=True, universalConstant=1.0)

	The algorithm approximates the betweenness of all vertices so that the scores are
	within an additive error epsilon with probability at least (1- delta).
	The values are normalized by default.

	Parameters
	----------
	G : Graph
		the graph
	epsilon : double, optional
		maximum additive error
	delta : double, optional
		probability that the values are within the error guarantee
	storePredecessors : bool, optional
		store lists of predecessors?
	universalConstant: double, optional
		the universal constant to be used in computing the sample size.
		It is 1 by default. Some references suggest using 0.5, but there
		is no guarantee in this case.
	"""
	cdef _DynApproxBetweenness* _this
	cdef Graph _G

	def __cinit__(self, Graph G, epsilon=0.01, delta=0.1, storePredecessors = True, universalConstant=1.0):
		self._G = G
		self._this = new _DynApproxBetweenness(G._this, epsilon, delta, storePredecessors, universalConstant)

	# this is necessary so that the C++ object gets properly garbage collected
	def __dealloc__(self):
		del self._this

	def run(self):
		with nogil:
			self._this.run()
		return self

	def update(self, batch):
		""" Updates the betweenness centralities after the batch `batch` of edge insertions.

		Parameters
		----------
		batch : list of GraphEvent.
		"""
		cdef vector[_GraphEvent] _batch
		for ev in batch:
			_batch.push_back(_GraphEvent(ev.type, ev.u, ev.v, ev.w))
		self._this.update(_batch)

	def scores(self):
		""" Get a vector containing the betweenness score for each node in the graph.

		Returns
		-------
		vector
			The betweenness scores calculated by run().
		"""
		return self._this.scores()

	def score(self, v):
		""" Get the betweenness score of node `v` calculated by run().

		Parameters
		----------
		v : node
			A node.

		Returns
		-------
		double
			The betweenness score of node `v.
		"""
		return self._this.score(v)

	def ranking(self):
		""" Get a vector of pairs sorted into descending order. Each pair contains a node and the corresponding score
		calculated by run().

		Returns
		-------
		vector
			A vector of pairs.
		"""
		return self._this.ranking()

	def getNumberOfSamples(self):
		"""
		Get number of path samples used in last calculation.
		"""
		return self._this.getNumberOfSamples()

cdef extern from "cpp/centrality/PermanenceCentrality.h":
	cdef cppclass _PermanenceCentrality "NetworKit::PermanenceCentrality":
		_PermanenceCentrality(const _Graph& G, const _Partition& P) except +
		void run() nogil except +
		double getIntraClustering(node u) except +
		double getPermanence(node u) except +

cdef class PermanenceCentrality:
	"""
	Permanence centrality

	This centrality measure measure how well a vertex belongs to its community. The values are calculated on the fly, the partion may be changed in between the requests.
	For details see

	Tanmoy Chakraborty, Sriram Srinivasan, Niloy Ganguly, Animesh Mukherjee, and Sanjukta Bhowmick. 2014.
	On the permanence of vertices in network communities.
	In Proceedings of the 20th ACM SIGKDD international conference on Knowledge discovery and data mining (KDD '14).
	ACM, New York, NY, USA, 1396-1405. DOI: http://dx.doi.org/10.1145/2623330.2623707

	FIXME: does not use the common centrality interface yet.
	"""
	cdef _PermanenceCentrality *_this
	cdef Graph _G
	cdef Partition _P

	def __cinit__(self, Graph G, Partition P):
		self._this = new _PermanenceCentrality(G._this, P._this)
		self._G = G
		self._P = P

	def __dealloc__(self):
		del self._this

	def run(self):
		with nogil:
			self._this.run()
		return self

	def getIntraClustering(self, node u):
		return self._this.getIntraClustering(u)

	def getPermanence(self, node u):
		return self._this.getPermanence(u)

cdef extern from "cpp/centrality/LocalPartitionCoverage.h":
	cdef cppclass _LocalPartitionCoverage "NetworKit::LocalPartitionCoverage" (_Centrality):
		_LocalPartitionCoverage(_Graph, _Partition) except +

cdef class LocalPartitionCoverage(Centrality):
	"""
	The local partition coverage is the amount of neighbors of a node u that are in the same partition as u.

	Parameters
	----------
	G : Graph
		The graph.
	P : Partition
		The partition to use
	"""
	cdef Partition _P

	def __cinit__(self, Graph G not None, Partition P not None):
		self._G = G
		self._P = P
		self._this = new _LocalPartitionCoverage(G._this, P._this)


# Module: dynamic

cdef extern from "cpp/dynamics/GraphEvent.h":
	enum _GraphEventType "NetworKit::GraphEvent::Type":
		NODE_ADDITION,
		NODE_REMOVAL,
		NODE_RESTORATION,
		EDGE_ADDITION,
		EDGE_REMOVAL,
		EDGE_WEIGHT_UPDATE,
		EDGE_WEIGHT_INCREMENT,
		TIME_STEP

cdef extern from "cpp/dynamics/GraphEvent.h":
	cdef cppclass _GraphEvent "NetworKit::GraphEvent":
		node u, v
		edgeweight w
		_GraphEventType type
		_GraphEvent() except +
		_GraphEvent(_GraphEventType type, node u, node v, edgeweight w) except +
		string toString() except +

cdef class GraphEvent:
	cdef _GraphEvent _this
	NODE_ADDITION = 0
	NODE_REMOVAL = 1
	NODE_RESTORATION = 2
	EDGE_ADDITION = 3
	EDGE_REMOVAL = 4
	EDGE_WEIGHT_UPDATE = 5
	EDGE_WEIGHT_INCREMENT = 6
	TIME_STEP = 7

	property type:
		def __get__(self):
			return self._this.type
		def __set__(self, t):
			self._this.type = t

	property u:
		def __get__(self):
			return self._this.u
		def __set__(self, u):
			self._this.u = u

	property v:
		def __get__(self):
			return self._this.v
		def __set__(self, v):
			self._this.v = v

	property w:
		def __get__(self):
			return self._this.w
		def __set__(self, w):
			self._this.w = w

	def __cinit__(self, _GraphEventType type, node u, node v, edgeweight w):
		self._this = _GraphEvent(type, u, v, w)

	def toString(self):
		return self._this.toString().decode("utf-8")

	def __repr__(self):
		return self.toString()


cdef extern from "cpp/dynamics/DGSStreamParser.h":
	cdef cppclass _DGSStreamParser "NetworKit::DGSStreamParser":
		_DGSStreamParser(string path, bool mapped, node baseIndex) except +
		vector[_GraphEvent] getStream() except +

cdef class DGSStreamParser:
	cdef _DGSStreamParser* _this

	def __cinit__(self, path, mapped=True, baseIndex=0):
		self._this = new _DGSStreamParser(stdstring(path), mapped, baseIndex)

	def __dealloc__(self):
		del self._this

	def getStream(self):
		return [GraphEvent(ev.type, ev.u, ev.v, ev.w) for ev in self._this.getStream()]


cdef extern from "cpp/dynamics/DGSWriter.h":
	cdef cppclass _DGSWriter "NetworKit::DGSWriter":
		void write(vector[_GraphEvent] stream, string path) except +


cdef class DGSWriter:
	cdef _DGSWriter* _this

	def __cinit__(self):
		self._this = new _DGSWriter()

	def __dealloc__(self):
		del self._this

	def write(self, stream, path):
		cdef vector[_GraphEvent] _stream
		for ev in stream:
			_stream.push_back(_GraphEvent(ev.type, ev.u, ev.v, ev.w))
		self._this.write(_stream, stdstring(path))


# cdef extern from "cpp/dcd2/DynamicCommunityDetection.h":
# 	cdef cppclass _DynamicCommunityDetection "NetworKit::DynamicCommunityDetection":
# 		_DynamicCommunityDetection(string inputPath, string algoName, string updateStrategy, count interval, count restart, vector[string] recordSettings) except +
# 		void run() except +
# 		vector[double] getTimeline(string key) except +
# 		vector[pair[count, count]] getGraphSizeTimeline() except +
# 		vector[pair[_Graph, _Partition]] getResultTimeline() except +

# cdef class DynamicCommunityDetection:
# 	cdef _DynamicCommunityDetection* _this

# 	def __cinit__(self, inputPath, algoName, updateStrategy, interval, restart, recordSettings):
# 		self._this = new _DynamicCommunityDetection(stdstring(inputPath), stdstring(algoName), stdstring(updateStrategy), interval, restart, [stdstring(key) for key in recordSettings])

# 	def run(self):
# 		self._this.run()

# 	def getTimeline(self, key):
# 		return self._this.getTimeline(stdstring(key))

# 	def getGraphSizeTimeline(self):
# 		return self._this.getGraphSizeTimeline()

# 	def getResultTimeline(self):
# 		timeline = []
# 		for pair in self._this.getResultTimeline():
# 			_G = pair.first
# 			_zeta = pair.second
# 			timeline.append((Graph().setThis(_G), Partition().setThis(_zeta)))
# 		return timeline



cdef extern from "cpp/generators/DynamicPathGenerator.h":
	cdef cppclass _DynamicPathGenerator "NetworKit::DynamicPathGenerator":
		_DynamicPathGenerator() except +
		vector[_GraphEvent] generate(count nSteps) except +


cdef class DynamicPathGenerator:
	""" Example dynamic graph generator: Generates a dynamically growing path. """
	cdef _DynamicPathGenerator* _this

	def __cinit__(self):
		self._this = new _DynamicPathGenerator()

	def __dealloc__(self):
		del self._this

	def generate(self, nSteps):
		return [GraphEvent(ev.type, ev.u, ev.v, ev.w) for ev in self._this.generate(nSteps)]


cdef extern from "cpp/generators/DynamicDorogovtsevMendesGenerator.h":
	cdef cppclass _DynamicDorogovtsevMendesGenerator "NetworKit::DynamicDorogovtsevMendesGenerator":
		_DynamicDorogovtsevMendesGenerator() except +
		vector[_GraphEvent] generate(count nSteps) except +


cdef class DynamicDorogovtsevMendesGenerator:
	""" Generates a graph according to the Dorogovtsev-Mendes model.

 	DynamicDorogovtsevMendesGenerator()

 	Constructs the generator class.
	"""
	cdef _DynamicDorogovtsevMendesGenerator* _this

	def __cinit__(self):
		self._this = new _DynamicDorogovtsevMendesGenerator()

	def __dealloc__(self):
		del self._this

	def generate(self, nSteps):
		""" Generate event stream.

		Parameters
		----------
		nSteps : count
			Number of time steps in the event stream.
		"""
		return [GraphEvent(ev.type, ev.u, ev.v, ev.w) for ev in self._this.generate(nSteps)]



cdef extern from "cpp/generators/DynamicPubWebGenerator.h":
	cdef cppclass _DynamicPubWebGenerator "NetworKit::DynamicPubWebGenerator":
		_DynamicPubWebGenerator(count numNodes, count numberOfDenseAreas,
			float neighborhoodRadius, count maxNumberOfNeighbors) except +
		vector[_GraphEvent] generate(count nSteps) except +
		_Graph getGraph() except +


cdef class DynamicPubWebGenerator:
	cdef _DynamicPubWebGenerator* _this

	def __cinit__(self, numNodes, numberOfDenseAreas, neighborhoodRadius, maxNumberOfNeighbors):
		self._this = new _DynamicPubWebGenerator(numNodes, numberOfDenseAreas, neighborhoodRadius, maxNumberOfNeighbors)

	def __dealloc__(self):
		del self._this

	def generate(self, nSteps):
		""" Generate event stream.

		Parameters
		----------
		nSteps : count
			Number of time steps in the event stream.
		"""
		return [GraphEvent(ev.type, ev.u, ev.v, ev.w) for ev in self._this.generate(nSteps)]

	def getGraph(self):
		return Graph().setThis(self._this.getGraph())

cdef extern from "cpp/generators/DynamicHyperbolicGenerator.h":
	cdef cppclass _DynamicHyperbolicGenerator "NetworKit::DynamicHyperbolicGenerator":
		_DynamicHyperbolicGenerator(count numNodes, double avgDegree, double gamma, double T, double moveEachStep, double moveDistance) except +
		vector[_GraphEvent] generate(count nSteps) except +
		_Graph getGraph() except +
		vector[Point[float]] getCoordinates() except +


cdef class DynamicHyperbolicGenerator:
	cdef _DynamicHyperbolicGenerator* _this

	def __cinit__(self, numNodes, avgDegree = 6, gamma = 3, T = 0, moveEachStep = 1, moveDistance = 0.1):
		""" Dynamic graph generator according to the hyperbolic unit disk model.

		Parameters
		----------
		numNodes : count
			number of nodes
		avgDegree : double
			average degree of the resulting graph
		gamma : double
			power-law exponent of the resulting graph
		T : double
			temperature, selecting a graph family on the continuum between hyperbolic unit disk graphs and Erdos-Renyi graphs
		moveFraction : double
			fraction of nodes to be moved in each time step. The nodes are chosen randomly each step
		moveDistance: double
			base value for the node movements
		"""
		if gamma <= 2:
				raise ValueError("Exponent of power-law degree distribution must be > 2")
		self._this = new _DynamicHyperbolicGenerator(numNodes, avgDegree = 6, gamma = 3, T = 0, moveEachStep = 1, moveDistance = 0.1)

	def generate(self, nSteps):
		""" Generate event stream.

		Parameters
		----------
		nSteps : count
			Number of time steps in the event stream.
		"""
		return [GraphEvent(ev.type, ev.u, ev.v, ev.w) for ev in self._this.generate(nSteps)]

	def getGraph(self):
		return Graph().setThis(self._this.getGraph())

	def getCoordinates(self):
		""" Get coordinates in the Poincare disk"""
		return [(p[0], p[1]) for p in self._this.getCoordinates()]



cdef extern from "cpp/generators/DynamicForestFireGenerator.h":
	cdef cppclass _DynamicForestFireGenerator "NetworKit::DynamicForestFireGenerator":
		_DynamicForestFireGenerator(double p, bool directed, double r) except +
		vector[_GraphEvent] generate(count nSteps) except +
		_Graph getGraph() except +


cdef class DynamicForestFireGenerator:
	""" Generates a graph according to the forest fire model.
	 The forest fire generative model produces dynamic graphs with the following properties:
     heavy tailed degree distribution
     communities
     densification power law
     shrinking diameter

    see Leskovec, Kleinberg, Faloutsos: Graphs over Tim: Densification Laws,
    Shringking Diameters and Possible Explanations

 	DynamicForestFireGenerator(double p, bool directed, double r = 1.0)

 	Constructs the generator class.

 	Parameters
 	----------
 	p : forward burning probability.
 	directed : decides whether the resulting graph should be directed
 	r : optional, backward burning probability
	"""
	cdef _DynamicForestFireGenerator* _this

	def __cinit__(self, p, directed, r = 1.0):
		self._this = new _DynamicForestFireGenerator(p, directed, r)

	def __dealloc__(self):
		del self._this

	def generate(self, nSteps):
		""" Generate event stream.

		Parameters
		----------
		nSteps : count
			Number of time steps in the event stream.
		"""
		return [GraphEvent(ev.type, ev.u, ev.v, ev.w) for ev in self._this.generate(nSteps)]




cdef extern from "cpp/dynamics/GraphUpdater.h":
	cdef cppclass _GraphUpdater "NetworKit::GraphUpdater":
		_GraphUpdater(_Graph G) except +
		void update(vector[_GraphEvent] stream) nogil except +
		vector[pair[count, count]] getSizeTimeline() except +

cdef class GraphUpdater:
	""" Updates a graph according to a stream of graph events.

	Parameters
	----------
	G : Graph
	 	initial graph
	"""
	cdef _GraphUpdater* _this
	cdef Graph _G

	def __cinit__(self, Graph G):
		self._G = G
		self._this = new _GraphUpdater(G._this)

	def __dealloc__(self):
		del self._this

	def update(self, stream):
		cdef vector[_GraphEvent] _stream
		for ev in stream:
			_stream.push_back(_GraphEvent(ev.type, ev.u, ev.v, ev.w))
		with nogil:
			self._this.update(_stream)


# Module: coarsening

cdef extern from "cpp/coarsening/GraphCoarsening.h":
	cdef cppclass _GraphCoarsening "NetworKit::GraphCoarsening"(_Algorithm):
		_GraphCoarsening(_Graph) except +
		_Graph getCoarseGraph() except +
		vector[node] getFineToCoarseNodeMapping() except +
		map[node, vector[node]] getCoarseToFineNodeMapping() except +

cdef class GraphCoarsening(Algorithm):
	cdef Graph _G

	def __init__(self, *args, **namedargs):
		if type(self) == GraphCoarsening:
			raise RuntimeError("Error, you may not use GraphCoarsening directly, use a sub-class instead")

	def __dealloc__(self):
		self._G = None # just to be sure the graph is deleted

	def run(self):
		"""
		Executes the Graph coarsening algorithm.

		Returns
		-------
		GraphCoarsening:
			self
		"""
		if self._this == NULL:
			raise RuntimeError("Error, object not properly initialized")
		with nogil:
			self._this.run()
		return self

	def getCoarseGraph(self):
		return Graph(0).setThis((<_GraphCoarsening*>(self._this)).getCoarseGraph())

	def getFineToCoarseNodeMapping(self):
		return (<_GraphCoarsening*>(self._this)).getFineToCoarseNodeMapping()

	def getCoarseToFineNodeMapping(self):
		return (<_GraphCoarsening*>(self._this)).getCoarseToFineNodeMapping()


cdef extern from "cpp/coarsening/ParallelPartitionCoarsening.h":
	cdef cppclass _ParallelPartitionCoarsening "NetworKit::ParallelPartitionCoarsening"(_GraphCoarsening):
		_ParallelPartitionCoarsening(_Graph, _Partition, bool) except +


cdef class ParallelPartitionCoarsening(GraphCoarsening):
	def __cinit__(self, Graph G not None, Partition zeta not None, useGraphBuilder = True):
		self._this = new _ParallelPartitionCoarsening(G._this, zeta._this, useGraphBuilder)

cdef extern from "cpp/coarsening/MatchingCoarsening.h":
	cdef cppclass _MatchingCoarsening "NetworKit::MatchingCoarsening"(_GraphCoarsening):
		_MatchingCoarsening(_Graph, _Matching, bool) except +


cdef class MatchingCoarsening(GraphCoarsening):
	"""Coarsens graph according to a matching.
 	Parameters
 	----------
 	G : Graph
	M : Matching
 	noSelfLoops : bool, optional
		if true, self-loops are not produced
	"""

	def __cinit__(self, Graph G not None, Matching M not None, bool noSelfLoops=False):
		self._this = new _MatchingCoarsening(G._this, M._this, noSelfLoops)


# Module: scd

cdef extern from "cpp/scd/PageRankNibble.h":
	cdef cppclass _PageRankNibble "NetworKit::PageRankNibble":
		_PageRankNibble(_Graph G, double alpha, double epsilon) except +
		map[node, set[node]] run(set[unsigned int] seeds) except +

cdef class PageRankNibble:
	"""
	Produces a cut around a given seed node using the PageRank-Nibble algorithm.
	see Andersen, Chung, Lang: Local Graph Partitioning using PageRank Vectors

	Parameters:
	-----------
	G : graph in which the cut is to be produced, must be unweighted.
	alpha : Loop probability of random walk; smaller values tend to produce larger communities.
	epsilon: Tolerance threshold for approximation of PageRank vectors
	"""
	cdef _PageRankNibble *_this
	cdef Graph _G

	def __cinit__(self, Graph G, double alpha, double epsilon):
		self._G = G
		self._this = new _PageRankNibble(G._this, alpha, epsilon)

	def run(self, set[unsigned int] seeds):
		"""
		Produces a cut around a given seed node.

		Parameters:
		-----------
		seeds : the seed node ids.
		"""
		return self._this.run(seeds)

cdef extern from "cpp/scd/GCE.h":
	cdef cppclass _GCE "NetworKit::GCE":
		_GCE(_Graph G, string quality) except +
		map[node, set[node]] run(set[unsigned int] seeds) except +

cdef class GCE:
	"""
	Produces a cut around a given seed node using the GCE algorithm.

	Parameters:
	-----------
	G : graph in which the cut is to be produced, must be unweighted.
	"""
	cdef _GCE *_this
	cdef Graph _G

	def __cinit__(self, Graph G, quality):
		self._G = G
		self._this = new _GCE(G._this, stdstring(quality))

	def run(self, set[unsigned int] seeds):
		"""
		Produces a cut around a given seed node.

		Parameters:
		-----------
		seeds : the seed node ids.
		"""
		return self._this.run(seeds)
# Module: clique

cdef extern from "cpp/clique/MaxClique.h":
	cdef cppclass _MaxClique "NetworKit::MaxClique":
		_MaxClique(_Graph G, count lb) except +
		void run() nogil except +
		count getMaxCliqueSize() except +

cdef class MaxClique:
	"""
	Exact algorithm for computing the size of the largest clique in a graph.
	Worst-case running time is exponential, but in practice the algorithm is fairly fast.
	Reference: Pattabiraman et al., http://arxiv.org/pdf/1411.7460.pdf

	Parameters:
	-----------
	G : graph in which the cut is to be produced, must be unweighted.
	lb : the lower bound of the size of the maximum clique.
	"""
	cdef _MaxClique* _this
	cdef Graph _G

	def __cinit__(self, Graph G not None, lb=0):
		self._G = G
		self._this = new _MaxClique(G._this, lb)


	def __dealloc__(self):
		del self._this

	def run(self):
		"""
		Actual maximum clique algorithm. Determines largest clique each vertex
	 	is contained in and returns size of largest. Pruning steps keep running time
	 	acceptable in practice.
	 	"""
		cdef count size
		with nogil:
			self._this.run()

	def getMaxCliqueSize(self):
		"""
		Returns the size of the biggest clique
		"""
		return self._this.getMaxCliqueSize()

# Module: linkprediction

cdef extern from "cpp/linkprediction/LinkPredictor.h":
	cdef cppclass _LinkPredictor "NetworKit::LinkPredictor":
		_LinkPredictor(const _Graph& G) except +
		double run(node u, node v) except +
		vector[pair[pair[node, node], double]] runAll() except +
		vector[pair[pair[node, node], double]] runOn(vector[pair[node, node]] nodePairs) except +
		void setGraph(const _Graph& newGraph) except +

cdef class LinkPredictor:
	""" Abstract base class for link predictors.

	Parameters
	----------
	G : Graph, optional
		The graph to work on. Defaults to None.
	"""
	cdef _LinkPredictor* _this

	def __cinit__(self, *args):
		# The construction is handled by the subclasses
		return

	def __dealloc__(self):
		if self._this is not NULL:
			del self._this
			self._this = NULL

	def setGraph(self, Graph newGraph):
		""" Sets the graph to work on.

		Parameters
		----------
		newGraph : Graph
			The graph to work on.
   	"""
		self._this.setGraph(newGraph._this)

	def run(self, node u, node v):
		""" Returns a score indicating the likelihood of a future link between the given nodes.

		Prior to calling this method a graph should be provided through the constructor or
		by calling setGraph. Note that only undirected graphs are accepted.
		There is also no lower or upper bound for scores and the actual range of values depends
		on the specific link predictor implementation. In case u == v a 0 is returned.
		If suitable this method might make use of parallelization to enhance performance.

		Parameters
		----------
		u : node
			First node in graph.
		v : node
			Second node in graph.

		Returns
		-------
		A prediction-score indicating the likelihood of a future link between the given nodes.
		"""
		return self._this.run(u, v)

	def runAll(self):
		""" Runs the link predictor on all currently unconnected node-pairs.

		Possible self-loops are also excluded. The method makes use of parallelisation.

		Returns
		-------
		A vector of pairs containing all currently unconnected node-pairs as the first elements
		and the corresponding scores as the second elements. The vector is sorted ascendingly by node-pair.
		"""
		return move(self._this.runAll())

	def runOn(self, vector[pair[node, node]] nodePairs):
		""" Executes the run-method on aĺl given node-pairs and returns a vector of predictions.

		The result is a vector of pairs where the first element is the node-pair and it's second
		element the corresponding score generated by the run-method. The method makes use of
		parallelisation.

		Parameters
		----------
		nodePairs : vector[pair[node, node]]
			Node-pairs to run the predictor on.

		Returns
		-------
		A vector of pairs containing the given node-pair as the first element and it's corresponding score
		as the second element. The vector is sorted ascendingly by node-pair.
		"""
		return move(self._this.runOn(nodePairs))

cdef extern from "cpp/linkprediction/KatzIndex.h":
	cdef cppclass _KatzIndex "NetworKit::KatzIndex"(_LinkPredictor):
		_KatzIndex(count maxPathLength, double dampingValue) except +
		_KatzIndex(const _Graph& G, count maxPathLength, double dampingValue) except +

cdef class KatzIndex(LinkPredictor):
	""" Implementation of the Katz index.

	Katz index assigns a pair of nodes a similarity score
	that is based on the sum of the weighted number of paths of length l
	where l is smaller than a given limit.

	Parameters
	----------
	G : Graph, optional
		The graph to operate on. Defaults to None.
	maxPathLength : count, optional
		Maximal length of the paths to consider. Defaults to 5.
	dampingValue : double, optional
		Used to exponentially damp every addend of the sum. Should be in (0, 1]. Defaults to 0.005.
	"""

	def __cinit__(self, Graph G = None, count maxPathLength = 5, double dampingValue = 0.005):
		if G is None:
			self._this = new _KatzIndex(maxPathLength, dampingValue)
		else:
			self._this = new _KatzIndex(G._this, maxPathLength, dampingValue)

	def __dealloc__(self):
		if self._this is not NULL:
			del self._this
			self._this = NULL

	def run(self, node u, node v):
		""" Returns the similarity score for the given node-pair based on the Katz index specified during construction.

		The algorithm considers all paths starting at the node with the smaller degree except the algorithm
		started at the other node at the last call.

		Parameters
		----------
		u : node
			First node in graph.
		v : node
			Second node in graph.

		Returns
		-------
		The similarity score of the given node-pair calculated by the specified Katz index.
		"""
		return self._this.run(u, v)

cdef extern from "cpp/linkprediction/CommonNeighborsIndex.h":
	cdef cppclass _CommonNeighborsIndex "NetworKit::CommonNeighborsIndex"(_LinkPredictor):
		_CommonNeighborsIndex() except +
		_CommonNeighborsIndex(const _Graph& G) except +

cdef class CommonNeighborsIndex(LinkPredictor):
	""" The CommonNeighborsIndex calculates the number of common neighbors of a node-pair in a given graph.

	Parameters
	----------
	G : Graph, optional
		The graph to work on. Defaults to None.
	"""

	def __cinit__(self, Graph G = None):
		if G is None:
			self._this = new _CommonNeighborsIndex()
		else:
			self._this = new _CommonNeighborsIndex(G._this)

	def __dealloc__(self):
		if self._this is not NULL:
			del self._this
			self._this = NULL

	def run(self, node u, node v):
		""" Returns the number of common neighbors of the given nodes u and v.

		Parameters
		----------
		u : node
			First node in graph.
		v : node
			Second node in graph.

		Returns
		-------
		The number of common neighbors of u and v.
		"""
		return self._this.run(u, v)

cdef extern from "cpp/linkprediction/PreferentialAttachmentIndex.h":
	cdef cppclass _PreferentialAttachmentIndex "NetworKit::PreferentialAttachmentIndex"(_LinkPredictor):
		_PreferentialAttachmentIndex() except +
		_PreferentialAttachmentIndex(const _Graph& G) except +

cdef class PreferentialAttachmentIndex(LinkPredictor):
	""" Implementation of the Preferential Attachment Index.

	The run-method simply calculates the product of the number of nodes in the neighborhoods
	regarding the given nodes.

	Parameters
	----------
	G : Graph, optional
		The graph to work on. Defaults to None.
	"""

	def __cinit__(self, Graph G = None):
		if G is None:
			self._this = new _PreferentialAttachmentIndex()
		else:
			self._this = new _PreferentialAttachmentIndex(G._this)

	def __dealloc__(self):
		if self._this is not NULL:
			del self._this
			self._this = NULL

	def run(self, node u, node v):
		""" Returns the product of the cardinalities of the neighborhoods regarding u and v.

		Parameters
		----------
		u : node
			First node in graph.
		v : node
			Second node in graph.

		Returns
		-------
		The product of the cardinalities of the neighborhoods regarding u and v
		"""
		return self._this.run(u, v)

cdef extern from "cpp/linkprediction/JaccardIndex.h":
	cdef cppclass _JaccardIndex "NetworKit::JaccardIndex"(_LinkPredictor):
		_JaccardIndex() except +
		_JaccardIndex(const _Graph& G) except +

cdef class JaccardIndex(LinkPredictor):
	""" Implementation of the Jaccard index which normalizes the Common Neighbors Index.

	This is done through dividing the number of common neighbors by the number of nodes
	in the neighboorhood-union.

	Parameters
	----------
	G : Graph, optional
		The graph to work on. Defaults to None.
	"""
	def __cinit__(self, Graph G = None):
		if G is None:
			self._this = new _JaccardIndex()
		else:
			self._this = new _JaccardIndex(G._this)

	def __dealloc__(self):
		if self._this is not NULL:
			del self._this
			self._this = NULL

	def run(self, node u, node v):
		""" Returns the Jaccard index for the given node-pair (u, v).

		Parameters
		----------
		u : node
			First node in graph.
		v : node
			Second node in graph.

		Returns
		-------
		The Jaccard index for the given node-pair (u, v).
		"""
		return self._this.run(u, v)

cdef extern from "cpp/linkprediction/AdamicAdarIndex.h":
	cdef cppclass _AdamicAdarIndex "NetworKit::AdamicAdarIndex"(_LinkPredictor):
		_AdamicAdarIndex() except +
		_AdamicAdarIndex(const _Graph& G) except +

cdef class AdamicAdarIndex(LinkPredictor):
	""" Implementation of the Adamic/Adar Index.

	The index sums up the reciprocals of the logarithm of the degree of all
	common neighbors of u and v.

	Parameters
	----------
	G : Graph, optional
		The graph to work on. Defaults to None.
	"""

	def __cinit__(self, Graph G = None):
		if G is None:
			self._this = new _AdamicAdarIndex()
		else:
			self._this = new _AdamicAdarIndex(G._this)

	def __dealloc__(self):
		if self._this is not NULL:
			del self._this
			self._this = NULL

	def run(self, node u, node v):
		""" Returns the Adamic/Adar Index of the given node-pair (u, v).

		Parameters
		----------
		u : node
			First node in graph.
		v : node
			Second node in graph.

		Returns
		-------
		The Adamic/Adar Index of the given node-pair (u, v).
		"""
		return self._this.run(u, v)

cdef extern from "cpp/linkprediction/UDegreeIndex.h":
	cdef cppclass _UDegreeIndex "NetworKit::UDegreeIndex"(_LinkPredictor):
		_UDegreeIndex() except +
		_UDegreeIndex(const _Graph& G) except +

cdef class UDegreeIndex(LinkPredictor):
	""" Index that simply returns the degree of the first given node.

	Parameters
	----------
	G : Graph, optional
		The graph to work on. Defaults to None.
	"""

	def __cinit__(self, Graph G = None):
		if G is None:
			self._this = new _UDegreeIndex()
		else:
			self._this = new _UDegreeIndex(G._this)

	def __dealloc__(self):
		if self._this is not NULL:
			del self._this
			self._this = NULL

	def run(self, node u, node v):
		""" Returns the degree of the first node provided, namely u.

		Parameters
		----------
		u : node
			First node in graph.
		v : node
			Second node in graph.

		Returns
		-------
		The degree of the first node provided, namely u.
		"""
		return self._this.run(u, v)

cdef extern from "cpp/linkprediction/VDegreeIndex.h":
	cdef cppclass _VDegreeIndex "NetworKit::VDegreeIndex"(_LinkPredictor):
		_VDegreeIndex() except +
		_VDegreeIndex(const _Graph& G) except +

cdef class VDegreeIndex(LinkPredictor):
	""" Index that simply returns the degree of the second given node.

	Parameters
	----------
	G : Graph, optional
		The graph to work on. Defaults to None.
	"""

	def __cinit__(self, Graph G = None):
		if G is None:
			self._this = new _VDegreeIndex()
		else:
			self._this = new _VDegreeIndex(G._this)

	def __dealloc__(self):
		if self._this is not NULL:
			del self._this
			self._this = NULL

	def run(self, node u, node v):
		""" Returns the degree of the second node provided, namely v.

		Parameters
		----------
		u : node
			First node in graph.
		v : node
			Second node in graph.

		Returns
		-------
		The degree of the second node provided, namely v.
		"""
		return self._this.run(u, v)

cdef extern from "cpp/linkprediction/AlgebraicDistanceIndex.h":
	cdef cppclass _AlgebraicDistanceIndex "NetworKit::AlgebraicDistanceIndex"(_LinkPredictor):
		_AlgebraicDistanceIndex(count numberSystems, count numberIterations, double omega, index norm) except +
		_AlgebraicDistanceIndex(const _Graph& G, count numberSystems, count numberIterations, double omega, index norm) except +
		void preprocess() except +
		double run(node u, node v) except +

cdef class AlgebraicDistanceIndex(LinkPredictor):
	""" Algebraic distance assigns a distance value to pairs of nodes according to their structural closeness in the graph.

	Parameters
	----------
	G : Graph
		The graph to work on. Can be set to None and default is None.
	numberSystems : count
		Number of vectors/systems used for algebraic iteration.
	numberIterations : count
		Number of iterations in each system.
	omega : double, optional
		Overrelaxation parameter, default: 0.5.
	norm : index, optional
		The norm factor of the extended algebraic distance. Maximum norm is realized by setting the norm to 0. Default: 2.
	"""

	def __cinit__(self, Graph G, count numberSystems, count numberIterations, double omega = 0.5, index norm = 2):
		if G is None:
			self._this = new _AlgebraicDistanceIndex(numberSystems, numberIterations, omega, norm)
		else:
			self._this = new _AlgebraicDistanceIndex(G._this, numberSystems, numberIterations, omega, norm)

	def __dealloc__(self):
		if self._this is not NULL:
			del self._this
			self._this = NULL

	def preprocess(self):
		""" Executes necessary initializations.

		Starting with random initialization, compute for all numberSystems
		"diffusion" systems the situation after numberIterations iterations
		of overrelaxation with overrelaxation parameter omega.

		REQ: Needs to be called before algdist delivers meaningful results!
		"""
		(<_AlgebraicDistanceIndex *>self._this).preprocess()

	def run(self, node u, node v):
		""" Returns the extended algebraic distance between node u and node v in the norm specified in the constructor.

		Parameters
		----------
		u : node
			The first node.
		v : node
			The second node.

		Returns
		-------
		Extended algebraic distance between the two nodes.
		"""
		return self._this.run(u, v)

cdef extern from "cpp/linkprediction/NeighborhoodDistanceIndex.h":
	cdef cppclass _NeighborhoodDistanceIndex "NetworKit::NeighborhoodDistanceIndex"(_LinkPredictor):
		_NeighborhoodDistanceIndex() except +
		_NeighborhoodDistanceIndex(const _Graph& G) except +
		double run(node u, node v) except +

cdef class NeighborhoodDistanceIndex(LinkPredictor):
	""" Assigns a distance value to pairs of nodes according to the overlap of their neighborhoods.

	Parameters
	----------
	G : Graph, optional
		The graph to work on. Defaults to None.
	"""
	def __cinit__(self, Graph G = None):
		if G is None:
			self._this = new _NeighborhoodDistanceIndex()
		else:
			self._this = new _NeighborhoodDistanceIndex(G._this)

	def __dealloc__(self):
		if self._this is not NULL:
			del self._this
			self._this = NULL

	def run(self, node u, node v):
		""" Returns the Neighborhood Distance index for the given node-pair (u, v).

		Parameters
		----------
		u : node
			First node in graph.
		v : node
			Second node in graph.

		Returns
		-------
		The Neighborhood Distance index for the given node-pair (u, v).
		"""
		return self._this.run(u, v)

cdef extern from "cpp/linkprediction/TotalNeighborsIndex.h":
	cdef cppclass _TotalNeighborsIndex "NetworKit::TotalNeighborsIndex"(_LinkPredictor):
		_TotalNeighborsIndex() except +
		_TotalNeighborsIndex(const _Graph& G) except +

cdef class TotalNeighborsIndex(LinkPredictor):
	""" Implementation of the Total Neighbors Index.

	This index is also known as Total Friends Index and returns
	the number of nodes in the neighborhood-union of u and v.

	Parameters
	----------
	G : Graph, optional
		The graph to work on. Defaults to None.
	"""

	def __cinit__(self, Graph G = None):
		if G is None:
			self._this = new _TotalNeighborsIndex()
		else:
			self._this = new _TotalNeighborsIndex(G._this)

	def __dealloc__(self):
		if self._this is not NULL:
			del self._this
			self._this = NULL

	def run(self, node u, node v):
		""" Returns the number of total union-neighbors for the given node-pair (u, v).

		Parameters
		----------
		u : node
			First node in graph.
		v : node
			Second node in graph.

		Returns
		-------
		The number of total union-neighbors for the given node-pair (u, v).
		"""
		return self._this.run(u, v)

cdef extern from "cpp/linkprediction/NeighborsMeasureIndex.h":
	cdef cppclass _NeighborsMeasureIndex "NetworKit::NeighborsMeasureIndex"(_LinkPredictor):
		_NeighborsMeasureIndex() except +
		_NeighborsMeasureIndex(const _Graph& G) except +

cdef class NeighborsMeasureIndex(LinkPredictor):
	""" Implementation of the Neighbors Measure Index.

	This index is also known as Friends Measure and simply returns
	the number of connections between neighbors of the given nodes u and v.

	Parameters
	----------
	G : Graph, optional
		The graph to work on. Defaults to None.
	"""

	def __cinit__(self, Graph G = None):
		if G is None:
			self._this = new _NeighborsMeasureIndex()
		else:
			self._this = new _NeighborsMeasureIndex(G._this)

	def __dealloc__(self):
		if self._this is not NULL:
			del self._this
			self._this = NULL

	def run(self, node u, node v):
		""" Returns the number of connections between neighbors of u and v.

		Parameters
		----------
		u : node
			First node in graph.
		v : node
			Second node in graph.

		Returns
		-------
		The number of connections between neighbors of u and v.
		"""
		return self._this.run(u, v)

cdef extern from "cpp/linkprediction/SameCommunityIndex.h":
	cdef cppclass _SameCommunityIndex "NetworKit::SameCommunityIndex"(_LinkPredictor):
		_SameCommunityIndex() except +
		_SameCommunityIndex(const _Graph& G) except +

cdef class SameCommunityIndex(LinkPredictor):
	""" Index to determine whether two nodes are in the same community.

	Parameters
	----------
	G : Graph, optional
		The graph to work on. Defaults to None.
	"""

	def __cinit__(self, Graph G = None):
		if G is None:
			self._this = new _SameCommunityIndex()
		else:
			self._this = new _SameCommunityIndex(G._this)

	def __dealloc__(self):
		if self._this is not NULL:
			del self._this
			self._this = NULL

	def run(self, node u, node v):
		""" Returns 1 if the given nodes u and v are in the same community, 0 otherwise.

		Parameters
		----------
		u : node
			First node in graph.
		v : node
			Second node in graph.

		Returns
		-------
		1 if the given nodes u and v are in the same community, 0 otherwise.
		"""
		return self._this.run(u, v)

cdef extern from "cpp/linkprediction/AdjustedRandIndex.h":
	cdef cppclass _AdjustedRandIndex "NetworKit::AdjustedRandIndex"(_LinkPredictor):
		_AdjustedRandIndex() except +
		_AdjustedRandIndex(const _Graph& G) except +

cdef class AdjustedRandIndex(LinkPredictor):
	""" AdjustedRandIndex proposed by Hoffman et al. with natural threshold of 0.

	Parameters
	----------
	G : Graph, optional
		The graph to work on. Defaults to None.
	"""

	def __cinit__(self, Graph G = None):
		if G is None:
			self._this = new _AdjustedRandIndex()
		else:
			self._this = new _AdjustedRandIndex(G._this)

	def __dealloc__(self):
		if self._this is not NULL:
			del self._this
			self._this = NULL

	def run(self, node u, node v):
		""" Returns the Adjusted Rand Index of the given node-pair (u, v).

		Parameters
		----------
		u : node
			First node in graph.
		v : node
			Second node in graph.

		Returns
		-------
		The Adjusted Rand Index of the given node-pair (u, v).
		"""
		return self._this.run(u, v)

cdef extern from "cpp/linkprediction/ResourceAllocationIndex.h":
	cdef cppclass _ResourceAllocationIndex "NetworKit::ResourceAllocationIndex"(_LinkPredictor):
		_ResourceAllocationIndex() except +
		_ResourceAllocationIndex(const _Graph& G) except +

cdef class ResourceAllocationIndex(LinkPredictor):
	""" Implementation of the ResourceAllocationIndex.

	The index is similar to Adamic/Adar and sums up the reciprocals of
	the degree of all common neighbors of u and v.

	Parameters
	----------
	G : Graph, optional
		The graph to work on. Defaults to None.
	"""

	def __cinit__(self, Graph G = None):
		if G is None:
			self._this = new _ResourceAllocationIndex()
		else:
			self._this = new _ResourceAllocationIndex(G._this)

	def __dealloc__(self):
		if self._this is not NULL:
			del self._this
			self._this = NULL

	def run(self, node u, node v):
		""" Returns the Resource Allocation Index of the given node-pair (u, v).

		Parameters
		----------
		u : node
			First node in graph.
		v : node
			Second node in graph.

		Returns
		-------
		The Resource Allocation Index of the given node-pair (u, v).
		"""
		return self._this.run(u, v)

cdef extern from "cpp/linkprediction/RandomLinkSampler.h" namespace "NetworKit::RandomLinkSampler":
	_Graph byPercentage(_Graph G, double percentage) except +
	_Graph byCount(_Graph G, count numLinks) except +

cdef class RandomLinkSampler:
	""" Provides methods to randomly sample a number of edges from a given graph. """

	@staticmethod
	def byPercentage(Graph G, double percentage):
		""" Returns a graph that contains percentage percent of links form the given graph G.

		The links are randomly selected from G until the given percentage is reached.

		Parameters
		----------
		G : Graph
			The graph to construct the training graph from.
		percentage : double
			Percentage of links regarding the number of links in the given graph that should
			be in the returned graph.

		Returns
		-------
		A graph that contains the given percentage of links from G.
		"""
		return Graph().setThis(byPercentage(G._this, percentage))

	@staticmethod
	def byCount(Graph G, count numLinks):
		""" Returns a graph that contains numLinks links from the given graph G.

		The links are randomly selected from G until the given count is reached.

		Parameters
		----------
		G : Graph
			The graph to construct the training graph from.
		numLinks : count
			Number of links the returned graph should consist of.

		Returns
		-------
		A graph that contains the given number of links from G.
		"""
		return Graph().setThis(byCount(G._this, numLinks))

cdef extern from "cpp/linkprediction/EvaluationMetric.h":
	cdef cppclass _EvaluationMetric "NetworKit::EvaluationMetric":
		_EvaluationMetric() except +
		_EvaluationMetric(const _Graph& testGraph) except +
		void setTestGraph(const _Graph& newTestGraph) except +
		pair[vector[double], vector[double]] getCurve(vector[pair[pair[node, node], double]] predictions, count numThresholds) except +
		double getAreaUnderCurve() except +
		double getAreaUnderCurve(pair[vector[double], vector[double]] curve) except +

cdef class EvaluationMetric:
	""" Abstract base class for evaluation curves.

	The evualation curves are generated based on the predictions calculated
	by the link predictor and a testGraph to compare against.

	Parameters
	----------
	testGraph : Graph
		Graph containing the links to use for evaluation. Can be set to None and default is None.
	"""
	cdef _EvaluationMetric *_this

	def __cinit__(self, *args):
		# The construction is handled by the subclasses
		return

	def __dealloc__(self):
		if self._this is not NULL:
			del self._this
			self._this = NULL

	def setTestGraph(self, Graph newTestGraph):
		""" Sets a new graph to use as ground truth for evaluation.

		Note that this won't reset the most recently calculated curve and as a consequence
		getAreaUnderCurve() will still behave as expected by returning the AUC of the most recent curve.

		Parameters
		----------
		newTestGraph : Graph
			New graph to use as ground truth.
		"""
		self._this.setTestGraph(newTestGraph._this)

	def getCurve(self, vector[pair[pair[node, node], double]] predictions, count numThresholds = 1000):
		""" Returns a pair of X- and Y-vectors describing the evaluation curve generated from the given predictions.

		The latest y-value will be used as a tie-breaker in case there are multiple y-values for one x-value.
		Note that the given number of thresholds (@a numThresholds) is an upper bound for the number of
		points returned. This is due to the fact that multiple y-values can map to one x-value in which case
		the tie-breaking behaviour described above will intervene.

		Parameters
		----------
		predictions : vector[pair[pair[node, node], double]]
			Predictions to evaluate.
		numThresholds : count, optional
			The number of thresholds to use the metric on. Defaults to 1000.

		Returns
		-------
		A pair of vectors where the first vectors contains all x-values and the second one contains the
		corresponding y-value.
		"""
		return self._this.getCurve(predictions, numThresholds)

	def getAreaUnderCurve(self, pair[vector[double], vector[double]] curve = pair[vector[double], vector[double]]()):
		""" Returns the area under the most recently calculated or optionally the given curve by using the trapezoidal rule.

		Note that if there is no curve specified or the vectors of the given curves are empty than
		the area under the most recently calculated curve will be returned.

		Parameters
		----------
		curve : pair[vector[double], vector[double]]
			Curve whose AUC to determine. Default: Pair of empty vectors.

		Returns
		-------
		The area under the given curve.
		"""
		if len(curve.first) == 0:
			return self._this.getAreaUnderCurve()
		return self._this.getAreaUnderCurve(curve)

cdef extern from "cpp/linkprediction/ROCMetric.h":
	cdef cppclass _ROCMetric "NetworKit::ROCMetric"(_EvaluationMetric):
		_ROCMetric() except +
		_ROCMetric(const _Graph& testGraph) except +
		pair[vector[double], vector[double]] getCurve(vector[pair[pair[node, node], double]] predictions, count numThresholds) except +

cdef class ROCMetric(EvaluationMetric):
	""" Provides points that define the Receiver Operating Characteristic curve for a given set of predictions.

	Based on the generated points the area under the curve can be calculated with the trapzoidal rule.

	Parameters
	----------
	testGraph : Graph, optional
		Graph containing the links to use for evaluation. Defaults to None.
	"""

	def __cinit__(self, Graph testGraph = None):
		if testGraph is None:
			self._this = new _ROCMetric()
		else:
			self._this = new _ROCMetric(testGraph._this)

	def __dealloc__(self):
		if self._this is not NULL:
			del self._this
			self._this = NULL

	def getCurve(self, vector[pair[pair[node, node], double]] predictions, count numThresholds = 1000):
		""" Generate the points of the Receiver Operating Characteristic curve regarding the previously set predictions.

		Note that in the case of multiple y-values mapping to the same x-value the highest (=latest) y-value gets picked.

		Parameters
		----------
		predictions : vector[pair[pair[node, node], double]]
			Predictions to evaluate.
		numThresholds : count, optional
			The number of thresholds to use the metric on. Defaults to 1000.

		Returns
		-------
		A pair of vectors where the first vector contains the false positive rates and the second vector the
		corresponding true positive rates.
		"""
		return self._this.getCurve(predictions, numThresholds)

cdef extern from "cpp/linkprediction/PrecisionRecallMetric.h":
	cdef cppclass _PrecisionRecallMetric "NetworKit::PrecisionRecallMetric"(_EvaluationMetric):
		_PrecisionRecallMetric() except +
		_PrecisionRecallMetric(const _Graph& testGraph) except +
		pair[vector[double], vector[double]] getCurve(vector[pair[pair[node, node], double]] predictions, count numThresholds) except +

cdef class PrecisionRecallMetric(EvaluationMetric):
	""" Provides points that define the Precision-Recall curve for a given set of predictions.

	Based on the generated points the area under the curve can be calculated with the trapzoidal rule.

	Parameters
	----------
	testGraph : Graph, optional
		Graph containing the links to use for evaluation. Defaults to None.
	"""

	def __cinit__(self, Graph testGraph = None):
		if testGraph is None:
			self._this = new _PrecisionRecallMetric()
		else:
			self._this = new _PrecisionRecallMetric(testGraph._this)

	def __dealloc__(self):
		if self._this is not NULL:
			del self._this
			self._this = NULL

	def getCurve(self, vector[pair[pair[node, node], double]] predictions, count numThresholds = 1000):
		""" Generates the points for the Precision-Recall curve with respect to the given predictions.

		The curve assigns every recall-value a corresponding precision as the y-value.
		In case of a tie regarding multiple y-values for a x-value the smallest (= latest) y-value will be used.

		Parameters
		----------
		predictions : vector[pair[pair[node, node], double]]
			Predictions to evaluate.
		numThresholds : count, optional
			The number of thresholds to use the metric on. Defaults to 1000.

		Returns
		-------
		A pair of vectors where the first vector contains all recall-values and the second vector
		the corresponding precision-values.
		"""
		return self._this.getCurve(predictions, numThresholds)

cdef extern from "cpp/linkprediction/MissingLinksFinder.h":
	cdef cppclass _MissingLinksFinder "NetworKit::MissingLinksFinder":
		_MissingLinksFinder(const _Graph& G) except +
		vector[pair[node, node]] findAtDistance(count k) except +
		vector[pair[node, node]] findFromNode(node u, count k) except +

cdef class MissingLinksFinder:
	""" Allows the user to find missing links in the given graph.

	The absent links to find are narrowed down by providing a distance
	that the nodes of the missing links should have.
	For example in case of distance 2 only node-pairs that would close
	a triangle in the given graph get returned.

	Parameters
	----------
	G : Graph
		The graph to find missing links in.
	"""
	cdef _MissingLinksFinder* _this

	def __cinit__(self, Graph G):
		self._this = new _MissingLinksFinder(G._this)

	def __dealloc__(self):
		del self._this

	def findAtDistance(self, count k):
		""" Returns all missing links in the graph that have distance k.

		Note that a distance of k actually means that there are k different links
		on the path of the two nodes that are connected through that path.

		Parameters
		----------
		k : count
			Distance of the absent links.

		Returns
		-------
		An ascendingly sorted vector of node-pairs where there is a missing link of distance k
		between the two nodes.
		"""
		return move(self._this.findAtDistance(k))

	def findFromNode(self, node u, count k):
		""" Returns all missing links in the graph that have distance k and are connected to u.

		Note that a distance of k actually means that there are k different links
		on the path of the two nodes that are connected through that path.

		Parameters
		----------
		u : node
			Node to find missing links from.
		k : count
			Distance of the absent links.

		Returns
		-------
		A vector of node-pairs where there is a missing link of distance k
		between the given node u and another node in the graph.
		"""
		return move(self._this.findFromNode(u, k))

cdef extern from "cpp/linkprediction/NeighborhoodUtility.h" namespace "NetworKit::NeighborhoodUtility":
	vector[node] getNeighborsUnion(const _Graph& G, node u, node v) except +
	vector[node] getCommonNeighbors(const _Graph& G, node u, node v) except +

cdef class NeighborhoodUtility:
	""" Provides basic operations on neighborhoods in a given graph. """

	@staticmethod
	def getNeighborsUnion(Graph G, node u, node v):
		""" Returns the union of the neighboorhoods of u and v.

		Parameters
		----------
		G : Graph
			Graph to obtain neighbors-union from.
		u : node
			First node.
		v : node
			Second node.

		Returns
		-------
		A vector containing all the nodes in the neighboorhood-union of u and v.
		"""
		return getNeighborsUnion(G._this, u, v)

	@staticmethod
	def getCommonNeighbors(Graph G, node u, node v):
		""" Returns a vector containing the node-ids of all common neighbors of u and v.

		Parameters
		----------
		G : Graph
			Graph to obtain common neighbors from.
		u : node
			First node.
		v : node
			Second node.

		Returns
		-------
		A vector containing the node-ids of all common neighbors of u and v.
		"""
		return getCommonNeighbors(G._this, u, v)

cdef extern from "cpp/linkprediction/LinkThresholder.h" namespace "NetworKit::LinkThresholder":
	vector[pair[node, node]] byScore(vector[pair[pair[node, node], double]] predictions, double minScore)
	vector[pair[node, node]] byCount(vector[pair[pair[node, node], double]] predictions, count numLinks)
	vector[pair[node, node]] byPercentage(vector[pair[pair[node, node], double]] predictions, double percentageLinks)

cdef class LinkThresholder:
	""" Filters given predictions based on some criterion and returns a vector of node-pairs that fulfill the given criterion.

	This can be used to determine which node-pairs should actually be interpreted
	as future links and which shouldn't.
	"""

	@staticmethod
	def byScore(vector[pair[pair[node, node], double]] predictions, double minScore):
		""" Returns the node-pairs whose scores are at least equal to the given minScore.

		Parameters
		----------
		predictions : vector[pair[pair[node, node], double]].
			Predictions to filter.
		minScore : double
			Minimal score that the returned node-pairs should have.

		Returns
		-------
		A vector of node-pairs whose scores are at least equal to the given minScore.
		"""
		return byScore(predictions, minScore)

	@staticmethod
	def byCount(vector[pair[pair[node, node], double]] predictions, count numLinks):
		""" Returns the first numLinks highest scored node-pairs.

		Parameters
		----------
		predictions : vector[pair[pair[node, node], double]].
			Predictions to filter.
		numLinks : count
			Number of top-scored node-pairs to return.

		Returns
		-------
		The first numLinks highest scored node-pairs.
		"""
		return byCount(predictions, numLinks)

	@staticmethod
	def byPercentage(vector[pair[pair[node, node], double]] predictions, double percentageLinks):
		""" Returns the first percentageLinks percent of the highest scores node-pairs.

		Parameters
		----------
		predictions : vector[pair[pair[node, node], double]].
			Predictions to filter.
		percentageLinks : double
			Percentage of highest scored node-pairs to return.

		Returns
		-------
		The first percentageLinks percent of the highest scores node-pairs.
		"""
		return byPercentage(predictions, percentageLinks)

cdef extern from "cpp/linkprediction/PredictionsSorter.h" namespace "NetworKit::PredictionsSorter":
	void sortByScore (vector[pair[pair[node, node], double]]& predictions) except +
	void sortByNodePair (vector[pair[pair[node, node], double]]& predictions) except +

cdef class PredictionsSorter:
	""" Allows the sorting of predictions by score or node-pair. """

	@staticmethod
	def sortByScore(list predictions):
		""" Sorts the given predictions descendingly by score.

		In case there is a tie the node-pairs are used as a tie-breaker by sorting them
		ascendingly on the first node and on a tie ascendingly by the second node.

		Parameters
		----------
		predictions : vector[pair[pair[node, node], double]]
			The predictions to sort.
		"""
		cdef vector[pair[pair[node, node], double]] predCopy = predictions
		sortByScore(predCopy)
		predictions[:] = predCopy

	@staticmethod
	def sortByNodePair(list predictions):
		""" Sorts the predictions ascendingly by node-pair.

		This means for example (0, 0) < (0, 1) and (1, 1) < (1, 0).

		Parameters
		----------
		predictions : vector[pair[pair[node, node], double]]
			The predictions to sort.
		"""
		cdef vector[pair[pair[node, node], double]] predCopy = predictions
		sortByNodePair(predCopy)
		predictions[:] = predCopy

# Module: EdgeScore

cdef extern from "cpp/edgescores/EdgeScore.h":
	cdef cppclass _EdgeScore "NetworKit::EdgeScore"[T](_Algorithm):
		_EdgeScore(const _Graph& G) except +
		vector[T] scores() except +
		T score(edgeid eid) except +
		T score(node u, node v) except +

cdef class EdgeScore(Algorithm):
	"""
	TODO DOCSTIRNG
	"""
	cdef Graph _G

	cdef bool isDoubleValue(self):
		raise RuntimeError("Implement in subclass")

	def __init__(self, *args, **namedargs):
		if type(self) == EdgeScore:
			raise RuntimeError("Error, you may not use EdgeScore directly, use a sub-class instead")

	def __dealloc__(self):
		self._G = None # just to be sure the graph is deleted

	def score(self, u, v = None):
		if v is None:
			if self.isDoubleValue():
				return (<_EdgeScore[double]*>(self._this)).score(u)
			else:
				return (<_EdgeScore[count]*>(self._this)).score(u)
		else:
			if self.isDoubleValue():
				return (<_EdgeScore[double]*>(self._this)).score(u, v)
			else:
				return (<_EdgeScore[count]*>(self._this)).score(u, v)

	def scores(self):
		if self.isDoubleValue():
			return (<_EdgeScore[double]*>(self._this)).scores()
		else:
			return (<_EdgeScore[count]*>(self._this)).scores()


cdef extern from "cpp/edgescores/ChibaNishizekiTriangleEdgeScore.h":
	cdef cppclass _ChibaNishizekiTriangleEdgeScore "NetworKit::ChibaNishizekiTriangleEdgeScore"(_EdgeScore[count]):
		_ChibaNishizekiTriangleEdgeScore(const _Graph& G) except +

cdef class ChibaNishizekiTriangleEdgeScore(EdgeScore):
	"""
	Calculates for each edge the number of triangles it is embedded in.

	Parameters
	----------
	G : Graph
		The graph to count triangles on.
	"""

	def __cinit__(self, Graph G):
		"""
		G : Graph
			The graph to count triangles on.
		"""
		self._G = G
		self._this = new _ChibaNishizekiTriangleEdgeScore(G._this)

	cdef bool isDoubleValue(self):
		return False

cdef extern from "cpp/edgescores/ChibaNishizekiQuadrangleEdgeScore.h":
	cdef cppclass _ChibaNishizekiQuadrangleEdgeScore "NetworKit::ChibaNishizekiQuadrangleEdgeScore"(_EdgeScore[count]):
		_ChibaNishizekiQuadrangleEdgeScore(const _Graph& G) except +

cdef class ChibaNishizekiQuadrangleEdgeScore(EdgeScore):
	"""
	Calculates for each edge the number of quadrangles (circles of length 4) it is embedded in.

	Parameters
	----------
	G : Graph
		The graph to count quadrangles on.
	"""

	def __cinit__(self, Graph G):
		"""
		Parameters
		----------
		G : Graph
			The graph to count quadrangles on.
		"""
		self._G = G
		self._this = new _ChibaNishizekiQuadrangleEdgeScore(G._this)

	cdef bool isDoubleValue(self):
		return False

cdef extern from "cpp/edgescores/TriangleEdgeScore.h":
	cdef cppclass _TriangleEdgeScore "NetworKit::TriangleEdgeScore"(_EdgeScore[double]):
		_TriangleEdgeScore(const _Graph& G) except +

cdef class TriangleEdgeScore(EdgeScore):
	"""
	Triangle counting.

	Parameters
	----------
	G : Graph
		The graph to count triangles on.
	"""

	def __cinit__(self, Graph G):
		"""
		Parameters
		----------
		G : Graph
			The graph to count triangles on.
		"""
		self._G = G
		self._this = new _TriangleEdgeScore(G._this)

	cdef bool isDoubleValue(self):
		return False

cdef extern from "cpp/edgescores/EdgeScoreLinearizer.h":
	cdef cppclass _EdgeScoreLinearizer "NetworKit::EdgeScoreLinearizer"(_EdgeScore[double]):
		_EdgeScoreLinearizer(const _Graph& G, const vector[double]& attribute, bool inverse) except +

cdef class EdgeScoreLinearizer(EdgeScore):
	"""
	Linearizes a score such that values are evenly distributed between 0 and 1.

	Parameters
	----------
	G : Graph
		The input graph.
	a : vector[double]
		Edge score that shall be linearized.
	"""
	cdef vector[double] _score

	def __cinit__(self, Graph G, vector[double] score, inverse = False):
		self._G = G
		self._score = score
		self._this = new _EdgeScoreLinearizer(G._this, self._score, inverse)

	cdef bool isDoubleValue(self):
		return True


cdef extern from "cpp/edgescores/EdgeScoreNormalizer.h":
	cdef cppclass _EdgeScoreNormalizer "NetworKit::EdgeScoreNormalizer"[T](_EdgeScore[double]):
		_EdgeScoreNormalizer(const _Graph&, const vector[T]&, bool inverse, double lower, double upper) except +

cdef class EdgeScoreNormalizer(EdgeScore):
	"""
	Normalize an edge score such that it is in a certain range.

	Parameters
	----------
	G : Graph
		The graph the edge score is defined on.
	score : vector[double]
		The edge score to normalize.
	inverse
		Set to True in order to inverse the resulting score.
	lower
		Lower bound of the target range.
	upper
		Upper bound of the target range.
	"""
	cdef vector[double] _inScoreDouble
	cdef vector[count] _inScoreCount

	def __cinit__(self, Graph G not None, score, bool inverse = False, double lower = 0.0, double upper = 1.0):
		self._G = G
		try:
			self._inScoreDouble = <vector[double]?>score
			self._this = new _EdgeScoreNormalizer[double](G._this, self._inScoreDouble, inverse, lower, upper)
		except TypeError:
			try:
				self._inScoreCount = <vector[count]?>score
				self._this = new _EdgeScoreNormalizer[count](G._this, self._inScoreCount, inverse, lower, upper)
			except TypeError:
				raise TypeError("score must be either a vector of integer or float")

	cdef bool isDoubleValue(self):
		return True

cdef extern from "cpp/edgescores/EdgeScoreBlender.h":
	cdef cppclass _EdgeScoreBlender "NetworKit::EdgeScoreBlender"(_EdgeScore[double]):
		_EdgeScoreBlender(const _Graph&, const vector[double]&, const vector[double]&, const vector[bool]&) except +

cdef class EdgeScoreBlender(EdgeScore):
	"""
	Blends two attribute vectors, the value is chosen depending on the supplied boolean vector

	Parameters
	----------
	G : Graph
		The graph for which the attribute shall be blended
	attribute0 : vector[double]
		The first attribute (chosen for selection[eid] == false)
	attribute1 : vector[double]
		The second attribute (chosen for selection[eid] == true)
	selection : vector[bool]
		The selection vector
	"""
	cdef vector[double] _attribute0
	cdef vector[double] _attribute1
	cdef vector[bool] _selection

	def __cinit__(self, Graph G not None, vector[double] attribute0, vector[double] attribute1, vector[bool] selection):
		self._G = G
		self._attribute0 = move(attribute0)
		self._attribute1 = move(attribute1)
		self._selection = move(selection)

		self._this = new _EdgeScoreBlender(G._this, self._attribute0, self._attribute1, self._selection)

	cdef bool isDoubleValue(self):
		return True

cdef extern from "cpp/edgescores/GeometricMeanScore.h":
	cdef cppclass _GeometricMeanScore "NetworKit::GeometricMeanScore"(_EdgeScore[double]):
		_GeometricMeanScore(const _Graph& G, const vector[double]& a) except +

cdef class GeometricMeanScore(EdgeScore):
	"""
	Normalizes the given edge attribute by the geometric average of the sum of the attributes of the incident edges of the incident nodes.

	Parameters
	----------
	G : Graph
		The input graph.
	a : vector[double]
		Edge attribute that shall be normalized.
	"""
	cdef vector[double] _attribute

	def __cinit__(self, Graph G, vector[double] attribute):
		self._G = G
		self._attribute = attribute
		self._this = new _GeometricMeanScore(G._this, self._attribute)

	cdef bool isDoubleValue(self):
		return True

cdef extern from "cpp/edgescores/EdgeScoreAsWeight.h":
	cdef cppclass _EdgeScoreAsWeight "NetworKit::EdgeScoreAsWeight":
		_EdgeScoreAsWeight(const _Graph& G, const vector[double]& score, bool squared, edgeweight offset, edgeweight factor) except +
		_Graph calculate() except +

cdef class EdgeScoreAsWeight:
	"""
	Assigns an edge score as edge weight of a graph.

	Parameters
	----------
	G : Graph
		The graph to assign edge weights to.
	score : vector[double]
		The input edge score.
	squared : bool
		Edge weights will be squared if set to True.
	offset : edgeweight
		This offset will be added to each edge weight.
	factor : edgeweight
		Each edge weight will be multiplied by this factor.
	"""

	cdef _EdgeScoreAsWeight* _this
	cdef Graph _G
	cdef vector[double] _score

	def __cinit__(self, Graph G, vector[double] score, bool squared, edgeweight offset, edgeweight factor):
		self._G = G
		self._score = score
		self._this = new _EdgeScoreAsWeight(G._this, self._score, squared, offset, factor)

	def __dealloc__(self):
		self._G = None
		self._score = None
		del self._this

	def getWeightedGraph(self):
		"""
		Returns
		-------
		Graph
			The weighted result graph.
		"""
		return Graph(0).setThis(self._this.calculate())

# Module: distances
cdef extern from "cpp/distance/AdamicAdarDistance.h":
	cdef cppclass _AdamicAdarDistance "NetworKit::AdamicAdarDistance":
		_AdamicAdarDistance(const _Graph& G) except +
		void preprocess() except +
		double distance(node u, node v) except +
		vector[double] getEdgeScores() except +

cdef class AdamicAdarDistance:
	"""
	Calculate the adamic adar similarity.

	Parameters
	----------
	G : Graph
		The input graph.
	"""
	cdef _AdamicAdarDistance* _this
	cdef Graph _G

	def __cinit__(self, Graph G):
		self._G = G
		self._this = new _AdamicAdarDistance(G._this)

	def __dealloc__(self):
		del self._this

	def preprocess(self):
		self._this.preprocess()

	def getAttribute(self):
		"""
		Returns
		-------
		vector[double]
			The edge attribute that contains the adamic adar similarity.

		"""
		#### TODO: convert distance to similarity!?! ####
		return self._this.getEdgeScores()

# Module: sparsification

cdef extern from "cpp/sparsification/SimmelianOverlapScore.h":
	cdef cppclass _SimmelianOverlapScore "NetworKit::SimmelianOverlapScore"(_EdgeScore[double]):
		_SimmelianOverlapScore(const _Graph& G, const vector[count]& triangles, count maxRank) except +

cdef class SimmelianOverlapScore(EdgeScore):
	cdef vector[count] _triangles

	"""
	An implementation of the parametric variant of Simmelian Backbones. Calculates
	for each edge the minimum parameter value such that the edge is still contained in
	the sparsified graph.

	Parameters
	----------
	G : Graph
		The graph to apply the Simmelian Backbone algorithm to.
	triangles : vector[count]
		Previously calculated edge triangle counts on G.
	"""
	def __cinit__(self, Graph G, vector[count] triangles, count maxRank):
		self._G = G
		self._triangles = triangles
		self._this = new _SimmelianOverlapScore(G._this, self._triangles, maxRank)

	cdef bool isDoubleValue(self):
		return True

cdef extern from "cpp/edgescores/PrefixJaccardScore.h":
	cdef cppclass _PrefixJaccardScore "NetworKit::PrefixJaccardScore<double>"(_EdgeScore[double]):
		_PrefixJaccardScore(const _Graph& G, const vector[double]& a) except +

cdef class PrefixJaccardScore(EdgeScore):
	cdef vector[double] _attribute

	def __cinit__(self, Graph G, vector[double] attribute):
		self._G = G
		self._attribute = attribute
		self._this = new _PrefixJaccardScore(G._this, self._attribute)

	cdef bool isDoubleValue(self):
		return True

cdef extern from "cpp/sparsification/MultiscaleScore.h":
	cdef cppclass _MultiscaleScore "NetworKit::MultiscaleScore"(_EdgeScore[double]):
		_MultiscaleScore(const _Graph& G, const vector[double]& a) except +

cdef class MultiscaleScore(EdgeScore):
	"""
	An implementation of the Multiscale Backbone. Calculates for each edge the minimum
	parameter value such that the edge is still contained in the sparsified graph.

	Parameters
	----------
	G : Graph
		The graph to apply the Multiscale algorithm to.
	attribute : vector[double]
		The edge attribute the Multiscale algorithm is to be applied to.
	"""

	cdef vector[double] _attribute

	def __cinit__(self, Graph G, vector[double] attribute):
		self._G = G
		self._attribute = attribute
		self._this = new _MultiscaleScore(G._this, self._attribute)

	cdef bool isDoubleValue(self):
		return True

cdef extern from "cpp/sparsification/RandomEdgeScore.h":
	cdef cppclass _RandomEdgeScore "NetworKit::RandomEdgeScore"(_EdgeScore[double]):
		_RandomEdgeScore(const _Graph& G) except +

cdef class RandomEdgeScore(EdgeScore):
	"""
	[todo]

	Parameters
	----------
	G : Graph
		The graph to calculate the Random Edge attribute for.
	"""

	def __cinit__(self, Graph G):
		self._G = G
		self._this = new _RandomEdgeScore(G._this)

	cdef bool isDoubleValue(self):
		return True

cdef extern from "cpp/sparsification/LocalSimilarityScore.h":
	cdef cppclass _LocalSimilarityScore "NetworKit::LocalSimilarityScore"(_EdgeScore[double]):
		_LocalSimilarityScore(const _Graph& G, const vector[count]& triangles) except +

cdef class LocalSimilarityScore(EdgeScore):
	"""
	An implementation of the Local Simlarity sparsification approach.
	This attributizer calculates for each edge the maximum parameter value
	such that the edge is still contained in the sparsified graph.

	Parameters
	----------
	G : Graph
		The graph to apply the Local Similarity algorithm to.
	triangles : vector[count]
		Previously calculated edge triangle counts.
	"""
	cdef vector[count] _triangles

	def __cinit__(self, Graph G, vector[count] triangles):
		self._G = G
		self._triangles = triangles
		self._this = new _LocalSimilarityScore(G._this, self._triangles)

	cdef bool isDoubleValue(self):
		return True

cdef extern from "cpp/sparsification/ForestFireScore.h":
	cdef cppclass _ForestFireScore "NetworKit::ForestFireScore"(_EdgeScore[double]):
		_ForestFireScore(const _Graph& G, double pf, double tebr) except +

cdef class ForestFireScore(EdgeScore):
	"""
	A variant of the Forest Fire sparsification approach that is based on random walks.
	This attributizer calculates for each edge the minimum parameter value
	such that the edge is still contained in the sparsified graph.

	Parameters
	----------
	G : Graph
		The graph to apply the Forest Fire algorithm to.
	pf : double
		The probability for neighbor nodes to get burned aswell.
	tebr : double
		The Forest Fire will burn until tebr * numberOfEdges edges have been burnt.
	"""

	def __cinit__(self, Graph G, double pf, double tebr):
		self._G = G
		self._this = new _ForestFireScore(G._this, pf, tebr)

	cdef bool isDoubleValue(self):
		return True

cdef extern from "cpp/sparsification/LocalDegreeScore.h":
	cdef cppclass _LocalDegreeScore "NetworKit::LocalDegreeScore"(_EdgeScore[double]):
		_LocalDegreeScore(const _Graph& G) except +

cdef class LocalDegreeScore(EdgeScore):
	"""
	The LocalDegree sparsification approach is based on the idea of hub nodes.
	This attributizer calculates for each edge the maximum parameter value
	such that the edge is still contained in the sparsified graph.

	Parameters
	----------
	G : Graph
		The graph to apply the Local Degree  algorithm to.
	"""

	def __cinit__(self, Graph G):
		self._G = G
		self._this = new _LocalDegreeScore(G._this)

	cdef bool isDoubleValue(self):
		return True

cdef extern from "cpp/distance/JaccardDistance.h":
	cdef cppclass _JaccardDistance "NetworKit::JaccardDistance":
		_JaccardDistance(const _Graph& G, const vector[count]& triangles) except +
		void preprocess() except +
		vector[double] getEdgeScores() except +

cdef class JaccardDistance:
	"""
	The Jaccard distance measure assigns to each edge the jaccard coefficient
	of the neighborhoods of the two adjacent nodes.

	Parameters
	----------
	G : Graph
		The graph to calculate Jaccard distances for.
	triangles : vector[count]
		Previously calculated edge triangle counts.
	"""

	cdef _JaccardDistance* _this
	cdef Graph _G
	cdef vector[count] triangles

	def __cinit__(self, Graph G, vector[count] triangles):
		self._G = G
		self._triangles = triangles
		self._this = new _JaccardDistance(G._this, self._triangles)

	def __dealloc__(self):
		del self._this

	def getAttribute(self):
		return self._this.getEdgeScores()


cdef extern from "cpp/distance/AlgebraicDistance.h":
	cdef cppclass _AlgebraicDistance "NetworKit::AlgebraicDistance":
		_AlgebraicDistance(_Graph G, count numberSystems, count numberIterations, double omega, index norm, bool withEdgeScores) except +
		void preprocess() except +
		double distance(node, node) except +
		vector[double] getEdgeScores() except +


cdef class AlgebraicDistance:
	"""
	Algebraic distance assigns a distance value to pairs of nodes
    according to their structural closeness in the graph.
    Algebraic distances will become small within dense subgraphs.

	Parameters
	----------
	G : Graph
		The graph to calculate Jaccard distances for.
	numberSystems : count
	 	Number of vectors/systems used for algebraic iteration.
	numberIterations : count
	 	Number of iterations in each system.
	omega : double
	 	attenuation factor in [0,1] influencing convergence speed.
	norm : index
		The norm factor of the extended algebraic distance.
	withEdgeScores : bool
		calculate array of scores for edges {u,v} that equal ad(u,v)
	"""

	cdef _AlgebraicDistance* _this
	cdef Graph _G

	def __cinit__(self, Graph G, count numberSystems=10, count numberIterations=30, double omega=0.5, index norm=0, bool withEdgeScores=False):
		self._G = G
		self._this = new _AlgebraicDistance(G._this, numberSystems, numberIterations, omega, norm, withEdgeScores)

	def __dealloc__(self):
		del self._this

	def preprocess(self):
		self._this.preprocess()
		return self

	def distance(self, node u, node v):
		return self._this.distance(u, v)

	def getEdgeScores(self):
		return self._this.getEdgeScores()


cdef class JaccardSimilarityAttributizer:
	"""
	The Jaccard similarity measure assigns to each edge (1 - the jaccard coefficient
	of the neighborhoods of the two adjacent nodes).

	Parameters
	----------
	G : Graph
		The graph to calculate Jaccard similarities for.
	triangles : vector[count]
		Previously calculated edge triangle counts.
	"""

	cdef _JaccardDistance* _this
	cdef Graph _G
	cdef vector[count] _triangles

	def __cinit__(self, Graph G, vector[count] triangles):
		self._G = G
		self._triangles = triangles
		self._this = new _JaccardDistance(G._this, self._triangles)

	def __dealloc__(self):
		del self._this

	def getAttribute(self):
		#convert distance to similarity
		self._this.preprocess()
		return [1 - x for x in self._this.getEdgeScores()]

cdef extern from "cpp/sparsification/RandomNodeEdgeScore.h":
	cdef cppclass _RandomNodeEdgeScore "NetworKit::RandomNodeEdgeScore"(_EdgeScore[double]):
		_RandomNodeEdgeScore(const _Graph& G) except +

cdef class RandomNodeEdgeScore(EdgeScore):
	"""
	Random Edge sampling. This attributizer returns edge attributes where
	each value is selected uniformly at random from [0,1].

	Parameters
	----------
	G : Graph
		The graph to calculate the Random Edge attribute for.
	"""
	def __cinit__(self, Graph G):
		self._G = G
		self._this = new _RandomNodeEdgeScore(G._this)

	cdef bool isDoubleValue(self):
		return True

ctypedef fused DoubleInt:
	int
	double

cdef extern from "cpp/sparsification/LocalFilterScore.h":
	cdef cppclass _LocalFilterScoreDouble "NetworKit::LocalFilterScore<double>"(_EdgeScore[double]):
		_LocalFilterScoreDouble(const _Graph& G, const vector[double]& a, bool logarithmic) except +

	cdef cppclass _LocalFilterScoreInt "NetworKit::LocalFilterScore<int>"(_EdgeScore[count]):
		_LocalFilterScoreInt(const _Graph& G, const vector[double]& a, bool logarithmic) except +

cdef class LocalFilterScore(EdgeScore):
	"""
	Local filtering edge scoring. Edges with high score are more important.

	Edges are ranked locally, the top d^e (logarithmic, default) or 1+e*(d-1) edges (non-logarithmic) are kept.
	For equal attribute values, neighbors of low degree are preferred.
	If bothRequired is set (default: false), both neighbors need to indicate that they want to keep the edge.

	Parameters
	----------
	G : Graph
		The input graph
	a : list
		The input attribute according to which the edges shall be fitlered locally.
	logarithmic : bool
		If the score shall be logarithmic in the rank (then d^e edges are kept). Linear otherwise.
	"""
	cdef vector[double] _a

	def __cinit__(self, Graph G, vector[double] a, bool logarithmic = True):
		self._G = G
		self._a = a
		self._this = new _LocalFilterScoreDouble(G._this, self._a, logarithmic)

	cdef bool isDoubleValue(self):
		return True

cdef extern from "cpp/sparsification/ChanceCorrectedTriangleScore.h":
	cdef cppclass _ChanceCorrectedTriangleScore "NetworKit::ChanceCorrectedTriangleScore"(_EdgeScore[double]):
		_ChanceCorrectedTriangleScore(const _Graph& G, const vector[count]& triangles) except +

cdef class ChanceCorrectedTriangleScore(EdgeScore):
	"""
	Divide the number of triangles per edge by the expected number of triangles given a random edge distribution.

	Parameters
	----------
	G : Graph
		The input graph.
	triangles : vector[count]
		Triangle count.
	"""
	cdef vector[count] _triangles

	def __cinit__(self, Graph G, vector[count] triangles):
		self._G = G
		self._triangles = triangles
		self._this = new _ChanceCorrectedTriangleScore(G._this, self._triangles)

	cdef bool isDoubleValue(self):
		return True

cdef extern from "cpp/sparsification/SCANStructuralSimilarityScore.h":
	cdef cppclass _SCANStructuralSimilarityScore "NetworKit::SCANStructuralSimilarityScore"(_EdgeScore[double]):
		_SCANStructuralSimilarityScore(_Graph G, const vector[count]& triangles) except +

cdef class SCANStructuralSimilarityScore(EdgeScore):
	cdef vector[count] _triangles

	def __cinit__(self, Graph G, vector[count] triangles):
		self._G = G
		self._triangles = triangles
		self._this = new _SCANStructuralSimilarityScore(G._this, self._triangles)

	cdef bool isDoubleValue(self):
		return True

cdef extern from "cpp/sparsification/GlobalThresholdFilter.h":
	cdef cppclass _GlobalThresholdFilter "NetworKit::GlobalThresholdFilter":
		_GlobalThresholdFilter(const _Graph& G, const vector[double]& a, double alpha, bool above) except +
		_Graph calculate() except +

cdef class GlobalThresholdFilter:
	"""
	Calculates a sparsified graph by filtering globally using a constant threshold value
	and a given edge attribute.

	Parameters
	----------
	G : Graph
		The graph to sparsify.
	attribute : vector[double]
		The edge attribute to consider for filtering.
	e : double
		Threshold value.
	above : bool
		If set to True (False), all edges with an attribute value equal to or above (below)
		will be kept in the sparsified graph.
	"""
	cdef _GlobalThresholdFilter* _this
	cdef Graph _G
	cdef vector[double] _attribute

	def __cinit__(self, Graph G not None, vector[double] attribute, double e, bool above):
		self._G = G
		self._attribute = attribute
		self._this = new _GlobalThresholdFilter(G._this, self._attribute, e, above)

	def __dealloc__(self):
		del self._this

	def calculate(self):
		return Graph().setThis(self._this.calculate())

# matching

cdef extern from "cpp/matching/Matching.h":
	cdef cppclass _Matching "NetworKit::Matching":
		_Matching() except +
		_Matching(count) except +
		void match(node, node) except +
		void unmatch(node, node) except +
		bool isMatched(node) except +
		bool areMatched(node, node) except +
		bool isProper(_Graph) except +
		count size(_Graph) except +
		index mate(node) except +
		edgeweight weight(_Graph) except +
		_Partition toPartition(_Graph) except +
		vector[node] getVector() except +

cdef class Matching:
	""" Implements a graph matching.

 		Matching(z=0)

 		Create a new matching data structure for `z` elements.

		Parameters
		----------
		z : index, optional
			Maximum number of nodes.
	"""
	cdef _Matching _this

	def __cinit__(self, index z=0):
		self._this = move(_Matching(z))

	cdef setThis(self,  _Matching& other):
		swap[_Matching](self._this,  other)
		return self

	def match(self, node u, node v):
		self._this.match(u,v)

	def unmatch(self, node u,  node v):
		self._this.unmatch(u, v)

	def isMatched(self, node u):
		return self._this.isMatched(u)

	def areMatched(self, node u, node v):
		return self._this.areMatched(u,v)

	def isProper(self, Graph G):
		return self._this.isProper(G._this)

	def size(self, Graph G):
		return self._this.size(G._this)

	def mate(self, node v):
		return self._this.mate(v)

	def weight(self, Graph G):
		return self._this.weight(G._this)

	def toPartition(self, Graph G):
		return Partition().setThis(self._this.toPartition(G._this))

	def getVector(self):
		""" Get the vector storing the data

		Returns
		-------
		vector
			Vector indexed by node id to node id of mate or none if unmatched
		"""
		return self._this.getVector()





cdef extern from "cpp/matching/Matcher.h":
	cdef cppclass _Matcher "NetworKit::Matcher"(_Algorithm):
		_Matcher(const _Graph _G) except +
		_Matching getMatching() except +

cdef class Matcher(Algorithm):
	""" Abstract base class for matching algorithms """
	cdef Graph G

	def __init__(self, *args, **namedargs):
		if type(self) == Matcher:
			raise RuntimeError("Instantiation of abstract base class")

	def __dealloc__(self):
		self.G = None # just to be sure the graph is deleted

	def getMatching(self):
		"""  Returns the matching.

		Returns
		-------
		Matching
		"""
		if self._this == NULL:
			raise RuntimeError("Error, object not properly initialized")
		return Matching().setThis((<_Matcher*>(self._this)).getMatching())


cdef extern from "cpp/matching/PathGrowingMatcher.h":
	cdef cppclass _PathGrowingMatcher "NetworKit::PathGrowingMatcher"(_Matcher):
		_PathGrowingMatcher(_Graph) except +
		_PathGrowingMatcher(_Graph, vector[double]) except +

cdef class PathGrowingMatcher(Matcher):
	"""
	Path growing matching algorithm as described by  Hougardy and Drake.
	Computes an approximate maximum weight matching with guarantee 1/2.
	"""
	def __cinit__(self, Graph G not None, edgeScores=None):
		self.G = G
		if edgeScores:
			self._this = new _PathGrowingMatcher(G._this, edgeScores)
		else:
			self._this = new _PathGrowingMatcher(G._this)

# profiling

def ranked(sample):
	"""
		Given a list of numbers, this function computes the rank of each value
		and returns a list of ranks where result[i] is the rank of
		the i-th element in the given sample.
		Currently used in profiling.stat.
	"""
	cdef vector[pair[double, count]] helper = vector[pair[double, count]](len(sample))
	cdef vector[double] result = vector[double](len(sample), 0)
	for i in range(len(sample)):
		helper[i] = <pair[double, count]?>(sample[i], i)
	sort(helper.begin(), helper.end())
	cdef double value = helper[0].first
	cdef double summ = 0.
	cdef count length = 0
	for i in range(len(sample)):
		if value == helper[i].first:
			summ += (i+1)
			length += 1
		else:
			summ /= length
			for j in range(length):
				result[helper[i-j-1].second] = summ
			value = helper[i].first
			summ = i+1
			length = 1
	summ /= length
	for j in range(length):
		result[helper[len(sample)-j-1].second] = summ
	return result

def sort2(sample):
	"""
		Sorts a given list of numbers.
		Currently used as profiling.stat.sorted.
	"""
	cdef vector[double] result = <vector[double]?>sample
	sort(result.begin(),result.end())
	return result


cdef extern from "cpp/distance/CommuteTimeDistance.h":
	cdef cppclass _CommuteTimeDistance "NetworKit::CommuteTimeDistance":
		_CommuteTimeDistance(_Graph G, double tol) except +
		void run() nogil except +
		void runApproximation() except +
		void runParallelApproximation() except +
		double distance(node, node) except +
		double runSinglePair(node, node) except +
		double runSingleSource(node) except +


cdef class CommuteTimeDistance:
	""" Computes the Euclidean Commute Time Distance between each pair of nodes for an undirected unweighted graph.

	CommuteTimeDistance(G)

	Create CommuteTimeDistance for Graph `G`.

	Parameters
	----------
	G : Graph
		The graph.
	tol: double
	"""
	cdef _CommuteTimeDistance* _this
	cdef Graph _G

	def __cinit__(self,  Graph G, double tol = 0.1):
		self._G = G
		self._this = new _CommuteTimeDistance(G._this, tol)

	def __dealloc__(self):
		del self._this

	def run(self):
		""" This method computes ECTD exactly. """
		with nogil:
			self._this.run()
		return self

	def runApproximation(self):
		""" Computes approximation of the ECTD. """
		return self._this.runApproximation()

	def runParallelApproximation(self):
		""" Computes approximation (in parallel) of the ECTD. """
		return self._this.runParallelApproximation()

	def distance(self, u, v):
		"""  Returns the ECTD between node u and node v.

		u : node
		v : node
		"""
		return self._this.distance(u, v)

	def runSinglePair(self, u, v):
		"""  Returns the ECTD between node u and node v, without preprocessing.

		u : node
		v : node
		"""
		return self._this.runSinglePair(u, v)

	def runSingleSource(self, u):
		"""  Returns the sum of the ECTDs from u, without preprocessing.

		u : node
		"""
		return self._this.runSingleSource(u)


# stats

def gini(values):
	"""
	Computes the Gini coefficient for the distribution given as a list of values.
	"""
	sorted_list = sorted(values)
	height, area = 0, 0
	for value in sorted_list:
		height += value
		area += height - value / 2.
	fair_area = height * len(values) / 2
	return (fair_area - area) / fair_area


# simulation
cdef extern from "cpp/simulation/EpidemicSimulationSEIR.h":
	cdef cppclass _EpidemicSimulationSEIR "NetworKit::EpidemicSimulationSEIR" (_Algorithm):
		_EpidemicSimulationSEIR(_Graph, count, double, count, count, node) except +
		vector[vector[count]] getData() except +

cdef class EpidemicSimulationSEIR(Algorithm):
	"""
 	Parameters
 	----------
 	G : Graph
 		The graph.
 	tMax : count
 		max. number of timesteps
	transP : double
		transmission probability
	eTime : count
		exposed time
	iTime : count
		infectious time
	zero : node
		starting node
	"""
	cdef Graph G
	def __cinit__(self, Graph G, count tMax, double transP=0.5, count eTime=2, count iTime=7, node zero=none):
		self.G = G
		self._this = new _EpidemicSimulationSEIR(G._this, tMax, transP, eTime, iTime, zero)
	def getData(self):
		return pandas.DataFrame((<_EpidemicSimulationSEIR*>(self._this)).getData(), columns=["zero", "time", "state", "count"])



cdef extern from "cpp/centrality/SpanningEdgeCentrality.h":
	cdef cppclass _SpanningEdgeCentrality "NetworKit::SpanningEdgeCentrality":
		_SpanningEdgeCentrality(_Graph G, double tol) except +
		void run() nogil except +
		void runApproximation() except +
		void runParallelApproximation() except +
		vector[double] scores() except +

cdef class SpanningEdgeCentrality:
	""" Computes the Spanning Edge centrality for the edges of the graph.
	Parameters
	----------
	G : Graph
		The graph.
	tol: double
		Tolerance used for the approximation
	"""
	cdef _SpanningEdgeCentrality* _this
	cdef Graph _G
	def __cinit__(self,  Graph G, double tol = 0.1):
		self._G = G
		self._this = new _SpanningEdgeCentrality(G._this, tol)
	def __dealloc__(self):
		del self._this
	def run(self):
		""" This method computes Spanning Edge Centrality exactly. """
		with nogil:
			self._this.run()
		return self
	def runApproximation(self):
		""" Computes approximation of the Spanning Edge Centrality. """
		return self._this.runApproximation()

	def runParallelApproximation(self):
		""" Computes approximation (in parallel) of the Spanning Edge Centrality. """
		return self._this.runParallelApproximation()

	def scores(self):
		""" Get a vector containing the SEC score for each edge in the graph.

		Returns
		-------
		vector
			The SEC scores.
		"""
		return self._this.scores()



## Module: viz


cdef extern from "cpp/viz/GraphLayoutAlgorithm.h":
	cdef cppclass _GraphLayoutAlgorithm "NetworKit::GraphLayoutAlgorithm"[T]:
		_GraphLayoutAlgorithm(_Graph, count) except +
		count numEdgeCrossings() except +
		bool writeGraphToGML(string path) except +
		bool writeKinemage(string path) except +

cdef class GraphLayoutAlgorithm:

	"""Abstract base class for graph drawing algorithms"""

	cdef _GraphLayoutAlgorithm[double] *_this
	cdef Graph _G

	def __init__(self, *args, **kwargs):
		if type(self) == GraphLayoutAlgorithm:
			raise RuntimeError("Error, you may not use GraphLayoutAlgorithm directly, use a sub-class instead")

	def __dealloc__(self):
		self._G = None # just to be sure the graph is deleted

	def numEdgeCrossings(self):
		""" Computes approximation (in parallel) of the Spanning Edge Centrality. """
		if self._this == NULL:
			raise RuntimeError("Error, object not properly initialized")
		return self._this.numEdgeCrossings()

	def writeGraphToGML(self, path):
		"""Writes the graph and its layout to a .gml file at the specified path
	path: string
		Path where the graph file should be created"""
		if self._this == NULL:
			raise RuntimeError("Error, object not properly initialized")
		return self._this.writeGraphToGML(stdstring(path))

	def writeKinemage(self, string path):
		"""Writes the graph and its layout to a file at the specified path
			path: string
		Path where the graph file should be created"""
		if self._this == NULL:
			raise RuntimeError("Error, object not properly initialized")
		return self._this.writeKinemage(stdstring(path))



cdef extern from "cpp/viz/MaxentStress.h" namespace "NetworKit":
	enum _GraphDistance "NetworKit::MaxentStress::GraphDistance":
		EDGE_WEIGHT,
		ALGEBRAIC_DISTANCE

cdef extern from "cpp/viz/MaxentStress.h" namespace "NetworKit":
	enum _LinearSolverType "NetworKit::MaxentStress::LinearSolverType":
		LAMG,
		CONJUGATE_GRADIENT_IDENTITY_PRECONDITIONER,
		CONJUGATE_GRADIENT_DIAGONAL_PRECONDITIONER


cdef extern from "cpp/viz/MaxentStress.h":
	cdef cppclass _MaxentStress "NetworKit::MaxentStress" (_GraphLayoutAlgorithm[double]):
		_MaxentStress(_Graph G, count dim, count k, double tolerance, _LinearSolverType linearSolverType, bool fastComputation, _GraphDistance graphDistance) except +
		_MaxentStress(_Graph G, count dim, const vector[Point[double]] coordinates, count k, double tolerance, _LinearSolverType linearSolverType, bool fastComputation, _GraphDistance graphDistance) except +
		void run() except +
		void scaleLayout() except +
		double computeScalingFactor() except +
		double fullStressMeasure() except +
		double maxentMeasure() except +
		double meanDistanceError() except +
		double ldme() except +
		void setQ(double q) except +
		void setAlpha(double alpha) except +
		void setAlphaReduction(double alphaReduction) except +
		void setFinalAlpha(double finalAlpha) except +
		void setConvergenceThreshold(double convThreshold) except +
		double getRhs() except +
		double getApproxEntropyTerm() except +
		double getSolveTime() except +


cdef class MaxentStress (GraphLayoutAlgorithm):

	"""
	Implementation of MaxentStress by Gansner et al. using a Laplacian system solver.
  	@see Gansner, Emden R., Yifan Hu, and Steve North. "A maxent-stress model for graph layout."
	Visualization and Computer Graphics, IEEE Transactions on 19, no. 6 (2013): 927-940.

	Parameters
	----------
	G : Graph
		The graph to be handled. Should be connected, otherwise the run() and runAlgo() methods will fail.
	dim: count
		Number of dimensions.
	count: k
	coordinates: vector[pair[double, double]]
		The coordinates we want to draw in.
	tolerance: double
		The tolerance we want our solver to have.
	linearSolverType: _LinearSolverType
		The type of linear solver we wish to use.
	fastComputation: bool
		Decides whether or not slightly faster computation should be employed, leading to slightly worse results.
	graphDistance: _GraphDistance
		Decides what type of graph distance should be utilised.
	"""

	LAMG = 0
	CONJUGATE_GRADIENT_IDENTITY_PRECONDITIONER = 1
	CONJUGATE_GRADIENT_DIAGONAL_PRECONDITIONER = 2
	EDGE_WEIGHT = 0
	ALGEBRAIC_DISTANCE = 1

	def __cinit__(self, Graph G, count dim, count k, vector[pair[double, double]] coordinates = [], double tolerance = 1e-5, _LinearSolverType linearSolverType = LAMG, bool fastComputation = False, _GraphDistance graphDistance = EDGE_WEIGHT):
		cdef Point[double] p = Point[double](0, 0)
		cdef vector[Point[double]] pointCoordinates = vector[Point[double]]()

		for pr in coordinates:
			p = Point[double](pr.first, pr.second)
			pointCoordinates.push_back(p)

		if (coordinates.size() != 0):
			self._this = new _MaxentStress(G._this, dim, pointCoordinates, k, tolerance, linearSolverType, fastComputation, graphDistance)
		else:
			self._this = new _MaxentStress(G._this, dim, k, tolerance, linearSolverType, fastComputation, graphDistance)

	def __dealloc__(self):
		del self._this

	def run(self):
		"""Approximates a graph layout with the maxent-stress algorithm"""
		(<_MaxentStress*>(self._this)).run()
		return self

	def scaleLayout(self):
		"""Scale the layout computed by run() by a scalar s to minimize \sum_{u,v \in V} w_{uv} (s ||x_u - x_v|| - d_{uv}||)^2"""
		(<_MaxentStress*>(self._this)).scaleLayout()
		return self

	def computeScalingFactor(self):
		"""Computes a scalar s s.t. \sum_{u,v \in V} w_{uv} (s ||x_u - x_v|| - d_{uv}||)^2 is minimized"""
		return (<_MaxentStress*>(self._this)).computeScalingFactor()

	def fullStressMeasure(self):
		"""Computes the full stress measure of the computed layout with run()"""
		return (<_MaxentStress*>(self._this)).fullStressMeasure()

	def maxentMeasure(self):
		"""Computes the maxent stress measure for the computed layout with run()"""
		return (<_MaxentStress*>(self._this)).maxentMeasure()

	def meanDistanceError(self):
		"""Computes mean distance error"""
		return (<_MaxentStress*>(self._this)).meanDistanceError()

	def ldme(self):
		"""Computes the ldme"""
		return (<_MaxentStress*>(self._this)).ldme()

	def setQ(self, double q):
		(<_MaxentStress*>(self._this)).setQ(q)
		return self

	def setAlpha(self, double alpha):
		(<_MaxentStress*>(self._this)).setAlpha(alpha)
		return self

	def setAlphaReduction(self, double alphaReduction):
		(<_MaxentStress*>(self._this)).setAlphaReduction(alphaReduction)
		return self

	def setFinalAlpha(self, double finalAlpha):
		(<_MaxentStress*>(self._this)).setFinalAlpha(finalAlpha)
		return self

	def setConvergenceThreshold(self, double convThreshold):
		(<_MaxentStress*>(self._this)).setConvergenceThreshold(convThreshold)
		return self

	def getRhs(self):
		return (<_MaxentStress*>(self._this)).getRhs()

	def getApproxEntropyTerm(self):
		return (<_MaxentStress*>(self._this)).getApproxEntropyTerm()

	def getSolveTime(self):
		return (<_MaxentStress*>(self._this)).getSolveTime()
