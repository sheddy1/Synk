"""
Script used to fetch the latest `CaseFolding.txt` file
from the Unicode Character Database (UCD) and parse it
to extract case mappings for Unicode characters.
"""

import urllib.request
from typing import List, Tuple
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

case_mappings_parsed: List[Tuple[List[str], str]] = [
    (case_mapping.mapping.split(), case_mapping.code) for case_mapping in case_mappings if len(case_mapping.code) == 4
]

# Add `Latin Small Letter Reversed E` (ɘ)
# which is missing for some reason.
case_mappings_parsed.append((["0258"], "018E"))

ucaps_str = """/**************************************************************************/
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

static const int caps_table[][2] = {
\t"""

case_mappings_parsed.sort(key=lambda x: int(x[0][0], 16))
lower_to_caps_used = set()

for code, mapping in case_mappings_parsed:
    code_tmp = code[0]
    if code_tmp in lower_to_caps_used:
        continue
    ucaps_str += f"{{ 0x{code_tmp}, 0x{mapping} }},\n\t"
    lower_to_caps_used.add(code_tmp)

ucaps_str = ucaps_str[:-1]  # Remove trailing tab.
ucaps_str += """};

static const int reverse_caps_table[][2] = {
\t"""

case_mappings_parsed.sort(key=lambda x: int(x[1], 16))
caps_to_lower_used = set()

for code, mapping in case_mappings_parsed:
    if mapping in caps_to_lower_used:
        continue
    ucaps_str += f"{{ 0x{mapping}, 0x{code[0]} }},\n\t"
    caps_to_lower_used.add(mapping)

ucaps_str = ucaps_str[:-1]  # Remove trailing tab.
ucaps_str += """};

static int _find_upper(int ch) {
\tint low = 0;
\tint high = sizeof(caps_table)/sizeof(caps_table[0]) - 1;
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
\tint high = sizeof(caps_table)/sizeof(caps_table[0]) - 2;
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
