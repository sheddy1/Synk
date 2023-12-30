/**************************************************************************/
/*  nav_utils.h                                                           */
/**************************************************************************/
/*                         This file is part of:                          */
/*                             GODOT ENGINE                               */
/*                        https://godotengine.org                         */
/**************************************************************************/
/* Copyright (c) 2014-present Godot Engine contributors (see AUTHORS.md). */
/* Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.                  */
/*                                                                        */
/* Permission is hereby granted, free of charge, to any person obtaining  */
/* a copy of this software and associated documentation files (the        */
/* "Software"), to deal in the Software without restriction, including    */
/* without limitation the rights to use, copy, modify, merge, publish,    */
/* distribute, sublicense, and/or sell copies of the Software, and to     */
/* permit persons to whom the Software is furnished to do so, subject to  */
/* the following conditions:                                              */
/*                                                                        */
/* The above copyright notice and this permission notice shall be         */
/* included in all copies or substantial portions of the Software.        */
/*                                                                        */
/* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,        */
/* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF     */
/* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. */
/* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY   */
/* CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,   */
/* TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE      */
/* SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                 */
/**************************************************************************/

#ifndef NAV_UTILS_H
#define NAV_UTILS_H

#include "core/math/vector3.h"
#include "core/templates/hash_map.h"
#include "core/templates/hashfuncs.h"
#include "core/templates/local_vector.h"

class NavBase;

namespace gd {
struct Polygon;

union PointKey {
	struct {
		int64_t x : 21;
		int64_t y : 22;
		int64_t z : 21;
	};

	uint64_t key = 0;
};

struct EdgeKey {
	PointKey a;
	PointKey b;

	static uint32_t hash(const EdgeKey &p_val) {
		return hash_one_uint64(p_val.a.key) ^ hash_one_uint64(p_val.b.key);
	}

	bool operator==(const EdgeKey &p_key) const {
		return (a.key == p_key.a.key) && (b.key == p_key.b.key);
	}

	EdgeKey(const PointKey &p_a = PointKey(), const PointKey &p_b = PointKey()) :
			a(p_a),
			b(p_b) {
		if (a.key > b.key) {
			SWAP(a, b);
		}
	}
};

struct Point {
	Vector3 pos;
	PointKey key;
};

struct Edge {
	/// The gateway in the edge, as, in some case, the whole edge might not be navigable.
	struct Connection {
		/// Polygon that this connection leads to.
		Polygon *polygon = nullptr;

		/// Edge of the source polygon where this connection starts from.
		int edge = -1;

		/// Point on the edge where the gateway leading to the poly starts.
		Vector3 pathway_start;

		/// Point on the edge where the gateway leading to the poly ends.
		Vector3 pathway_end;
	};

	/// Connections from this edge to other polygons.
	Vector<Connection> connections;
};

struct Polygon {
	/// Id of the polygon in the map.
	uint32_t id = UINT32_MAX;

	/// Navigation region or link that contains this polygon.
	const NavBase *owner = nullptr;

	/// The points of this `Polygon`
	LocalVector<Point> points;

	/// Are the points clockwise?
	bool clockwise;

	/// The edges of this `Polygon`
	LocalVector<Edge> edges;

	/// The center of this `Polygon`
	Vector3 center;

	real_t surface_area = 0.0;
};

struct NavigationPoly {
	/// This poly.
	const Polygon *poly = nullptr;

	/// Index in the heap of traversable polygons.
	uint32_t open_set_index = UINT32_MAX;

	/// Those 4 variables are used to travel the path backwards.
	int back_navigation_poly_id = -1;
	int back_navigation_edge = -1;
	Vector3 back_navigation_edge_pathway_start;
	Vector3 back_navigation_edge_pathway_end;

	/// The entry position of this poly.
	Vector3 entry;
	/// The distance traveled until now (g cost).
	real_t traveled_distance = 0.0;
	/// The distance to the destination (h cost).
	real_t distance_to_destination = 0.0;

	/// The total travel cost (f cost).
	real_t total_travel_cost() const {
		return traveled_distance + distance_to_destination;
	}

	bool operator==(const NavigationPoly &p_other) const {
		return this->poly == p_other.poly;
	}

	bool operator!=(const NavigationPoly &p_other) const {
		return !operator==(p_other);
	}
};

class NavPolyTravelCostGreaterThan {
	const LocalVector<NavigationPoly> &_nav_polys;

public:
	NavPolyTravelCostGreaterThan(const LocalVector<NavigationPoly> &p_nav_polys) :
			_nav_polys(p_nav_polys) {}

	// Returns `true` if the travel cost of `a` is higher than that of `b`.
	bool operator()(uint32_t p_id_a, uint32_t p_id_b) const {
		real_t f_cost_a = _nav_polys[p_id_a].total_travel_cost();
		real_t h_cost_a = _nav_polys[p_id_a].distance_to_destination;
		real_t f_cost_b = _nav_polys[p_id_b].total_travel_cost();
		real_t h_cost_b = _nav_polys[p_id_b].distance_to_destination;

		if (f_cost_a != f_cost_b) {
			return f_cost_a > f_cost_b;
		} else {
			return h_cost_a > h_cost_b;
		}
	}
};

class NavPolyHeapIndexer {
	LocalVector<NavigationPoly> &_nav_polys;

public:
	NavPolyHeapIndexer(LocalVector<NavigationPoly> &p_nav_polys) :
			_nav_polys(p_nav_polys) {}

	void operator()(uint32_t p_nav_poly_id, uint32_t p_heap_index) {
		_nav_polys[p_nav_poly_id].open_set_index = p_heap_index;
	}
};

struct ClosestPointQueryResult {
	Vector3 point;
	Vector3 normal;
	RID owner;
};

} // namespace gd

#endif // NAV_UTILS_H
