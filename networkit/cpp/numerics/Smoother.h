/*
 * Smoother.h
 *
 *  Created on: 31.10.2014
 *      Author: Michael Wegner (michael.wegner@student.kit.edu)
 */

#ifndef SMOOTHER_H_
#define SMOOTHER_H_

#include "../algebraic/CSRMatrix.h"
#include "../algebraic/Vector.h"

#include <limits>
#include "../algebraic/DynamicMatrix.h"

namespace NetworKit {

/**
 * @ingroup numerics
 * Abstract base class of a smoother.
 */
template<class Matrix>
class Smoother {
public:
	Smoother() {}
	virtual ~Smoother(){}

	virtual Vector relax(const Matrix& A, const Vector& b, const Vector& initialGuess, const count maxIterations = std::numeric_limits<count>::max()) const = 0;
	virtual Vector relax(const Matrix& A, const Vector& b, const count maxIterations = std::numeric_limits<count>::max()) const = 0;
};

} /* namespace NetworKit */

#endif /* SMOOTHER_H_ */
