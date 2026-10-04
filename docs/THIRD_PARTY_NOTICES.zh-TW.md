# 第三方聲明

繁體中文 | [English](../THIRD_PARTY_NOTICES.md)

本倉庫提供 Windows／WSL 社群整合，不主張擁有上游 MCP 伺服器、Model Context Protocol 或 OpenAI tunnel client 的原創作者身分。第三方軟體保留各自的著作權與授權。本倉庫不夾帶第三方二進位檔。

## Local Workspace MCP

- 原始碼：[arumwu/local-workspace-mcp](https://github.com/arumwu/local-workspace-mcp)
- 固定的原始碼修訂版本：[`ba42837e7aa54cd265e62023e5079f0e4affdf84`](https://github.com/arumwu/local-workspace-mcp/tree/ba42837e7aa54cd265e62023e5079f0e4affdf84)
- 授權：[上游 MIT License](https://github.com/arumwu/local-workspace-mcp/blob/ba42837e7aa54cd265e62023e5079f0e4affdf84/LICENSE)
- Copyright (c) 2026 Local Workspace MCP contributors

安裝器會另外取得上游原始碼。請將上游的 `LICENSE` 與該原始碼，以及任何再散布的副本或重要部分一併保留。本倉庫的 MIT 授權適用於自身的貢獻，不取代上游聲明。

為方便查閱，以下重現上游 MIT 授權聲明原文：

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

本整合會在需要時下載官方 [openai/tunnel-client](https://github.com/openai/tunnel-client) 的 `v0.0.15` 版本。常駐連線使用 runtime-only 執行檔。設定由整合腳本自行產生，完整 CLI 僅用於執行 `doctor`。本倉庫不包含 tunnel-client 執行檔。請參閱該專案的版本發布資訊與授權聲明，以了解其適用條款。

OpenAI、ChatGPT 與 Codex 名稱用於辨識本整合可連接的產品。本專案由獨立維護者維護，並非 OpenAI 官方發行版本，也不代表獲得 OpenAI 背書。

## 其他安裝元件

Python、Node.js／npm 套件、Docker、容器映像與作業系統元件各自保留其授權。固定版本的上游相依套件鎖定檔維持原樣。再散布前，請檢查上游的套件資訊清單、鎖定檔與已安裝套件的聲明；本文件用於標示第三方歸屬，並非完整的相依套件授權清冊。
