import urllib.request
from typing import List


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


for line in lines:
    split_line = line.split(";")
    code = split_line[0].strip()
    status = split_line[1].strip()
    mapping = split_line[2].strip()
    name = split_line[3].strip()
    print(code, status, mapping, name)
