/**************************************************************************/
/*  test_sky.h                                                            */
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

#ifndef TEST_SKY_H
#define TEST_SKY_H

#include "scene/resources/3d/sky_material.h"
#include "scene/resources/sky.h"

#include "tests/test_macros.h"
#include "tests/test_tools.h"

namespace TestSky {
TEST_CASE("[Sky] Setters and Getters") {
	Ref<Sky> test_sky;
	test_sky.instantiate();

	SUBCASE("[Sky] Set and Get Radiance") {
		test_sky->set_radiance_size(Sky::RADIANCE_SIZE_MAX);
		CHECK(test_sky->get_radiance_size() == Sky::RADIANCE_SIZE_MAX);
	}

	SUBCASE("[Sky] Set and Get Material") {
		Ref<ProceduralSkyMaterial> test_material;
		test_material.instantiate();
		test_sky->set_material(test_material);
		CHECK(test_sky->get_material() == test_material);
	}

	SUBCASE("[Sky] Set and Get Process Mode") {
		Sky::ProcessMode process_mode = Sky::ProcessMode::PROCESS_MODE_QUALITY;
		test_sky->set_process_mode(process_mode);
		CHECK(test_sky->get_process_mode() == process_mode);
	}
}
} //namespace TestSky

#endif
