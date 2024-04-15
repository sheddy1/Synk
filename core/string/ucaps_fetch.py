"""
Script used to fetch the latest `CaseFolding.txt` file
from the Unicode Character Database (UCD) and parse it
to extract case mappings for Unicode characters.
"""

import urllib.request
from typing import List
import os


def txt_fetch(target_url: str) -> List[str]:
    """
    Fetches a text file from the given URL and returns it as a list of lines.

    :param target_url: The URL of the text file to fetch.
    :return: A list of lines from the fetched text file.
    """
    return [line.decode("utf-8") for line in urllib.request.urlopen(target_url)]


# CaseFolding-15.1.0.txt
# Date: 2023-05-12, 21:53:10 GMT
# © 2023 Unicode®, Inc.
#
# Format:
# <code>; <status>; <mapping>; # <name>
URL = "https://www.unicode.org/Public/UCD/latest/ucd/CaseFolding.txt"

lines = txt_fetch(URL)
lines = lines[62 : (len(lines) - 2)]  # Trim unnecessary data.


class CaseMapping:
    def __init__(self, code: str, status: str, mapping: str, name: str) -> None:
        self.code = code
        self.status = status
        self.mapping = mapping
        self.name = name

    def __str__(self) -> str:
        return f"{self.code}; {self.status}; {self.mapping}  # {self.name}"


case_mappings: List[CaseMapping] = []

for line in lines:
    split_line = line.split(";")
    case_mapping = CaseMapping(
        split_line[0].strip(),
        split_line[1].strip(),
        split_line[2].strip(),
        split_line[3].strip()[2:],
    )
    case_mappings.append(case_mapping)

case_mappings_parsed = [
    (case_mapping.mapping, case_mapping.code, case_mapping.name)
    for case_mapping in case_mappings
    if case_mapping.status in ["C", "F", "S", "T"]
    and len(case_mapping.code) == 4
    and case_mapping.mapping != case_mapping.code
]

case_mappings_parsed.sort(key=lambda x: x[0])

CAPS_LEN = len(case_mappings_parsed)

ucaps_str = f"""/**************************************************************************/
/*  ucaps.h                                                               */
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

#ifndef UCAPS_H
#define UCAPS_H

#define CAPS_LEN {CAPS_LEN}

static const int caps_table[CAPS_LEN][2] = {{
\t"""

for code, mapping, _ in case_mappings_parsed:
    ucaps_str += f"{{ 0x{code}, 0x{mapping} }},\n\t"

# for code, mapping, name in case_mappings_parsed:
#     ucaps_str += f"{{ 0x{code}, 0x{mapping} }},  // {name}.\n\t"

ucaps_str = ucaps_str[:-1]  # Remove trailing tab.
ucaps_str += """};

static const int reverse_caps_table[CAPS_LEN][2] = {
\t"""

for code, mapping, _ in case_mappings_parsed:
    ucaps_str += f"{{ 0x{mapping}, 0x{code} }},\n\t"

# for code, mapping, name in case_mappings_parsed:
#     ucaps_str += f"{{ 0x{mapping}, 0x{code} }},  // {name}.\n\t"

ucaps_str = ucaps_str[:-1]  # Remove trailing tab.
ucaps_str += """};

static int _find_upper(int ch) {
\tint low = 0;
\tint high = CAPS_LEN - 1;
\tint middle;

\twhile (low <= high) {
\t\tmiddle = (low + high) / 2;

\t\tif (ch < caps_table[middle][0]) {
\t\t\thigh = middle - 1;  // Search low end of array.
\t\t} else if (caps_table[middle][0] < ch) {
\t\t\tlow = middle + 1;  // Search high end of array.
\t\t} else {
\t\t\treturn caps_table[middle][1];
\t\t}
\t}

\treturn ch;
}

static int _find_lower(int ch) {
\tint low = 0;
\tint high = CAPS_LEN - 2;
\tint middle;

\twhile (low <= high) {
\t\tmiddle = (low + high) / 2;

\t\tif (ch < reverse_caps_table[middle][0]) {
\t\t\thigh = middle - 1;  // Search low end of array.
\t\t} else if (reverse_caps_table[middle][0] < ch) {
\t\t\tlow = middle + 1;  // Search high end of array.
\t\t} else {
\t\t\treturn reverse_caps_table[middle][1];
\t\t}
\t}

\treturn ch;
}

#endif // UCAPS_H
"""

ucaps_path = os.path.join(os.path.dirname(__file__), "ucaps.h")
with open(ucaps_path, "w") as f:
    f.write(ucaps_str)

print("`ucaps.h` generated successfully.")
