#!/usr/bin/env python3
"""Small threaded release server with single-range HTTP download support."""

from __future__ import annotations

import argparse
import os
from functools import partial
from http import HTTPStatus
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer


class RangeRequestHandler(SimpleHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "CN77ReleaseHTTP/1.0"

    def send_head(self):  # noqa: N802 - stdlib handler API
        path = self.translate_path(self.path)
        if os.path.isdir(path):
            return super().send_head()

        try:
            file_handle = open(path, "rb")
        except OSError:
            self.send_error(HTTPStatus.NOT_FOUND, "File not found")
            return None

        stat_result = os.fstat(file_handle.fileno())
        size = stat_result.st_size
        range_header = self.headers.get("Range")
        content_type = self.guess_type(path)

        if not range_header:
            start = 0
            length = size
            status = HTTPStatus.OK
        else:
            if not range_header.startswith("bytes=") or "," in range_header:
                return self._send_range_error(file_handle, size)
            spec = range_header[6:].strip()
            if "-" not in spec:
                return self._send_range_error(file_handle, size)
            start_text, end_text = spec.split("-", 1)
            try:
                if not start_text:
                    suffix_length = int(end_text)
                    if suffix_length <= 0:
                        return self._send_range_error(file_handle, size)
                    start = max(0, size - suffix_length)
                    end = size - 1
                else:
                    start = int(start_text)
                    if start < 0 or start >= size:
                        return self._send_range_error(file_handle, size)
                    end = int(end_text) if end_text else size - 1
                    end = min(end, size - 1)
                    if end < start:
                        return self._send_range_error(file_handle, size)
            except ValueError:
                return self._send_range_error(file_handle, size)
            length = end - start + 1
            file_handle.seek(start)
            status = HTTPStatus.PARTIAL_CONTENT

        self._range_length = length
        self.send_response(status)
        self.send_header("Content-type", content_type)
        self.send_header("Content-Length", str(length))
        self.send_header("Accept-Ranges", "bytes")
        self.send_header("Last-Modified", self.date_time_string(stat_result.st_mtime))
        if status == HTTPStatus.PARTIAL_CONTENT:
            self.send_header("Content-Range", f"bytes {start}-{start + length - 1}/{size}")
        self.end_headers()
        return file_handle

    def _send_range_error(self, file_handle, size):
        file_handle.close()
        self.send_response(HTTPStatus.REQUESTED_RANGE_NOT_SATISFIABLE)
        self.send_header("Content-Range", f"bytes */{size}")
        self.send_header("Accept-Ranges", "bytes")
        self.send_header("Content-Length", "0")
        self.end_headers()
        return None

    def copyfile(self, source, outputfile):  # noqa: N802 - stdlib handler API
        remaining = getattr(self, "_range_length", None)
        if remaining is None:
            return super().copyfile(source, outputfile)
        while remaining > 0:
            chunk = source.read(min(1024 * 1024, remaining))
            if not chunk:
                break
            outputfile.write(chunk)
            remaining -= len(chunk)


def main() -> None:
    parser = argparse.ArgumentParser(description="Serve CN77 release files with HTTP Range support")
    parser.add_argument("--bind", default="66.45.226.118")
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--directory", required=True)
    args = parser.parse_args()

    handler = partial(RangeRequestHandler, directory=args.directory)
    server = ThreadingHTTPServer((args.bind, args.port), handler)
    server.daemon_threads = True
    try:
        server.serve_forever()
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
