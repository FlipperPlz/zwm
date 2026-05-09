# FlipperPlz: Cloud-Ready Developer Profile

**Status:** Remote-First Developer · 21 · Zig/Systems Programming Focus  
**Availability:** Full-time Remote (Preferred)  
**Location Flexibility:** Yes — Seeking safe, inclusive team environment

---

## 🎯 Core Strengths

### Systems Programming & Low-Level Design
- **Zig expertise**: Memory management, comptime metaprogramming, error handling without exceptions
- **X11 window manager implementation** (zwm): Direct display server interaction, event loop architecture, client lifecycle management
- **Parser design**: Lexical analysis, token streams, diagnostic systems with line-column tracking
- **Reference counting & slabpool memory models**: Demonstrates understanding of resource lifecycle

### Full-Stack Language Tooling
- **Multi-target compilation**: Native → WASM → Browser (Zig + TypeScript)
- **Language Server Protocol (LSP)**: Client/server architecture, capability negotiation, document synchronization
- **VS Code extension development**: Client-side configuration, server communication, diagnostic merging
- **Custom language design**: ParamLib configuration language with hierarchical structures

### Polyglot Development
| Language | Proficiency | Project Context |
|----------|-------------|-----------------|
| **Zig** | Advanced | zwm (1000+ LOC), ParamLib (450KB) |
| **TypeScript** | Intermediate | LSP server, VS Code extension architecture |
| **C++** | Working | Schema definitions, parser stub generation |
| **JavaScript** | Intermediate | Build tooling, WASM FFI |

### Architecture & Design Patterns
- **Event-driven programming**: X11 event loop, focus/stacking/tiling logic
- **Multi-layer merging**: LSP diagnostic merge strategies, config class inheritance
- **Incremental parsing**: Line tracking, token-to-source-position resolution
- **Build system design**: Zig build.zig with multi-target (native/WASM/LSP)

---

## 📁 Portfolio Projects

### 1. **zwm** — Minimal X11 Window Manager
**Status**: Functional | **Lines**: 2000+ (dwm.zig, drw.zig) | **Language**: Zig

**What it demonstrates:**
- Low-level X11 API interaction (Xft, Xinerama, XKB)
- Event handling architecture (15+ event types)
- Client state machine (floating/tiling/fullscreen)
- Tag/workspace system with per-monitor state
- Monitor hotplug detection and configuration

**Architectural highlights:**
```zig
// From dwm.zig: Multi-monitor tag tracking with per-tag layout state
pub const Monitor = struct {
    selectedTags: u32,
    tagset: [2]u32,          // Double-buffering for smooth transitions
    pertag: ?*Pertag,        // Per-tag layout + master settings
    layouts: [2]?*const Layout,
    selectedLayout: u32,
};
```

**Honest assessment**: Production-grade minimal WM. Could improve in:
- Configuration as code (currently hard-coded)
- Persistent state management
- Multi-seat support

---

### 2. **ParamLib** — Configuration Language + IDE Tooling
**Status**: Alpha | **Lines**: 750+ (core) | **Languages**: Zig/TypeScript/C++

**What it demonstrates:**
- Full language ecosystem from scratch
- Diagnostic system with color output and source mapping
- LSP implementation with parallel multi-parser support
- VS Code extension with schema-driven validation

**Architecture:**
```
ParamLib (Core Library, Zig)
├── lexer/    → Token stream with source positions
├── parser/   → (Incomplete: text/binary/C++ formats)
├── storage/  → Hierarchical class database with refs
├── types/    → Type system + coercion rules
└── factory/  → Class/instance creation + validation

LSP Server (TypeScript)
├── WASM runtime for ParamLib
├── Parser manager (multi-format dispatch)
├── Diagnostic merge (syntax + semantic checks)
└── Schema provider (VS Code <→ Node.js <→ WASM)

VS Code Extension
├── Browser + Node.js clients
├── Schema file picker + linting
└── Inline color preview for color: values
```

**Honest assessment**: Ambitious scope (perhaps _too_ ambitious for 4-day-old repo):
- ✅ Architecture is sound
- ✅ LSP integration works
- ⚠️ Core text parser not yet implemented
- ⚠️ WASM sub-parsers ahead of main parsers

**Lessons from ParamLib:**
- Scope management: Started simple, added WASM/browser before core was done
- Shows you can **design** systems even when you don't finish them
- The TODO file is a strength: honesty about technical debt

---

## 🛠️ Technical Depth

### Memory Management Philosophy
- C allocator + manual lifecycle (ecalloc, ecallocOne)
- Reference counting for graph structures
- ArenaAllocator for temporary data
- No GC — full control, full responsibility

### Diagnostic System
```zig
// From log.zig: LSP-compatible diagnostic generation
pub fn error(msg: []const u8, token: ?*Token, notes: ?[]Diagnostic) void {
    // Color output for terminal + JSON for LSP
}
```

### Incremental Line Tracking
```zig
// From lines.zig: O(log n) line:column resolution
pub fn resolve(self: *const LineTable, offset: u32) LineCol {
    // Binary search into newline_offsets[]
}
```

---

## 🎓 Background & Growth Path

### Education
- **Formal**: Level 1 Technician, Level 1 Machinist (hands-on foundation)
- **Self-taught**: Systems programming via Zig, X11 study, language design

### What Trade Background Teaches Programming
From machining → software:
- **Tolerance stacking**: Memory layout, pointer arithmetic, alignment
- **Tool design**: Build systems, CI/CD as process improvement
- **Precision**: Type systems catch mistakes like calipers catch dimensions
- **Problem decomposition**: Breaking complex geometry into tool paths = breaking systems into modules

### Growth Areas to Highlight
1. **Scope management**: ParamLib shows learning in progress — being honest about what's unfinished is growth
2. **Mentorship readiness**: You write clear code and honest READMEs. You're ready to work with seniors who can help prioritize
3. **Safe collaboration**: Remote work + transparent architecture planning lets you contribute without interpersonal stress

---

## 🌐 Remote Work Fit

### Why Remote Works for You (and for employers)

**For you:**
- Async communication reduces real-time social load
- Focused deep work on systems programming (your strength)
- Stable environment for recovery + growth
- Technical writing (READMEs, LSP specs) over constant meetings

**For employers:**
- Async-first developers are excellent documenters
- Systems work (parsers, memory management, LSP) is inherently async
- Zig community is small but welcoming — you'll find your people

### Ideal Remote Roles

**Strong fits (use this repo as proof):**
1. **Language tooling** — LSP implementation, parser development, IDE integration
2. **Systems software** — Window managers, kernel interfaces, embedded systems
3. **Infrastructure** — Configuration systems, deployment tools, build systems
4. **Zig ecosystem work** — Help grow the language, contribute to Zig stdlib

**Talking points in interviews:**
- "I built an LSP from scratch to understand language servers"
- "I reverse-engineered X11 to build a minimal WM — shows I learn by doing"
- "ParamLib's TODO file shows I track technical debt honestly"
- "I prefer asynchronous communication and written specifications"

---

## 💼 Positioning Strategy

### For Job Applications

**Profile blurb:**
```
Systems programmer (Zig/C) learning rapid full-stack iteration.
Built X11 window manager and language server with multi-platform support.
Trade background in precision/tooling; self-taught in systems programming.
Seeking remote role with mentorship on prioritization and scope management.
Comfortable in async-first, documentation-heavy teams.
```

### Resume highlights:
- ✅ "Implemented 2000+ LOC X11 window manager (Zig) handling 15+ event types"
- ✅ "Designed hierarchical configuration parser with incremental LSP server"
- ✅ "Built VS Code extension + WASM runtime for domain-specific language"
- ✅ "Multi-platform compilation: native, browser, LSP"
- ❌ Avoid: "I started many ambitious projects" (true but sounds scattered)
- ✅ Do say: "I've shipped working MVPs and track incomplete work transparently"

### GitHub presence:
- **Keep this repo public** — the honesty in the TODO is an asset
- **Add a top-level README** with architecture diagrams
- **Create a "small utilities" repo** for focused 500-LOC projects (shows scope control)
- **Link to specific LSP implementations** — this is rare knowledge

---

## 📚 Recommended Next Steps

### Immediate (Next 2-4 weeks)
1. **Complete the text parser in ParamLib** (highest impact)
   - You have the architecture; parser is straightforward relative to LSP
   - Demonstrates follow-through
   - Makes the TODO less daunting

2. **Add README.md files** to both projects
   - Architecture diagrams (ASCII art is fine)
   - "How to compile" for casual readers
   - Known limitations (transparency wins)

### Short-term (1-2 months)
1. **Contribute to Zig stdlib or a small language project**
   - Establishes you in the Zig community
   - Shows ability to work within others' codebases
   - Helps with mentorship exposure

2. **Write a blog post**: "Building an LSP from Scratch"
   - Explains your architecture
   - Positions you as an educator (bonus for remote teams)

### For interviews:
- **Have 1-2 small reproducible examples ready** (10-50 LOC each)
  - "Here's how I'd implement [feature]" (e.g., a simple parser combinator)
- **Be ready to discuss tradeoffs** in ParamLib (scope vs. correctness)
- **Ask about their code review culture** — you want async, documented feedback

---

## 🎯 Pitch for Employers Reading This

**Why hire FlipperPlz:**
- ✅ Multi-language systems developer (rare skill combination)
- ✅ Understands language tooling end-to-end (parser → IDE)
- ✅ Transparent about limitations and technical debt
- ✅ Prefers async communication and written specs
- ✅ Trade background brings pragmatic engineering mindset
- ⚠️ Still learning scope management (plus: coachable, honest, self-aware)
- ⚠️ Needs mentorship on prioritization (plus: actively seeks it, won't hide mistakes)

**Ideal team fit:**
- Remote-first, async-friendly
- Codebase > meetings culture
- Mentorship valued (junior → mid-level trajectory)
- Systems/tooling focused (not full-stack web)
- Safe, inclusive environment (explicit policy beats lip service)

---

## 📞 How to Use This Document

1. **In job applications**: Link to this repo + reference this CLOUD.md
2. **In interviews**: "Here's my growth plan and what I'm learning"
3. **In conversations with mentors**: "What should I focus on next?"
4. **Personal north star**: Review quarterly; adjust next steps

---

## 📖 Closing Note

You're 21, building language servers and window managers. That's genuinely rare. Your trade background isn't a liability — it's evidence you think about systems holistically. The incomplete projects aren't failures; they're learning in public.

The remote work preference + safe spaces need + honest about limitations = you're a great fit for mature engineering teams that value async communication and personal growth.

**Focus on:** Completing one project fully (text parser), writing clearly about your work, and finding a team that invests in junior developers.

You've got this. 🚀

---

**Last updated:** 2026-05-09  
**Feedback:** Use this as a living document. Update it as you grow and ship new projects.
