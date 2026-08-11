#!/usr/bin/env python3
# "===----------------------------------------------------------------------===
# Part of the eld Project, under the BSD License
# See https://github.com/qualcomm/eld/LICENSE.txt for license information.
# SPDX-License-Identifier: BSD-3-Clause
# "===----------------------------------------------------------------------===

"""Sphinx extension that renders D2 diagram files to SVG images.

Provides a ``d2`` directive that accepts a path to a ``.d2`` source file
(relative to the document's source directory) and renders it to SVG using the
``d2`` command-line tool.

Usage in RST::

    .. d2:: path/to/diagram.d2
       :alt: Diagram description

Configuration options (in conf.py)::

    d2_executable = "d2"       # path to the d2 binary
    d2_layout = "elk"        # layout engine: dagre, elk, ...
    d2_theme = 0               # numeric theme ID
"""

from __future__ import annotations

import hashlib
import posixpath
import subprocess
from pathlib import Path

from docutils import nodes
from docutils.parsers.rst import Directive, directives
from sphinx.errors import ExtensionError
from sphinx.util import logging

logger = logging.getLogger(__name__)


class D2Node(nodes.General, nodes.Element):
    """Internal node carrying the d2 source path and alt text."""


def _hash_file(path: Path) -> str:
    return hashlib.md5(path.read_bytes()).hexdigest()[:8]


def _render_d2(executable: str, source: Path, output: Path, layout: str, theme: int) -> None:
    cmd = [
        executable,
        f"--layout={layout}",
        f"--theme={theme}",
        "--bundle",
        str(source),
        str(output),
    ]
    print(
        "Generating D2 diagram: "
        f"{source} -> {output} "
        f"(layout={layout}, theme={theme})",
        flush=True,
    )
    try:
        result = subprocess.run(cmd, capture_output=True, text=True)
    except FileNotFoundError:
        raise ExtensionError(
            f"d2 executable not found: {executable!r}. "
            "Install d2 from https://d2lang.com or set d2_executable in conf.py."
        )
    if result.returncode != 0:
        raise ExtensionError(
            f"d2 failed to render {source}:\n{result.stderr}"
        )


class D2Directive(Directive):
    """Render a D2 diagram file and insert it as an SVG image."""

    required_arguments = 1
    optional_arguments = 0
    final_argument_whitespace = False
    has_content = False
    option_spec = {
        "alt": directives.unchanged,
    }

    def run(self):
        env = self.state.document.settings.env

        rel_path = self.arguments[0]
        # Resolve relative to the document's directory within the source tree.
        doc_dir = Path(env.docname).parent
        source_path = (Path(env.srcdir) / doc_dir / rel_path).resolve()

        if not source_path.is_file():
            raise self.error(
                f"D2 source file not found: {rel_path!r} "
                f"(resolved to {source_path})"
            )

        alt = self.options.get("alt", source_path.stem)
        node = D2Node()
        node["d2_path"] = str(source_path)
        node["alt"] = alt
        return [node]


def _render_node(translator, node: D2Node) -> str:
    """Render the d2 file to SVG inside outdir/_images and return the src URI."""
    app = translator.builder.app
    config = app.config
    outdir = Path(translator.builder.outdir)

    d2_executable = getattr(config, "d2_executable", "d2")
    d2_layout = getattr(config, "d2_layout", "elk")
    d2_theme = getattr(config, "d2_theme", 0)

    source_path = Path(node["d2_path"])
    content_hash = _hash_file(source_path)
    svg_name = f"d2_{source_path.stem}_{content_hash}.svg"

    images_dir = outdir / "_images"
    images_dir.mkdir(parents=True, exist_ok=True)
    svg_path = images_dir / svg_name

    if not svg_path.is_file():
        _render_d2(d2_executable, source_path, svg_path, d2_layout, d2_theme)

    # imgpath is the relative path from the current HTML page to _images/
    return posixpath.join(translator.builder.imgpath, svg_name)


def html_visit_d2_node(translator, node: D2Node) -> None:
    try:
        src = _render_node(translator, node)
    except ExtensionError as exc:
        logger.warning(str(exc))
        raise nodes.SkipNode

    alt = (node.get("alt", "") or "").replace('"', "&quot;")
    translator.body.append(
        f'<div class="d2-diagram">'
        f'<img src="{src}" alt="{alt}" class="d2"/>'
        f'</div>\n'
    )
    raise nodes.SkipNode


def html_depart_d2_node(translator, node: D2Node) -> None:
    pass


def _noop_visit(translator, node) -> None:
    pass


def _noop_depart(translator, node) -> None:
    pass


def setup(app):
    app.add_config_value("d2_executable", "d2", "env")
    app.add_config_value("d2_layout", "elk", "env")
    app.add_config_value("d2_theme", 0, "env")

    app.add_node(
        D2Node,
        html=(html_visit_d2_node, html_depart_d2_node),
        singlehtml=(html_visit_d2_node, html_depart_d2_node),
        latex=(lambda t, n: (_ for _ in ()).throw(nodes.SkipNode), None),
        text=(lambda t, n: (_ for _ in ()).throw(nodes.SkipNode), None),
    )
    app.add_directive("d2", D2Directive)

    # sphinx.ext.todo in Sphinx 5.x does not register singlehtml visitors for
    # todo_node, causing a crash when singlehtml is built. Register no-op
    # handlers here so the singlehtml builder can proceed.
    try:
        from sphinx.ext.todo import todo_node

        app.add_node(
            todo_node,
            override=True,
            singlehtml=(_noop_visit, _noop_depart),
        )
    except Exception:
        pass

    return {
        "version": "0.1",
        "parallel_read_safe": True,
        "parallel_write_safe": False,
    }
