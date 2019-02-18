cimport cython
from libc.math cimport sqrt
from . random cimport randomDouble_UnitRange
from .. utils.limits cimport INT_MAX
from .. data_structures cimport Vector3DList, FloatList, EulerList, Euler3, QuaternionList, Quaternion

# http://freespace.virgin.net/hugo.elias/models/m_perlin.htm

def perlinNoiseVectorForNodes(seed, nodeSeed, double evolution, double speed, amplitude, octaves, double persistance):
    cdef double finalX = evolution * max(speed, 0) / 20 + seed * 9234612 + nodeSeed * 3424533
    cdef int finalOctaves = max(octaves, 0) % 0x7fffffff
    return (perlinNoise1D(finalX, persistance, finalOctaves) * amplitude[0],
            perlinNoise1D(finalX + 1356453, persistance, finalOctaves) * amplitude[1],
            perlinNoise1D(finalX + 9786652, persistance, finalOctaves) * amplitude[2])

def perlinNoiseForNodes(seed, nodeSeed, double evolution, double speed, double amplitude, octaves, double persistance):
    cdef double finalX = evolution * max(speed, 0) / 20 + seed * 545621 + nodeSeed * 3424536
    return perlinNoise1D(finalX, persistance, octaves % 0x7fffffff) * amplitude

def wiggleVectorList(amount, double evolution, amplitude, int octaves, double persistance):
    cdef Vector3DList result = Vector3DList(length = amount)
    cdef float *values = <float*>result.data
    cdef float _amplitude[3]
    cdef Py_ssize_t i
    _amplitude[0], _amplitude[1], _amplitude[2] = amplitude[0], amplitude[1], amplitude[2]
    for i in range(amount * 3):
        values[i] = perlinNoise1D(evolution + i * 354623, persistance, octaves) * _amplitude[i % 3]
    return result

def wiggleFloatList(amount, double evolution, amplitude, int octaves, double persistance):
    cdef FloatList result = FloatList(length = amount)
    cdef float *values = <float*>result.data
    cdef Py_ssize_t i
    for i in range(amount):
        values[i] = perlinNoise1D(evolution + i * 354623, persistance, octaves) * amplitude
    return result

def wiggleEulerList(amount, double evolution, amplitude, int octaves, double persistance):
    cdef EulerList result = EulerList(length = amount)
    cdef Euler3 *values = <Euler3*>result.data
    cdef float _amplitude[3]
    cdef Py_ssize_t i
    _amplitude[0], _amplitude[1], _amplitude[2] = amplitude[0], amplitude[1], amplitude[2]
    for i in range(amount):
        values[i].x = perlinNoise1D(evolution + i * 354623, persistance, octaves) * _amplitude[0]
        values[i].y = perlinNoise1D(evolution + i + 0.33 * 354623, persistance, octaves) * _amplitude[1]
        values[i].z = perlinNoise1D(evolution + i + 0.66 * 354623, persistance, octaves) * _amplitude[2]
        values[i].order = 0
    return result

def wiggleQuaternionList(amount, double evolution, amplitude, int octaves, double persistance):
    cdef QuaternionList result = QuaternionList(length = amount)
    cdef Quaternion *values = <Quaternion*>result.data
    cdef float _amplitude[4]
    cdef float _length
    cdef float x, y, z, w
    cdef Py_ssize_t i
    _amplitude[0], _amplitude[1], _amplitude[2], _amplitude[3] = amplitude[0], amplitude[1], amplitude[2], amplitude[3]
    for i in range(amount):
        x = perlinNoise1D(evolution + i * 354623, persistance, octaves) * _amplitude[0]
        y = perlinNoise1D(evolution + i + 0.25 * 354623, persistance, octaves) * _amplitude[1]
        z = perlinNoise1D(evolution + i + 0.5 * 354623, persistance, octaves) * _amplitude[2]
        w = perlinNoise1D(evolution + i + 0.75 * 354623, persistance, octaves) * _amplitude[3]

        _length = sqrt(x * x + y * y + z * z + w * w)
        x /= _length
        y /= _length
        z /= _length
        w /= _length

        values[i].x = x
        values[i].y = y
        values[i].z = z
        values[i].w = w

    return result

cpdef double perlinNoise1D(double x, double persistance, int octaves):
    cdef:
        double total = 0
        double frequency = 1
        double amplitude = 1
        int i

    for i in range(max(octaves, 0)):
        total += interpolatedNoise(x * frequency) * amplitude
        frequency *= 2
        amplitude *= persistance

    return total

@cython.cdivision(True)
cdef double interpolatedNoise(double x):
    x = x % INT_MAX
    cdef:
        int intX = <int>x
        double fracX = x - intX
        double v0 = randomDouble_UnitRange(intX - 2)
        double v1 = randomDouble_UnitRange(intX - 1)
        double v2 = randomDouble_UnitRange(intX)
        double v3 = randomDouble_UnitRange(intX + 1)
        double v4 = randomDouble_UnitRange(intX + 2)
        double v5 = randomDouble_UnitRange(intX + 3)

    return cubicInterpolation(
            v0 / 4.0 + v1 / 2.0 + v2 / 4.0,
            v1 / 4.0 + v2 / 2.0 + v3 / 4.0,
            v2 / 4.0 + v3 / 2.0 + v4 / 4.0,
            v3 / 4.0 + v4 / 2.0 + v5 / 4.0,
            fracX)

cdef inline double cubicInterpolation(double v0, double v1, double v2, double v3, double x):
    cdef double p, q, r, s, x2
    p = (v3 - v2) - (v0 - v1)
    q = (v0 - v1) - p
    r = v2 - v0
    s = v1
    x2 = x * x
    return p * x2 * x + q * x2 + r * x + s