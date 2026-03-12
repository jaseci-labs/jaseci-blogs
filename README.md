# Jac Blog

A clean MkDocs blog setup with Jac syntax highlighting and interactive, runnable Jac code blocks.

## Contributing

We welcome contributions from anyone in the community! If you'd like to write a blog post, we'd love to hear from you. Topics can include anything relevant to:

- **Jac & Jaseci** -- tutorials, tips, deep dives, project showcases
- **AI & Machine Learning** -- techniques, tools, research, opinions
- **Cool Open Source Tools** -- discoveries, comparisons, how-tos
- **Open Source News** -- notable releases, ecosystem updates, community happenings
- **Anything Nerdy** -- if it's insightful, creative, or just plain fun for a technical audience, we're interested

We'll review all submissions and happily accept anything that's insightful or otherwise enjoyable to the community. Don't be shy -- submit a PR!

### How to Submit a Post

1. Fork the repo and create a new branch
2. Add your post as a markdown file in `docs/blog/posts/`:
   ```bash
   touch docs/blog/posts/my-awesome-post.md
   ```
3. Add frontmatter to the top of your post:
   ```yaml
   ---
   date: 2026-03-12
   authors:
     - your_author_id
   categories:
     - Your Category
   slug: my-awesome-post
   ---
   ```
4. Write your post in markdown (see [Adding Jac Code Blocks](#adding-jac-code-blocks) for interactive code examples). We also love [Mermaid](https://mermaid.js.org/) diagrams -- use ` ```mermaid ` code blocks to add flowcharts, sequence diagrams, and more. For custom graphics, we prefer SVGs since they scale nicely and keep the site looking crisp
5. If you need images (e.g., screenshots of what you built), place them in `docs/assets/` and keep file sizes reasonable -- aim for under 100KB per image when possible. Compress PNGs/JPGs before committing
6. Open a pull request

### Adding Yourself as an Author

If you're a new contributor, add yourself to `docs/blog/.authors.yml`:

```yaml
authors:
  # ... existing authors ...
  your_author_id:
    name: Your Name
    description: A short bio about yourself
    avatar: https://avatars.githubusercontent.com/u/YOUR_GITHUB_USER_ID?v=4
```

To get your GitHub avatar URL, just replace `YOUR_GITHUB_USER_ID` with your numeric GitHub user ID. You can find your ID by visiting `https://api.github.com/users/YOUR_GITHUB_USERNAME` -- look for the `id` field in the response. This will make your profile picture show up nicely alongside your posts.

## Features

- **Jac Syntax Highlighting**: Beautiful syntax highlighting for Jac code using custom Pygments and Monaco lexers
- **Interactive Code Blocks**: Run Jac code directly in the browser using Pyodide (WebAssembly)
- **Clean Design**: Built with MkDocs Material theme
- **Easy to Use**: Simple markdown-based content creation
- **Fast**: Static site generation for optimal performance

## Prerequisites

- Python 3.8 or higher
- pip (Python package installer)
- Git

## Installation

1. **Clone this repository** (if you haven't already):
   ```bash
   cd ~/blog
   ```

2. **Install all dependencies and the Jac syntax highlighter**:
   ```bash
   pip install -e .
   ```

   This will install all required dependencies (mkdocs-material, pymdown-extensions, pygments, mkdocs-video, starlette, uvicorn) and register the Jac syntax highlighter.

## Usage

### Development Server

To start the development server with interactive code execution:

```bash
python scripts/mkdocs_serve.py
```

This will start a server at `http://127.0.0.1:8000` with the necessary CORS headers for Pyodide to work.

> **Note**: The custom server (`mkdocs_serve.py`) is required for runnable code blocks to work properly because it sets up the CORS headers needed for SharedArrayBuffer support.

Alternatively, for basic preview without runnable code blocks:

```bash
mkdocs serve
```

### Building the Site

To build the static site:

```bash
mkdocs build
```

The built site will be in the `site/` directory.

### Deploying

Deploy to GitHub Pages:

```bash
mkdocs gh-deploy
```

## Writing Blog Posts

### Creating a New Post

1. Create a new markdown file in `docs/posts/`:
   ```bash
   touch docs/posts/my-new-post.md
   ```

2. Add the post to the navigation in `mkdocs.yml`:
   ```yaml
   nav:
     - Posts:
       - My New Post: posts/my-new-post.md
   ```

### Adding Jac Code Blocks

#### Static Syntax Highlighting Only

For code that just needs syntax highlighting:

````markdown
```jac
with entry {
    print("Hello, World!");
}
```
````

#### Interactive/Runnable Code Blocks

For code that users can edit and run in the browser:

````markdown
<div class="code-block">
```jac
with entry {
    print("Hello, World!");
}
```
</div>
````

This will add a "Run" button that executes the code in the browser.

#### Additional Options

You can customize the buttons shown:

- **Run only** (default): `<div class="code-block">`
- **Run and Serve**: `<div class="code-block run-serve">`
- **Serve only**: `<div class="code-block serve-only">`

Example:

````markdown
<div class="code-block run-serve">
```jac
with entry {
    print("This has both Run and Serve buttons!");
}
```
</div>
````

## Project Structure

```
~/blog/
├── docs/                          # Documentation source files
│   ├── index.md                   # Homepage
│   ├── about.md                   # About page
│   ├── posts/                     # Blog posts
│   │   └── welcome.md            # Example post
│   ├── js/                        # JavaScript files
│   │   ├── jac.monarch.js        # Monaco Editor Jac syntax
│   │   ├── run-code.js           # Interactive code execution
│   │   └── pyodide-worker.js     # Pyodide web worker
│   ├── playground/                # Playground resources
│   │   ├── language-configuration.json
│   │   └── jaclang.zip           # (Generated by build hook)
│   ├── extra.css                  # Custom CSS styling
│   └── assets/                    # Images and other assets
├── scripts/                       # Build and serve scripts
│   ├── handle_jac_compile_data.py # Build hook for Jac compiler
│   └── mkdocs_serve.py           # Custom dev server
├── overrides/                     # Theme overrides (optional)
├── jac_syntax_highlighter.py     # Pygments lexer for Jac
├── mkdocs.yml                     # MkDocs configuration
└── README.md                      # This file
```

## How It Works

### Syntax Highlighting

The blog uses two lexers for syntax highlighting:

1. **Pygments Lexer** (`jac_syntax_highlighter.py`): Used for server-side static code highlighting during build
2. **Monaco Monarch Lexer** (`docs/js/jac.monarch.js`): Used for client-side syntax highlighting in the interactive code editor

### Interactive Code Execution

The runnable code blocks use:

1. **Pyodide**: A Python runtime compiled to WebAssembly that runs in the browser
2. **Monaco Editor**: The same code editor that powers VS Code
3. **Web Workers**: For isolated code execution without blocking the UI
4. **SharedArrayBuffer**: For synchronous input handling (requires special CORS headers)

When you click "Run":
1. The code is loaded into Monaco Editor
2. A web worker initializes Pyodide and loads the Jac compiler
3. The code is executed in the browser
4. Output is streamed back to the page in real-time

## Customization

### Changing Theme Colors

Edit the `palette` section in `mkdocs.yml`:

```yaml
theme:
  palette:
    scheme: slate        # Use 'default' for light mode
    primary: black       # Primary color
    accent: orange       # Accent color
```

### Adding Social Links

Edit the `extra.social` section in `mkdocs.yml`:

```yaml
extra:
  social:
    - icon: fontawesome/brands/github
      link: https://github.com/yourusername
    - icon: fontawesome/brands/twitter
      link: https://twitter.com/yourusername
```

### Custom CSS

Add your custom styles to `docs/extra.css`.

## Troubleshooting

### Runnable code blocks not working

- Make sure you're using the custom server: `python scripts/mkdocs_serve.py`
- The custom server sets CORS headers required for SharedArrayBuffer
- Check browser console for errors

### Syntax highlighting not working

- Ensure `jac_syntax_highlighter.py` is installed properly
- Try rebuilding: `mkdocs build --clean`

### Build hook errors

- Make sure you have the Jac compiler installed
- The hook tries to create `docs/playground/jaclang.zip` from your Jac installation
- If you don't have Jac installed, comment out the hook in `mkdocs.yml`

## Dependencies

Core dependencies:
- `mkdocs-material`: Material theme for MkDocs
- `pymdown-extensions`: Markdown extensions for code highlighting
- `pygments`: Syntax highlighting library
- `starlette`: ASGI framework for custom server
- `uvicorn`: ASGI server

Optional dependencies:
- `mkdocs-video`: Video embedding support

## License

[Add your license here]


## Acknowledgments

- Built with [MkDocs](https://www.mkdocs.org/) and [Material for MkDocs](https://squidfunk.github.io/mkdocs-material/)
- Interactive code execution powered by [Pyodide](https://pyodide.org/)
- Code editor powered by [Monaco Editor](https://microsoft.github.io/monaco-editor/)
- Based on the excellent documentation setup from the [Jaseci project](https://github.com/Jaseci-Labs/jaseci)
