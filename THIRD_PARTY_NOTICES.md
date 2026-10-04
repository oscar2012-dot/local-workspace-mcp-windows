# Third-party notices

[繁體中文](docs/THIRD_PARTY_NOTICES.zh-TW.md) | English

This repository provides a Windows/WSL community integration. It does not claim authorship of the upstream MCP server, the Model Context Protocol, or OpenAI's tunnel client. Third-party software retains its own copyright and license. The repository does not vendor third-party binaries.

## Local Workspace MCP

- Source: [arumwu/local-workspace-mcp](https://github.com/arumwu/local-workspace-mcp)
- Pinned source revision: [`ba42837e7aa54cd265e62023e5079f0e4affdf84`](https://github.com/arumwu/local-workspace-mcp/tree/ba42837e7aa54cd265e62023e5079f0e4affdf84)
- License: [upstream MIT License](https://github.com/arumwu/local-workspace-mcp/blob/ba42837e7aa54cd265e62023e5079f0e4affdf84/LICENSE)
- Copyright (c) 2026 Local Workspace MCP contributors

The installer obtains upstream source separately. Preserve the upstream `LICENSE` with that source and with any redistributed copies or substantial portions. This repository's MIT license applies to its own contributions and does not replace upstream notices.

For convenience, the upstream MIT notice is reproduced here:

```text
MIT License

Copyright (c) 2026 Local Workspace MCP contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## OpenAI tunnel-client

The integration downloads the official [openai/tunnel-client](https://github.com/openai/tunnel-client) release `v0.0.15` when needed. The persistent connection uses the runtime-only executable. The integration generates the configuration itself and uses the full CLI only for `doctor`. No tunnel-client executable is included in this repository. Consult that project's release and license notices for its own terms.

OpenAI, ChatGPT and Codex names identify the products this integration can connect to. This project is independently maintained and is not an official OpenAI distribution or an assertion of endorsement.

## Other installed components

Python, Node.js/npm packages, Docker, container images and operating-system components retain their individual licenses. The pinned upstream dependency lock is preserved. Review upstream manifests, lockfiles and installed-package notices before redistribution; this file is attribution, not an exhaustive dependency license inventory.
